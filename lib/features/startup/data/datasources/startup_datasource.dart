import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../shared/core/constants/api_constants.dart';
import '../../../../shared/data/datasources/api_client.dart';
import '../../../../shared/data/models/kiosk_config.dart';
import '../../../../shared/data/models/template.dart';

/// Startup datasource — API calls for device status check & template sync.
///
/// Uses [ApiClient] for real API calls. Falls back to mock when
/// [useMock] is true (default for initial development).
///
/// API:
/// - GET /kiosk/me → KioskConfig (status check)
/// - GET /kiosk/templates → List<Template> (template sync)
class StartupDatasource {
  final ApiClient _apiClient;
  final bool useMock;

  StartupDatasource({
    required ApiClient apiClient,
    this.useMock = ApiConstants.useMock,
  }) : _apiClient = apiClient;

  /// Check device status via GET /kiosk/me.
  ///
  /// Returns [KioskConfig] with device info and pricing.
  /// Throws [StartupException] on failure.
  Future<KioskConfig> getKioskStatus() async {
    if (useMock) return _mockGetKioskStatus();

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiConstants.meEndpoint,
      );

      final data = response.data;
      if (data == null) {
        throw const StartupException('Respons status device tidak valid');
      }

      final responseData = data['data'] as Map<String, dynamic>?;
      if (responseData == null) {
        throw const StartupException('Respons status device tidak valid');
      }

      return KioskConfig.fromMeJson(responseData);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const StartupException('Device token tidak valid');
      }
      throw StartupException(
        _friendlyDioMessage(e, 'Gagal mengecek status device'),
      );
    } catch (e) {
      throw StartupException(
        'Gagal memproses data device: $e',
      );
    }
  }

  /// Sync templates via GET /kiosk/templates.
  ///
  /// Returns list of [Template] available for this device.
  /// Throws [StartupException] on failure.
  Future<List<Template>> getTemplates() async {
    if (useMock) return _mockGetTemplates();

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiConstants.templatesEndpoint,
      );

      final data = response.data;
      if (data == null) {
        throw const StartupException('Respons template tidak valid');
      }

      final templateList = data['data'] as List<dynamic>?;
      if (templateList == null) {
        throw const StartupException('Respons template tidak valid');
      }

      // Debug: log raw API response
      for (final item in templateList) {
        final tmpl = (item as Map<String, dynamic>)['template'] as Map<String, dynamic>?;
        debugPrint('[API] template "${tmpl?['name']}" backgroundUrl: ${tmpl?['backgroundUrl']}');
      }

      final templates = templateList
          .map((e) => Template.fromApiJson(e as Map<String, dynamic>))
          .toList();

      return templates;
    } on DioException catch (e) {
      throw StartupException(
        _friendlyDioMessage(e, 'Gagal sinkronisasi template'),
      );
    } catch (e) {
      throw StartupException(
        'Gagal memproses data template: $e',
      );
    }
  }

  // ─── Mock Implementations ─────────────────────────────────────

  Future<KioskConfig> _mockGetKioskStatus() async {
    // Simulasi network delay
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    return const KioskConfig(
      id: 'kiosk_mock_001',
      name: 'Booth Wedding Hall A',
      ownerId: 'owner_mock_001',
      priceBaseSession: 25000,
      pricePerExtraPrint: 10000,
      priceDigitalCopy: 5000,
      subscriptionStatus: 'ACTIVE',
      sessionPreviewUrl: 'https://memoir.id/preview',
    );
  }

  Future<List<Template>> _mockGetTemplates() async {
    // Simulasi network delay
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    return [
      Template(
        id: 'tmpl_001',
        name: 'Classic Strip 4',
        width: 600,
        height: 1800,
        backgroundUrl: 'https://example.com/bg1.png',
        elements: [
          const TemplateElement(
            id: 'el_001',
            type: 'PHOTO_SLOT',
            x: 50,
            y: 50,
            width: 500,
            height: 375,
            sequence: 1,
            properties: {'captureOrder': 1},
          ),
          const TemplateElement(
            id: 'el_002',
            type: 'PHOTO_SLOT',
            x: 50,
            y: 475,
            width: 500,
            height: 375,
            sequence: 2,
            properties: {'captureOrder': 2},
          ),
          const TemplateElement(
            id: 'el_003',
            type: 'PHOTO_SLOT',
            x: 50,
            y: 900,
            width: 500,
            height: 375,
            sequence: 3,
            properties: {'captureOrder': 3},
          ),
          const TemplateElement(
            id: 'el_004',
            type: 'PHOTO_SLOT',
            x: 50,
            y: 1325,
            width: 500,
            height: 375,
            sequence: 4,
            properties: {'captureOrder': 4},
          ),
        ],
        updatedAt: DateTime(2026, 3, 1),
      ),
      Template(
        id: 'tmpl_002',
        name: 'Duo Frame',
        width: 1200,
        height: 800,
        backgroundUrl: 'https://example.com/bg2.png',
        elements: [
          const TemplateElement(
            id: 'el_005',
            type: 'PHOTO_SLOT',
            x: 50,
            y: 50,
            width: 540,
            height: 700,
            sequence: 1,
            properties: {'captureOrder': 1},
          ),
          const TemplateElement(
            id: 'el_006',
            type: 'PHOTO_SLOT',
            x: 610,
            y: 50,
            width: 540,
            height: 700,
            sequence: 2,
            properties: {'captureOrder': 2},
          ),
        ],
        updatedAt: DateTime(2026, 3, 2),
      ),
      Template(
        id: 'tmpl_003',
        name: 'Single Wide',
        width: 1200,
        height: 800,
        backgroundUrl: 'https://example.com/bg3.png',
        elements: [
          const TemplateElement(
            id: 'el_007',
            type: 'PHOTO_SLOT',
            x: 100,
            y: 100,
            width: 1000,
            height: 600,
            sequence: 1,
            properties: {'captureOrder': 1},
          ),
          const TemplateElement(
            id: 'el_008',
            type: 'TEXT',
            x: 400,
            y: 720,
            width: 400,
            height: 60,
            sequence: 2,
            properties: {
              'text': 'memoir.',
              'fontSize': 32,
              'fontFamily': 'Inter',
              'color': '#FFFFFF',
            },
          ),
        ],
        updatedAt: DateTime(2026, 3, 3),
      ),
    ];
  }
}

/// Exception thrown when startup operations fail.
class StartupException implements Exception {
  final String message;

  const StartupException(this.message);

  @override
  String toString() => message;
}

/// Translate DioException into user-friendly message.
String _friendlyDioMessage(DioException e, String fallback) {
  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      'Koneksi ke server terlalu lama.\nPeriksa koneksi internet Anda.',
    DioExceptionType.connectionError =>
      'Tidak dapat terhubung ke server.\nPeriksa koneksi internet Anda.',
    _ => fallback,
  };
}
