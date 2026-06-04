import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../shared/data/services/print_channel.dart';
import '../../../session/data/services/native_bluetooth_channel.dart';
import '../../../session/data/services/native_usb_channel.dart';
import '../../bloc/home_state.dart';

/// Service wrapper for thermal printer testing and device scanning.
///
/// Uses [NativeBluetoothChannel] (custom memoir/bluetooth_print MethodChannel)
/// for all Bluetooth operations — never [print_bluetooth_thermal], which has a
/// fatal race condition: its coroutine callback can be submitted twice, causing
/// `Reply already submitted` → app crash.
class PrinterTestService {
  /// Request Bluetooth runtime permissions (Android 12+).
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
      throw Exception(
        'Izin Bluetooth diperlukan. '
        'Buka Pengaturan › Aplikasi › memoir › Izin '
        'dan aktifkan "Perangkat terdekat".',
      );
    }
  }

  /// Return paired Bluetooth printers (IMAGING / UNCATEGORIZED class only).
  ///
  /// Uses the bonded-devices list rather than live discovery because most
  /// thermal printers stop broadcasting after initial pairing. Class
  /// filtering removes phones, headsets, and speakers so only likely
  /// printers appear. Validation happens separately on selection (Option A).
  Future<List<PrinterInfo>> scanBluetoothPrinters() async {
    await _ensureBluetoothPermissions();

    final isOn = await NativeBluetoothChannel.isEnabled();
    if (!isOn) {
      throw Exception('Bluetooth tidak aktif. Nyalakan Bluetooth lalu coba lagi.');
    }

    final paired = await NativeBluetoothChannel.pairedDevices();

    return paired
        .map(
          (d) => PrinterInfo(
            name: d['name'] as String? ?? 'Unknown',
            address: d['mac'] as String,
            connectionType: PrinterConnectionType.bluetooth,
          ),
        )
        .toList();
  }

  /// Get list of USB printers connected via OTG cable.
  ///
  /// When no printers are found, falls back to [NativeUsbChannel.listAllDevices]
  /// to produce a diagnostic error message — distinguishing "OTG not working"
  /// (empty device list) from "device found but not recognized as printer"
  /// (non-empty device list with wrong USB class).
  Future<List<PrinterInfo>> scanUsbPrinters() async {
    final devices = await NativeUsbChannel.listDevices();

    if (devices.isNotEmpty) {
      return devices
          .map(
            (d) => PrinterInfo(
              name: d['deviceName'] as String? ?? 'USB Printer',
              address: '${d['vendorId']}-${d['productId']}',
              connectionType: PrinterConnectionType.usb,
            ),
          )
          .toList();
    }

    // Diagnose why no printer was found.
    final allDevices = await NativeUsbChannel.listAllDevices();
    if (allDevices.isEmpty) {
      throw Exception(
        'Printer USB tidak terdeteksi. '
        'Pastikan kabel OTG terpasang dengan benar dan printer dalam keadaan menyala. '
        'Coba cabut lalu pasang ulang kabel OTG.',
      );
    }

    // OS sees a device but isPrinterDevice filtered it out.
    throw Exception(
      'Perangkat USB terdeteksi namun tidak dikenali sebagai printer. '
      'Coba cabut dan pasang ulang, atau gunakan printer yang berbeda.',
    );
  }

  /// Return the first physically-connected USB printer, or null if none.
  ///
  /// Silent (never throws) — used for page-open detection where a plugged-in
  /// USB printer should automatically become the active printer.
  Future<PrinterInfo?> findConnectedUsbPrinter() async {
    final devices = await NativeUsbChannel.listDevices();
    if (devices.isEmpty) return null;
    final d = devices.first;
    return PrinterInfo(
      name: d['deviceName'] as String? ?? 'USB Printer',
      address: '${d['vendorId']}-${d['productId']}',
      connectionType: PrinterConnectionType.usb,
    );
  }

  /// Quick reachability ping for page-open verification of a saved BT printer.
  ///
  /// Returns:
  /// - `true`  — printer responded within the 5 s RFCOMM timeout.
  /// - `false` — printer did not respond (off / out of range / gone).
  /// - `null`  — could not verify: Bluetooth permission not granted or the
  ///   adapter is off. Caller should keep the saved printer as-is rather than
  ///   clearing it.
  ///
  /// Never prompts for permission — page open must not surface a dialog. We
  /// only read the current permission status; if it isn't already granted we
  /// return `null` (unverifiable) instead of requesting.
  Future<bool?> quickPingBluetooth(PrinterInfo printer) async {
    final status = await Permission.bluetoothConnect.status;
    if (!status.isGranted) return null;

    final isOn = await NativeBluetoothChannel.isEnabled();
    if (!isOn) return null;

    try {
      return await NativeBluetoothChannel.quickPing(printer.address);
    } catch (_) {
      return null;
    }
  }

  /// Validate a Bluetooth printer is reachable by opening and immediately
  /// closing an RFCOMM connection — no data sent.
  Future<void> validateBluetoothConnection(PrinterInfo printer) async {
    await _ensureBluetoothPermissions();
    final channel = NativeBluetoothChannel();
    final connected = await channel.connect(printer.address);
    if (!connected) {
      throw Exception(
        'Printer tidak merespons. '
        'Pastikan printer menyala dan berada dalam jangkauan Bluetooth.',
      );
    }
    await channel.disconnect();
  }

  /// Perform a test print on the given printer.
  ///
  /// Routes to Bluetooth or USB based on [printerInfo.connectionType].
  Future<void> testPrint(PrinterInfo printerInfo) async {
    final bytes = await _generateTestReceipt(printerInfo);

    if (printerInfo.connectionType == PrinterConnectionType.usb) {
      await _testPrintUsb(printerInfo, bytes);
    } else {
      await _testPrintBluetooth(printerInfo, bytes);
    }
  }

  /// Send pre-encoded ESC/POS bands to a printer.
  ///
  /// Each band is written separately so the native pacing layer can drain
  /// the previous one before queuing the next — identical to the real
  /// session print path. Used by the image-processing test page.
  Future<void> printBands(
    PrinterInfo printerInfo,
    List<Uint8List> bands,
  ) async {
    if (printerInfo.connectionType == PrinterConnectionType.usb) {
      final channel = NativeUsbChannel();
      final connected = await channel.connect(printerInfo.address);
      if (!connected) {
        throw Exception(
          'Koneksi USB ke printer gagal. '
          'Pastikan kabel OTG terpasang dengan benar.',
        );
      }
      try {
        for (final band in bands) {
          final ok = await channel.write(band);
          if (!ok) {
            throw Exception(
              'Gagal mengirim data ke printer. '
              'Periksa kertas dan pastikan printer menyala.',
            );
          }
        }
      } finally {
        await channel.disconnect();
      }
    } else {
      await _ensureBluetoothPermissions();
      final channel = NativeBluetoothChannel();
      final connected = await channel.connect(printerInfo.address);
      if (!connected) {
        throw Exception(
          'Koneksi Bluetooth ke printer gagal. '
          'Pastikan printer menyala dan berada dalam jangkauan.',
        );
      }
      try {
        for (final band in bands) {
          final ok = await channel.write(band);
          if (!ok) {
            throw Exception(
              'Gagal mengirim data ke printer. '
              'Periksa kertas dan pastikan printer menyala.',
            );
          }
        }
      } finally {
        await channel.disconnect();
      }
    }
  }

  /// Generate ESC/POS test receipt bytes.
  Future<List<int>> _generateTestReceipt(PrinterInfo printerInfo) async {
    final List<int> bytes = [];
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    bytes.addAll(generator.reset());
    bytes.addAll(
      generator.text(
        'memoir.',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );
    bytes.addAll(
      generator.text(
        'Mobile Runner',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text(
        'PRINTER TEST',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text(
        'Status: BERHASIL',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(
      generator.text(
        'Printer: ${printerInfo.name}',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        'Koneksi: ${printerInfo.connectionType == PrinterConnectionType.usb ? 'USB' : 'Bluetooth'}',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        'Alamat: ${printerInfo.address}',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        DateTime.now().toIso8601String(),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());

    return bytes;
  }

  /// Test print via Bluetooth SPP using [NativeBluetoothChannel].
  Future<void> _testPrintBluetooth(
    PrinterInfo printerInfo,
    List<int> bytes,
  ) async {
    await _ensureBluetoothPermissions();

    final channel = NativeBluetoothChannel();

    final connected = await channel.connect(printerInfo.address);
    if (!connected) {
      throw Exception(
        'Koneksi Bluetooth ke printer gagal. '
        'Pastikan printer menyala dan berada dalam jangkauan.',
      );
    }

    try {
      final success = await channel.write(Uint8List.fromList(bytes));
      if (!success) {
        throw Exception(
          'Gagal mengirim data ke printer. '
          'Periksa kertas dan pastikan printer menyala.',
        );
      }
    } finally {
      await channel.disconnect();
    }
  }

  /// Test print via USB OTG.
  Future<void> _testPrintUsb(
    PrinterInfo printerInfo,
    List<int> bytes,
  ) async {
    final channel = NativeUsbChannel();

    final connected = await channel.connect(printerInfo.address);
    if (!connected) {
      throw Exception(
        'Koneksi USB ke printer gagal. '
        'Pastikan kabel OTG terpasang dengan benar.',
      );
    }

    try {
      final success = await channel.write(Uint8List.fromList(bytes));
      if (!success) {
        throw Exception(
          'Gagal mengirim data ke printer. '
          'Periksa kertas dan pastikan printer menyala.',
        );
      }
    } finally {
      await channel.disconnect();
    }
  }

  Future<void> dispose() async {}
}
