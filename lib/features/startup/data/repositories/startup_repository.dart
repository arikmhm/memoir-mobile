import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../shared/core/utils/result.dart';
import '../../../../shared/data/datasources/storage_service.dart';
import '../../../../shared/data/models/kiosk_config.dart';
import '../../../../shared/data/models/template.dart';
import '../../../../shared/data/services/template_cache_service.dart';
import '../datasources/startup_datasource.dart';

/// Repository yang mengorkestrasi startup sequence.
///
/// Menjalankan:
/// 1. Status check device (GET /kiosk/me)
/// 2. Template sync (GET /kiosk/templates)
/// 3. Menyimpan data ke local storage/cache
class StartupRepository {
  final StartupDatasource _datasource;
  final StorageService _storageService;
  final TemplateCacheService _cacheService;

  StartupRepository({
    required StartupDatasource datasource,
    required StorageService storageService,
    required TemplateCacheService cacheService,
  }) : _datasource = datasource,
       _storageService = storageService,
       _cacheService = cacheService;

  /// Check device status dari backend.
  ///
  /// Returns [KioskConfig] jika device aktif.
  /// Jika status bukan 'ACTIVE', kembalikan error.
  Future<Result<KioskConfig>> checkDeviceStatus() async {
    try {
      final config = await _datasource.getKioskStatus();

      if (!config.canOperate) {
        return Result.error(
          Exception('Device tidak aktif: ${config.subscriptionStatus}'),
        );
      }

      // Persist full config (includes sessionPreviewUrl from /kiosk/me)
      await _storageService.setKioskConfig(config.toJsonString());

      return Result.ok(config);
    } on StartupException catch (e) {
      return Result.error(Exception(e.message));
    } catch (e) {
      return Result.error(Exception(_friendlyMessage(e)));
    }
  }

  /// Sinkronisasi template dari backend.
  ///
  /// Fetches from API, caches JSON + downloads images locally.
  /// Falls back to local cache if API fails.
  Future<Result<List<Template>>> syncTemplates() async {
    try {
      final templates = await _datasource.getTemplates();

      // Cache JSON + download background/overlay images
      final cached = await _cacheService.cacheTemplates(templates);

      return Result.ok(cached);
    } on StartupException catch (e) {
      // API failed — try local cache as fallback
      final cached = _cacheService.loadCached();
      if (cached.isNotEmpty) return Result.ok(cached);
      return Result.error(Exception(e.message));
    } catch (e) {
      final cached = _cacheService.loadCached();
      if (cached.isNotEmpty) return Result.ok(cached);
      return Result.error(Exception(_friendlyMessage(e)));
    }
  }

  /// Cek apakah device token masih tersedia.
  Future<bool> hasDeviceToken() => _storageService.hasDeviceToken();

  /// Translate raw exceptions into user-friendly Indonesian messages.
  String _friendlyMessage(Object e) {
    if (e is SocketException) {
      return 'Tidak dapat terhubung ke server.\nPeriksa koneksi internet Anda.';
    }
    if (e is DioException) {
      return switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'Koneksi ke server terlalu lama.\nPeriksa koneksi internet Anda.',
        DioExceptionType.connectionError =>
          'Tidak dapat terhubung ke server.\nPeriksa koneksi internet Anda.',
        _ => 'Gagal berkomunikasi dengan server.',
      };
    }
    return 'Terjadi kesalahan. Silakan coba lagi.';
  }
}
