import 'package:dio/dio.dart';

import '../../../shared/core/constants/api_constants.dart';

/// Dio HTTP client wrapper for memoir. Backend API.
///
/// Handles:
/// - Base URL configuration
/// - Auth interceptor (Bearer device_token)
/// - Timeout configuration
/// - Error handling (401 → token invalidation)
///
/// Currently uses mock responses until API integration is ready.
class ApiClient {
  late final Dio _dio;
  final Future<String?> Function() _getToken;
  final Future<void> Function() _onAuthError;

  ApiClient({
    required Future<String?> Function() getToken,
    required Future<void> Function() onAuthError,
    String? baseUrl,
  }) : _getToken = getToken,
       _onAuthError = onAuthError {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await _onAuthError();
          }
          handler.next(error);
        },
      ),
    );
  }

  /// GET request.
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) => _dio.get<T>(path, queryParameters: queryParameters);

  /// POST request.
  Future<Response<T>> post<T>(String path, {Object? data}) =>
      _dio.post<T>(path, data: data);

  /// Exposed Dio instance for advanced usage (e.g., multipart upload).
  Dio get dio => _dio;
}
