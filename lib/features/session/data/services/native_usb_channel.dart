import 'package:flutter/services.dart';

import '../../../../shared/data/services/print_channel.dart';

/// USB Host API (bulk transfer) implementation of [PrintChannel].
///
/// Wraps the custom `memoir/usb_print` MethodChannel defined in
/// `MainActivity.kt`. Uses Android's USB Host Mode to send ESC/POS
/// data directly to a USB-connected thermal printer via OTG cable.
///
/// Unlike Bluetooth, USB bulk transfer delivers data at ~12 MB/s
/// with <1ms latency — 57 KB of ESC/POS data arrives in <5ms,
/// completely eliminating buffer underrun and horizontal banding.
///
/// No chunking or pacing needed; the entire payload is written
/// in a single `bulkTransfer` call on the native side.
class NativeUsbChannel implements PrintChannel {
  static const _channel = MethodChannel('memoir/usb_print');

  @override
  Future<bool> connect(String address) async {
    final result = await _channel.invokeMethod<bool>(
      'connect',
      {'vendorProductId': address},
    );
    return result ?? false;
  }

  @override
  Future<bool> write(Uint8List bytes) async {
    final result = await _channel.invokeMethod<bool>(
      'write',
      {'bytes': bytes},
    );
    return result ?? false;
  }

  @override
  Future<void> disconnect() async {
    await _channel.invokeMethod<bool>('disconnect');
  }

  /// List USB printers currently connected via OTG.
  ///
  /// Returns a list of maps with keys: `deviceId`, `vendorId`,
  /// `productId`, `deviceName`.
  static Future<List<Map<String, dynamic>>> listDevices() async {
    final result = await _channel.invokeMethod<List<dynamic>>('listDevices');
    if (result == null) return [];
    return result
        .cast<Map<dynamic, dynamic>>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
  }

  /// Diagnostic: list ALL USB devices visible to Android, without any filter.
  ///
  /// Use this when [listDevices] returns empty to distinguish:
  /// - Empty list → OTG adapter tidak mengaktifkan USB host mode (masalah hardware)
  /// - Non-empty list → device terdeteksi OS tapi difilter oleh heuristic printer
  ///
  /// Fields: `deviceId`, `vendorId`, `productId`, `deviceName`,
  /// `deviceClass`, `interfaceCount`, `interfaceClasses`.
  static Future<List<Map<String, dynamic>>> listAllDevices() async {
    final result =
        await _channel.invokeMethod<List<dynamic>>('listAllDevices');
    if (result == null) return [];
    return result
        .cast<Map<dynamic, dynamic>>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
  }
}
