import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../di.dart';
import '../../../../shared/core/theme/app_colors.dart';
import '../../../../shared/core/theme/app_spacing.dart';
import '../../../../shared/core/utils/formatters.dart';
import '../../../../shared/data/datasources/storage_service.dart';
import '../../../../shared/data/models/kiosk_config.dart';
import '../../../../shared/data/models/template.dart';
import '../../../app/bloc/app_cubit.dart';
import '../../../app/bloc/app_state.dart';
import '../../../session/data/models/local_session.dart';
import '../../../session/data/services/local_session_service.dart';

class SavedSessionsSection extends StatefulWidget {
  const SavedSessionsSection({super.key});

  @override
  State<SavedSessionsSection> createState() => _SavedSessionsSectionState();
}

class _SavedSessionsSectionState extends State<SavedSessionsSection> {
  List<LocalSession>? _sessions;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await sl<LocalSessionService>().listAll();
    if (mounted) setState(() => _sessions = sessions);
  }

  Future<void> _delete(String id) async {
    await sl<LocalSessionService>().delete(id);
    await _loadSessions();
  }

  void _showReprintSheet(LocalSession session, Template? template) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReprintBottomSheet(
        session: session,
        template: template,
        onReprinted: _loadSessions,
      ),
    );
  }

  Template? _findTemplate(String templateId) {
    final appState = context.read<AppCubit>().state;
    if (appState is! AppReady) return null;
    final templates = appState.templates.cast<Template>();
    try {
      return templates.firstWhere((t) => t.id == templateId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'SESI TERSIMPAN (${sessions?.length ?? 0})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  _RefreshButton(onPressed: _loadSessions),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Content ──
              if (sessions == null)
                const _LoadingState()
              else if (sessions.isEmpty)
                const _EmptyState()
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: sessions.map((session) {
                    final template = _findTemplate(session.templateId);
                    return SizedBox(
                      width: (constraints.maxWidth - AppSpacing.sm) / 2,
                      child: _SessionCard(
                        session: session,
                        template: template,
                        onTap: () => _showReprintSheet(session, template),
                        onDelete: () => _delete(session.id),
                      ),
                    );
                  }).toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Session Card ────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final LocalSession session;
  final Template? template;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.template,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Preview ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _SessionPreview(
                  session: session,
                  template: template,
                ),
              ),
            ),

            // ── Info bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm + 2,
                AppSpacing.xs,
                AppSpacing.sm + 2,
                AppSpacing.sm + 2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.templateName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTime(session.savedAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onDelete,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    if (diff.inDays == 1) return 'Kemarin';

    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Session Preview (composite rendered as widget) ──────────────

class _SessionPreview extends StatelessWidget {
  final LocalSession session;
  final Template? template;

  static const double _maxHeight = 220.0;

  const _SessionPreview({required this.session, required this.template});

  @override
  Widget build(BuildContext context) {
    final t = template;
    if (t == null) {
      return Container(
        height: 120,
        color: AppColors.surfaceVariant,
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 28,
            color: AppColors.textDisabled,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasW = t.width.toDouble();
        final canvasH = t.height.toDouble();

        const double inset = AppSpacing.sm;
        final availW = constraints.maxWidth - inset * 2;
        const availH = _maxHeight - inset * 2;
        final scale = (availW / canvasW).clamp(0.0, availH / canvasH);
        final renderedW = canvasW * scale;
        final renderedH = canvasH * scale;

        final sortedElements = List<TemplateElement>.from(t.elements)
          ..sort((a, b) => a.sequence.compareTo(b.sequence));
        final slots = t.elements
            .where((e) => e.type == 'PHOTO_SLOT')
            .toList()
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
                _buildBackground(t),
                ...sortedElements.map((el) => _buildElement(el, scale, slots)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackground(Template t) {
    final localPath = t.localBackgroundPath;
    if (localPath != null && File(localPath).existsSync()) {
      return Positioned.fill(
        child: Image.file(
          File(localPath),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      );
    }
    final url = t.backgroundUrl;
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

  Widget _buildElement(
    TemplateElement el,
    double scale,
    List<TemplateElement> slots,
  ) {
    Widget child;

    if (el.type == 'PHOTO_SLOT') {
      final idx = slots.indexOf(el);
      final path = session.photoPaths[idx];
      child = path != null && File(path).existsSync()
          ? ClipRect(
              child: Transform.flip(
                flipX: true,
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: AppColors.surfaceVariant),
                ),
              ),
            )
          : const ColoredBox(color: AppColors.surfaceVariant);
    } else if (el.type == 'TEXT') {
      final rawText = el.properties['content'] as String? ??
          el.properties['text'] as String? ?? '';
      final fontSize =
          ((el.properties['fontSize'] as num?)?.toDouble() ?? 24) * scale;
      child = Center(
        child: Text(
          rawText,
          style: TextStyle(
            fontSize: fontSize.clamp(2.0, 100.0),
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else if (el.type == 'IMAGE') {
      final url = el.properties['imageUrl'] as String? ?? '';
      child = url.isNotEmpty
          ? Image.network(url, fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink())
          : const SizedBox.shrink();
    } else {
      child = const SizedBox.shrink();
    }

    return Positioned(
      left: el.x * scale,
      top: el.y * scale,
      width: el.width * scale,
      height: el.height * scale,
      child: Opacity(opacity: el.normalizedOpacity, child: child),
    );
  }
}

// ─── Reprint Bottom Sheet ────────────────────────────────────────

class _ReprintBottomSheet extends StatefulWidget {
  final LocalSession session;
  final Template? template;
  final VoidCallback onReprinted;

  const _ReprintBottomSheet({
    required this.session,
    required this.template,
    required this.onReprinted,
  });

  @override
  State<_ReprintBottomSheet> createState() => _ReprintBottomSheetState();
}

class _ReprintBottomSheetState extends State<_ReprintBottomSheet> {
  late int _printQty;
  late bool _hasDigitalCopy;
  late String _paymentMethod;

  @override
  void initState() {
    super.initState();
    final storage = sl<StorageService>();
    _printQty = storage.defaultPrintCount;
    _hasDigitalCopy = storage.isSoftcopyEnabled;
    _paymentMethod = storage.paymentActiveMode;
  }

  KioskConfig? _getKioskConfig() {
    final json = sl<StorageService>().kioskConfigJson;
    if (json == null) return null;
    return KioskConfig.fromJsonString(json);
  }

  // Reprint: sama seperti transaksi normal — base session sudah termasuk
  // 1 lembar, lembar berikutnya dihitung pricePerExtraPrint.
  int _extraPrintTotal(KioskConfig config) =>
      _printQty > 1 ? (_printQty - 1) * config.pricePerExtraPrint : 0;

  int _calcTotal(KioskConfig config) {
    return config.priceBaseSession +
        _extraPrintTotal(config) +
        (_hasDigitalCopy ? config.priceDigitalCopy : 0);
  }

  void _confirm(KioskConfig config) {
    final template = widget.template;
    if (template == null) return;

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    widget.onReprinted();

    context.go('/processing', extra: {
      'template': template,
      'capturedPhotos': Map<int, String>.from(widget.session.photoPaths),
      'paymentMethod': _paymentMethod,
      'printQty': _printQty,
      'hasDigitalCopy': _hasDigitalCopy,
      'totalAmount': _calcTotal(config),
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = _getKioskConfig();
    final template = widget.template;

    return Container(
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag handle ──
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Title ──
              Text(
                'Cetak Ulang Sesi',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.session.templateName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),

              if (template == null || config == null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Template atau konfigurasi kiosk tidak tersedia.',
                    style: TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else ...[
                // ── Composite thumbnail ──
                SizedBox(
                  height: 180,
                  child: _SessionPreview(
                    session: widget.session,
                    template: template,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Options ──
                _OptionsRow(
                  printQty: _printQty,
                  pricePerExtra: config.pricePerExtraPrint,
                  onQtyChanged: (v) => setState(() => _printQty = v),
                  hasDigitalCopy: _hasDigitalCopy,
                  digitalCopyPrice: config.priceDigitalCopy,
                  onDigitalCopyChanged: (v) =>
                      setState(() => _hasDigitalCopy = v),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Payment method ──
                _PaymentMethodSelector(
                  selected: _paymentMethod,
                  onChanged: (v) => setState(() => _paymentMethod = v),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Rincian harga ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _PriceRow(
                        label: 'Harga sesi',
                        value: Formatters.formatRupiah(config.priceBaseSession),
                      ),
                      if (_printQty > 1) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _PriceRow(
                          label: 'Cetak ekstra (${_printQty - 1} lembar)',
                          value: Formatters.formatRupiah(
                            _extraPrintTotal(config),
                          ),
                        ),
                      ],
                      if (_hasDigitalCopy && config.priceDigitalCopy > 0) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _PriceRow(
                          label: 'Salinan digital',
                          value:
                              Formatters.formatRupiah(config.priceDigitalCopy),
                        ),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Divider(height: 1, color: AppColors.border),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            Formatters.formatRupiah(_calcTotal(config)),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Confirm button ──
                _ConfirmButton(onPressed: () => _confirm(config)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Options Row (qty stepper + digital copy) ────────────────────

class _OptionsRow extends StatelessWidget {
  final int printQty;
  final int pricePerExtra;
  final ValueChanged<int> onQtyChanged;
  final bool hasDigitalCopy;
  final int digitalCopyPrice;
  final ValueChanged<bool> onDigitalCopyChanged;

  const _OptionsRow({
    required this.printQty,
    required this.pricePerExtra,
    required this.onQtyChanged,
    required this.hasDigitalCopy,
    required this.digitalCopyPrice,
    required this.onDigitalCopyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // Print qty
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jumlah Cetak',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (pricePerExtra > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '+${Formatters.formatRupiah(pricePerExtra)}/lembar ekstra',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _Stepper(
                  value: printQty,
                  min: 1,
                  max: 10,
                  onChanged: onQtyChanged,
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Digital copy
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Salinan Digital',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        digitalCopyPrice > 0
                            ? Formatters.formatRupiah(digitalCopyPrice)
                            : 'Gratis',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: hasDigitalCopy,
                  onChanged: onDigitalCopyChanged,
                  activeThumbColor: AppColors.brandPrimary,
                  activeTrackColor: AppColors.brandPrimary.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Price Row ───────────────────────────────────────────────────

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;

  const _PriceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─── Stepper ─────────────────────────────────────────────────────

class _Stepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(
            icon: Icons.remove_rounded,
            enabled: value > min,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(value - 1);
            },
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _StepBtn(
            icon: Icons.add_rounded,
            enabled: value < max,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(value + 1);
            },
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.textPrimary : AppColors.textDisabled,
        ),
      ),
    );
  }
}

// ─── Confirm Button ───────────────────────────────────────────────

class _ConfirmButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _ConfirmButton({required this.onPressed});

  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.brandPrimary,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.print_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Konfirmasi & Cetak',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Refresh Button ───────────────────────────────────────────────

class _RefreshButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _RefreshButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, size: 14, color: AppColors.textSecondary),
            SizedBox(width: 6),
            Text(
              'Muat Ulang',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading State ────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

// ─── Payment Method Selector ──────────────────────────────────────

class _PaymentMethodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  static const _methods = [
    ('CASH', 'Tunai', Icons.payments_outlined),
    ('STATIC_QRIS', 'QRIS Statis', Icons.qr_code_outlined),
    ('PG', 'QRIS Dinamis', Icons.qr_code_scanner_outlined),
  ];

  const _PaymentMethodSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Metode Pembayaran',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: _methods.map((entry) {
            final (value, label, icon) = entry;
            final isSelected = selected == value;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: AppSpacing.xs),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                    horizontal: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.brandPrimary.withValues(alpha: 0.08)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.brandPrimary
                          : AppColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: isSelected
                            ? AppColors.brandPrimary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppColors.brandPrimary
                              : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────

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
            'Belum ada sesi tersimpan',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Sesi akan tersimpan otomatis\nketika pelanggan klik Lanjutkan.',
            style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
