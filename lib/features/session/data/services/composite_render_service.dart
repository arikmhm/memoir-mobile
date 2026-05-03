import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../../../shared/data/models/template.dart';

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
///
/// For digital copy, renders at 3× (1728px) for decent screen quality.
class CompositeRenderService {
  static const int _printScale = 1; // 576px native
  static const int _digitalScale = 3; // 1728px

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
        ));
  }

  /// Pure computation — runs in a separate isolate.
  ///
  /// **Single-pass dual-canvas architecture**: both print (1×) and digital
  /// (3×) canvases are built simultaneously in one element iteration.
  /// Each photo is decoded → downscaled → drawn on both canvases → freed
  /// before the next photo, so only **one photo lives in memory at a time**.
  ///
  /// Previous approach kept all decoded photos in a map (~4 × 48MB = 192MB
  /// peak), causing heavy GC storms. New approach: ~52MB peak per photo
  /// (48MB raw decode + 4MB downscaled), dropping between photos.
  ///
  /// Additional optimizations:
  /// - **Float64List** for dithering buffer (not boxed `List<double>`)
  /// - **Auto-levels**: histogram stretch (0.5% clip) recovers detail
  ///   from narrow-range selfies before tone adjustments
  /// - **Gamma 0.72 + brightness +8**: stronger lift for thermal paper
  /// - **In-buffer sharpen**: 3×3 convolution (amount 0.5) on Float64List
  /// - **Atkinson dithering**: 75% error diffusion produces crisper
  ///   B&W output than Floyd-Steinberg (100%) — ideal for thermal
  static CompositeResult _renderInIsolate({
    required Map<String, dynamic> templateJson,
    required Map<int, String> photoPathsBySlot,
    required String? backgroundPath,
    required String outputDir,
    required bool hasDigitalCopy,
  }) {
    final template = Template.fromJson(templateJson);
    final canvasW = template.width;
    final canvasH = template.height;

    // Decode background inside isolate — small template asset.
    img.Image? background;
    if (backgroundPath != null && File(backgroundPath).existsSync()) {
      background = img.decodeImage(File(backgroundPath).readAsBytesSync());
    }

    // ── Create both canvases upfront ──
    final printCanvas = img.Image(
      width: canvasW,
      height: canvasH,
      numChannels: 4,
    );
    img.fill(printCanvas, color: img.ColorRgba8(255, 255, 255, 255));

    img.Image? digitalCanvas;
    if (hasDigitalCopy) {
      digitalCanvas = img.Image(
        width: canvasW * _digitalScale,
        height: canvasH * _digitalScale,
        numChannels: 4,
      );
      img.fill(digitalCanvas, color: img.ColorRgba8(255, 255, 255, 255));
    }

    // Background on both canvases.
    if (background != null) {
      final bgP = img.copyResize(
        background,
        width: canvasW,
        height: canvasH,
      );
      img.compositeImage(printCanvas, bgP);
      if (digitalCanvas != null) {
        final bgD = img.copyResize(
          background,
          width: digitalCanvas.width,
          height: digitalCanvas.height,
        );
        img.compositeImage(digitalCanvas, bgD);
      }
    }
    background = null; // free — no longer needed

    // Sort elements by sequence (z-order).
    final sortedElements = List<TemplateElement>.from(template.elements)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final photoSlots =
        sortedElements.where((e) => e.type == 'PHOTO_SLOT').toList();

    // ── Single-pass: draw all elements on both canvases ──
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
          // Target: 1.5× the largest slot dimension needed.
          final maxSlotW = hasDigitalCopy
              ? el.width * _digitalScale
              : el.width;
          final targetW = (maxSlotW * 1.5).round();
          if (photo.width > targetW) {
            photo = img.copyResize(
              photo,
              width: targetW,
              interpolation: img.Interpolation.average,
            );
            // Original 48MB is now eligible for GC.
          }

          // Print canvas — B&W dithered.
          _drawPhotoDithered(
            printCanvas,
            photo,
            el.x,
            el.y,
            el.width,
            el.height,
          );

          // Digital canvas — full color.
          if (digitalCanvas != null) {
            _drawPhoto(
              digitalCanvas,
              photo,
              el.x * _digitalScale,
              el.y * _digitalScale,
              el.width * _digitalScale,
              el.height * _digitalScale,
            );
          }
          // photo goes out of scope → eligible for GC before next decode

        case 'TEXT':
          _drawText(
            printCanvas,
            el,
            el.x,
            el.y,
            el.width,
            el.height,
            _printScale,
          );
          if (digitalCanvas != null) {
            _drawText(
              digitalCanvas,
              el,
              el.x * _digitalScale,
              el.y * _digitalScale,
              el.width * _digitalScale,
              el.height * _digitalScale,
              _digitalScale,
            );
          }

        case 'IMAGE':
          break;
      }
    }

    // ── Encode ESC/POS raster directly from print canvas ──
    // Skip PNG encode→decode→imageRaster cycle entirely.
    // Manual bit-packing: pixel 0 (black) → bit 1 (print dot).
    // Returns a list of band payloads for per-band Bluetooth writes.
    final printBands = _encodeEscPosRasterBands(printCanvas);

    // Digital PNG only if needed.
    String? digitalPath;
    if (digitalCanvas != null) {
      digitalPath = '$outputDir/composite_digital.png';
      File(digitalPath).writeAsBytesSync(img.encodePng(digitalCanvas));
    }

    return CompositeResult(
      printBands: printBands,
      digitalFilePath: digitalPath,
    );
  }

  /// Draw a photo with full preprocessing + Atkinson dithering.
  ///
  /// **Optimized multi-stage pipeline** — all preprocessing is computed
  /// directly into [Float64List] buffers without intermediate Images:
  ///
  /// 1. Center-crop + resize + mirror → single Image (unavoidable)
  /// 2. BT.709 Grayscale → Float64List + histogram (1 pass)
  /// 3. Auto-levels (histogram stretch, 0.5% clip) → in-place
  /// 4. Gamma(0.72) + brightness(+8) + contrast(1.35) → in-place
  /// 5. Sharpen 3×3 unsharp (amount 0.5) → second Float64List
  /// 6. Atkinson dither → write directly to canvas pixels
  ///
  /// **Why Atkinson over Floyd-Steinberg?**
  /// Atkinson diffuses only 75% (6/8) of quantization error; the
  /// remaining 25% is discarded. This produces:
  /// - Higher perceived contrast (blacks stay black, whites stay white)
  /// - Crisper fine detail on low-resolution thermal output
  /// - Less "muddy" midtones — ideal for 203 DPI thermal paper
  /// Originally developed for the Apple Macintosh — the gold standard
  /// for 1-bit B&W rendering.
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
      // Brightness offset — small constant lift to compensate for
      // thermal head heat bleed that darkens light areas.
      v += 8.0;
      // Contrast 1.35 — tighten dynamic range around midpoint.
      // Slightly less than old 1.4 because auto-levels already
      // expanded the range.
      v = (v - 128.0) * 1.35 + 128.0;
      if (v < 0.0) v = 0.0;
      if (v > 255.0) v = 255.0;
      lum[i] = v;
    }

    // ── Step 3: Sharpen on Float64List (3×3 unsharp kernel) ──
    // Kernel [0,-1,0, -1,5,-1, 0,-1,0], amount 0.5.
    // Stronger than previous 0.3 — compensates for detail loss from
    // 1-bit quantization and low thermal DPI. Preserves edges that
    // Atkinson dithering can then faithfully reproduce.
    const sharpenAmt = 0.5;
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

    // ── Step 4: Atkinson dithering → write directly to canvas ──
    // Atkinson error diffusion pattern (each neighbor gets error/8):
    //
    //         *   +1  +2
    //    -1   0   +1
    //         +2
    //
    // Only 6/8 (75%) of error is diffused. The discarded 25% means
    // pure black/white areas stay pure — critical for thermal print
    // contrast. Floyd-Steinberg spreads 100% which muddies extremes.
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

        // Distribute to 6 neighbors (Atkinson pattern).
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

  /// Encode ESC/POS raster bytes from a B&W print canvas using band-based
  /// `GS v 0` commands.
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
  static List<Uint8List> _encodeEscPosRasterBands(img.Image bwCanvas) {
    final w = bwCanvas.width;
    final h = bwCanvas.height;
    final bytesPerRow = (w + 7) ~/ 8;
    final numBands = (h + _bandHeight - 1) ~/ _bandHeight;

    // Pixel buffer — toUint8List() gives zero-copy RGBA access.
    final pixels = bwCanvas.toUint8List();
    final rowStride = w * 4; // 4 bytes per pixel (RGBA)

    final bands = <Uint8List>[];

    // Band 0: ESC @ reset — sent as a separate band so the printer
    // has time to process the reset before raster data arrives.
    // Over USB bulk transfer, data arrivals are <1ms apart; without
    // this separation the GS v 0 bytes arrive before the printer
    // finishes resetting and get printed as random text characters.
    bands.add(Uint8List.fromList([0x1B, 0x40]));

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

  /// Draw a photo into its slot for digital output (full color, no dither).
  static void _drawPhoto(
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

  /// Draw a shape element (rect or circle).
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
