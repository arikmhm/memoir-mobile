import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../di.dart';
import '../../../../shared/core/theme/app_colors.dart';
import '../../../../shared/core/theme/app_spacing.dart';
import '../../../../shared/data/datasources/storage_service.dart';
import '../../../../shared/widgets/memoir_button.dart';
import '../../../../shared/widgets/memoir_section_card.dart';
import '../../../../shared/widgets/menu_header_card.dart';
import '../../../session/data/services/composite_render_service.dart';
import '../../bloc/home_cubit.dart';
import '../../bloc/home_state.dart';
import '../widgets/screen_configs/timeout_chips.dart';

/// Main-menu page for tuning thermal image processing.
///
/// Combines:
/// - Live test: capture a photo with the front camera and see how it
///   would render to the thermal printer, updated in real time as the
///   user adjusts the controls (300 ms debounce).
/// - Controls: density, dither algorithm, sharpen — all in one card.
class ImageProcessingPage extends StatelessWidget {
  const ImageProcessingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<HomeCubit>(),
      child: Scaffold(
        backgroundColor: AppColors.surfaceVariant,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          leading: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          title: Text(
            'Pemrosesan Gambar',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          ),
          centerTitle: true,
        ),
        body: const _ImageProcessingBody(),
      ),
    );
  }
}

class _ImageProcessingBody extends StatefulWidget {
  const _ImageProcessingBody();

  @override
  State<_ImageProcessingBody> createState() => _ImageProcessingBodyState();
}

class _ImageProcessingBodyState extends State<_ImageProcessingBody> {
  /// Debounce window — also drives the "Menunggu..." indicator duration.
  static const _debounceDuration = Duration(milliseconds: 300);

  late int _density;
  late String _dither;
  late double _sharpen;
  late double _brightness;

  Timer? _debouncer;

  /// True from when a setting changes until the debounce timer fires.
  /// Drives the loading indicator overlay on the preview area.
  bool _isDebouncing = false;

  StorageService get _storage => sl<StorageService>();

  ProcessingSettings get _settings => ProcessingSettings(
        thermalDensity: _density,
        dither: DitherAlgorithm.fromKey(_dither),
        sharpenAmount: _sharpen,
        brightness: _brightness,
      );

  @override
  void initState() {
    super.initState();
    _density = _storage.thermalDensity;
    _dither = _storage.ditherAlgorithm;
    _sharpen = _storage.sharpenAmount;
    _brightness = _storage.brightness;
  }

  @override
  void dispose() {
    _debouncer?.cancel();
    super.dispose();
  }

  /// Debounced re-render. Sets [_isDebouncing] so the preview can show a
  /// progress indicator during the wait window.
  void _scheduleRerender() {
    _debouncer?.cancel();
    setState(() => _isDebouncing = true);
    _debouncer = Timer(_debounceDuration, () {
      if (!mounted) return;
      setState(() => _isDebouncing = false);
      final cubit = context.read<HomeCubit>();
      if (cubit.hasCapturedPreviewPhoto) {
        cubit.rerenderPreview(_settings);
      }
    });
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Pengaturan?'),
        content: const Text(
          'Kepekatan, Algoritma Dithering, Ketajaman, dan Kecerahan akan '
          'dikembalikan ke nilai default '
          '(Kepekatan 2, Floyd-Steinberg, Ketajaman 0.25, Kecerahan +8).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandPrimary,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _storage.resetImageProcessingSettings();
    if (!mounted) return;
    setState(() {
      _density = _storage.thermalDensity;
      _dither = _storage.ditherAlgorithm;
      _sharpen = _storage.sharpenAmount;
      _brightness = _storage.brightness;
    });
    _scheduleRerender();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pengaturan dikembalikan ke default.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MenuHeaderCard(
            icon: Icons.image_outlined,
            title: 'Pemrosesan Gambar',
            description:
                'Atur density, dither, dan brightness untuk hasil cetak thermal.',
          ),
          const SizedBox(height: AppSpacing.lg),
          _TestPreviewSection(
            getSettings: () => _settings,
            isDebouncing: _isDebouncing,
          ),
          const SizedBox(height: AppSpacing.md),
          _ControlsCard(
            density: _density,
            dither: _dither,
            sharpen: _sharpen,
            brightness: _brightness,
            onDensityChanged: (v) {
              setState(() => _density = v.round());
            },
            onDensityChangeEnd: (v) {
              _storage.setThermalDensity(v.round());
              _scheduleRerender();
            },
            onDitherChanged: (v) {
              setState(() => _dither = v);
              _storage.setDitherAlgorithm(v);
              _scheduleRerender();
            },
            onSharpenChanged: (v) {
              setState(() => _sharpen = v);
            },
            onSharpenChangeEnd: (v) {
              _storage.setSharpenAmount(v);
              _scheduleRerender();
            },
            onBrightnessChanged: (v) {
              setState(() => _brightness = v);
            },
            onBrightnessChangeEnd: (v) {
              _storage.setBrightness(v);
              _scheduleRerender();
            },
            onReset: _resetToDefaults,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Test preview section — camera, capture, live re-render
// ════════════════════════════════════════════════════════════════════

class _TestPreviewSection extends StatelessWidget {
  /// Pulls latest settings lazily — when called, returns current slider state.
  final ProcessingSettings Function() getSettings;

  /// True while a slider change is pending the debounce window.
  final bool isDebouncing;

  const _TestPreviewSection({
    required this.getSettings,
    required this.isDebouncing,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (prev, curr) =>
          curr is HomeInitial ||
          curr is ImageProcessingInitializing ||
          curr is ImageProcessingCameraReady ||
          curr is ImageProcessingCapturing ||
          curr is ImageProcessingPreviewRendering ||
          curr is ImageProcessingPreviewReady ||
          curr is ImageProcessingError,
      builder: (context, state) {
        final cubit = context.read<HomeCubit>();
        return MemoirSectionCard(
          label: 'Test Cetak',
          subtitle:
              'Ambil foto contoh, lalu geser slider di bawah untuk melihat '
              'efek setting langsung di layar (tanpa membuang kertas).',
          icon: Icons.preview_outlined,
          children: [
            _TestBody(
              state: state,
              cubit: cubit,
              getSettings: getSettings,
              isDebouncing: isDebouncing,
            ),
          ],
        );
      },
    );
  }
}

class _TestBody extends StatefulWidget {
  final HomeState state;
  final HomeCubit cubit;
  final ProcessingSettings Function() getSettings;
  final bool isDebouncing;

  const _TestBody({
    required this.state,
    required this.cubit,
    required this.getSettings,
    required this.isDebouncing,
  });

  @override
  State<_TestBody> createState() => _TestBodyState();
}

class _TestBodyState extends State<_TestBody> {
  /// Local flag — print is a one-shot operation, no need for a cubit state.
  bool _isPrinting = false;

  Future<void> _handlePrintTest() async {
    setState(() => _isPrinting = true);
    try {
      await widget.cubit.printPreviewTest(widget.getSettings());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test cetak terkirim ke printer.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final cubit = widget.cubit;

    if (state is ImageProcessingInitializing) {
      return const _Centered(child: CircularProgressIndicator());
    }

    if (state is ImageProcessingCapturing) {
      return const _Centered(child: CircularProgressIndicator());
    }

    if (state is ImageProcessingCameraReady) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CameraView(controller: cubit.imageProcessingController),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: MemoirButton.outlined(
                  label: 'Batal',
                  icon: Icons.close,
                  onPressed: () => cubit.stopImageProcessingTest(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: MemoirButton.filled(
                  label: 'Ambil Foto',
                  icon: Icons.camera_alt,
                  onPressed: () =>
                      cubit.captureForImageProcessing(widget.getSettings()),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (state is ImageProcessingPreviewRendering ||
        state is ImageProcessingPreviewReady) {
      final isRendering = state is ImageProcessingPreviewRendering;
      final bytes = state is ImageProcessingPreviewReady
          ? state.previewBytes
          : (state as ImageProcessingPreviewRendering).previousBytes;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PreviewImage(
            bytes: bytes,
            isRendering: isRendering,
            isDebouncing: widget.isDebouncing,
          ),
          const SizedBox(height: AppSpacing.md),
          MemoirButton.filled(
            label: _isPrinting ? 'Mencetak...' : 'Cetak Test ke Printer',
            icon: _isPrinting ? null : Icons.print,
            isLoading: _isPrinting,
            onPressed: _isPrinting ? null : _handlePrintTest,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: MemoirButton.outlined(
                  label: 'Ambil Ulang',
                  icon: Icons.refresh,
                  onPressed: _isPrinting
                      ? null
                      : () => cubit.startImageProcessingTest(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: MemoirButton.outlined(
                  label: 'Selesai',
                  icon: Icons.done,
                  onPressed: _isPrinting
                      ? null
                      : () => cubit.stopImageProcessingTest(),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // HomeInitial or ImageProcessingError → idle state
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state is ImageProcessingError) ...[
          _ErrorBanner(message: state.message),
          const SizedBox(height: AppSpacing.md),
        ],
        MemoirButton.filled(
          label: 'Mulai Test',
          icon: Icons.play_arrow,
          onPressed: () => cubit.startImageProcessingTest(),
        ),
      ],
    );
  }
}

class _CameraView extends StatelessWidget {
  final CameraController? controller;

  const _CameraView({this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c == null || !c.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 360),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: c.value.previewSize!.height,
            height: c.value.previewSize!.width,
            child: CameraPreview(c),
          ),
        ),
      ),
    );
  }
}

class _PreviewImage extends StatelessWidget {
  final Uint8List? bytes;
  final bool isRendering;
  final bool isDebouncing;

  const _PreviewImage({
    required this.bytes,
    required this.isRendering,
    required this.isDebouncing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 480),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                bytes!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Sedang merender preview...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          // Debounce badge wins when both are active — it shows up first
          // (300ms window) and is replaced by the render badge afterward.
          if (isDebouncing)
            const _StatusBadge(label: 'Menunggu...', color: Color(0xFFCC9933))
          else if (isRendering)
            const _StatusBadge(label: 'Render...', color: Colors.black),
        ],
      ),
    );
  }
}

/// Top-right status pill on the preview area (debounce / render indicators).
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: AppSpacing.sm,
      right: AppSpacing.sm,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  final Widget child;
  const _Centered({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(child: child),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Consolidated controls card — density + dither + sharpen + reset
// ════════════════════════════════════════════════════════════════════

class _ControlsCard extends StatelessWidget {
  final int density;
  final String dither;
  final double sharpen;
  final double brightness;
  final ValueChanged<double> onDensityChanged;
  final ValueChanged<double> onDensityChangeEnd;
  final ValueChanged<String> onDitherChanged;
  final ValueChanged<double> onSharpenChanged;
  final ValueChanged<double> onSharpenChangeEnd;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onBrightnessChangeEnd;
  final VoidCallback onReset;

  const _ControlsCard({
    required this.density,
    required this.dither,
    required this.sharpen,
    required this.brightness,
    required this.onDensityChanged,
    required this.onDensityChangeEnd,
    required this.onDitherChanged,
    required this.onSharpenChanged,
    required this.onSharpenChangeEnd,
    required this.onBrightnessChanged,
    required this.onBrightnessChangeEnd,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return MemoirSectionCard(
      label: 'Pengaturan Cetak',
      subtitle:
          'Atur kepekatan, algoritma dithering, dan ketajaman. '
          'Setting berlaku untuk sesi foto berikutnya.',
      icon: Icons.tune_outlined,
      children: [
        _ControlGroup(
          title: 'Kepekatan Cetak',
          description:
              'Ketebalan tinta thermal head. Rendah = tipis (kurangi belobor di kulit). '
              'Tinggi = gelap (pulihkan detail yang pucat).',
          child: _SliderRow(
            value: density.toDouble(),
            min: 0,
            max: 8,
            divisions: 8,
            valueLabel: density.toString(),
            hintLeft: 'Tipis',
            hintRight: 'Tebal',
            onChanged: onDensityChanged,
            onChangeEnd: onDensityChangeEnd,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: AppSpacing.md),
        _ControlGroup(
          title: 'Algoritma Dithering',
          description:
              'Cara konversi foto ke hitam-putih. Floyd-Steinberg bagus untuk wajah/kulit '
              '(gradasi halus). Atkinson lebih tajam untuk logo/garis.',
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: TimeoutChip(
                    label: 'Floyd-Steinberg',
                    isActive: dither == 'fs',
                    onTap: () => onDitherChanged('fs'),
                  ),
                ),
              ),
              Expanded(
                child: TimeoutChip(
                  label: 'Atkinson',
                  isActive: dither == 'atkinson',
                  onTap: () => onDitherChanged('atkinson'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: AppSpacing.md),
        _ControlGroup(
          title: 'Kecerahan',
          description:
              'Offset luminansi sebelum dithering. Positif (+) untuk mengangkat '
              'area gelap, negatif (−) untuk meredupkan keseluruhan foto.',
          child: _SliderRow(
            value: brightness,
            min: -30.0,
            max: 30.0,
            divisions: 60,
            valueLabel: brightness.round().toString(),
            hintLeft: 'Gelap',
            hintRight: 'Terang',
            onChanged: onBrightnessChanged,
            onChangeEnd: onBrightnessChangeEnd,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: AppSpacing.md),
        _ControlGroup(
          title: 'Ketajaman',
          description:
              'Penguatan tepi (unsharp mask). Tinggi mempertajam garis tapi bisa '
              'memunculkan halo/noise di area halus seperti kulit.',
          child: _SliderRow(
            value: sharpen,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            valueLabel: sharpen.toStringAsFixed(2),
            hintLeft: 'Halus',
            hintRight: 'Tajam',
            onChanged: onSharpenChanged,
            onChangeEnd: onSharpenChangeEnd,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reset ke Default'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Heading + description + control widget. Used to title each control inside
/// the consolidated card.
class _ControlGroup extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _ControlGroup({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

/// Slider with value chip + hint labels (reused from old processing section).
class _SliderRow extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final String hintLeft;
  final String hintRight;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _SliderRow({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.hintLeft,
    required this.hintRight,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              hintLeft,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                valueLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
            Text(
              hintRight,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.brandPrimary,
            inactiveTrackColor: AppColors.border,
            thumbColor: AppColors.brandPrimary,
            overlayColor: AppColors.brandPrimary.withValues(alpha: 0.15),
            trackHeight: 4,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}
