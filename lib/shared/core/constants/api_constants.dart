/// API configuration constants.
///
/// Endpoint paths match PRD-05 Section 7 (identical to PRD-04).
/// Base URL configurable via --dart-define=API_BASE_URL=...
class ApiConstants {
  ApiConstants._();

  // Base URL — override via: flutter run --dart-define=API_BASE_URL=https://...
  // Local API di port 3000, host 0.0.0.0
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.3.102:3000/api/v1',
  );

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

  /// Returns confirm-cash endpoint for a given transaction ID.
  static String confirmCashEndpoint(String transactionId) =>
      '/kiosk/transactions/$transactionId/confirm-cash';

  /// Returns check-payment endpoint for a given transaction ID.
  static String checkPaymentEndpoint(String transactionId) =>
      '/kiosk/transactions/$transactionId/check-payment';

  static const String sessionsEndpoint = '/kiosk/sessions';
}
