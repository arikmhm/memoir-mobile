import 'package:flutter/material.dart';

import '../../../../shared/core/theme/app_colors.dart';
import '../../../../shared/core/theme/app_spacing.dart';
import '../../../../shared/widgets/memoir_section_card.dart';

enum _BoothMode { normal, event }

class BoothModeSection extends StatefulWidget {
  const BoothModeSection({super.key});

  @override
  State<BoothModeSection> createState() => _BoothModeSectionState();
}

class _BoothModeSectionState extends State<BoothModeSection> {
  _BoothMode _selected = _BoothMode.normal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Mode selector ──
        MemoirSectionCard(
          label: 'Mode Operasi',
          subtitle: 'Tentukan cara kerja photobooth untuk sesi ini.',
          icon: Icons.tune_outlined,
          children: [
            _ModeRow(
              icon: Icons.photo_camera_outlined,
              iconColor: AppColors.brandPrimary,
              title: 'Normal',
              description: 'Tamu memilih template & membayar secara mandiri.',
              isSelected: _selected == _BoothMode.normal,
              isFirst: true,
              isLast: false,
              onTap: () => setState(() => _selected = _BoothMode.normal),
            ),
            _ModeRow(
              icon: Icons.celebration_outlined,
              iconColor: const Color(0xFF5C6BC0),
              title: 'Event',
              description: 'Template terkunci, cocok untuk pesta atau acara.',
              isSelected: _selected == _BoothMode.event,
              isFirst: false,
              isLast: true,
              onTap: () => setState(() => _selected = _BoothMode.event),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        // ── Mode detail ──
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _selected == _BoothMode.normal
              ? const _ModeDetailCard(
                  key: ValueKey(_BoothMode.normal),
                  mode: _BoothMode.normal,
                )
              : const _ModeDetailCard(
                  key: ValueKey(_BoothMode.event),
                  mode: _BoothMode.event,
                ),
        ),
      ],
    );
  }
}

// ─── Mode row (iPhone-style list row) ───────────────────────────

class _ModeRow extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _ModeRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  State<_ModeRow> createState() => _ModeRowState();
}

class _ModeRowState extends State<_ModeRow> {
  bool _pressed = false;

  BorderRadius get _radius {
    if (widget.isFirst && widget.isLast) return BorderRadius.circular(8);
    if (widget.isFirst) {
      return const BorderRadius.vertical(top: Radius.circular(8));
    }
    if (widget.isLast) {
      return const BorderRadius.vertical(bottom: Radius.circular(8));
    }
    return BorderRadius.zero;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(
              color: _pressed
                  ? AppColors.surfaceContainer
                  : AppColors.surfaceVariant,
              borderRadius: _radius,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 2,
              vertical: AppSpacing.sm + 4,
            ),
            child: Row(
              children: [
                // Icon badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: widget.iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.icon, size: 18, color: widget.iconColor),
                ),
                const SizedBox(width: AppSpacing.sm + 2),

                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Checkmark
                AnimatedOpacity(
                  opacity: widget.isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!widget.isLast)
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.divider,
            indent: 52,
          ),
      ],
    );
  }
}

// ─── Mode detail card ────────────────────────────────────────────

class _ModeDetailCard extends StatelessWidget {
  final _BoothMode mode;

  const _ModeDetailCard({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final isEvent = mode == _BoothMode.event;

    final features = isEvent
        ? const [
            _FeatureLine(
              icon: Icons.lock_outline,
              label: 'Template terkunci',
              detail: 'Tamu tidak bisa memilih template sendiri.',
            ),
            _FeatureLine(
              icon: Icons.money_off_outlined,
              label: 'Pembayaran opsional',
              detail: 'Bisa dinonaktifkan untuk acara gratis.',
            ),
            _FeatureLine(
              icon: Icons.branding_watermark_outlined,
              label: 'Branding event',
              detail: 'Nama & logo event ditampilkan di layar.',
            ),
            _FeatureLine(
              icon: Icons.analytics_outlined,
              label: 'Laporan per event',
              detail: 'Statistik sesi dikelompokkan per acara.',
            ),
          ]
        : const [
            _FeatureLine(
              icon: Icons.grid_view_outlined,
              label: 'Pemilihan template bebas',
              detail: 'Tamu memilih template dari galeri.',
            ),
            _FeatureLine(
              icon: Icons.payment_outlined,
              label: 'Pembayaran mandiri',
              detail: 'Tamu melakukan pembayaran sendiri via QRIS.',
            ),
            _FeatureLine(
              icon: Icons.auto_mode_outlined,
              label: 'Alur penuh otomatis',
              detail: 'Dari pilih template hingga cetak tanpa intervensi.',
            ),
            _FeatureLine(
              icon: Icons.print_outlined,
              label: 'Cetak otomatis',
              detail: 'Hasil langsung dicetak setelah pembayaran.',
            ),
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md + 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isEvent ? 'MODE EVENT' : 'MODE NORMAL',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.brandPrimary.withValues(alpha: 0.12),
                  ),
                ),
                child: const Text(
                  'AKTIF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: f,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Feature line ────────────────────────────────────────────────

class _FeatureLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;

  const _FeatureLine({
    required this.icon,
    required this.label,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              children: [
                TextSpan(
                  text: '$label  ',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: detail,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
