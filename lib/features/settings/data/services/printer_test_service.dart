import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

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
  /// Get list of Bluetooth devices paired in Android settings.
  ///
  /// No scanning needed — reads from OS paired list directly.
  /// Printer must be paired in Android Bluetooth Settings first.
  Future<List<PrinterInfo>> scanPrinters() async {
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
          ),
        )
        .toList();
  }

  /// Perform a test print on the given printer.
  ///
  /// Connects via Bluetooth Classic SPP, sends ESC/POS formatted
  /// test receipt, then disconnects.
  Future<void> testPrint(PrinterInfo printerInfo) async {
    // Disconnect any existing connection first.
    await PrintBluetoothThermal.disconnect;

    // Connect to the printer by MAC address.
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
      // Generate ESC/POS test receipt.
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
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
          ),
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
          'MAC: ${printerInfo.address}',
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

      // Send to printer.
      await PrintBluetoothThermal.writeBytes(bytes);
    } finally {
      // Always disconnect after printing.
      await PrintBluetoothThermal.disconnect;
    }
  }

  /// Dispose resources.
  Future<void> dispose() async {
    await PrintBluetoothThermal.disconnect;
  }
}
