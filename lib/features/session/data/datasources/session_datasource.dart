import 'package:dio/dio.dart';

import '../../../../shared/core/constants/api_constants.dart';
import '../../../../shared/data/datasources/api_client.dart';
import '../../../../shared/data/models/session.dart';

/// Session datasource — upload digital copy via multipart.
///
/// API: POST /kiosk/sessions (multipart: transactionId + file)
class SessionDatasource {
  final ApiClient _apiClient;
  final bool useMock;

  SessionDatasource({
    required ApiClient apiClient,
    this.useMock = ApiConstants.useMock,
  }) : _apiClient = apiClient;

  /// Upload composite image as digital copy.
  ///
  /// Returns [UploadResult] with session data + download URL.
  /// Throws [SessionUploadException] on failure.
  Future<UploadResult> uploadDigitalCopy({
    required String transactionId,
    required String filePath,
  }) async {
    if (useMock) return _mockUpload(transactionId);

    try {
      final formData = FormData.fromMap({
        'transactionId': transactionId,
        'file': await MultipartFile.fromFile(
          filePath,
          filename: 'composite.jpg',
        ),
      });

      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        ApiConstants.sessionsEndpoint,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 1),
        ),
      );

      final data = response.data?['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw const SessionUploadException(
          'Respons tidak valid dari server',
        );
      }

      final sessionJson = data['session'] as Map<String, dynamic>?;
      final downloadUrl = data['downloadUrl'] as String?;
      if (sessionJson == null || downloadUrl == null) {
        throw const SessionUploadException(
          'Respons session tidak lengkap',
        );
      }

      return UploadResult(
        session: Session.fromJson(sessionJson),
        downloadUrl: downloadUrl,
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ─── Mock ──────────────────────────────────────────────────────

  Future<UploadResult> _mockUpload(String transactionId) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return UploadResult(
      session: Session(
        id: 'session-mock-001',
        transactionId: transactionId,
        resultImageUrl:
            'https://storage.supabase.co/sessions/$transactionId/result.jpeg',
        createdAt: DateTime.now().toIso8601String(),
      ),
      downloadUrl:
          'https://storage.supabase.co/sessions/$transactionId/result.jpeg',
    );
  }

  // ─── Error mapping ─────────────────────────────────────────────

  SessionUploadException _mapDioError(DioException e) {
    return switch (e.response?.statusCode) {
      400 => const SessionUploadException(
        'File tidak valid atau terlalu besar (maks 10MB)',
      ),
      404 => const SessionUploadException('Transaksi tidak ditemukan'),
      409 => const SessionUploadException(
        'Session sudah ada untuk transaksi ini',
      ),
      422 => const SessionUploadException(
        'Transaksi belum dibayar atau digital copy tidak aktif',
      ),
      _ => SessionUploadException(
        'Gagal upload: ${e.message}',
      ),
    };
  }
}

/// Result of uploading a digital copy.
class UploadResult {
  final Session session;
  final String downloadUrl;
  const UploadResult({required this.session, required this.downloadUrl});
}

/// Exception for session upload errors.
class SessionUploadException implements Exception {
  final String message;
  const SessionUploadException(this.message);

  @override
  String toString() => 'SessionUploadException: $message';
}
