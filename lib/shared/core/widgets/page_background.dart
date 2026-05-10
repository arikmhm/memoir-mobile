import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../di.dart';
import '../../data/datasources/storage_service.dart';
import 'noise_background.dart';

/// Full-size background widget for session screens.
///
/// Reads background config from [StorageService] using [pageKey] and renders:
/// - 'default' → [NoiseBackground] texture
/// - 'image'   → fullscreen image file
/// - 'video'   → fullscreen looping video (muted)
///
/// [pageKey] must match the key used when saving in settings
/// (e.g. 'selectTemplate', 'photoSession', 'preview').
class PageBackground extends StatefulWidget {
  final String pageKey;
  const PageBackground({super.key, required this.pageKey});

  @override
  State<PageBackground> createState() => _PageBackgroundState();
}

class _PageBackgroundState extends State<PageBackground> {
  late String _bgType;
  String? _bgFilePath;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final storage = sl<StorageService>();
    final type = storage.pageBgType(widget.pageKey);
    final path = storage.pageBgFilePath(widget.pageKey);
    if ((type == 'image' || type == 'video') &&
        (path == null || !File(path).existsSync())) {
      _bgType = 'default';
      return;
    }
    _bgType = type;
    _bgFilePath = path;
    if (_bgType == 'video') _initVideo();
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.file(File(_bgFilePath!));
    await _videoController!.initialize();
    _videoController!.setLooping(true);
    _videoController!.setVolume(0);
    _videoController!.play();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bgType == 'image' && _bgFilePath != null) {
      return Image.file(
        File(_bgFilePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) =>
            const RepaintBoundary(child: NoiseBackground()),
      );
    }
    if (_bgType == 'video') {
      if (_videoController != null && _videoController!.value.isInitialized) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        );
      }
      return const ColoredBox(color: Colors.black);
    }
    return const RepaintBoundary(child: NoiseBackground());
  }
}
