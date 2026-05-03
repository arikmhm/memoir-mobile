import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../di.dart';
import '../../../shared/core/theme/app_colors.dart';
import '../../../shared/core/widgets/noise_background.dart';
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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  String? _cameraError;
  int _activeSlotIndex = 0;
  int? _countdownValue;

  late final AnimationController _slotFadeController;
  late final Animation<double> _slotFadeAnimation;

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
    _cameraController?.dispose();
    super.dispose();
  }

  /// Animate slot transition: fade out → change slot → fade in.
  void _changeSlot(int newIndex) {
    if (newIndex == _activeSlotIndex) return;
    if (_slotFadeController.isAnimating) return;
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

    // Countdown from configured value → 1
    final start = sl<StorageService>().captureCountdown;
    for (var i = start; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdownValue = i);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() => _countdownValue = null);

    try {
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

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(
              child: NoiseBackground(),
            ),
          ),
          SafeArea(
        child: Column(
          children: [
            // ── Template preview with live camera ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                  vertical: AppSpacing.xl,
                ),
                child: FadeTransition(
                  opacity: _slotFadeAnimation,
                  child: _SessionPreview(
                    template: template,
                    slots: slots,
                    activeSlotIndex: _activeSlotIndex,
                    capturedPhotos: _capturedPhotos,
                    cameraController: _isCameraReady ? _cameraController : null,
                    cameraError: _cameraError,
                    countdownValue: _countdownValue,
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

// ─── Session Preview ────────────────────────────────────────────

class _SessionPreview extends StatelessWidget {
  final Template template;
  final List<TemplateElement> slots;
  final int activeSlotIndex;
  final Map<int, String> capturedPhotos;
  final CameraController? cameraController;
  final String? cameraError;
  final int? countdownValue;
  final ValueChanged<int> onSlotTap;

  const _SessionPreview({
    required this.template,
    required this.slots,
    required this.activeSlotIndex,
    required this.capturedPhotos,
    required this.cameraController,
    required this.cameraError,
    required this.countdownValue,
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
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  isActive ? AppColors.brandPrimary : Colors.transparent,
              width: isActive ? 2 : 0,
            ),
          ),
          child: ClipRect(
            child: Transform.flip(
              flipX: true,
              child: Image.file(
                File(capturedPath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
    }

    // Active slot: show camera preview
    if (isActive) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _CameraSlot(
            controller: cameraController,
            error: cameraError,
          ),
          if (countdownValue != null)
            _CountdownOverlay(value: countdownValue!),
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
                color: AppColors.textDisabled,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                error!,
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.textDisabled,
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
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textDisabled,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.brandPrimary, width: 2),
      ),
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller!.value.previewSize!.height,
            height: controller!.value.previewSize!.width,
            child: CameraPreview(controller!),
          ),
        ),
      ),
    );
  }
}

// ─── Countdown Overlay ──────────────────────────────────────────

class _CountdownOverlay extends StatelessWidget {
  final int value;

  const _CountdownOverlay({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withAlpha(100),
      child: Center(
        child: Text(
          '$value',
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w300,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Controls ────────────────────────────────────────────

class _BottomControls extends StatelessWidget {
  final List<TemplateElement> slots;
  final int activeSlotIndex;
  final Map<int, String> capturedPhotos;
  final VoidCallback onCapture;
  final ValueChanged<int> onSlotTap;

  const _BottomControls({
    required this.slots,
    required this.activeSlotIndex,
    required this.capturedPhotos,
    required this.onCapture,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slot indicators
          if (slots.length > 1) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(slots.length, (i) {
                final isFilled = capturedPhotos.containsKey(i);
                final isActive = i == activeSlotIndex;
                return GestureDetector(
                  onTap: () => onSlotTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isActive ? 32 : 24,
                    height: isActive ? 32 : 24,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? AppColors.brandPrimary
                          : isFilled
                              ? AppColors.surfaceContainer
                              : AppColors.surface,
                      border: Border.all(
                        color: isActive
                            ? AppColors.brandPrimary
                            : isFilled
                                ? AppColors.textSecondary
                                : AppColors.border,
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: isFilled && !isActive
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: AppColors.textSecondary,
                            )
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: isActive ? 12 : 10,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? AppColors.brandAccent
                                    : AppColors.textDisabled,
                              ),
                            ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Capture button
          _CaptureButton(onTap: onCapture),
        ],
      ),
    );
  }
}

// ─── Capture Button ─────────────────────────────────────────────

class _CaptureButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CaptureButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.brandPrimary,
              width: 3,
            ),
          ),
          child: Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandPrimary,
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
