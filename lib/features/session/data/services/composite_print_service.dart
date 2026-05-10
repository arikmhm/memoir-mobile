import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

import '../../../../shared/core/utils/formatters.dart';
import '../../../../shared/data/services/print_channel.dart';

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
      throw PrintException(
        'Gagal terhubung ke printer "$printerName". '
        'Pastikan printer menyala dan terhubung.',
      );
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
          'Pastikan printer menyala dan kertas tersedia.',
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
        height: PosTextSize.size2,
        width: PosTextSize.size2,
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

    // ── Transaction ID ──
    bytes.addAll(generator.text(
      'ID: $transactionId',
      styles: const PosStyles(
        align: PosAlign.center,
        fontType: PosFontType.fontB,
      ),
      linesAfter: 1,
    ));

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

    bytes.addAll(generator.feed(3));
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
