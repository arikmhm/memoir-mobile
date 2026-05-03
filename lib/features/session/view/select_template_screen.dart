import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../di.dart';
import '../../../shared/core/theme/app_colors.dart';
import '../../../shared/core/widgets/noise_background.dart';
import '../../../shared/core/widgets/session_countdown_bar.dart';
import '../../../shared/core/theme/app_spacing.dart';
import '../../../shared/data/datasources/storage_service.dart';
import '../../../shared/data/models/template.dart';
import '../../app/bloc/app_cubit.dart';
import '../../app/bloc/app_state.dart';

/// Template selection screen — portrait layout with large preview + thumbnail strip.
///
/// Per PRD-05 FEAT-MR-04:
/// - Top: large preview of selected template (fills majority of screen)
/// - Bottom: horizontal scrollable thumbnail strip
/// - Tap thumbnail → preview updates immediately
class SelectTemplateScreen extends StatefulWidget {
  const SelectTemplateScreen({super.key});

  @override
  State<SelectTemplateScreen> createState() => _SelectTemplateScreenState();
}

class _SelectTemplateScreenState extends State<SelectTemplateScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Start global session timer when entering template selection.
    sl<StorageService>().startSessionTimer();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppCubit>().state;
    final templates = appState is AppReady
        ? appState.templates.cast<Template>()
        : <Template>[];

    if (templates.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(child: _buildEmptyState(context)),
      );
    }

    // Clamp index in case templates change
    if (_selectedIndex >= templates.length) {
      _selectedIndex = 0;
    }

    final selected = templates[_selectedIndex];

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
            // ── Header ──
            const _Header(),

            // ── Session countdown ──
            SessionCountdownBar(
              perPageTimeout: sl<StorageService>().selectTemplateTimeout,
            ),

            // ── Main preview (2/3 of available space) ──
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: () => context.go('/photo-session/${selected.id}'),
                child: _LargePreview(template: selected),
              ),
            ),

            // ── Template info ──
            _TemplateInfo(
              templateName: selected.name,
              photoSlotCount: selected.photoSlotCount,
            ),

            Container(height: 1, color: AppColors.border),

            // ── Thumbnail strip (1/3 of available space) ──
            Expanded(
              flex: 1,
              child: _ThumbnailStrip(
                templates: templates,
                selectedIndex: _selectedIndex,
                onSelect: (i) => setState(() => _selectedIndex = i),
              ),
            ),

            // ── Confirm button ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              child: SizedBox(
                width: double.infinity,
                height: AppSpacing.touchTarget,
                child: FilledButton(
                  onPressed: () =>
                      context.go('/photo-session/${selected.id}'),
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
                  child: const Text('GUNAKAN TEMPLATE'),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.photo_library_outlined,
            size: 48,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Belum ada template',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Hubungi pemilik untuk menambahkan template',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

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
          'PILIH TEMPLATE',
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

// ─── Template Info ───────────────────────────────────────────────

class _TemplateInfo extends StatelessWidget {
  final String templateName;
  final int photoSlotCount;

  const _TemplateInfo({
    required this.templateName,
    required this.photoSlotCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            templateName,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$photoSlotCount foto',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Large Preview ──────────────────────────────────────────────

class _LargePreview extends StatelessWidget {
  final Template template;

  const _LargePreview({required this.template});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canvasW = template.width.toDouble();
          final canvasH = template.height.toDouble();

          final scaleX = constraints.maxWidth / canvasW;
          final scaleY = constraints.maxHeight / canvasH;
          final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.92;

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
                  ...sortedElements.map((el) => _buildElement(el, scale)),
                ],
              ),
            ),
          );
        },
      ),
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
    final child = switch (el.type) {
      'PHOTO_SLOT' => _PhotoSlotElement(element: el, scale: scale),
      'TEXT' => _TextElement(element: el, scale: scale),
      'IMAGE' => _ImageElement(element: el, scale: scale),
      _ => _GenericElement(element: el, scale: scale),
    };
    return Positioned(
      left: el.x * scale,
      top: el.y * scale,
      width: el.width * scale,
      height: el.height * scale,
      child: Opacity(opacity: el.normalizedOpacity, child: child),
    );
  }
}

// ─── Thumbnail Strip ────────────────────────────────────────────

class _ThumbnailStrip extends StatelessWidget {
  final List<Template> templates;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _ThumbnailStrip({
    required this.templates,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.md,
      ),
      itemCount: templates.length,
      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
      itemBuilder: (context, index) {
        final template = templates[index];
        final isSelected = index == selectedIndex;
        return _Thumbnail(
          template: template,
          isSelected: isSelected,
          onTap: () => onSelect(index),
        );
      },
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final Template template;
  final bool isSelected;
  final VoidCallback onTap;

  const _Thumbnail({
    required this.template,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final aspect = template.width / template.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final thumbHeight = constraints.maxHeight;
        final thumbWidth = thumbHeight * aspect;

        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: thumbWidth.clamp(96, 280),
            height: thumbHeight,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : AppColors.border,
            width: isSelected ? 2.0 : 1.0,
          ),
          color: AppColors.surfaceContainer,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildThumbBackground(),
            // Selected overlay label
            if (isSelected)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  color: AppColors.brandPrimary.withAlpha(180),
                  child: Text(
                    template.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: AppColors.brandAccent,
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

  Widget _buildThumbBackground() {
    final localPath = template.localBackgroundPath;
    if (localPath != null && File(localPath).existsSync()) {
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    final url = template.backgroundUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    return const SizedBox.shrink();
  }
}

// ─── Element Renderers ──────────────────────────────────────────

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

class _PhotoSlotElement extends StatelessWidget {
  final TemplateElement element;
  final double scale;

  const _PhotoSlotElement({required this.element, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(180),
        border: Border.all(color: AppColors.textDisabled, width: 0.5),
      ),
      child: Center(
        child: Icon(
          Icons.photo_camera_outlined,
          size: (element.width * scale * 0.25).clamp(12, 40).toDouble(),
          color: AppColors.textDisabled,
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
