import 'package:flutter/services.dart';

import '../../../../shared/data/services/print_channel.dart';

/// Bluetooth SPP (RFCOMM) implementation of [PrintChannel].
///
/// Wraps the custom `memoir/bluetooth_print` MethodChannel defined in
/// `MainActivity.kt`.
///
/// Sends [Uint8List] bytes directly to the native side as `ByteArray` —
/// no boxing, no intermediate copies, no O(n²) concatenation.
class NativeBluetoothChannel implements PrintChannel {
  static const _channel = MethodChannel('memoir/bluetooth_print');

  @override
  Future<bool> connect(String address) async {
    final result = await _channel.invokeMethod<bool>(
      'connect',
      {'mac': address},
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

  /// Return all Bluetooth devices currently paired in Android settings.
  ///
  /// Returns maps with keys: `name`, `mac`.
  static Future<List<Map<String, dynamic>>> pairedDevices() async {
    final result =
        await _channel.invokeMethod<List<dynamic>>('pairedDevices');
    if (result == null) return [];
    return result
        .cast<Map<dynamic, dynamic>>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
  }

  /// Perform real Bluetooth discovery (~12 s) and return printers found.
  ///
  /// Only returns devices that are physically on and broadcasting —
  /// unlike [pairedDevices] which returns the full bonded list.
  /// Returns maps with keys: `name`, `mac`.
  static Future<List<Map<String, dynamic>>> discoverPrinters() async {
    final result =
        await _channel.invokeMethod<List<dynamic>>('discoverPrinters');
    if (result == null) return [];
    return result
        .cast<Map<dynamic, dynamic>>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
  }

  /// Quick reachability check with a 5-second hard timeout.
  ///
  /// Returns true if RFCOMM connects within 5 s, false otherwise.
  /// Use this for page-open checks — not for full validation before saving.
  static Future<bool> quickPing(String mac) async {
    final result = await _channel.invokeMethod<bool>(
      'quickPing',
      {'mac': mac},
    );
    return result ?? false;
  }

  /// Return true if the device Bluetooth adapter is currently enabled.
  static Future<bool> isEnabled() async {
    final result = await _channel.invokeMethod<bool>('isEnabled');
    return result ?? false;
  }
}
