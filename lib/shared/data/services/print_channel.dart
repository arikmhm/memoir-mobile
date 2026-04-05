import 'dart:typed_data';

/// Connection type for the saved printer.
enum PrinterConnectionType {
  bluetooth,
  usb;

  /// Persist-friendly string.
  String get key => name;

  /// Parse from persisted string.
  static PrinterConnectionType fromKey(String? key) {
    if (key == 'usb') return PrinterConnectionType.usb;
    return PrinterConnectionType.bluetooth; // default
  }
}

/// Abstract transport layer for thermal printer communication.
///
/// Two implementations:
/// - [NativeBluetoothChannel] — Bluetooth SPP (RFCOMM)
/// - [NativeUsbChannel]       — USB Host API (bulk transfer via OTG)
///
/// The caller ([CompositePrintService]) does not care about the transport;
/// it calls [connect] → N × [write] → [disconnect].
abstract class PrintChannel {
  /// Open a connection to the printer identified by [address].
  ///
  /// For Bluetooth: [address] is a MAC address (e.g. "AA:BB:CC:DD:EE:FF").
  /// For USB: [address] is a device ID string (e.g. "1003" — vendor:product).
  Future<bool> connect(String address);

  /// Write raw ESC/POS [bytes] to the connected printer.
  Future<bool> write(Uint8List bytes);

  /// Close the connection. Safe to call even if not connected.
  Future<void> disconnect();
}
