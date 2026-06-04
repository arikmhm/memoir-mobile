import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/local_session.dart';

class LocalSessionService {
  Future<Directory> _sessionsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/sessions');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<void> save({
    required String templateId,
    required String templateName,
    required Map<int, String> capturedPhotos,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final sessionsDir = await _sessionsDir();
    final photosDir = Directory('${sessionsDir.path}/$id/photos');
    photosDir.createSync(recursive: true);

    final savedPaths = <int, String>{};
    for (final entry in capturedPhotos.entries) {
      final src = File(entry.value);
      if (!src.existsSync()) continue;
      final dest = '${photosDir.path}/${entry.key}.jpg';
      await src.copy(dest);
      savedPaths[entry.key] = dest;
    }

    final session = LocalSession(
      id: id,
      savedAt: DateTime.now(),
      templateId: templateId,
      templateName: templateName,
      photoPaths: savedPaths,
    );

    await File('${sessionsDir.path}/$id/metadata.json')
        .writeAsString(jsonEncode(session.toJson()));
  }

  Future<List<LocalSession>> listAll() async {
    final sessionsDir = await _sessionsDir();
    final sessions = <LocalSession>[];

    for (final entity in sessionsDir.listSync()) {
      if (entity is! Directory) continue;
      final metaFile = File('${entity.path}/metadata.json');
      if (!metaFile.existsSync()) continue;
      try {
        final raw = await metaFile.readAsString();
        sessions.add(LocalSession.fromJsonString(raw));
      } catch (_) {}
    }

    sessions.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return sessions;
  }

  Future<void> delete(String id) async {
    final sessionsDir = await _sessionsDir();
    final dir = Directory('${sessionsDir.path}/$id');
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
