import 'package:dio/dio.dart';

import '../../../../shared/core/constants/api_constants.dart';
import '../../../../shared/data/datasources/api_client.dart';

/// Result of a successful pairing API call.
class PairResult {
  final String deviceToken;
  final Map<String, dynamic>? kioskConfig;

  const PairResult({required this.deviceToken, this.kioskConfig});
}

/// Pairing datasource — API calls for device pairing.
///
/// API: POST /kiosk/pair { pairingCode } → { data: { deviceToken, kioskConfig } }
class PairingDatasource {
  final ApiClient _apiClient;
  final bool useMock;

  PairingDatasource({
    required ApiClient apiClient,
    this.useMock = ApiConstants.useMock,
  }) : _apiClient = apiClient;

  /// Exchange 6-digit pairing code for a device token + kiosk config.
  ///
  /// Implements exponential backoff retry on 429 (rate limit).
  /// Returns [PairResult] with token and optional kioskConfig.
  /// Throws [PairingException] on failure.
  Future<PairResult> pair(String pairingCode) => _retryWithExponentialBackoff(
    () => _performPair(pairingCode),
    maxRetries: 3,
  );

  /// Performs the actual pair request.
  Future<PairResult> _performPair(String pairingCode) async {
    if (useMock) return _mockPair(pairingCode);

    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.pairEndpoint,
        data: {'pairingCode': pairingCode},
      );

      final responseData =
          response.data?['data'] as Map<String, dynamic>?;
      final token = responseData?['deviceToken'] as String?;
      if (token == null || token.isEmpty) {
        throw const PairingException('Respons tidak valid dari server');
      }

      final kioskConfig =
          responseData?['kioskConfig'] as Map<String, dynamic>?;

      return PairResult(deviceToken: token, kioskConfig: kioskConfig);
    } on DioException catch (e) {
      switch (e.response?.statusCode) {
        case 404:
          throw const PairingException('Kode pairing tidak ditemukan atau sudah kedaluwarsa');
        case 422:
          throw const PairingException('Kode pairing tidak valid (harus tepat 6 angka)');
        case 429:
          rethrow; // Let retry logic handle this
        default:
          throw PairingException(
            'Gagal menghubungi server: ${e.message}',
          );
      }
    }
  }

  /// Retries a pairing request with exponential backoff on 429 errors.
  ///
  /// Implements exponential backoff with jitter:
  /// - Attempt 1: immediate
  /// - Attempt 2: 100ms + jitter
  /// - Attempt 3: 200ms + jitter
  /// - Attempt 4: 400ms + jitter
  Future<PairResult> _retryWithExponentialBackoff(
    Future<PairResult> Function() fn, {
    int maxRetries = 3,
  }) async {
    var attempt = 0;
    while (true) {
      try {
        return await fn();
      } on DioException catch (e) {
        attempt++;
        if (e.response?.statusCode != 429 || attempt >= maxRetries) {
          rethrow;
        }
        // Exponential backoff: 100ms * 2^(attempt-1) + random jitter
        final baseDelay = 100 * (1 << (attempt - 1));
        final jitter = (baseDelay * 0.1 * (DateTime.now().millisecond % 100) / 100).toInt();
        await Future<void>.delayed(Duration(milliseconds: baseDelay + jitter));
      }
    }
  }

  /// Mock implementation for development without backend.
  Future<PairResult> _mockPair(String pairingCode) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    if (pairingCode == '000000') {
      throw const PairingException('Kode pairing tidak valid');
    }

    return PairResult(
      deviceToken: 'mock_device_token_${DateTime.now().millisecondsSinceEpoch}',
      kioskConfig: {
        'id': 'mock-kiosk-id',
        'name': 'Mock Booth A',
        'ownerId': 'mock-owner-id',
        'priceBaseSession': 25000,
        'pricePerExtraPrint': 5000,
        'priceDigitalCopy': 10000,
      },
    );
  }
}

/// Exception thrown when pairing fails.
class PairingException implements Exception {
  final String message;

  const PairingException(this.message);

  @override
  String toString() => message;
}
