import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../../shared/data/services/print_channel.dart';
import '../../../session/data/services/native_usb_channel.dart';
import '../../bloc/settings_state.dart';

/// Service wrapper for Bluetooth Classic thermal printer.
///
/// Uses `print_bluetooth_thermal` which supports SPP (Serial Port Profile)
/// — the protocol used by most thermal printers like EPPOS EP600.
///
/// Key difference from BLE:
/// - Uses Android's paired device list (no scan needed)
/// - Printer must be paired first via Android Bluetooth Settings
/// - Connection via MAC address over RFCOMM
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
        'Izin Bluetooth ditolak. Aktifkan izin "Nearby devices" '
        'di Pengaturan > Aplikasi > memoir > Izin.',
      );
    }
  }

  /// Get list of Bluetooth devices paired in Android settings.
  Future<List<PrinterInfo>> scanBluetoothPrinters() async {
    await _ensureBluetoothPermissions();

    final isOn = await PrintBluetoothThermal.bluetoothEnabled;
    if (!isOn) {
      throw Exception(
        'Bluetooth tidak aktif. Nyalakan Bluetooth terlebih dahulu.',
      );
    }

    final paired = await PrintBluetoothThermal.pairedBluetooths;

    return paired
        .map(
          (bt) => PrinterInfo(
            name: bt.name,
            address: bt.macAdress,
            connectionType: PrinterConnectionType.bluetooth,
          ),
        )
        .toList();
  }

  /// Get list of USB printers connected via OTG cable.
  Future<List<PrinterInfo>> scanUsbPrinters() async {
    final devices = await NativeUsbChannel.listDevices();

    return devices
        .map(
          (d) => PrinterInfo(
            name: d['deviceName'] as String? ?? 'USB Printer',
            address: '${d['deviceId']}',
            connectionType: PrinterConnectionType.usb,
          ),
        )
        .toList();
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

  /// Test print via Bluetooth SPP.
  Future<void> _testPrintBluetooth(
    PrinterInfo printerInfo,
    List<int> bytes,
  ) async {
    await _ensureBluetoothPermissions();

    await PrintBluetoothThermal.disconnect;

    final connected = await PrintBluetoothThermal.connect(
      macPrinterAddress: printerInfo.address,
    );

    if (!connected) {
      throw Exception(
        'Gagal terhubung ke printer "${printerInfo.name}". '
        'Pastikan printer menyala dan sudah di-pair.',
      );
    }

    try {
      await PrintBluetoothThermal.writeBytes(bytes);
    } finally {
      await PrintBluetoothThermal.disconnect;
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
        'Gagal terhubung ke printer USB "${printerInfo.name}". '
        'Pastikan kabel OTG terpasang dengan benar.',
      );
    }

    try {
      final success = await channel.write(Uint8List.fromList(bytes));
      if (!success) {
        throw Exception('Gagal mengirim data ke printer USB.');
      }
    } finally {
      await channel.disconnect();
    }
  }

  /// Dispose resources.
  Future<void> dispose() async {
    await PrintBluetoothThermal.disconnect;
  }
}
