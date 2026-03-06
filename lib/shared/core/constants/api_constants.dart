/// API configuration constants.
///
/// Endpoint paths match PRD-05 Section 7 (identical to PRD-04).
/// Base URL is placeholder — will be configured per environment.
class ApiConstants {
  ApiConstants._();

  // Base URL (placeholder — override via environment config)
  static const String baseUrl = 'https://api.memoir.local/api/v1';

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
