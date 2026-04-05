/// App-wide constants for memoir. Mobile Runner.
///
/// Timer defaults, version info, and device requirements.
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'memoir.';
  static const String appVersion = '1.0.0';
  static const int minAndroidApi = 29; // Android 10

  // Timer Defaults (in seconds)
  static const int retakeCountdownDefault = 5;
  static const int paymentTimeoutDefault = 300; // 5 minutes
  static const int thankYouDurationDefault = 300; // 5 minutes
  static const int idleTimeoutDefault = 60;

  // Photo Session
  static const int maxRetakeAttempts = -1; // unlimited
  static const int countdownSeconds = 3;

  // Hidden Settings Access
  static const int settingsTapCount = 5;
  static const int settingsTapWindowMs = 2000;
}
