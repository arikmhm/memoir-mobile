import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../di.dart';
import '../../../shared/core/theme/app_colors.dart';
import '../../../shared/core/widgets/global_session_countdown_bar.dart';
import '../../../shared/core/widgets/page_background.dart';
import '../../../shared/core/theme/app_spacing.dart';
import '../../../shared/data/datasources/storage_service.dart';
import '../../../shared/data/models/template.dart';
import '../../app/bloc/app_cubit.dart';
import '../../app/bloc/app_state.dart';

/// Photo session screen — live camera inside template slots.
///
/// Per PRD-05 FEAT-MR-05:
/// - Top: large template preview with active slot showing live camera
/// - Bottom: capture button + slot progress indicator
/// - Camera is contained (fit) within the active slot, centered
class PhotoSessionScreen extends StatefulWidget {
  final String templateId;

  const PhotoSessionScreen({super.key, required this.templateId});

  @override
  State<PhotoSessionScreen> createState() => _PhotoSessionScreenState();
}

class _PhotoSessionScreenState extends State<PhotoSessionScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  String? _cameraError;
  int _activeSlotIndex = 0;
  int? _countdownValue;

  late final AnimationController _slotFadeController;
  late final Animation<double> _slotFadeAnimation;

  late final AnimationController _activePulseController;
  late final Animation<double> _activePulseAnimation;

  late final AnimationController _countdownAnimController;

  /// Captured photos keyed by slot index.
  final Map<int, String> _capturedPhotos = {};

  Template? _findTemplate() {
    final appState = context.read<AppCubit>().state;
    if (appState is! AppReady) return null;
    final templates = appState.templates.cast<Template>();
    try {
      return templates.firstWhere((t) => t.id == widget.templateId);
    } catch (_) {
      return null;
    }
  }

  List<TemplateElement> _photoSlots(Template template) {
    return template.elements
        .where((e) => e.type == 'PHOTO_SLOT')
        .toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _slotFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _slotFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _slotFadeController, curve: Curves.easeInOut),
    );
    _activePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _activePulseAnimation = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _activePulseController,
        curve: Curves.easeInOut,
      ),
    );
    _countdownAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'Tidak ada kamera tersedia');
        return;
      }

      // Always use front camera (selfie) at max resolution.
      final selected = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        selected,
        ResolutionPreset.max,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _cameraError = 'Gagal menginisialisasi kamera',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
      _cameraController = null;
      setState(() => _isCameraReady = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _slotFadeController.dispose();
    _activePulseController.dispose();
    _countdownAnimController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  /// Animate slot transition: fade out → change slot → fade in.
  void _changeSlot(int newIndex) {
    if (newIndex == _activeSlotIndex) return;
    if (_slotFadeController.isAnimating) return;
    HapticFeedback.selectionClick();
    _slotFadeController.forward().then((_) {
      if (!mounted) return;
      setState(() => _activeSlotIndex = newIndex);
      _slotFadeController.reverse();
    });
  }

  Future<void> _capturePhoto(List<TemplateElement> slots) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (_countdownValue != null) return; // Already counting

    HapticFeedback.mediumImpact();

    // Countdown from configured value → 1
    final start = sl<StorageService>().captureCountdown;
    for (var i = start; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdownValue = i);
      _countdownAnimController.forward(from: 0);
      HapticFeedback.lightImpact();
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() => _countdownValue = null);

    try {
      HapticFeedback.heavyImpact();
      final file = await _cameraController!.takePicture();
      _capturedPhotos[_activeSlotIndex] = file.path;

      // All slots filled → auto-navigate to preview
      if (_capturedPhotos.length == slots.length) {
        if (mounted) {
          context.go(
            '/preview/${widget.templateId}',
            extra: Map<int, String>.from(_capturedPhotos),
          );
        }
        return;
      }

      // Advance to next empty slot with animation
      final nextEmpty = _findNextEmptySlot(slots);
      if (mounted && nextEmpty != null) {
        setState(() {}); // reflect captured photo first
        _changeSlot(nextEmpty);
      }
    } catch (_) {
      // Capture failed silently — user can retry
    }
  }

  int? _findNextEmptySlot(List<TemplateElement> slots) {
    // Look forward from current
    for (var i = _activeSlotIndex + 1; i < slots.length; i++) {
      if (!_capturedPhotos.containsKey(i)) return i;
    }
    // Wrap around
    for (var i = 0; i < _activeSlotIndex; i++) {
      if (!_capturedPhotos.containsKey(i)) return i;
    }
    return null; // All slots filled
  }

  Future<void> _handleCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Sesi?'),
        content: const Text(
          'Foto yang sudah diambil akan hilang. Anda akan kembali ke pilih template.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Lanjutkan'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      context.go('/select-template');
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = _findTemplate();

    if (template == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.textDisabled,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Template tidak ditemukan',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(
                  onPressed: () => context.go('/select-template'),
                  child: const Text('KEMBALI'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final slots = _photoSlots(template);
    final filledCount = _capturedPhotos.length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          const Positioned.fill(child: PageBackground(pageKey: 'photoSession')),
          SafeArea(
            child: Column(
              children: [
                // ── Header with cancel + title/progress + timer chip ──
                _Header(
                  filledCount: filledCount,
                  totalCount: slots.length,
                  onCancel: _handleCancel,
                ),

                // ── Template preview with live camera ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                      vertical: AppSpacing.lg,
                    ),
                    child: FadeTransition(
                      opacity: _slotFadeAnimation,
                      child: _SessionPreview(
                        template: template,
                        slots: slots,
                        activeSlotIndex: _activeSlotIndex,
                        capturedPhotos: _capturedPhotos,
                        cameraController:
                            _isCameraReady ? _cameraController : null,
                        cameraError: _cameraError,
                        countdownValue: _countdownValue,
                        countdownAnimation: _countdownAnimController,
                        activePulseAnimation: _activePulseAnimation,
                        onSlotTap: _changeSlot,
                      ),
                    ),
                  ),
                ),

                // ── Bottom controls ──
                _BottomControls(
                  slots: slots,
                  activeSlotIndex: _activeSlotIndex,
                  capturedPhotos: _capturedPhotos,
                  isCapturing: _countdownValue != null,
                  onCapture: () => _capturePhoto(slots),
                  onSlotTap: _changeSlot,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int filledCount;
  final int totalCount;
  final VoidCallback onCancel;

  const _Header({
    required this.filledCount,
    required this.totalCount,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.md,
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Cancel button
          GestureDetector(
            onTap: onCancel,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(
                Icons.close_rounded,
                size: 22,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          // Title + progress
          Expanded(
            child: Column(
              children: [
                Text(
                  'Sesi Foto',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Foto ${(filledCount + 1).clamp(1, totalCount)} dari $totalCount',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const GlobalSessionCountdownBar(compact: true),
        ],
      ),
    );
  }
}

// ─── Session Preview ────────────────────────────────────────────

class _SessionPreview extends StatelessWidget {
  final Template template;
  final List<TemplateElement> slots;
  final int activeSlotIndex;
  final Map<int, String> capturedPhotos;
  final CameraController? cameraController;
  final String? cameraError;
  final int? countdownValue;
  final AnimationController countdownAnimation;
  final Animation<double> activePulseAnimation;
  final ValueChanged<int> onSlotTap;

  const _SessionPreview({
    required this.template,
    required this.slots,
    required this.activeSlotIndex,
    required this.capturedPhotos,
    required this.cameraController,
    required this.cameraError,
    required this.countdownValue,
    required this.countdownAnimation,
    required this.activePulseAnimation,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasW = template.width.toDouble();
        final canvasH = template.height.toDouble();

        final scaleX = constraints.maxWidth / canvasW;
        final scaleY = constraints.maxHeight / canvasH;
        final scale = scaleX < scaleY ? scaleX : scaleY;

        final renderedW = canvasW * scale;
        final renderedH = canvasH * scale;

        final sortedElements = List<TemplateElement>.from(template.elements)
          ..sort((a, b) => a.sequence.compareTo(b.sequence));

        return Center(
          child: Container(
            width: renderedW,
            height: renderedH,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background
                _buildBackground(),
                // All elements
                ...sortedElements.map(
                  (el) => _buildElement(el, scale),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackground() {
    final localPath = template.localBackgroundPath;
    if (localPath != null && File(localPath).existsSync()) {
      return Positioned.fill(
        child: Image.file(
          File(localPath),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      );
    }
    final url = template.backgroundUrl;
    if (url != null && url.isNotEmpty) {
      return Positioned.fill(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildElement(TemplateElement el, double scale) {
    Widget child;

    if (el.type == 'PHOTO_SLOT') {
      final slotIndex = _slotIndex(el);
      child = _buildPhotoSlot(el, scale, slotIndex);
    } else if (el.type == 'TEXT') {
      child = _TextElement(element: el, scale: scale);
    } else if (el.type == 'IMAGE') {
      child = _ImageElement(element: el, scale: scale);
    } else {
      child = _GenericElement(element: el, scale: scale);
    }

    return Positioned(
      left: el.x * scale,
      top: el.y * scale,
      width: el.width * scale,
      height: el.height * scale,
      child: Opacity(
        opacity: el.normalizedOpacity,
        child: child,
      ),
    );
  }

  int _slotIndex(TemplateElement el) {
    return slots.indexOf(el);
  }

  Widget _buildPhotoSlot(TemplateElement el, double scale, int slotIndex) {
    final isActive = slotIndex == activeSlotIndex;
    final capturedPath = capturedPhotos[slotIndex];

    // If this slot has a captured photo, show it
    if (capturedPath != null) {
      return GestureDetector(
        onTap: () => onSlotTap(slotIndex),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: Transform.flip(
                flipX: true,
                child: Image.file(
                  File(capturedPath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            // Pulsing active border for already-captured slots that user re-selects
            if (isActive)
              AnimatedBuilder(
                animation: activePulseAnimation,
                builder: (_, _) => Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.brandPrimary.withValues(
                        alpha: activePulseAnimation.value,
                      ),
                      width: 2.5,
                    ),
                  ),
                ),
              )
            else
              // Subtle "tap to retake" hint via small badge in corner
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: (el.width * scale * 0.08).clamp(8, 14).toDouble(),
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Active slot: show camera preview with pulsing border
    if (isActive) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _CameraSlot(
            controller: cameraController,
            error: cameraError,
          ),
          AnimatedBuilder(
            animation: activePulseAnimation,
            builder: (_, _) => IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.brandPrimary.withValues(
                      alpha: activePulseAnimation.value,
                    ),
                    width: 2.5,
                  ),
                ),
              ),
            ),
          ),
          if (countdownValue != null)
            _CountdownOverlay(
              value: countdownValue!,
              animation: countdownAnimation,
            ),
        ],
      );
    }

    // Inactive empty slot: placeholder
    return GestureDetector(
      onTap: () => onSlotTap(slotIndex),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface.withAlpha(180),
          border: Border.all(color: AppColors.textDisabled, width: 0.5),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_camera_outlined,
                size: (el.width * scale * 0.2).clamp(12, 32).toDouble(),
                color: AppColors.textDisabled,
              ),
              const SizedBox(height: 2),
              Text(
                '${slotIndex + 1}',
                style: TextStyle(
                  fontSize: (el.width * scale * 0.08).clamp(8, 14),
                  color: AppColors.textDisabled,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Camera Slot ────────────────────────────────────────────────

/// Shows live camera preview filling the entire slot (cover), centered.
class _CameraSlot extends StatelessWidget {
  final CameraController? controller;
  final String? error;

  const _CameraSlot({required this.controller, required this.error});

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Container(
        color: AppColors.surfaceContainer,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                color: AppColors.error,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                error!,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (controller == null || !controller!.value.isInitialized) {
      return Container(
        color: AppColors.surfaceContainer,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.brandPrimary,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Mempersiapkan kamera...',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller!.value.previewSize!.height,
          height: controller!.value.previewSize!.width,
          child: CameraPreview(controller!),
        ),
      ),
    );
  }
}

// ─── Countdown Overlay ──────────────────────────────────────────

/// Dramatic countdown overlay: scale+fade animation per number,
/// with a rotating ring backing for emphasis.
class _CountdownOverlay extends StatelessWidget {
  final int value;
  final AnimationController animation;

  const _CountdownOverlay({required this.value, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) {
        final t = animation.value;
        // Scale: pops in big, settles smaller
        final scale = 0.5 + (1.4 - 0.5) * Curves.easeOutBack.transform(
          t.clamp(0.0, 1.0),
        );
        // Opacity: fade in fast, hold, slight fade out
        final opacity = t < 0.15
            ? (t / 0.15)
            : t > 0.85
                ? (1.0 - (t - 0.85) / 0.15) * 0.85 + 0.15
                : 1.0;
        // Ring grows + fades
        final ringScale = 0.8 + t * 1.2;
        final ringOpacity = (1.0 - t).clamp(0.0, 1.0) * 0.6;

        return Container(
          color: Colors.black.withAlpha(120),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Expanding ring
                Transform.scale(
                  scale: ringScale,
                  child: Opacity(
                    opacity: ringOpacity,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ),
                // Big number
                Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Text(
                      '$value',
                      style: const TextStyle(
                        fontSize: 120,
                        fontWeight: FontWeight.w200,
                        color: Colors.white,
                        letterSpacing: 2,
                        height: 1.0,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 20,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Bottom Controls ────────────────────────────────────────────

class _BottomControls extends StatelessWidget {
  final List<TemplateElement> slots;
  final int activeSlotIndex;
  final Map<int, String> capturedPhotos;
  final bool isCapturing;
  final VoidCallback onCapture;
  final ValueChanged<int> onSlotTap;

  const _BottomControls({
    required this.slots,
    required this.activeSlotIndex,
    required this.capturedPhotos,
    required this.isCapturing,
    required this.onCapture,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.md,
        AppSpacing.screenHorizontal,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slot indicators (clean dot language)
          if (slots.length > 1) ...[
            _SlotIndicators(
              total: slots.length,
              activeIndex: activeSlotIndex,
              capturedPhotos: capturedPhotos,
              onTap: onSlotTap,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Capture button
          _CaptureButton(onTap: onCapture, isCapturing: isCapturing),
        ],
      ),
    );
  }
}

// ─── Slot Indicators (clean dots) ───────────────────────────────

class _SlotIndicators extends StatelessWidget {
  final int total;
  final int activeIndex;
  final Map<int, String> capturedPhotos;
  final ValueChanged<int> onTap;

  const _SlotIndicators({
    required this.total,
    required this.activeIndex,
    required this.capturedPhotos,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isFilled = capturedPhotos.containsKey(i);
        final isActive = i == activeIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: isActive ? 28 : (isFilled ? 14 : 10),
              height: isActive ? 10 : (isFilled ? 14 : 10),
              decoration: BoxDecoration(
                shape: isActive ? BoxShape.rectangle : BoxShape.circle,
                borderRadius:
                    isActive ? BorderRadius.circular(5) : null,
                color: isActive
                    ? AppColors.brandPrimary
                    : isFilled
                        ? AppColors.success
                        : AppColors.textDisabled.withValues(alpha: 0.5),
              ),
              child: isFilled && !isActive
                  ? const Icon(
                      Icons.check,
                      size: 9,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

// ─── Capture Button (modern, larger, with pulse) ───────────────

class _CaptureButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isCapturing;

  const _CaptureButton({required this.onTap, required this.isCapturing});

  @override
  State<_CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends State<_CaptureButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.isCapturing;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTapUp: disabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) {
            return SizedBox(
              width: 110,
              height: 110,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing halo ring (only when ready, not capturing)
                  if (!disabled)
                    Container(
                      width: 90 + (_pulseAnim.value * 18),
                      height: 90 + (_pulseAnim.value * 18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.brandPrimary.withValues(
                            alpha: (1.0 - _pulseAnim.value) * 0.35,
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                  child!,
                ],
              ),
            );
          },
          child: AnimatedOpacity(
            opacity: disabled ? 0.55 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: AppColors.brandPrimary,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandPrimary,
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared Element Renderers ───────────────────────────────────

class _ImageElement extends StatelessWidget {
  final TemplateElement element;
  final double scale;

  const _ImageElement({required this.element, required this.scale});

  @override
  Widget build(BuildContext context) {
    final url = element.properties['imageUrl'] as String? ?? '';
    if (url.isEmpty) {
      return const SizedBox.shrink();
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border.withAlpha(80), width: 0.5),
        ),
      ),
    );
  }
}

class _TextElement extends StatelessWidget {
  final TemplateElement element;
  final double scale;

  const _TextElement({required this.element, required this.scale});

  @override
  Widget build(BuildContext context) {
    final rawText = element.properties['content'] as String? ??
        element.properties['text'] as String? ??
        '';
    final text = _resolveVariables(rawText);
    final fontSize =
        ((element.properties['fontSize'] as num?)?.toDouble() ?? 24) * scale;
    final letterSpacing =
        (element.properties['letterSpacing'] as num?)?.toDouble();

    // Parse color from hex
    Color textColor = AppColors.textSecondary;
    final colorHex = element.properties['color'] as String?;
    if (colorHex != null && colorHex.isNotEmpty) {
      final hex = colorHex.replaceFirst('#', '');
      final value = int.tryParse(hex, radix: 16);
      if (value != null) {
        textColor = Color(hex.length == 6 ? 0xFF000000 | value : value);
      }
    }

    final fontWeight = switch (element.properties['fontWeight'] as String?) {
      'bold' || 'w700' => FontWeight.w700,
      'normal' || 'w400' => FontWeight.w400,
      'w100' => FontWeight.w100,
      'w200' => FontWeight.w200,
      'w300' => FontWeight.w300,
      'w500' => FontWeight.w500,
      'w600' => FontWeight.w600,
      'w800' => FontWeight.w800,
      'w900' => FontWeight.w900,
      _ => FontWeight.w500,
    };

    final textAlign = switch (element.properties['textAlign'] as String?) {
      'left' => TextAlign.left,
      'right' => TextAlign.right,
      'center' => TextAlign.center,
      _ => TextAlign.center,
    };
    final alignment = switch (textAlign) {
      TextAlign.left => Alignment.centerLeft,
      TextAlign.right => Alignment.centerRight,
      _ => Alignment.center,
    };

    return Align(
      alignment: alignment,
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize.clamp(4.0, 200.0),
          color: textColor,
          fontWeight: fontWeight,
          fontFamily: element.properties['fontFamily'] as String?,
          letterSpacing: letterSpacing != null ? letterSpacing * scale : null,
        ),
        textAlign: textAlign,
      ),
    );
  }

  static String _resolveVariables(String text) {
    if (!text.contains('{{')) return text;
    final now = DateTime.now();
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final tanggal =
        '${now.day.toString().padLeft(2, '0')} ${months[now.month]} ${now.year}';
    final waktu =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final tanggalWaktu =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} $waktu';
    return text
        .replaceAll('{{tanggal}}', tanggal)
        .replaceAll('{{waktu}}', waktu)
        .replaceAll('{{tanggal_waktu}}', tanggalWaktu);
  }
}

class _GenericElement extends StatelessWidget {
  final TemplateElement element;
  final double scale;

  const _GenericElement({required this.element, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.border.withAlpha(120),
          width: 0.5,
        ),
      ),
    );
  }
}
