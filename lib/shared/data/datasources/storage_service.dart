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

  // ─── Kiosk Config Cache ──────────────────────────────────────

  static const _kioskConfigKey = 'kioskConfig';

  /// Cache kiosk config JSON string.
  Future<void> setKioskConfig(String jsonString) =>
      _prefs.setString(_kioskConfigKey, jsonString);

  /// Get cached kiosk config JSON string (null if not cached).
  String? get kioskConfigJson => _prefs.getString(_kioskConfigKey);

  /// Clear cached kiosk config.
  Future<void> clearKioskConfig() => _prefs.remove(_kioskConfigKey);

  // ─── Shared Preferences (Settings) ───────────────────────────

  // Payment
  String get paymentActiveMode {
    final stored = _prefs.getString('payment.activeMode') ?? 'CASH';
    // Migrate old 'QRIS' value (pre-fix) → correct API enum 'STATIC_QRIS'.
    return stored == 'QRIS' ? 'STATIC_QRIS' : stored;
  }

  Future<void> setPaymentActiveMode(String mode) =>
      _prefs.setString('payment.activeMode', mode);

  // Static QRIS image (local file path for owner's static QRIS)
  static const _staticQrisImageKey = 'payment.staticQrisImagePath';

  String? get staticQrisImagePath => _prefs.getString(_staticQrisImageKey);

  Future<void> setStaticQrisImagePath(String path) =>
      _prefs.setString(_staticQrisImageKey, path);

  Future<void> clearStaticQrisImage() => _prefs.remove(_staticQrisImageKey);

  bool get hasStaticQrisImage =>
      staticQrisImagePath != null && staticQrisImagePath!.isNotEmpty;

  // ─── Booth Operation Mode ──────────────────────────────────────

  static const _boothOperationModeKey = 'booth.operationMode';

  String get boothOperationMode =>
      _prefs.getString(_boothOperationModeKey) ?? 'normal';

  Future<void> setBoothOperationMode(String mode) =>
      _prefs.setString(_boothOperationModeKey, mode);

  bool get isNormalMode => boothOperationMode == 'normal';
  bool get isEventMode => boothOperationMode == 'event';

  // ─── Timers / Session Timeout ─────────────────────────────────

  // Capture countdown (3, 2, 1... snap!)
  int get captureCountdown =>
      _prefs.getInt('timers.captureCountdown') ?? 5;
  Future<void> setCaptureCountdown(int seconds) =>
      _prefs.setInt('timers.captureCountdown', seconds);

  // Timeout mode: 'off', 'per_page', or 'global'
  String get timeoutMode =>
      _prefs.getString('timers.timeoutMode') ?? 'off';
  Future<void> setTimeoutMode(String mode) =>
      _prefs.setString('timers.timeoutMode', mode);

  bool get isTimeoutOff => timeoutMode == 'off';
  bool get isGlobalTimeout => timeoutMode == 'global';
  bool get isPerPageTimeout => timeoutMode == 'per_page';

  // Global session timeout (end-to-end, in seconds)
  int get globalSessionTimeout =>
      _prefs.getInt('timers.globalSessionTimeout') ?? 600;
  Future<void> setGlobalSessionTimeout(int seconds) =>
      _prefs.setInt('timers.globalSessionTimeout', seconds);

  // Per-page timeouts (in seconds)
  int get selectTemplateTimeout =>
      _prefs.getInt('timers.selectTemplateTimeout') ?? 120;
  Future<void> setSelectTemplateTimeout(int seconds) =>
      _prefs.setInt('timers.selectTemplateTimeout', seconds);

  int get photoSessionTimeout =>
      _prefs.getInt('timers.photoSessionTimeout') ?? 120;
  Future<void> setPhotoSessionTimeout(int seconds) =>
      _prefs.setInt('timers.photoSessionTimeout', seconds);

  int get previewTimeout =>
      _prefs.getInt('timers.previewTimeout') ?? 60;
  Future<void> setPreviewTimeout(int seconds) =>
      _prefs.setInt('timers.previewTimeout', seconds);

  int get confirmationTimeout =>
      _prefs.getInt('timers.confirmationTimeout') ?? 180;
  Future<void> setConfirmationTimeout(int seconds) =>
      _prefs.setInt('timers.confirmationTimeout', seconds);

  int get paymentTimeout =>
      _prefs.getInt('timers.paymentTimeout') ?? 300;
  Future<void> setPaymentTimeout(int seconds) =>
      _prefs.setInt('timers.paymentTimeout', seconds);

  int get processingErrorDuration =>
      _prefs.getInt('timers.processingErrorDuration') ?? 10;
  Future<void> setProcessingErrorDuration(int seconds) =>
      _prefs.setInt('timers.processingErrorDuration', seconds);

  int get thankYouDuration =>
      _prefs.getInt('timers.thankYouDuration') ?? 30;
  Future<void> setThankYouDuration(int seconds) =>
      _prefs.setInt('timers.thankYouDuration', seconds);

  // Legacy aliases
  int get retakeCountdown => captureCountdown;
  int get idleTimeout => _prefs.getInt('timers.idleTimeout') ?? 60;

  // ─── Runtime Session Timer (not persisted) ──────────────────

  int? _sessionStartMillis;

  /// Call when session starts (entering select-template from screensaver).
  void startSessionTimer() {
    _sessionStartMillis = DateTime.now().millisecondsSinceEpoch;
  }

  /// Remaining seconds for global mode. Returns 0 if expired.
  int get globalRemainingSeconds {
    if (_sessionStartMillis == null) return globalSessionTimeout;
    final elapsed =
        (DateTime.now().millisecondsSinceEpoch - _sessionStartMillis!) ~/ 1000;
    return (globalSessionTimeout - elapsed).clamp(0, globalSessionTimeout);
  }

  /// Whether a global session is active.
  bool get hasActiveSession => _sessionStartMillis != null;

  /// Clear session timer (when returning to screensaver).
  void clearSessionTimer() {
    _sessionStartMillis = null;
  }

  // ─── Default Printer ─────────────────────────────────────────

  static const _printerNameKey = 'printer.defaultName';
  static const _printerMacKey = 'printer.defaultMac';
  static const _printerConnectionTypeKey = 'printer.connectionType';

  /// Get saved default printer name (null if none saved).
  String? get defaultPrinterName => _prefs.getString(_printerNameKey);

  /// Get saved default printer MAC/device address (null if none saved).
  String? get defaultPrinterMac => _prefs.getString(_printerMacKey);

  /// Get saved printer connection type (defaults to bluetooth).
  String? get defaultPrinterConnectionType =>
      _prefs.getString(_printerConnectionTypeKey);

  /// Whether a default printer is saved.
  bool get hasDefaultPrinter =>
      defaultPrinterMac != null && defaultPrinterMac!.isNotEmpty;

  /// Save default printer info.
  Future<void> setDefaultPrinter({
    required String name,
    required String mac,
    String connectionType = 'bluetooth',
  }) async {
    await _prefs.setString(_printerNameKey, name);
    await _prefs.setString(_printerMacKey, mac);
    await _prefs.setString(_printerConnectionTypeKey, connectionType);
  }

  /// Clear saved default printer.
  Future<void> clearDefaultPrinter() async {
    await _prefs.remove(_printerNameKey);
    await _prefs.remove(_printerMacKey);
    await _prefs.remove(_printerConnectionTypeKey);
  }

  // ─── Confirmation Settings ──────────────────────────────────

  // Default total print count
  static const _defaultPrintCountKey = 'confirmation.defaultPrintCount';

  int get defaultPrintCount =>
      _prefs.getInt(_defaultPrintCountKey) ?? 1;

  Future<void> setDefaultPrintCount(int count) =>
      _prefs.setInt(_defaultPrintCountKey, count);

  // Softcopy enabled
  static const _softcopyEnabledKey = 'confirmation.softcopyEnabled';

  bool get isSoftcopyEnabled =>
      _prefs.getBool(_softcopyEnabledKey) ?? true;

  Future<void> setSoftcopyEnabled(bool enabled) =>
      _prefs.setBool(_softcopyEnabledKey, enabled);

  // ─── Screensaver Config ─────────────────────────────────────

  static const _screensaverTypeKey = 'screensaver.type';
  static const _screensaverFileKey = 'screensaver.filePath';

  /// Screensaver type: 'default', 'image', or 'video'.
  String get screensaverType =>
      _prefs.getString(_screensaverTypeKey) ?? 'default';

  Future<void> setScreensaverType(String type) =>
      _prefs.setString(_screensaverTypeKey, type);

  /// Screensaver file path (image or video).
  String? get screensaverFilePath => _prefs.getString(_screensaverFileKey);

  Future<void> setScreensaverFilePath(String path) =>
      _prefs.setString(_screensaverFileKey, path);

  Future<void> clearScreensaver() async {
    await _prefs.remove(_screensaverTypeKey);
    await _prefs.remove(_screensaverFileKey);
  }

  // ─── Per-Page BG Config ──────────────────────────────────────

  /// Background type for a page: 'default', 'image', or 'video'.
  /// [pageKey] examples: 'selectTemplate', 'photoSession', 'preview',
  /// 'confirmation', 'processing', 'thankYou'.
  String pageBgType(String pageKey) =>
      _prefs.getString('$pageKey.bgType') ?? 'default';

  Future<void> setPageBgType(String pageKey, String type) =>
      _prefs.setString('$pageKey.bgType', type);

  String? pageBgFilePath(String pageKey) =>
      _prefs.getString('$pageKey.bgFilePath');

  Future<void> setPageBgFilePath(String pageKey, String path) =>
      _prefs.setString('$pageKey.bgFilePath', path);

  Future<void> clearPageBg(String pageKey) async {
    await _prefs.remove('$pageKey.bgType');
    await _prefs.remove('$pageKey.bgFilePath');
  }
}
