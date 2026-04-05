import 'package:flutter/material.dart';

import '../../../../shared/core/theme/app_colors.dart';
import '../../../../shared/core/theme/app_spacing.dart';
import '../../../../shared/data/datasources/storage_service.dart';
import '../../../../shared/widgets/memoir_section_card.dart';
import '../../../../shared/widgets/memoir_tab_toggle.dart';

/// Session timer configuration section.
///
/// Two parts:
/// 1. Capture countdown (always visible) — 3, 2, 1... snap!
/// 2. Timeout mode toggle: Global (one timer end-to-end) or
///    Per Halaman (individual timeout per screen).
class SessionTimerSection extends StatefulWidget {
  final StorageService storageService;

  const SessionTimerSection({super.key, required this.storageService});

  @override
  State<SessionTimerSection> createState() => _SessionTimerSectionState();
}

class _SessionTimerSectionState extends State<SessionTimerSection> {
  late String _timeoutMode; // 'off', 'per_page', 'global'
  late int _captureCountdown;
  late int _globalSessionTimeout;
  late int _selectTemplateTimeout;
  late int _previewTimeout;
  late int _confirmationTimeout;
  late int _paymentTimeout;
  late int _thankYouDuration;

  @override
  void initState() {
    super.initState();
    final s = widget.storageService;
    _timeoutMode = s.timeoutMode;
    _captureCountdown = s.captureCountdown;
    _globalSessionTimeout = s.globalSessionTimeout;
    _selectTemplateTimeout = s.selectTemplateTimeout;
    _previewTimeout = s.previewTimeout;
    _confirmationTimeout = s.confirmationTimeout;
    _paymentTimeout = s.paymentTimeout;
    _thankYouDuration = s.thankYouDuration;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Capture Countdown ──
        MemoirSectionCard(
          label: 'Countdown Foto',
          subtitle: 'Hitungan mundur sebelum kamera mengambil foto.',
          icon: Icons.camera_alt_outlined,
          children: [
            _OptionChips(
              options: const [3, 5, 7, 10],
              selected: _captureCountdown,
              labelBuilder: (v) => '$v detik',
              onSelected: (v) {
                setState(() => _captureCountdown = v);
                widget.storageService.setCaptureCountdown(v);
              },
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        // ── Timeout Mode ──
        MemoirSectionCard(
          label: 'Timeout Sesi',
          subtitle: 'Otomatis kembali ke screensaver jika idle.',
          icon: Icons.timer_outlined,
          children: [
            MemoirTabToggle<String>(
              items: const [
                MemoirTabItem(
                  value: 'off',
                  label: 'Off',
                  icon: Icons.timer_off_outlined,
                ),
                MemoirTabItem(
                  value: 'per_page',
                  label: 'Per Halaman',
                  icon: Icons.view_list_outlined,
                ),
                MemoirTabItem(
                  value: 'global',
                  label: 'Global',
                  icon: Icons.public_outlined,
                ),
              ],
              selected: _timeoutMode,
              onChanged: (value) {
                setState(() => _timeoutMode = value);
                widget.storageService.setTimeoutMode(value);
              },
            ),

            if (_timeoutMode != 'off') ...[
              const SizedBox(height: AppSpacing.md),
            ],

            if (_timeoutMode == 'global') ...[
              _TimeoutRow(
                label: 'Durasi Sesi',
                hint: 'Dari pilih template sampai selesai',
                options: const [300, 600, 900, 1200, 1800],
                selected: _globalSessionTimeout,
                onSelected: (v) {
                  setState(() => _globalSessionTimeout = v);
                  widget.storageService.setGlobalSessionTimeout(v);
                },
              ),
            ] else if (_timeoutMode == 'per_page') ...[
              _TimeoutRow(
                label: 'Pilih Template',
                options: const [60, 120, 180, 300],
                selected: _selectTemplateTimeout,
                onSelected: (v) {
                  setState(() => _selectTemplateTimeout = v);
                  widget.storageService.setSelectTemplateTimeout(v);
                },
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              _TimeoutRow(
                label: 'Preview Foto',
                options: const [30, 60, 120, 180],
                selected: _previewTimeout,
                onSelected: (v) {
                  setState(() => _previewTimeout = v);
                  widget.storageService.setPreviewTimeout(v);
                },
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              _TimeoutRow(
                label: 'Konfirmasi',
                options: const [60, 120, 180, 300],
                selected: _confirmationTimeout,
                onSelected: (v) {
                  setState(() => _confirmationTimeout = v);
                  widget.storageService.setConfirmationTimeout(v);
                },
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              _TimeoutRow(
                label: 'Pembayaran',
                options: const [180, 300, 600, 900],
                selected: _paymentTimeout,
                onSelected: (v) {
                  setState(() => _paymentTimeout = v);
                  widget.storageService.setPaymentTimeout(v);
                },
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              _TimeoutRow(
                label: 'Terima Kasih',
                options: const [15, 30, 60, 120],
                selected: _thankYouDuration,
                onSelected: (v) {
                  setState(() => _thankYouDuration = v);
                  widget.storageService.setThankYouDuration(v);
                },
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ─── Timeout Row (label + chips) ────────────────────────────────

class _TimeoutRow extends StatelessWidget {
  final String label;
  final String? hint;
  final List<int> options;
  final int selected;
  final ValueChanged<int> onSelected;

  const _TimeoutRow({
    required this.label,
    this.hint,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  hint!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textDisabled,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        _OptionChips(
          options: options,
          selected: selected,
          labelBuilder: _formatDuration,
          onSelected: onSelected,
        ),
      ],
    );
  }

  static String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}d';
    final minutes = seconds ~/ 60;
    return '${minutes}m';
  }
}

// ─── Option Chips ───────────────────────────────────────────────

class _OptionChips extends StatelessWidget {
  final List<int> options;
  final int selected;
  final String Function(int) labelBuilder;
  final ValueChanged<int> onSelected;

  const _OptionChips({
    required this.options,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((value) {
        final isActive = value == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: value == options.last ? 0 : AppSpacing.xs,
            ),
            child: _Chip(
              label: labelBuilder(value),
              isActive: isActive,
              onTap: () => onSelected(value),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Single Chip ────────────────────────────────────────────────

class _Chip extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.brandPrimary
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isActive
                  ? AppColors.brandPrimary
                  : AppColors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: widget.isActive
                  ? AppColors.brandAccent
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
