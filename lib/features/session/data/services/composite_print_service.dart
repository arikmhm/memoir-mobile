import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../shared/core/utils/formatters.dart';
import '../../../../shared/data/services/print_channel.dart';
import 'composite_render_service.dart' show CutMode;

/// Service for printing composite images via thermal printer.
///
/// Transport-agnostic: works with both Bluetooth SPP and USB OTG
/// via the [PrintChannel] abstraction. The active channel is set
/// by the caller based on the user's saved printer preference.
///
/// **Connection lifecycle**: call [connectPrinter] once before sending
/// data, [sendData] for each copy, then [disconnectPrinter] when done.
class CompositePrintService {
  PrintChannel? _channel;

  /// Set the active print channel (Bluetooth or USB).
  ///
  /// Must be called before [connectPrinter].
  void setChannel(PrintChannel channel) {
    _channel = channel;
  }
  /// Prepare ESC/POS raster bytes from a print-ready composite PNG.
  ///
  /// The composite is already dithered B&W from the render pipeline
  /// (per-photo Atkinson dithering with clean B&W template).
  /// imageRaster internally does grayscale → invert → threshold, which
  /// works correctly on our pre-dithered B&W input.
  ///
  /// Runs on main thread because CapabilityProfile.load() uses rootBundle
  /// which requires Flutter engine binding (not available in bare isolates).
  Future<Uint8List> prepareEscPosBytes(Uint8List imageBytes) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw const PrintException('Gagal memproses gambar untuk cetak.');
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    final bytes = <int>[];
    bytes.addAll(generator.reset());
    bytes.addAll(generator.imageRaster(decoded, align: PosAlign.center));
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());

    return Uint8List.fromList(bytes);
  }

  /// Open a connection to the printer.
  ///
  /// For Bluetooth: requests BT permissions, connects via SPP.
  /// For USB: connects via USB Host bulk transfer.
  ///
  /// Call once before [sendData]. Throws [PrintException] on failure.
  Future<void> connectPrinter({
    required String printerAddress,
    required String printerName,
    required PrinterConnectionType connectionType,
  }) async {
    if (_channel == null) {
      throw const PrintException('Print channel belum diatur.');
    }

    if (connectionType == PrinterConnectionType.bluetooth) {
      await _ensureBluetoothPermissions();
    }

    // Close stale connection (if any) before opening a new one.
    await _channel!.disconnect();

    final connected = await _channel!.connect(printerAddress);
    if (!connected) {
      final hint = connectionType == PrinterConnectionType.usb
          ? 'Pastikan kabel OTG terpasang dengan benar.'
          : 'Pastikan printer menyala dan berada dalam jangkauan Bluetooth.';
      throw PrintException('Koneksi ke printer gagal. $hint');
    }
  }

  /// Send pre-encoded ESC/POS bands to the already-connected printer.
  ///
  /// Each band is sent as a separate Bluetooth write so the native
  /// pacing layer can drain each ~4.6 KB payload before the next,
  /// preventing the printer's receive buffer from underrunning.
  ///
  /// Assumes [connectPrinter] was called beforehand.
  /// Throws [PrintException] on write failure.
  Future<void> sendData({required List<Uint8List> bands}) async {
    if (_channel == null) {
      throw const PrintException('Print channel belum diatur.');
    }
    for (final band in bands) {
      final success = await _channel!.write(band);
      if (!success) {
        throw const PrintException(
          'Gagal mengirim data ke printer. '
          'Periksa kertas dan pastikan printer menyala.',
        );
      }
    }
  }

  /// Close the printer connection. Safe to call even if not connected.
  Future<void> disconnectPrinter() async {
    await _channel?.disconnect();
  }

  /// Convenience: connect → send → disconnect in one call.
  ///
  /// For multi-copy printing, prefer the explicit lifecycle
  /// [connectPrinter] → N × [sendData] → [disconnectPrinter].
  Future<void> sendToPrinter({
    required String printerAddress,
    required String printerName,
    required PrinterConnectionType connectionType,
    required List<Uint8List> bands,
  }) async {
    await connectPrinter(
      printerAddress: printerAddress,
      printerName: printerName,
      connectionType: connectionType,
    );
    try {
      await sendData(bands: bands);
    } finally {
      await disconnectPrinter();
    }
  }

  /// Combines [prepareEscPosBytes] + [sendToPrinter] in one call.
  Future<void> printComposite({
    required String printerAddress,
    required String printerName,
    required PrinterConnectionType connectionType,
    required Uint8List imageBytes,
  }) async {
    final escPosBytes = await prepareEscPosBytes(imageBytes);
    await sendToPrinter(
      printerAddress: printerAddress,
      printerName: printerName,
      connectionType: connectionType,
      bands: [escPosBytes],
    );
  }

  /// Build ESC/POS bytes for a softfile QR band appended after the photo image.
  ///
  /// Printed when [hasDigitalCopy] is true: "Scan Here" label + QR code + cut.
  /// The photo bands are encoded without a cut so this band terminates the
  /// strip — [cutMode] and [feedLines] mirror the photo-band tail settings so
  /// the strip ends consistently regardless of whether a QR is appended.
  Future<Uint8List> buildSoftfileQrBand(
    String previewUrl, {
    CutMode cutMode = CutMode.full,
    int feedLines = 3,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final bytes = <int>[];

    // ESC 3 n — minimal line spacing (~1.1 mm) to reduce gap between text and QR.
    bytes.addAll(generator.rawBytes([0x1B, 0x33, 0x08]));

    bytes.addAll(generator.text(
      'Scan Here',
      styles: const PosStyles(align: PosAlign.center),
    ));

    // Render QR as raster bitmap so size is exact regardless of printer firmware.
    // 160 px ≈ 2 cm on a 203 DPI thermal printer.
    final qrImg = await _renderQrAsImage(previewUrl, sizePixels: 160);
    bytes.addAll(generator.imageRaster(qrImg, align: PosAlign.center));

    // ESC 2 — restore default line spacing before feed/cut.
    bytes.addAll(generator.rawBytes([0x1B, 0x32]));
    if (feedLines > 0) bytes.addAll(generator.feed(feedLines.clamp(0, 15)));
    switch (cutMode) {
      case CutMode.full:
        bytes.addAll(generator.cut());
      case CutMode.partial:
        bytes.addAll(generator.cut(mode: PosCutMode.partial));
      case CutMode.none:
        break;
    }

    return Uint8List.fromList(bytes);
  }

  /// Render [data] as a B&W QR code bitmap at exactly [sizePixels] × [sizePixels].
  ///
  /// Uses [QrPainter] + Flutter's PictureRecorder so the output is pixel-exact
  /// regardless of the printer's ESC/POS QR module-size implementation.
  Future<img.Image> _renderQrAsImage(
    String data, {
    required int sizePixels,
  }) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: ui.Color(0xFF000000),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: ui.Color(0xFF000000),
      ),
    );

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Fill white background explicitly (painter default is transparent).
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, sizePixels.toDouble(), sizePixels.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );

    painter.paint(canvas, Size(sizePixels.toDouble(), sizePixels.toDouble()));

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(sizePixels, sizePixels);
    final byteData = await uiImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return img.decodeImage(byteData!.buffer.asUint8List())!;
  }

  /// Build ESC/POS bytes for a session receipt.
  ///
  /// Includes booth name, date/time, print qty, optional digital copy flag,
  /// payment method, total, transaction ID, and optional QR for soft file.
  Future<Uint8List> buildReceiptBytes({
    required String boothName,
    required String transactionId,
    required String? paidAt,
    required int printQty,
    required bool hasDigitalCopy,
    required String paymentMethod,
    required int totalAmount,
    String? previewUrl,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final bytes = <int>[];

    bytes.addAll(generator.reset());

    // ── Header ──
    bytes.addAll(generator.text(
      boothName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    ));

    if (paidAt != null) {
      try {
        final dt = DateTime.parse(paidAt).toLocal();
        final d = '${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/'
            '${dt.year}';
        final t = '${dt.hour.toString().padLeft(2, '0')}:'
            '${dt.minute.toString().padLeft(2, '0')}';
        bytes.addAll(generator.text(
          '$d  $t',
          styles: const PosStyles(align: PosAlign.center),
        ));
      } catch (_) {
        bytes.addAll(generator.text(
          paidAt,
          styles: const PosStyles(align: PosAlign.center),
        ));
      }
    }

    bytes.addAll(generator.text(
      'ID: $transactionId',
      styles: const PosStyles(align: PosAlign.center),
    ));

    bytes.addAll(generator.hr());

    // ── Details ──
    bytes.addAll(generator.row([
      PosColumn(text: 'Jumlah Cetak', width: 7),
      PosColumn(
        text: '$printQty lembar',
        width: 5,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));

    if (hasDigitalCopy) {
      bytes.addAll(generator.row([
        PosColumn(text: 'Softcopy Digital', width: 7),
        PosColumn(
          text: 'Ya',
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }

    bytes.addAll(generator.row([
      PosColumn(text: 'Metode Bayar', width: 7),
      PosColumn(
        text: _labelPaymentMethod(paymentMethod),
        width: 5,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));

    bytes.addAll(generator.hr());

    // ── Total ──
    bytes.addAll(generator.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: Formatters.formatRupiah(totalAmount),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]));

    bytes.addAll(generator.hr());

    // ── QR soft file (opsional) ──
    if (hasDigitalCopy && previewUrl != null) {
      bytes.addAll(generator.text(
        'Scan untuk akses softcopy:',
        styles: const PosStyles(align: PosAlign.center),
      ));
      bytes.addAll(generator.qrcode(
        previewUrl,
        align: PosAlign.center,
        size: QRSize.size5,
        cor: QRCorrection.M,
      ));
    }

    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.cut());

    return Uint8List.fromList(bytes);
  }

  static String _labelPaymentMethod(String method) => switch (method) {
    'CASH' => 'Tunai',
    'STATIC_QRIS' => 'QRIS',
    'PG' => 'QRIS',
    _ => method,
  };

  Future<void> _ensureBluetoothPermissions() async {
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

    final denied = statuses.entries
        .where((e) => !e.value.isGranted)
        .map((e) => e.key.toString())
        .toList();

    if (denied.isNotEmpty) {
      throw const PrintException(
        'Izin Bluetooth ditolak. Aktifkan izin "Nearby devices" '
        'di Pengaturan > Aplikasi > memoir > Izin.',
      );
    }
  }
}

/// Print exception with user-friendly message.
class PrintException implements Exception {
  final String message;
  const PrintException(this.message);

  @override
  String toString() => 'PrintException: $message';
}
