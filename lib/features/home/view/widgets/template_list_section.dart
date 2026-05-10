import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/core/theme/app_colors.dart';
import '../../../../shared/core/theme/app_spacing.dart';
import '../../../../shared/data/models/template.dart';
import '../../../../shared/widgets/memoir_banner.dart';
import '../../../../shared/widgets/memoir_button.dart';
import '../../../app/bloc/app_cubit.dart';
import '../../../app/bloc/app_state.dart';
import '../../bloc/home_cubit.dart';
import '../../bloc/home_state.dart';

/// Template list section — displays synced templates with sync button.
///
/// Reads templates from AppCubit (AppReady state).
/// Sync triggers StartupRepository via HomeCubit.
class TemplateListSection extends StatefulWidget {
  const TemplateListSection({super.key});

  @override
  State<TemplateListSection> createState() => _TemplateListSectionState();
}

class _TemplateListSectionState extends State<TemplateListSection> {
  String? _bannerMessage;
  MemoirBannerType? _bannerType;

  void _showBanner(String message, MemoirBannerType type) {
    setState(() {
      _bannerMessage = message;
      _bannerType = type;
    });
  }

  void _dismissBanner() {
    if (mounted) setState(() => _bannerMessage = null);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppCubit>().state;
    final templates = appState is AppReady
        ? appState.templates.cast<Template>()
        : <Template>[];

    return BlocListener<HomeCubit, HomeState>(
      listenWhen: (_, current) =>
          current is TemplateSyncSuccess || current is TemplateSyncError,
      listener: (context, state) {
        if (state is TemplateSyncSuccess) {
          _showBanner(
            'Sinkronisasi berhasil — ${state.count} template.',
            MemoirBannerType.success,
          );
        }
        if (state is TemplateSyncError) {
          _showBanner(state.message, MemoirBannerType.error);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Inline banner ──
              if (_bannerMessage != null) ...[
                MemoirBanner(
                  message: _bannerMessage!,
                  type: _bannerType ?? MemoirBannerType.info,
                  onDismiss: _dismissBanner,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // ── Sync button ──
              BlocBuilder<HomeCubit, HomeState>(
                buildWhen: (_, current) =>
                    current is HomeInitial ||
                    current is TemplateSyncInProgress ||
                    current is TemplateSyncSuccess ||
                    current is TemplateSyncError,
                builder: (context, state) {
                  final isSyncing = state is TemplateSyncInProgress;
                  return MemoirButton.filled(
                    label: isSyncing ? 'Sinkronisasi...' : 'Sinkronisasi Template',
                    icon: isSyncing ? null : Icons.sync,
                    isLoading: isSyncing,
                    onPressed:
                        isSyncing ? null : context.read<HomeCubit>().syncTemplates,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Template count ──
              Text(
                'TEMPLATE (${templates.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Template grid (2 columns) ──
              if (templates.isEmpty)
                const _EmptyState()
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: templates.map(
                    (t) => SizedBox(
                      width: (constraints.maxWidth - AppSpacing.sm) / 2,
                      child: _TemplateCard(template: t),
                    ),
                  ).toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Template card (large preview + info) ───────────────────────

class _TemplateCard extends StatelessWidget {
  final Template template;

  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Preview with elements ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _TemplatePreview(template: template),
            ),
          ),

          // ── Info bar ──
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          _InfoChip(
                            label: '${template.width} x ${template.height}',
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _InfoChip(
                            label: '${template.photoSlotCount} foto',
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _InfoChip(
                            label: '${template.elements.length} elemen',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Template preview (renders bg + elements + overlay) ─────────

class _TemplatePreview extends StatelessWidget {
  final Template template;

  const _TemplatePreview({required this.template});

  static const double _maxHeight = 260.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasW = template.width.toDouble();
        final canvasH = template.height.toDouble();

        // Scale to fit within available area minus vertical inset
        const double inset = AppSpacing.md;
        final availW = constraints.maxWidth - inset * 2;
        const availH = _maxHeight - inset * 2;
        final scaleByWidth = availW / canvasW;
        final scaleByHeight = availH / canvasH;
        final scale = scaleByWidth < scaleByHeight ? scaleByWidth : scaleByHeight;
        final renderedW = canvasW * scale;
        final renderedH = canvasH * scale;

        final sortedElements = List<TemplateElement>.from(template.elements)
          ..sort((a, b) => a.sequence.compareTo(b.sequence));

        return Container(
          width: constraints.maxWidth,
          height: renderedH + inset * 2,
          color: AppColors.surfaceVariant,
          alignment: Alignment.center,
          child: SizedBox(
            width: renderedW,
            height: renderedH,
            child: Stack(
              children: [
                _buildBackground(renderedW, renderedH),
                ...sortedElements.map((el) => _buildElement(el, scale)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackground(double w, double h) {
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
    return const Positioned.fill(
      child: ColoredBox(color: AppColors.surfaceVariant),
    );
  }

  Widget _buildElement(TemplateElement el, double scale) {
    final child = switch (el.type) {
      'PHOTO_SLOT' => _PhotoSlotEl(element: el, scale: scale),
      'TEXT' => _TextEl(element: el, scale: scale),
      'IMAGE' => _ImageEl(element: el, scale: scale),
      _ => const SizedBox.shrink(),
    };
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

// ─── Element renderers ──────────────────────────────────────────

class _PhotoSlotEl extends StatelessWidget {
  final TemplateElement element;
  final double scale;

  const _PhotoSlotEl({required this.element, required this.scale});

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
          size: (element.width * scale * 0.25).clamp(8, 32).toDouble(),
          color: AppColors.textDisabled,
        ),
      ),
    );
  }
}

class _TextEl extends StatelessWidget {
  final TemplateElement element;
  final double scale;

  const _TextEl({required this.element, required this.scale});

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
      final hex = colorHex.replaceFirst('#', '');
      final value = int.tryParse(hex, radix: 16);
      if (value != null) {
        textColor = Color(hex.length == 6 ? 0xFF000000 | value : value);
      }
    }

    final fontWeight = switch (element.properties['fontWeight'] as String?) {
      'bold' || 'w700' => FontWeight.w700,
      'normal' || 'w400' => FontWeight.w400,
      'w300' => FontWeight.w300,
      'w500' => FontWeight.w500,
      'w600' => FontWeight.w600,
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

class _ImageEl extends StatelessWidget {
  final TemplateElement element;
  final double scale;

  const _ImageEl({required this.element, required this.scale});

  @override
  Widget build(BuildContext context) {
    final url = element.properties['imageUrl'] as String? ?? '';
    if (url.isEmpty) return const SizedBox.shrink();
    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}


// ─── Info chip ──────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Empty state ────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 28,
            color: AppColors.textDisabled,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Belum ada template',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Tekan tombol sinkronisasi atau tambahkan\ntemplate melalui dashboard.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textDisabled,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
