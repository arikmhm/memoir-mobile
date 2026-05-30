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
        'Izin Bluetooth ditolak. Aktifkan izin "Nearby devices" '
        'di Pengaturan > Aplikasi > memoir > Izin.',
      );
    }
  }

  /// Get list of Bluetooth devices paired in Android settings.
  Future<List<PrinterInfo>> scanBluetoothPrinters() async {
    await _ensureBluetoothPermissions();

    final isOn = await NativeBluetoothChannel.isEnabled();
    if (!isOn) {
      throw Exception(
        'Bluetooth tidak aktif. Nyalakan Bluetooth terlebih dahulu.',
      );
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
              address: '${d['deviceId']}',
              connectionType: PrinterConnectionType.usb,
            ),
          )
          .toList();
    }

    // Diagnose why no printer was found.
    final allDevices = await NativeUsbChannel.listAllDevices();
    if (allDevices.isEmpty) {
      throw Exception(
        'Tidak ada perangkat USB yang terdeteksi oleh Android.\n\n'
        'Kemungkinan penyebab:\n'
        '• Tablet tidak mengaktifkan USB host mode — coba adapter OTG lain '
        '(pastikan adapter mendukung mode host/DFP, bukan hanya charging)\n'
        '• Pada Samsung tablet tertentu, OTG hanya aktif dengan adapter resmi\n'
        '• Coba cabut dan pasang ulang adapter OTG',
      );
    }

    // OS sees the device but isPrinterDevice filtered it out.
    final names = allDevices
        .map((d) =>
            '${d['deviceName']} (class=${d['deviceClass']}, '
            'interfaces=${d['interfaceClasses']})')
        .join('\n');
    throw Exception(
      '${allDevices.length} perangkat USB terdeteksi, namun tidak ada yang '
      'dikenali sebagai printer:\n$names\n\n'
      'Hubungi developer dengan info di atas.',
    );
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
          'Gagal terhubung ke printer USB "${printerInfo.name}". '
          'Pastikan kabel OTG terpasang dengan benar.',
        );
      }
      try {
        for (final band in bands) {
          final ok = await channel.write(band);
          if (!ok) {
            throw Exception('Gagal mengirim data ke printer USB.');
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
          'Gagal terhubung ke printer "${printerInfo.name}". '
          'Pastikan printer menyala dan sudah di-pair.',
        );
      }
      try {
        for (final band in bands) {
          final ok = await channel.write(band);
          if (!ok) {
            throw Exception('Gagal mengirim data ke printer Bluetooth.');
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
        'Gagal terhubung ke printer "${printerInfo.name}". '
        'Pastikan printer menyala dan sudah di-pair.',
      );
    }

    try {
      final success = await channel.write(Uint8List.fromList(bytes));
      if (!success) {
        throw Exception('Gagal mengirim data ke printer Bluetooth.');
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

  Future<void> dispose() async {}
}
