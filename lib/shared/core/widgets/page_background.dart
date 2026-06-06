import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../di.dart';
import '../../data/datasources/storage_service.dart';

/// Full-size background widget for session screens.
///
/// Reads background config from [StorageService] using [pageKey] and renders:
/// - 'default' → solid white background
/// - 'image'   → fullscreen image file
/// - 'video'   → fullscreen looping video (muted)
///
/// [pageKey] must match the key used when saving in settings
/// (e.g. 'selectTemplate', 'photoSession', 'preview').
///
/// Config is re-read on every [build] (cheap in-memory prefs lookup) so a
/// background changed in settings is reflected on the next session without
/// having to wait for the widget's State to be disposed/recreated. File IO
/// and video (re)initialization only run when the stored config changes.
class PageBackground extends StatefulWidget {
  final String pageKey;
  const PageBackground({super.key, required this.pageKey});

  @override
  State<PageBackground> createState() => _PageBackgroundState();
}

class _PageBackgroundState extends State<PageBackground> {
  // Last raw config read from storage — used to short-circuit re-resolution.
  String? _lastRawType;
  String? _lastRawPath;

  // Resolved (validated) config.
  String _bgType = 'default';
  String? _bgFilePath;

  VideoPlayerController? _videoController;
  String? _videoControllerPath;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  /// Re-reads config from storage. Cheap to call every build: it short-circuits
  /// unless the stored type/path actually changed, so [File.existsSync] and
  /// video re-init only run on a real config change.
  void _resolveConfig() {
    final storage = sl<StorageService>();
    final type = storage.pageBgType(widget.pageKey);
    final path = storage.pageBgFilePath(widget.pageKey);

    if (type == _lastRawType && path == _lastRawPath) return;
    _lastRawType = type;
    _lastRawPath = path;

    // Validate file exists, fallback to default.
    if ((type == 'image' || type == 'video') &&
        (path == null || !File(path).existsSync())) {
      _bgType = 'default';
      _bgFilePath = null;
    } else {
      _bgType = type;
      _bgFilePath = path;
    }

    if (_bgType == 'video') {
      _syncVideo(_bgFilePath);
    } else {
      _disposeVideo();
    }
  }

  void _syncVideo(String? path) {
    if (_videoControllerPath == path && _videoController != null) return;
    _disposeVideo();
    if (path == null) return;

    _videoControllerPath = path;
    final controller = VideoPlayerController.file(File(path));
    _videoController = controller;
    controller.initialize().then((_) {
      if (!mounted || _videoController != controller) {
        controller.dispose();
        return;
      }
      controller.setLooping(true);
      controller.setVolume(0);
      controller.play();
      setState(() {});
    });
  }

  void _disposeVideo() {
    _videoController?.dispose();
    _videoController = null;
    _videoControllerPath = null;
  }

  @override
  Widget build(BuildContext context) {
    _resolveConfig();

    if (_bgType == 'image' && _bgFilePath != null) {
      return Image.file(
        File(_bgFilePath!),
        // Key by path so a reused element rebuilds when the file changes.
        key: ValueKey(_bgFilePath),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => const ColoredBox(color: Colors.white),
      );
    }
    if (_bgType == 'video') {
      final controller = _videoController;
      if (controller != null && controller.value.isInitialized) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        );
      }
      return const ColoredBox(color: Colors.black);
    }
    return const ColoredBox(color: Colors.white);
  }
}
