/// API configuration constants.
///
/// Endpoint paths match PRD-05 Section 7 (identical to PRD-04).
/// Base URL is now set dynamically via AppConfig (see lib/config/app_config.dart).
class ApiConstants {
  ApiConstants._();

  // Mock mode — override via: flutter run --dart-define=USE_MOCK=true
  static const bool useMock = bool.fromEnvironment('USE_MOCK');

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Kiosk Endpoints
  static const String pairEndpoint = '/kiosk/pair';
  static const String meEndpoint = '/kiosk/me';
  static const String templatesEndpoint = '/kiosk/templates';
  static const String transactionsEndpoint = '/kiosk/transactions';

  /// Returns check-payment endpoint for a given transaction ID.
  static String checkPaymentEndpoint(String transactionId) =>
      '/kiosk/transactions/$transactionId/check-payment';

  static const String sessionsEndpoint = '/kiosk/sessions';
}
