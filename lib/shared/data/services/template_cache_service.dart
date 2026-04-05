import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/template.dart';

/// Local template cache — persists template JSON + downloads images.
///
/// Stores:
/// - Template list as JSON → SharedPreferences (`templates_cache`)
/// - Background/overlay images → app documents dir (`templates/`)
///
/// Images are downloaded once and reused. Re-downloaded when
/// `updatedAt` changes (template edited by owner).
class TemplateCacheService {
  final SharedPreferences _prefs;
  final Dio _dio;

  static const _cacheKey = 'templates_cache';

  TemplateCacheService({
    required SharedPreferences prefs,
    required Dio dio,
  })  : _prefs = prefs,
        _dio = dio;

  /// Load cached templates from SharedPreferences.
  ///
  /// Returns empty list if nothing cached.
  List<Template> loadCached() {
    final jsonStr = _prefs.getString(_cacheKey);
    if (jsonStr == null) return [];

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => Template.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Cache templates: save JSON + download images to local files.
  ///
  /// Returns the list with `localBackgroundPath` / `localOverlayPath`
  /// filled in for templates whose images were successfully downloaded.
  Future<List<Template>> cacheTemplates(List<Template> templates) async {
    final dir = await _getTemplateDir();
    final updated = <Template>[];

    for (final tmpl in templates) {
      var localBg = tmpl.localBackgroundPath;
      var localOverlay = tmpl.localOverlayPath;

      // Download background image
      if (tmpl.backgroundUrl != null && tmpl.backgroundUrl!.isNotEmpty) {
        localBg = await _downloadIfNeeded(
          url: tmpl.backgroundUrl!,
          dir: dir,
          filename: '${tmpl.id}_bg',
        );
      }

      // Download overlay image
      if (tmpl.overlayUrl != null && tmpl.overlayUrl!.isNotEmpty) {
        localOverlay = await _downloadIfNeeded(
          url: tmpl.overlayUrl!,
          dir: dir,
          filename: '${tmpl.id}_overlay',
        );
      }

      updated.add(tmpl.copyWith(
        localBackgroundPath: localBg,
        localOverlayPath: localOverlay,
      ));
    }

    // Persist JSON
    final jsonStr = jsonEncode(updated.map((t) => t.toJson()).toList());
    await _prefs.setString(_cacheKey, jsonStr);

    return updated;
  }

  /// Clear all cached templates and downloaded images.
  Future<void> clearCache() async {
    await _prefs.remove(_cacheKey);
    final dir = await _getTemplateDir();
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }

  Future<Directory> _getTemplateDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/templates');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Download image if not already on disk.
  ///
  /// Returns local file path on success, null on failure.
  Future<String?> _downloadIfNeeded({
    required String url,
    required Directory dir,
    required String filename,
  }) async {
    // Derive extension from URL
    final ext = _extractExtension(url);
    final file = File('${dir.path}/$filename$ext');

    // Skip download if file already exists
    if (file.existsSync()) return file.path;

    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.data != null) {
        await file.writeAsBytes(response.data!);
        return file.path;
      }
    } catch (_) {
      // Silently fail — image just won't show locally
    }
    return null;
  }

  String _extractExtension(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final dot = path.lastIndexOf('.');
      if (dot != -1 && dot < path.length - 1) {
        final ext = path.substring(dot).toLowerCase();
        if (ext.length <= 5) return ext; // .png, .jpg, .webp
      }
    } catch (_) {}
    return '.png'; // Default
  }
}
