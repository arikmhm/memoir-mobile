import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unified storage service wrapping secure and non-secure storage.
///
/// - [FlutterSecureStorage]: Encrypted deviceToken (Android Keystore)
/// - [SharedPreferences]: App settings (payment mode, camera, printer, timers)
///
/// Keys are organized per PRD-05 Section 4.4.
class StorageService {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  StorageService({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences prefs,
  }) : _secureStorage = secureStorage,
       _prefs = prefs;

  // ─── Secure Storage (Device Token) ───────────────────────────

  static const _deviceTokenKey = 'deviceToken';

  Future<String?> getDeviceToken() => _secureStorage.read(key: _deviceTokenKey);

  Future<void> setDeviceToken(String token) =>
      _secureStorage.write(key: _deviceTokenKey, value: token);

  Future<void> clearDeviceToken() =>
      _secureStorage.delete(key: _deviceTokenKey);

  Future<bool> hasDeviceToken() async {
    final token = await getDeviceToken();
    return token != null && token.isNotEmpty;
  }

  // ─── Shared Preferences (Settings) ───────────────────────────

  // Payment
  String get paymentActiveMode =>
      _prefs.getString('payment.activeMode') ?? 'CASH';

  Future<void> setPaymentActiveMode(String mode) =>
      _prefs.setString('payment.activeMode', mode);

  // Timers
  int get retakeCountdown => _prefs.getInt('timers.retakeCountdown') ?? 5;

  int get paymentTimeout => _prefs.getInt('timers.paymentTimeout') ?? 300;

  int get thankYouDuration => _prefs.getInt('timers.thankYouDuration') ?? 10;

  int get idleTimeout => _prefs.getInt('timers.idleTimeout') ?? 60;

  // ─── Default Printer ─────────────────────────────────────────

  static const _printerNameKey = 'printer.defaultName';
  static const _printerMacKey = 'printer.defaultMac';

  /// Get saved default printer name (null if none saved).
  String? get defaultPrinterName => _prefs.getString(_printerNameKey);

  /// Get saved default printer MAC address (null if none saved).
  String? get defaultPrinterMac => _prefs.getString(_printerMacKey);

  /// Whether a default printer is saved.
  bool get hasDefaultPrinter =>
      defaultPrinterMac != null && defaultPrinterMac!.isNotEmpty;

  /// Save default printer info.
  Future<void> setDefaultPrinter({
    required String name,
    required String mac,
  }) async {
    await _prefs.setString(_printerNameKey, name);
    await _prefs.setString(_printerMacKey, mac);
  }

  /// Clear saved default printer.
  Future<void> clearDefaultPrinter() async {
    await _prefs.remove(_printerNameKey);
    await _prefs.remove(_printerMacKey);
  }
}
