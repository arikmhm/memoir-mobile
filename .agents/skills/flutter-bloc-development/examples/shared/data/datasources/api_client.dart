// Example: Shared API Client
// Path: lib/shared/data/datasources/api_client.dart
//
// This is a SHARED datasource used by multiple features.
// It provides the base HTTP client configuration.

import 'package:dio/dio.dart';

/// Shared API client used across all features
/// 
/// WHY SHARED: Every feature needs HTTP calls with the same:
/// - Base URL
/// - Auth headers
/// - Error handling
/// - Interceptors (logging, retry, token refresh)
class ApiClient {
  final Dio _dio;

  ApiClient({required String baseUrl, required String Function() getToken})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['Authorization'] = 'Bearer ${getToken()}';
        return handler.next(options);
      },
      onError: (error, handler) {
        // Centralized error handling
        return handler.next(error);
      },
    ));
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? params}) =>
      _dio.get<T>(path, queryParameters: params);

  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      _dio.post<T>(path, data: data);

  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      _dio.put<T>(path, data: data);

  Future<Response<T>> delete<T>(String path) => _dio.delete<T>(path);
}
