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
  /// Returns [PairResult] with token and optional kioskConfig.
  /// Throws [PairingException] on failure.
  Future<PairResult> pair(String pairingCode) async {
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
        case 400:
          throw const PairingException('Format kode pairing tidak valid');
        case 404:
          throw const PairingException(
            'Kode pairing tidak ditemukan atau sudah kedaluwarsa',
          );
        case 422:
          throw const PairingException('Kiosk tidak aktif');
        case 429:
          throw const PairingException(
            'Terlalu banyak percobaan. Coba lagi nanti.',
          );
        default:
          throw PairingException(
            'Gagal menghubungi server: ${e.message}',
          );
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
