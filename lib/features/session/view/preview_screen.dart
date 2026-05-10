import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../di.dart';
import '../../../shared/core/theme/app_colors.dart';
import '../../../shared/core/widgets/page_background.dart';
import '../../../shared/core/widgets/session_countdown_bar.dart';
import '../../../shared/core/theme/app_spacing.dart';
import '../../../shared/data/datasources/storage_service.dart';
import '../../../shared/data/models/kiosk_config.dart';
import '../../../shared/data/models/template.dart';
import '../../app/bloc/app_cubit.dart';
import '../../app/bloc/app_state.dart';

/// Preview & Retake screen — composite preview + retake.
///
/// Per PRD-05 FEAT-MR-06:
/// - Show composite preview (background + elements + photos + overlay)
/// - "Foto Ulang" → back to photo session (retake all)
/// - "Lanjut" → proceed to confirmation
class PreviewScreen extends StatelessWidget {
  final String templateId;
  final Map<int, String> capturedPhotos;

  const PreviewScreen({
    super.key,
    required this.templateId,
    required this.capturedPhotos,
  });

  Template? _findTemplate(BuildContext context) {
    final appState = context.read<AppCubit>().state;
    if (appState is! AppReady) return null;
    final templates = appState.templates.cast<Template>();
    try {
      return templates.firstWhere((t) => t.id == templateId);
    } catch (_) {
      return null;
    }
  }

  void _retake(BuildContext context) {
    context.go('/photo-session/$templateId');
  }

  void _proceed(BuildContext context) {
    final storage = sl<StorageService>();

    if (storage.isEventMode) {
      final template = _findTemplate(context);
      final configJson = storage.kioskConfigJson;
      if (template == null || configJson == null) {
        context.go('/screensaver');
        return;
      }
      final config = KioskConfig.fromJsonString(configJson);
      final printQty = storage.defaultPrintCount;
      final hasDigitalCopy = storage.isSoftcopyEnabled;
      final extraPrintTotal =
          printQty > 1 ? (printQty - 1) * config.pricePerExtraPrint : 0;
      final total = config.priceBaseSession +
          extraPrintTotal +
          (hasDigitalCopy ? config.priceDigitalCopy : 0);

      context.go('/processing', extra: {
        'template': template,
        'capturedPhotos': Map<int, String>.from(capturedPhotos),
        'paymentMethod': storage.paymentActiveMode,
        'printQty': printQty,
        'hasDigitalCopy': hasDigitalCopy,
        'totalAmount': total,
      });
    } else {
      context.go(
        '/confirmation/$templateId',
        extra: Map<int, String>.from(capturedPhotos),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = _findTemplate(context);

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
                  onPressed: () => context.go('/screensaver'),
                  child: const Text('KEMBALI'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          const Positioned.fill(child: PageBackground(pageKey: 'preview')),
          SafeArea(
        child: Column(
          children: [
            // ── Header ──
            const _PreviewHeader(),

            // ── Session countdown ──
            SessionCountdownBar(
              perPageTimeout: sl<StorageService>().previewTimeout,
            ),

            // ── Composite preview ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                  vertical: AppSpacing.md,
                ),
                child: _CompositePreview(
                  template: template,
                  capturedPhotos: capturedPhotos,
                ),
              ),
            ),

            // ── Bottom actions ──
            Container(height: 1, color: AppColors.border),
            _BottomActions(
              onRetake: () => _retake(context),
              onProceed: () => _proceed(context),
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

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.lg,
        AppSpacing.screenHorizontal,
        AppSpacing.md,
      ),
      child: Center(
        child: Text(
          'PREVIEW HASIL FOTO',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                letterSpacing: 4,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

// ─── Composite Preview ──────────────────────────────────────────

class _CompositePreview extends StatelessWidget {
  final Template template;
  final Map<int, String> capturedPhotos;

  const _CompositePreview({
    required this.template,
    required this.capturedPhotos,
  });

  List<TemplateElement> _photoSlots() {
    return template.elements
        .where((e) => e.type == 'PHOTO_SLOT')
        .toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
  }

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

        final slots = _photoSlots();

        return Center(
          child: Container(
            width: renderedW,
            height: renderedH,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.zero,
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
                _buildBackground(),
                ...sortedElements.map(
                  (el) => _buildElement(el, scale, slots),
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

  Widget _buildElement(
    TemplateElement el,
    double scale,
    List<TemplateElement> slots,
  ) {
    Widget child;

    if (el.type == 'PHOTO_SLOT') {
      final slotIndex = slots.indexOf(el);
      child = _PhotoSlotPreview(
        element: el,
        scale: scale,
        photoPath: capturedPhotos[slotIndex],
      );
    } else if (el.type == 'TEXT') {
      child = _TextElement(element: el, scale: scale);
    } else if (el.type == 'IMAGE') {
      child = _ImageElement(element: el, scale: scale);
    } else {
      child = const SizedBox.shrink();
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
}

// ─── Bottom Actions ─────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  final VoidCallback onRetake;
  final VoidCallback onProceed;

  const _BottomActions({
    required this.onRetake,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: AppSpacing.touchTarget,
              child: OutlinedButton(
                onPressed: onRetake,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                child: const Text('FOTO ULANG'),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: SizedBox(
              height: AppSpacing.touchTarget,
              child: FilledButton(
                onPressed: onProceed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.brandAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                child: const Text('LANJUTKAN'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Element Renderers ──────────────────────────────────────────

class _PhotoSlotPreview extends StatelessWidget {
  final TemplateElement element;
  final double scale;
  final String? photoPath;

  const _PhotoSlotPreview({
    required this.element,
    required this.scale,
    this.photoPath,
  });

  @override
  Widget build(BuildContext context) {
    if (photoPath != null) {
      final borderRadius =
          (element.properties['borderRadius'] as num?)?.toDouble() ?? 0;
      final borderWidth =
          (element.properties['borderWidth'] as num?)?.toDouble() ?? 0;
      final borderColorHex = element.properties['borderColor'] as String?;

      Color? borderColor;
      if (borderColorHex != null && borderColorHex.isNotEmpty) {
        borderColor = _parseHexColor(borderColorHex);
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius * scale),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius * scale),
            border: borderWidth > 0 && borderColor != null
                ? Border.all(
                    color: borderColor,
                    width: borderWidth * scale,
                  )
                : null,
          ),
          child: ClipRect(
            child: Transform.flip(
              flipX: true,
              child: Image.file(
                File(photoPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
    }

    // Empty slot fallback (shouldn't happen in preview)
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(180),
        border: Border.all(color: AppColors.textDisabled, width: 0.5),
      ),
      child: Center(
        child: Icon(
          Icons.photo_camera_outlined,
          size: (element.width * scale * 0.2).clamp(12, 32).toDouble(),
          color: AppColors.textDisabled,
        ),
      ),
    );
  }
}

class _ImageElement extends StatelessWidget {
  final TemplateElement element;
  final double scale;

  const _ImageElement({required this.element, required this.scale});

  @override
  Widget build(BuildContext context) {
    final url = element.properties['imageUrl'] as String? ?? '';
    if (url.isEmpty) return const SizedBox.shrink();
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

    Color textColor = AppColors.textSecondary;
    final colorHex = element.properties['color'] as String?;
    if (colorHex != null && colorHex.isNotEmpty) {
      final parsed = _parseHexColor(colorHex);
      if (parsed != null) textColor = parsed;
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

// ─── Helpers ────────────────────────────────────────────────────

Color? _parseHexColor(String hex) {
  hex = hex.replaceFirst('#', '');
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return null;
  return Color(hex.length == 6 ? 0xFF000000 | value : value);
}
