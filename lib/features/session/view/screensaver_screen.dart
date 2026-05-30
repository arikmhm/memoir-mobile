import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../di.dart';
import '../../../shared/core/theme/app_colors.dart';
import '../../../shared/core/theme/app_spacing.dart';
import '../../../shared/data/datasources/storage_service.dart';

/// Screensaver / attract-mode screen for the kiosk.
///
/// Supports three modes:
/// - 'default': memoir. logo with pulsing CTA (original)
/// - 'image': fullscreen background image
/// - 'video': looping video background
///
/// Mode is read from StorageService on init and on return from settings.
class ScreensaverScreen extends StatefulWidget {
  const ScreensaverScreen({super.key});

  @override
  State<ScreensaverScreen> createState() => _ScreensaverScreenState();
}

class _ScreensaverScreenState extends State<ScreensaverScreen>
    with SingleTickerProviderStateMixin {
  final List<DateTime> _hiddenTaps = [];

  static const int _requiredTaps = 5;
  static const Duration _tapWindow = Duration(seconds: 2);

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  late final StorageService _storage;
  late String _type;
  String? _filePath;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _storage = sl<StorageService>();
    _storage.clearSessionTimer();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadConfig();
  }

  void _loadConfig() {
    final type = _storage.screensaverType;
    final path = _storage.screensaverFilePath;

    // Validate file exists, fallback to default
    if ((type == 'image' || type == 'video') &&
        (path == null || !File(path).existsSync())) {
      _type = 'default';
      _filePath = null;
      return;
    }

    _type = type;
    _filePath = path;

    if (_type == 'video' && _filePath != null) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    _videoController?.dispose();
    _videoController = VideoPlayerController.file(File(_filePath!));
    await _videoController!.initialize();
    _videoController!.setLooping(true);
    _videoController!.setVolume(0);
    _videoController!.play();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _onHiddenTap() {
    final now = DateTime.now();
    _hiddenTaps.removeWhere((t) => now.difference(t) > _tapWindow);
    _hiddenTaps.add(now);

    if (_hiddenTaps.length >= _requiredTaps) {
      _hiddenTaps.clear();
      context.push('/home').then((_) {
        // Reload config when returning from home
        if (mounted) {
          _videoController?.dispose();
          _videoController = null;
          setState(() => _loadConfig());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Background layer ──
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.go('/select-template'),
            child: SizedBox.expand(
              child: switch (_type) {
                'image' => _ImageBackground(filePath: _filePath!),
                'video' => _VideoBackground(controller: _videoController),
                _ => _DefaultBackground(
                    pulseAnimation: _pulseAnimation,
                  ),
              },
            ),
          ),


          // ── Hidden access zone ──
          Positioned(
            left: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onHiddenTap,
              child: const SizedBox(width: 80, height: 80),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Default background (memoir. logo) ──────────────────────────

class _DefaultBackground extends StatelessWidget {
  final Animation<double> pulseAnimation;

  const _DefaultBackground({required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'memoir.',
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w300,
                letterSpacing: 4,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 40,
              height: 1,
              color: AppColors.border,
            ),
            const SizedBox(height: AppSpacing.xl),
            FadeTransition(
              opacity: pulseAnimation,
              child: Text(
                'TAP UNTUK MULAI',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Image background ───────────────────────────────────────────

class _ImageBackground extends StatelessWidget {
  final String filePath;

  const _ImageBackground({required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(filePath),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => const _DefaultBackground(
        pulseAnimation: AlwaysStoppedAnimation(1.0),
      ),
    );
  }
}

// ─── Video background ───────────────────────────────────────────

class _VideoBackground extends StatelessWidget {
  final VideoPlayerController? controller;

  const _VideoBackground({this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller!.value.size.width,
        height: controller!.value.size.height,
        child: VideoPlayer(controller!),
      ),
    );
  }
}
