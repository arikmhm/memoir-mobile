import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../../../shared/data/models/template.dart';

/// Dither algorithm for B&W photo conversion on thermal output.
enum DitherAlgorithm {
  /// Floyd-Steinberg — 100% error diffusion to 4 neighbors.
  /// Smooth midtone gradients; best for portraits and skin tones.
  floydSteinberg,

  /// Atkinson — 75% error diffusion to 6 neighbors.
  /// Crisper black/white contrast; best for line art and logos,
  /// but produces clumps in continuous-tone midtones.
  atkinson;

  String get key => switch (this) {
    DitherAlgorithm.floydSteinberg => 'fs',
    DitherAlgorithm.atkinson => 'atkinson',
  };

  static DitherAlgorithm fromKey(String? key) => switch (key) {
    'atkinson' => DitherAlgorithm.atkinson,
    _ => DitherAlgorithm.floydSteinberg,
  };
}

/// User-tunable image processing settings for thermal photo printing.
///
/// All values are sendable across isolate boundaries (primitives + enum),
/// so this object can be passed directly into [Isolate.run] closures.
class ProcessingSettings {
  /// Thermal head density level. 0 (lightest) … 8 (darkest), default 2.
  /// Lower values reduce heat-bleed on skin tones; higher values darken
  /// faded prints. Maps to ESC/POS `GS ( E fn=5` + `ESC 7` heating time.
  final int thermalDensity;

  /// Dither algorithm — see [DitherAlgorithm].
  final DitherAlgorithm dither;

  /// Unsharp-mask strength, 0.0 (off) … 1.0 (max). Default 0.25.
  /// Higher values sharpen edges but amplify noise in smooth areas.
  final double sharpenAmount;

  /// Brightness offset added after gamma, -30 … +30 (luminance units).
  /// Default +8 — small lift to compensate for thermal head heat bleed
  /// that darkens light areas. Negative values darken the image.
  final double brightness;

  const ProcessingSettings({
    this.thermalDensity = 2,
    this.dither = DitherAlgorithm.floydSteinberg,
    this.sharpenAmount = 0.25,
    this.brightness = 8.0,
  });
}

/// Result of composite rendering.
class CompositeResult {
  /// Pre-encoded ESC/POS raster bands ready for thermal printing.
  ///
  /// Each element is a self-contained ESC/POS payload:
  /// - Band 0: `ESC @` (reset) — separate so the printer has time
  ///   to process the reset before raster data arrives (critical for USB)
  /// - Band 1..N: `GS v 0` raster band
  /// - Band N (last): last `GS v 0` band + `ESC d` (feed) + `GS V` (cut)
  ///
  /// Splitting into bands lets the Dart layer send each band as a
  /// separate Bluetooth write, giving the native pacing layer time
  /// to drain each ~4.6 KB band before queuing the next. This prevents
  /// the printer's receive buffer from underrunning mid-print.
  final List<Uint8List> printBands;

  /// Path to the hi-res composite for digital download (null if not requested).
  final String? digitalFilePath;

  const CompositeResult({
    required this.printBands,
    this.digitalFilePath,
  });
}

/// Service that renders a composite image from template + captured photos
/// using the `image` library (pure Dart — isolate-safe).
///
/// Template is always 576px wide (matching 80mm thermal printer @ 203 DPI).
/// Photos are resized to slot dimensions before compositing → low memory.
/// Digital copy renders as B&W dithered (same as print, 1× scale).
class CompositeRenderService {
  static const int _printScale = 1; // 576px native

  /// Render composite images in a background isolate.
  ///
  /// Returns ESC/POS bytes + optional digital file path.
  /// Runs entirely off the main thread — zero GC pressure on UI.
  ///
  /// **File paths (not bytes)** are passed to the isolate so the main
  /// isolate never loads photo/bg/overlay bytes (~12-20 MB).  All file
  /// I/O happens inside the worker isolate via `dart:io` (isolate-safe).
  Future<CompositeResult> render({
    required Template template,
    required Map<int, String> capturedPhotos,
    required bool hasDigitalCopy,
    ProcessingSettings settings = const ProcessingSettings(),
  }) async {
    final tempDir = await getTemporaryDirectory();
    final outputDir = '${tempDir.path}/composite';
    await Directory(outputDir).create(recursive: true);

    // Serialize template data for isolate (can't pass non-sendable objects).
    final templateJson = template.toJson();

    // Collect file paths only — NO file I/O on main thread.
    final photoSlots = template.elements
        .where((e) => e.type == 'PHOTO_SLOT')
        .toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    final photoPathsBySlot = <int, String>{};
    for (var i = 0; i < photoSlots.length; i++) {
      final path = capturedPhotos[i];
      if (path != null) {
        photoPathsBySlot[i] = path;
      }
    }

    return Isolate.run(() => _renderInIsolate(
          templateJson: templateJson,
          photoPathsBySlot: photoPathsBySlot,
          backgroundPath: template.localBackgroundPath,
          outputDir: outputDir,
          hasDigitalCopy: hasDigitalCopy,
          settings: settings,
        ));
  }

  /// Render a single photo through the same B&W dither pipeline used for
  /// thermal printing, returning PNG bytes for on-screen preview.
  ///
  /// Used by the live-tuning UI: the user captures a photo, then adjusts
  /// settings and sees the rendered B&W result update immediately, so they
  /// can dial in density/dither/sharpen without burning paper.
  ///
  /// Output width matches the print canvas (576px) so dithering looks the
  /// same as the real print. Height follows the photo's aspect ratio.
  /// All heavy work runs in a background isolate.
  Future<Uint8List> previewSinglePhoto({
    required String photoPath,
    required ProcessingSettings settings,
  }) {
    return Isolate.run(() => _previewInIsolate(
          photoPath: photoPath,
          settings: settings,
        ));
  }

  /// Isolate worker for [previewSinglePhoto].
  static Uint8List _previewInIsolate({
    required String photoPath,
    required ProcessingSettings settings,
  }) {
    final canvas = _renderPhotoCanvas(photoPath: photoPath, settings: settings);
    return Uint8List.fromList(img.encodePng(canvas));
  }

  /// Render a single photo into ESC/POS print bands.
  ///
  /// Same pipeline as a real session ([render]) but for one photo without
  /// a template. Used by the "Cetak Test" button on the image-processing
  /// page so the operator can validate density/dither/sharpen against the
  /// physical printer without burning a full session.
  Future<List<Uint8List>> printPreviewPhoto({
    required String photoPath,
    required ProcessingSettings settings,
  }) {
    return Isolate.run(() => _printPreviewInIsolate(
          photoPath: photoPath,
          settings: settings,
        ));
  }

  /// Isolate worker for [printPreviewPhoto].
  static List<Uint8List> _printPreviewInIsolate({
    required String photoPath,
    required ProcessingSettings settings,
  }) {
    final canvas = _renderPhotoCanvas(photoPath: photoPath, settings: settings);
    return _encodeEscPosRasterBands(canvas, settings);
  }

  /// Shared core: decode a photo, apply the dither pipeline, return canvas.
  /// Used by both preview (encode to PNG) and print (encode to ESC/POS).
  static img.Image _renderPhotoCanvas({
    required String photoPath,
    required ProcessingSettings settings,
  }) {
    final photo = img.decodeImage(File(photoPath).readAsBytesSync());
    if (photo == null) {
      throw Exception('Gagal memproses foto preview.');
    }

    // Match the print canvas width so dither density looks identical.
    const previewW = 576;
    final aspect = photo.height / photo.width;
    final previewH = (previewW * aspect).round();

    final canvas = img.Image(
      width: previewW,
      height: previewH,
      numChannels: 4,
    );
    img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));

    _drawPhotoDithered(canvas, photo, 0, 0, previewW, previewH, settings);

    return canvas;
  }

  /// Pure computation — runs in a separate isolate.
  ///
  /// **Single B&W canvas architecture**: both print and digital are built
  /// from the same B&W dithered canvas. Each photo is decoded → downscaled
  /// → drawn dithered → freed before the next photo, so only **one photo
  /// lives in memory at a time**.
  ///
  /// Digital copy is 1× scale B&W (not 3× color), reducing:
  /// - Rendering time by ~70% (no 3x upscaling, no color processing)
  /// - Memory peak by ~150MB (no separate color canvas)
  /// - File size by ~80% (B&W PNG vs color)
  ///
  /// Additional optimizations:
  /// - **Float64List** for dithering buffer (not boxed `List<double>`)
  /// - **Auto-levels**: histogram stretch (0.5% clip) recovers detail
  ///   from narrow-range selfies before tone adjustments
  /// - **Gamma 0.72 + brightness +8**: stronger lift for thermal paper
  /// - **In-buffer sharpen**: 3×3 convolution on Float64List (strength
  ///   from [ProcessingSettings.sharpenAmount])
  /// - **User-selectable dithering**: Floyd-Steinberg (smooth midtones)
  ///   or Atkinson (crisp extremes) per [ProcessingSettings.dither]
  static CompositeResult _renderInIsolate({
    required Map<String, dynamic> templateJson,
    required Map<int, String> photoPathsBySlot,
    required String? backgroundPath,
    required String outputDir,
    required bool hasDigitalCopy,
    required ProcessingSettings settings,
  }) {
    final template = Template.fromJson(templateJson);
    final canvasW = template.width;
    final canvasH = template.height;

    // Decode background inside isolate — small template asset.
    img.Image? background;
    if (backgroundPath != null && File(backgroundPath).existsSync()) {
      background = img.decodeImage(File(backgroundPath).readAsBytesSync());
    }

    // ── Create single B&W canvas ──
    final canvas = img.Image(
      width: canvasW,
      height: canvasH,
      numChannels: 4,
    );
    img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));

    // Background on canvas.
    if (background != null) {
      final bg = img.copyResize(
        background,
        width: canvasW,
        height: canvasH,
      );
      img.compositeImage(canvas, bg);
    }
    background = null; // free — no longer needed

    // Sort elements by sequence (z-order).
    final sortedElements = List<TemplateElement>.from(template.elements)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final photoSlots =
        sortedElements.where((e) => e.type == 'PHOTO_SLOT').toList();

    // ── Single-pass: draw all elements on canvas ──
    for (final el in sortedElements) {
      switch (el.type) {
        case 'PHOTO_SLOT':
          final slotIndex = photoSlots.indexOf(el);
          final photoPath = photoPathsBySlot[slotIndex];
          if (photoPath == null || !File(photoPath).existsSync()) continue;

          // Read + decode photo inside isolate — scoped to this iteration.
          // JPEG bytes (~3-5 MB) never touch the main isolate heap.
          var photo = img.decodeImage(File(photoPath).readAsBytesSync());
          if (photo == null) continue;

          // Pre-downscale immediately to limit memory.
          // Target: 1.5× the slot dimension.
          final targetW = (el.width * 1.5).round();
          if (photo.width > targetW) {
            photo = img.copyResize(
              photo,
              width: targetW,
              interpolation: img.Interpolation.average,
            );
          }

          // Draw — color (dithering happens during print encoding).
          _drawPhotoColor(
            canvas,
            photo,
            el.x,
            el.y,
            el.width,
            el.height,
          );
          // photo goes out of scope → eligible for GC before next decode

        case 'TEXT':
          _drawText(
            canvas,
            el,
            el.x,
            el.y,
            el.width,
            el.height,
            _printScale,
          );

        case 'IMAGE':
          break;
      }
    }

    // ── Encode ESC/POS raster directly from canvas ──
    // Skip PNG encode→decode→imageRaster cycle entirely.
    // Manual bit-packing: pixel 0 (black) → bit 1 (print dot).
    // Returns a list of band payloads for per-band Bluetooth writes.
    // If hasDigitalCopy, omit cut so the caller can append a QR band first.
    final printBands = _encodeEscPosRasterBands(canvas, settings, addCut: !hasDigitalCopy);

    // Digital PNG (B&W, 1× scale) only if needed.
    String? digitalPath;
    if (hasDigitalCopy) {
      digitalPath = '$outputDir/composite_digital.png';
      File(digitalPath).writeAsBytesSync(img.encodePng(canvas));
    }

    return CompositeResult(
      printBands: printBands,
      digitalFilePath: digitalPath,
    );
  }

  /// Draw a photo with full preprocessing + dithering to a 1-bit canvas.
  ///
  /// **Pipeline** (all computed in [Float64List] buffers, no intermediate
  /// Images):
  ///
  /// 1. Center-crop + resize + mirror → single Image
  /// 2. BT.709 Grayscale → Float64List + histogram (1 pass)
  /// 3. Auto-levels (histogram stretch, 0.5% clip) → in-place
  /// 4. Gamma(0.72) + brightness ([settings.brightness]) + contrast(1.35)
  /// 5. Sharpen 3×3 unsharp (amount = [settings.sharpenAmount])
  /// 6. Dither (algorithm = [settings.dither]) → write to canvas pixels
  ///
  /// **Why auto-levels?**
  /// Real-world selfies often have narrow luminance range (e.g. 40-210
  /// instead of 0-255). Histogram stretch maps the actual range to full
  /// 0-255 before tone adjustments, recovering shadow/highlight detail
  /// that would otherwise be lost.
  static void _drawPhotoDithered(
    img.Image canvas,
    img.Image photo,
    int x,
    int y,
    int w,
    int h,
    ProcessingSettings settings,
  ) {
    final fitted = _fitToSlot(photo, w, h);
    final pw = fitted.width;
    final ph = fitted.height;
    final totalPixels = pw * ph;

    // ── Step 1: BT.709 Grayscale → Float64List + histogram ──
    // Single pass converts RGB to luminance and builds a 256-bin
    // histogram simultaneously — needed for auto-levels in step 2.
    final lum = Float64List(totalPixels);
    final hist = List<int>.filled(256, 0);
    final rawBytes = fitted.toUint8List();
    final nc = fitted.numChannels; // 3 for JPEG, 4 for PNG
    final stride = pw * nc;
    for (var py = 0; py < ph; py++) {
      final rowOff = py * pw;
      final byteRow = py * stride;
      for (var px = 0; px < pw; px++) {
        final bi = byteRow + px * nc;
        // ITU-R BT.709 luminance (same as img.grayscale).
        final v = 0.2126 * rawBytes[bi]
            + 0.7152 * rawBytes[bi + 1]
            + 0.0722 * rawBytes[bi + 2];
        lum[rowOff + px] = v;
        hist[v.round().clamp(0, 255)]++;
      }
    }
    // fitted Image is no longer needed — eligible for GC.

    // ── Step 2: Auto-levels + Gamma + Contrast (single pass) ──
    // Histogram stretch clips 0.5% of shadow/highlight extremes for
    // noise robustness, then maps the actual luminance range to 0-255.
    // Gamma, brightness offset, and contrast are fused into the same
    // loop to avoid an extra pass over the buffer.
    final clipCount = (totalPixels * 0.005).round();
    var cumLow = 0;
    var loVal = 0;
    for (var i = 0; i < 256; i++) {
      cumLow += hist[i];
      if (cumLow >= clipCount) {
        loVal = i;
        break;
      }
    }
    var cumHigh = 0;
    var hiVal = 255;
    for (var i = 255; i >= 0; i--) {
      cumHigh += hist[i];
      if (cumHigh >= clipCount) {
        hiVal = i;
        break;
      }
    }
    final lo = loVal.toDouble();
    final scale = hiVal > loVal ? 255.0 / (hiVal - loVal) : 1.0;
    for (var i = 0; i < totalPixels; i++) {
      // Auto-levels: stretch actual range to 0-255.
      var v = (lum[i] - lo) * scale;
      if (v < 0.0) v = 0.0;
      if (v > 255.0) v = 255.0;
      // Gamma 0.72 — stronger midtone lift for thermal paper that
      // prints darker than screen preview. Lifts midpoint 128 → ~151.
      v = 255.0 * math.pow(v / 255.0, 0.72);
      // Brightness offset from user settings — compensates for the
      // thermal head heat bleed that darkens light areas.
      v += settings.brightness;
      // Contrast 1.35 — tighten dynamic range around midpoint.
      // Slightly less than old 1.4 because auto-levels already
      // expanded the range.
      v = (v - 128.0) * 1.35 + 128.0;
      if (v < 0.0) v = 0.0;
      if (v > 255.0) v = 255.0;
      lum[i] = v;
    }

    // ── Step 3: Sharpen on Float64List (3×3 unsharp kernel) ──
    // Kernel [0,-1,0, -1,5,-1, 0,-1,0]. Strength from user settings.
    // Higher values preserve edge detail through 1-bit quantization,
    // but also amplify noise in smooth midtone areas (skin) that
    // dithering then smears as visible halos.
    final sharpenAmt = settings.sharpenAmount;
    final sharp = Float64List(totalPixels);
    for (var py = 0; py < ph; py++) {
      final rowOff = py * pw;
      for (var px = 0; px < pw; px++) {
        final c = lum[rowOff + px];
        // Clamped neighbors (replicate border — same as image library).
        final t = lum[(py > 0 ? py - 1 : 0) * pw + px];
        final b = lum[(py < ph - 1 ? py + 1 : py) * pw + px];
        final l = lum[rowOff + (px > 0 ? px - 1 : 0)];
        final r = lum[rowOff + (px < pw - 1 ? px + 1 : px)];
        final conv = 5.0 * c - t - b - l - r;
        var v = (1.0 - sharpenAmt) * c + sharpenAmt * conv;
        if (v < 0.0) v = 0.0;
        if (v > 255.0) v = 255.0;
        sharp[rowOff + px] = v;
      }
    }
    // lum buffer is no longer needed (sharp is the working buffer now).

    // ── Step 4: Dither → write directly to canvas ──
    // Algorithm selected by user via [ProcessingSettings.dither]:
    //   - Floyd-Steinberg: 100% error diffusion, smooth midtones.
    //   - Atkinson: 75% error diffusion, crisper extremes but clumps
    //     in continuous-tone midtones (visible "belobor" on skin).
    switch (settings.dither) {
      case DitherAlgorithm.floydSteinberg:
        _ditherFloydSteinberg(canvas, sharp, x, y, pw, ph);
      case DitherAlgorithm.atkinson:
        _ditherAtkinson(canvas, sharp, x, y, pw, ph);
    }
  }

  /// Floyd-Steinberg error diffusion (100% error distributed to 4 neighbors):
  ///
  ///              *     7/16
  ///   3/16    5/16    1/16
  ///
  /// Best for portraits / skin tones — smooth midtone gradients.
  static void _ditherFloydSteinberg(
    img.Image canvas,
    Float64List sharp,
    int x,
    int y,
    int pw,
    int ph,
  ) {
    const double fs7 = 7.0 / 16.0;
    const double fs3 = 3.0 / 16.0;
    const double fs5 = 5.0 / 16.0;
    const double fs1 = 1.0 / 16.0;
    for (var py = 0; py < ph; py++) {
      final rowOff = py * pw;
      final canvasY = y + py;
      for (var px = 0; px < pw; px++) {
        final idx = rowOff + px;
        final oldVal = sharp[idx];
        final newVal = oldVal > 127.0 ? 255.0 : 0.0;
        final err = oldVal - newVal;

        final bw = newVal.toInt();
        canvas.setPixelRgba(x + px, canvasY, bw, bw, bw, 255);

        if (px + 1 < pw) sharp[idx + 1] += err * fs7;
        if (py + 1 < ph) {
          final nextRow = (py + 1) * pw;
          if (px > 0) sharp[nextRow + px - 1] += err * fs3;
          sharp[nextRow + px] += err * fs5;
          if (px + 1 < pw) sharp[nextRow + px + 1] += err * fs1;
        }
      }
    }
  }

  /// Atkinson error diffusion (75% error / 8 distributed to 6 neighbors):
  ///
  ///              *    +1/8   +1/8
  ///   +1/8    +1/8   +1/8
  ///           +1/8
  ///
  /// 25% of error is discarded → blacks stay black, whites stay white.
  /// Best for line art / high-contrast logos. On photos, the discarded
  /// error accumulates as clumps in skin midtones.
  static void _ditherAtkinson(
    img.Image canvas,
    Float64List sharp,
    int x,
    int y,
    int pw,
    int ph,
  ) {
    const double atkC = 1.0 / 8.0;
    for (var py = 0; py < ph; py++) {
      final rowOff = py * pw;
      final canvasY = y + py;
      for (var px = 0; px < pw; px++) {
        final idx = rowOff + px;
        final oldVal = sharp[idx];
        final newVal = oldVal > 127.0 ? 255.0 : 0.0;
        final err = (oldVal - newVal) * atkC;

        final bw = newVal.toInt();
        canvas.setPixelRgba(x + px, canvasY, bw, bw, bw, 255);

        if (px + 1 < pw) sharp[idx + 1] += err;
        if (px + 2 < pw) sharp[idx + 2] += err;
        if (py + 1 < ph) {
          final nextRow = (py + 1) * pw;
          if (px > 0) sharp[nextRow + px - 1] += err;
          sharp[nextRow + px] += err;
          if (px + 1 < pw) sharp[nextRow + px + 1] += err;
        }
        if (py + 2 < ph) {
          sharp[(py + 2) * pw + px] += err;
        }
      }
    }
  }

  /// Draw a color photo directly to canvas without dithering.
  ///
  /// Used for digital copy (upload) — preserves full color information.
  /// Dithering happens later during print encoding if needed.
  static void _drawPhotoColor(
    img.Image canvas,
    img.Image photo,
    int x,
    int y,
    int w,
    int h,
  ) {
    final fitted = _fitToSlot(photo, w, h);
    img.compositeImage(canvas, fitted, dstX: x, dstY: y);
  }

  /// Center-crop, resize, and mirror a photo to fill a slot.
  ///
  /// Equivalent to [BoxFit.cover] + horizontal flip (selfie mirror).
  /// Returns a single Image sized exactly w × h — shared by both
  /// print (dithered) and digital (color) paths.
  static img.Image _fitToSlot(img.Image photo, int w, int h) {
    final srcAspect = photo.width / photo.height;
    final dstAspect = w / h;

    int srcX, srcY, srcW, srcH;
    if (srcAspect > dstAspect) {
      srcH = photo.height;
      srcW = (srcH * dstAspect).round();
      srcX = ((photo.width - srcW) / 2).round();
      srcY = 0;
    } else {
      srcW = photo.width;
      srcH = (srcW / dstAspect).round();
      srcX = 0;
      srcY = ((photo.height - srcH) / 2).round();
    }

    final cropped = img.copyCrop(
      photo,
      x: srcX,
      y: srcY,
      width: srcW,
      height: srcH,
    );
    final resized = img.copyResize(cropped, width: w, height: h);
    return img.flipHorizontal(resized);
  }

  /// Build the printer-init bytes (reset + density-setting) for band 0.
  ///
  /// Sent before raster data via two complementary ESC/POS commands so it
  /// works across both Epson-spec and generic Chinese clones (XPrinter,
  /// POS-58/80, Goojprt, etc.):
  ///
  /// - `GS ( E pL pH fn=5 d` — Epson standard "set print density" (d: 0-8,
  ///   0 = -50% (lightest), 4 = default, 8 = +50% (darkest)).
  /// - `ESC 7 n1 n2 n3` — generic Chinese spec "printing parameters"
  ///   (n2 = heating time in 10µs units; lower = lighter).
  ///
  /// Order: `ESC @` (reset) → `GS ( E ... fn=5` → `ESC 7 ...`.
  /// Both commands are no-ops on printers that don't implement them,
  /// so sending both maximizes compatibility.
  static Uint8List _buildInitBytes(int thermalDensity) {
    final density = thermalDensity.clamp(0, 8);
    // Heating time → map 0..8 to 50..150 (10µs units)
    final heatingTime = 50 + (density * 12);

    return Uint8List.fromList([
      // ESC @ — reset printer
      0x1B, 0x40,
      // GS ( E pL=2 pH=0 fn=5 d — Epson "set print density"
      0x1D, 0x28, 0x45, 0x02, 0x00, 0x05, density,
      // ESC 7 n1 n2 n3 — generic "set printing parameters"
      // n1=max heating dots (7 = default, 64 dots),
      // n2=heating time in 10µs units (lower = lighter),
      // n3=heating interval (2 = default, 20µs).
      0x1B, 0x37, 0x07, heatingTime, 0x02,
    ]);
  }

  /// Band height for raster encoding.
  ///
  /// Each band is a separate `GS v 0` command. Smaller bands ensure the
  /// printer's receive buffer holds the entire band before printing it,
  /// preventing buffer underrun that causes horizontal banding over BT.
  ///
  /// 64 lines × 72 bytes/row = 4,608 bytes per band. At 2 KB/chunk with
  /// 8 ms pacing, each band takes ~20 ms to transmit — well under the
  /// printer's ~100 ms mechanical cycle time per 64 lines.
  static const int _bandHeight = 64;

  /// Encode ESC/POS raster bytes from a color canvas, applying the full
  /// image-processing pipeline from [ProcessingSettings] before encoding.
  ///
  /// **Pipeline** (mirrors [_drawPhotoDithered] so preview = print output):
  /// 1. BT.709 grayscale + histogram (full image, one pass)
  /// 2. Auto-levels (0.5% clip) + gamma(0.72) + brightness + contrast(1.35)
  /// 3. Sharpen 3×3 unsharp mask ([ProcessingSettings.sharpenAmount])
  /// 4. Band-by-band dithering using selected algorithm (FS or Atkinson)
  /// 5. Pack bits → GS v 0 raster bands
  ///
  /// All four [ProcessingSettings] fields are applied:
  /// - [ProcessingSettings.thermalDensity] → ESC/POS init bytes (band 0)
  /// - [ProcessingSettings.brightness] → luminance offset (step 2)
  /// - [ProcessingSettings.sharpenAmount] → unsharp mask (step 3)
  /// - [ProcessingSettings.dither] → FS or Atkinson (step 4)
  static List<Uint8List> _encodeEscPosRasterBands(
    img.Image colorCanvas,
    ProcessingSettings settings, {
    bool addCut = true,
  }) {
    final w = colorCanvas.width;
    final h = colorCanvas.height;
    final bytesPerRow = (w + 7) ~/ 8;
    final numBands = (h + _bandHeight - 1) ~/ _bandHeight;
    final pixels = colorCanvas.toUint8List();
    final rowStride = w * 4;
    final totalPixels = w * h;

    // ── Step 1: BT.709 Grayscale + histogram (full image) ──
    final lum = Float64List(totalPixels);
    final hist = List<int>.filled(256, 0);
    for (var y = 0; y < h; y++) {
      final rowStart = y * rowStride;
      final lumRowStart = y * w;
      for (var px = 0; px < w; px++) {
        final pxIdx = rowStart + px * 4;
        final v = 0.2126 * pixels[pxIdx]
            + 0.7152 * pixels[pxIdx + 1]
            + 0.0722 * pixels[pxIdx + 2];
        lum[lumRowStart + px] = v;
        hist[v.round().clamp(0, 255)]++;
      }
    }

    // ── Step 2: Auto-levels + Gamma 0.72 + Brightness + Contrast 1.35 ──
    final clipCount = (totalPixels * 0.005).round();
    var cumLow = 0;
    var loVal = 0;
    for (var i = 0; i < 256; i++) {
      cumLow += hist[i];
      if (cumLow >= clipCount) { loVal = i; break; }
    }
    var cumHigh = 0;
    var hiVal = 255;
    for (var i = 255; i >= 0; i--) {
      cumHigh += hist[i];
      if (cumHigh >= clipCount) { hiVal = i; break; }
    }
    final lo = loVal.toDouble();
    final levelScale = hiVal > loVal ? 255.0 / (hiVal - loVal) : 1.0;
    for (var i = 0; i < totalPixels; i++) {
      var v = (lum[i] - lo) * levelScale;
      if (v < 0.0) v = 0.0;
      if (v > 255.0) v = 255.0;
      v = 255.0 * math.pow(v / 255.0, 0.72);
      v += settings.brightness;
      v = (v - 128.0) * 1.35 + 128.0;
      if (v < 0.0) v = 0.0;
      if (v > 255.0) v = 255.0;
      lum[i] = v;
    }

    // ── Step 3: Sharpen 3×3 unsharp mask ──
    final sharpenAmt = settings.sharpenAmount;
    final sharp = Float64List(totalPixels);
    for (var py = 0; py < h; py++) {
      final rowOff = py * w;
      for (var px = 0; px < w; px++) {
        final c = lum[rowOff + px];
        final t = lum[(py > 0 ? py - 1 : 0) * w + px];
        final b = lum[(py < h - 1 ? py + 1 : py) * w + px];
        final l = lum[rowOff + (px > 0 ? px - 1 : 0)];
        final r = lum[rowOff + (px < w - 1 ? px + 1 : px)];
        final conv = 5.0 * c - t - b - l - r;
        var v = (1.0 - sharpenAmt) * c + sharpenAmt * conv;
        if (v < 0.0) v = 0.0;
        if (v > 255.0) v = 255.0;
        sharp[rowOff + px] = v;
      }
    }

    // ── Band encoding ──
    final bands = <Uint8List>[];

    // Band 0: ESC @ reset + density-setting commands — sent as a separate
    // band so the printer has time to process them before raster data
    // arrives. Over USB bulk transfer, data arrivals are <1ms apart;
    // without this separation the GS v 0 bytes arrive before the printer
    // finishes initializing and get printed as random text characters.
    bands.add(_buildInitBytes(settings.thermalDensity));

    for (var band = 0; band < numBands; band++) {
      final startY = band * _bandHeight;
      final bandH = math.min(_bandHeight, h - startY);
      final isLast = band == numBands - 1;

      // Size: GS v 0 header(8) + pixel data + optional feed(3)+cut(4)
      final pixelBytes = bytesPerRow * bandH;
      var size = 8 + pixelBytes;
      if (isLast && addCut) size += 3 + 4; // ESC d + GS V

      final buf = Uint8List(size);
      var pos = 0;

      // GS v 0 m xL xH yL yH — print raster bit image.
      buf[pos++] = 0x1D;
      buf[pos++] = 0x76;
      buf[pos++] = 0x30;
      buf[pos++] = 0x00; // m = normal density
      buf[pos++] = bytesPerRow & 0xFF;
      buf[pos++] = (bytesPerRow >> 8) & 0xFF;
      buf[pos++] = bandH & 0xFF;
      buf[pos++] = (bandH >> 8) & 0xFF;

      // ── Step 4: Dither this band using selected algorithm ──
      // Copy band from preprocessed buffer, then dither in-place.
      final bandLum = Float64List(w * bandH);
      for (var by = 0; by < bandH; by++) {
        final src = (startY + by) * w;
        final dst = by * w;
        for (var px = 0; px < w; px++) {
          bandLum[dst + px] = sharp[src + px];
        }
      }

      switch (settings.dither) {
        case DitherAlgorithm.floydSteinberg:
          _ditherBandFloydSteinberg(bandLum, w, bandH);
        case DitherAlgorithm.atkinson:
          _ditherBandAtkinson(bandLum, w, bandH);
      }

      // ── Step 5: Pack dithered bits ──
      for (var by = 0; by < bandH; by++) {
        final lumRowStart = by * w;
        for (var bx = 0; bx < bytesPerRow; bx++) {
          var byte = 0;
          final baseX = bx * 8;
          for (var bit = 0; bit < 8; bit++) {
            final px = baseX + bit;
            if (px < w && bandLum[lumRowStart + px] < 128.0) {
              byte |= (0x80 >> bit);
            }
          }
          buf[pos++] = byte;
        }
      }

      // Feed + cut on last band (skipped when caller will append a QR band).
      if (isLast && addCut) {
        buf[pos++] = 0x1B;
        buf[pos++] = 0x64;
        buf[pos++] = 0x03;
        buf[pos++] = 0x1D;
        buf[pos++] = 0x56;
        buf[pos++] = 0x41;
        buf[pos++] = 0x03;
      }

      bands.add(buf);
    }

    return bands;
  }

  /// Floyd-Steinberg error diffusion on a Float64List band buffer (in-place).
  static void _ditherBandFloydSteinberg(Float64List buf, int w, int h) {
    const double fs7 = 7.0 / 16.0;
    const double fs3 = 3.0 / 16.0;
    const double fs5 = 5.0 / 16.0;
    const double fs1 = 1.0 / 16.0;
    for (var by = 0; by < h; by++) {
      final rowOff = by * w;
      for (var px = 0; px < w; px++) {
        final idx = rowOff + px;
        final oldVal = buf[idx];
        final newVal = oldVal > 127.0 ? 255.0 : 0.0;
        final err = oldVal - newVal;
        buf[idx] = newVal;
        if (px + 1 < w) buf[idx + 1] += err * fs7;
        if (by + 1 < h) {
          final nextRow = (by + 1) * w;
          if (px > 0) buf[nextRow + px - 1] += err * fs3;
          buf[nextRow + px] += err * fs5;
          if (px + 1 < w) buf[nextRow + px + 1] += err * fs1;
        }
      }
    }
  }

  /// Atkinson error diffusion on a Float64List band buffer (in-place).
  static void _ditherBandAtkinson(Float64List buf, int w, int h) {
    const double atkC = 1.0 / 8.0;
    for (var by = 0; by < h; by++) {
      final rowOff = by * w;
      for (var px = 0; px < w; px++) {
        final idx = rowOff + px;
        final oldVal = buf[idx];
        final newVal = oldVal > 127.0 ? 255.0 : 0.0;
        final err = (oldVal - newVal) * atkC;
        buf[idx] = newVal;
        if (px + 1 < w) buf[idx + 1] += err;
        if (px + 2 < w) buf[idx + 2] += err;
        if (by + 1 < h) {
          final nextRow = (by + 1) * w;
          if (px > 0) buf[nextRow + px - 1] += err;
          buf[nextRow + px] += err;
          if (px + 1 < w) buf[nextRow + px + 1] += err;
        }
        if (by + 2 < h) buf[(by + 2) * w + px] += err;
      }
    }
  }

  /// Encode ESC/POS raster bytes from a B&W print canvas using band-based
  /// `GS v 0` commands. [DEPRECATED — use the color version above instead]
  ///
  /// **Why bands?** Over Bluetooth SPP (~100-200 KB/s), a single 57 KB
  /// raster command causes buffer underrun: the printer starts printing
  /// before all data arrives, runs out of buffered data mid-print, pauses
  /// until more data arrives → the thermal head cools → visible
  /// horizontal line when printing resumes.
  ///
  /// Band-based encoding splits the image into 128-line chunks, each as
  /// a separate `GS v 0` command (~9 KB). Each band is small enough to
  /// be fully buffered before the printer starts printing it. Between
  /// bands, `GS v 0` positions the print head immediately below the
  /// image — no gap, no extra line feed.
  ///
  /// Over USB this is unnecessary (57 KB arrives in <1 ms), but the
  /// overhead is negligible (~56 extra header bytes for 7 bands).
  /// Encode a B&W canvas into a list of self-contained ESC/POS band payloads.
  ///
  /// Each band is a separate `GS v 0` command wrapped so that:
  /// - Band 0 starts with `ESC @` (reset).
  /// - The last band ends with `ESC d` (feed) + `GS V` (cut).
  ///
  /// The caller sends each band as an independent Bluetooth write so the
  /// native pacing layer can drain the ~4.6 KB payload before the next.
  static List<Uint8List> _encodeEscPosRasterBandsBW(
    img.Image bwCanvas,
    ProcessingSettings settings,
  ) {
    final w = bwCanvas.width;
    final h = bwCanvas.height;
    final bytesPerRow = (w + 7) ~/ 8;
    final numBands = (h + _bandHeight - 1) ~/ _bandHeight;

    // Pixel buffer — toUint8List() gives zero-copy RGBA access.
    final pixels = bwCanvas.toUint8List();
    final rowStride = w * 4; // 4 bytes per pixel (RGBA)

    final bands = <Uint8List>[];

    // Band 0: ESC @ reset + density-setting commands — sent as a separate
    // band so the printer has time to process them before raster data
    // arrives. Over USB bulk transfer, data arrivals are <1ms apart;
    // without this separation the GS v 0 bytes arrive before the printer
    // finishes initializing and get printed as random text characters.
    bands.add(_buildInitBytes(settings.thermalDensity));

    for (var band = 0; band < numBands; band++) {
      final startY = band * _bandHeight;
      final bandH = math.min(_bandHeight, h - startY);
      final isLast = band == numBands - 1;

      // Size: GS v 0 header(8) + pixel data + optional feed(3)+cut(4)
      final pixelBytes = bytesPerRow * bandH;
      var size = 8 + pixelBytes;
      if (isLast) size += 3 + 4; // ESC d + GS V

      final buf = Uint8List(size);
      var pos = 0;

      // GS v 0 m xL xH yL yH — print raster bit image.
      buf[pos++] = 0x1D;
      buf[pos++] = 0x76;
      buf[pos++] = 0x30;
      buf[pos++] = 0x00; // m = normal density
      buf[pos++] = bytesPerRow & 0xFF;
      buf[pos++] = (bytesPerRow >> 8) & 0xFF;
      buf[pos++] = bandH & 0xFF;
      buf[pos++] = (bandH >> 8) & 0xFF;

      // Pack pixels: bit 1 = black (print), bit 0 = white.
      for (var y = startY; y < startY + bandH; y++) {
        final rowStart = y * rowStride;
        for (var bx = 0; bx < bytesPerRow; bx++) {
          var byte = 0;
          final baseX = bx * 8;
          for (var bit = 0; bit < 8; bit++) {
            final px = baseX + bit;
            if (px < w) {
              if (pixels[rowStart + px * 4] < 128) {
                byte |= (0x80 >> bit);
              }
            }
          }
          buf[pos++] = byte;
        }
      }

      // Feed + cut on last band.
      if (isLast) {
        // ESC d n — feed n lines.
        buf[pos++] = 0x1B;
        buf[pos++] = 0x64;
        buf[pos++] = 0x03;
        // GS V A n — partial cut.
        buf[pos++] = 0x1D;
        buf[pos++] = 0x56;
        buf[pos++] = 0x41;
        buf[pos++] = 0x03;
      }

      bands.add(buf);
    }

    return bands;
  }

  /// Draw a text element using built-in bitmap font.
  /// Draw a text element using built-in bitmap font.
  static void _drawText(
    img.Image canvas,
    TemplateElement el,
    int x,
    int y,
    int w,
    int h,
    int scale,
  ) {
    final rawText = el.properties['content'] as String? ??
        el.properties['text'] as String? ??
        '';
    final text = _resolveVariables(rawText);
    if (text.isEmpty) return;

    final colorHex = el.properties['color'] as String?;
    final color = _parseHexColor(colorHex) ?? img.ColorRgba8(0, 0, 0, 255);

    // Use the largest built-in font for best quality.
    // image library ships arial14 and arial24 as built-in.
    final font = img.arial24;

    img.drawString(
      canvas,
      text,
      font: font,
      x: x,
      y: y,
      color: color,
    );
  }

  static String _resolveVariables(String text) {
    if (!text.contains('{{')) return text;
    final now = DateTime.now();
    const months = [
      '',
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final tanggal =
        '${now.day.toString().padLeft(2, '0')} ${months[now.month]} ${now.year}';
    final waktu =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final tanggalWaktu =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} $waktu';
    return text
        .replaceAll('{{tanggal}}', tanggal)
        .replaceAll('{{waktu}}', waktu)
        .replaceAll('{{tanggal_waktu}}', tanggalWaktu);
  }

  /// Parse #RRGGBB or #AARRGGBB hex string to img.Color.
  static img.Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    hex = hex.replaceFirst('#', '');
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    if (hex.length == 6) {
      return img.ColorRgba8(
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
        255,
      );
    }
    if (hex.length == 8) {
      return img.ColorRgba8(
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
        (value >> 24) & 0xFF,
      );
    }
    return null;
  }
}
