import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../di.dart';
import '../../../shared/core/theme/app_colors.dart';
import '../../../shared/core/widgets/noise_background.dart';
import '../../../shared/core/widgets/session_countdown_bar.dart';
import '../../../shared/core/theme/app_spacing.dart';
import '../../../shared/core/utils/formatters.dart';
import '../../../shared/data/datasources/storage_service.dart';
import '../../../shared/data/models/kiosk_config.dart';
import '../../../shared/data/models/template.dart';
import '../../app/bloc/app_cubit.dart';
import '../../app/bloc/app_state.dart';

/// Confirmation & Payment screen.
///
/// Per PRD-05 FEAT-MR-07:
/// - Read-only composite preview (small)
/// - Print quantity selector (default 1, include base)
/// - "Digital Copy" toggle with price indication
/// - Real-time price summary
/// - Payment flow: CASH / STATIC_QRIS → operator confirm; PG → create tx + QR
class ConfirmationScreen extends StatefulWidget {
  final String templateId;
  final Map<int, String> capturedPhotos;

  const ConfirmationScreen({
    super.key,
    required this.templateId,
    required this.capturedPhotos,
  });

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  int _printQty = 1;
  bool _hasDigitalCopy = true;

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

  KioskConfig? _getKioskConfig() {
    final storage = sl<StorageService>();
    final json = storage.kioskConfigJson;
    if (json == null) return null;
    return KioskConfig.fromJsonString(json);
  }

  /// Price resolution: use kiosk config pricing
  _PriceInfo _resolvePrice(Template template, KioskConfig config) {
    final basePrice = config.priceBaseSession;
    final extraPrintPrice = config.pricePerExtraPrint;
    final digitalCopyPrice = config.priceDigitalCopy;

    final extraPrintTotal =
        _printQty > 1 ? (_printQty - 1) * extraPrintPrice : 0;
    final digitalCopyTotal = _hasDigitalCopy ? digitalCopyPrice : 0;
    final total = basePrice + extraPrintTotal + digitalCopyTotal;

    return _PriceInfo(
      basePrice: basePrice,
      extraPrintPrice: extraPrintPrice,
      digitalCopyPrice: digitalCopyPrice,
      extraPrintTotal: extraPrintTotal,
      digitalCopyTotal: digitalCopyTotal,
      total: total,
    );
  }

  void _confirm() {
    final template = _findTemplate();
    final kioskConfig = _getKioskConfig();
    if (template == null || kioskConfig == null) return;

    final price = _resolvePrice(template, kioskConfig);
    final paymentMode = sl<StorageService>().paymentActiveMode;

    context.go('/processing', extra: {
      'template': template,
      'capturedPhotos': Map<int, String>.from(widget.capturedPhotos),
      'paymentMethod': paymentMode,
      'printQty': _printQty,
      'hasDigitalCopy': _hasDigitalCopy,
      'totalAmount': price.total,
    });
  }

  @override
  Widget build(BuildContext context) {
    final template = _findTemplate();
    final kioskConfig = _getKioskConfig();

    if (template == null || kioskConfig == null) {
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
                  template == null
                      ? 'Template tidak ditemukan'
                      : 'Konfigurasi kiosk tidak tersedia',
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

    final price = _resolvePrice(template, kioskConfig);
    final paymentMode = sl<StorageService>().paymentActiveMode;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Noise texture background
          const Positioned.fill(
            child: RepaintBoundary(
              child: NoiseBackground(),
            ),
          ),
          SafeArea(
        child: Column(
          children: [
            // ── Header ──
            const _ConfirmHeader(),

            // ── Session countdown ──
            SessionCountdownBar(
              perPageTimeout: sl<StorageService>().confirmationTimeout,
            ),

            // ── Preview (takes remaining top space) ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                  vertical: AppSpacing.md,
                ),
                child: _MiniPreview(
                  template: template,
                  capturedPhotos: widget.capturedPhotos,
                ),
              ),
            ),

            // ── Transaction details (pinned bottom) ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _OptionsCard(
                    printQty: _printQty,
                    pricePerExtra: price.extraPrintPrice,
                    onQtyChanged: (qty) =>
                        setState(() => _printQty = qty),
                    hasDigitalCopy: _hasDigitalCopy,
                    digitalCopyPrice: price.digitalCopyPrice,
                    onDigitalCopyChanged: (v) =>
                        setState(() => _hasDigitalCopy = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _PriceSummary(price: price, printQty: _printQty),
                ],
              ),
            ),

            // ── Bottom: payment + confirm ──
            _ConfirmSection(
              total: price.total,
              paymentMode: paymentMode,
              onConfirm: _confirm,
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }
}

// ─── Price Info ─────────────────────────────────────────────────

class _PriceInfo {
  final int basePrice;
  final int extraPrintPrice;
  final int digitalCopyPrice;
  final int extraPrintTotal;
  final int digitalCopyTotal;
  final int total;

  const _PriceInfo({
    required this.basePrice,
    required this.extraPrintPrice,
    required this.digitalCopyPrice,
    required this.extraPrintTotal,
    required this.digitalCopyTotal,
    required this.total,
  });
}

// ─── Header ─────────────────────────────────────────────────────

class _ConfirmHeader extends StatelessWidget {
  const _ConfirmHeader();

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
          'KONFIRMASI',
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

// ─── Mini Composite Preview ─────────────────────────────────────

class _MiniPreview extends StatelessWidget {
  final Template template;
  final Map<int, String> capturedPhotos;

  const _MiniPreview({
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
    final canvasW = template.width.toDouble();
    final canvasH = template.height.toDouble();
    final slots = _photoSlots();

    final sortedElements = List<TemplateElement>.from(template.elements)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaleX = constraints.maxWidth / canvasW;
        final scaleY = constraints.maxHeight / canvasH;
        final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.95;

        final previewW = canvasW * scale;
        final previewH = canvasH * scale;

        return Center(
      child: Container(
        width: previewW,
        height: previewH,
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
      final path = capturedPhotos[slotIndex];
      child = path != null
          ? ClipRect(
              child: Transform.flip(
                flipX: true,
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            )
          : Container(color: AppColors.surfaceContainer);
    } else if (el.type == 'TEXT') {
      child = _buildText(el, scale);
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
      child: Opacity(
        opacity: el.normalizedOpacity,
        child: child,
      ),
    );
  }

  Widget _buildText(TemplateElement el, double scale) {
    final rawText = el.properties['content'] as String? ??
        el.properties['text'] as String? ?? '';
    final text = _resolveVariables(rawText);
    final fontSize =
        ((el.properties['fontSize'] as num?)?.toDouble() ?? 24) * scale;

    Color textColor = AppColors.textSecondary;
    final colorHex = el.properties['color'] as String?;
    if (colorHex != null && colorHex.isNotEmpty) {
      final parsed = _parseHexColor(colorHex);
      if (parsed != null) textColor = parsed;
    }

    return Center(
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize.clamp(2.0, 100.0),
          color: textColor,
          fontWeight: FontWeight.w500,
          fontFamily: el.properties['fontFamily'] as String?,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
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

// ─── Options Card (Print Qty + Digital Copy) ───────────────────

class _OptionsCard extends StatelessWidget {
  final int printQty;
  final int pricePerExtra;
  final ValueChanged<int> onQtyChanged;
  final bool hasDigitalCopy;
  final int digitalCopyPrice;
  final ValueChanged<bool> onDigitalCopyChanged;

  const _OptionsCard({
    required this.printQty,
    required this.pricePerExtra,
    required this.onQtyChanged,
    required this.hasDigitalCopy,
    required this.digitalCopyPrice,
    required this.onDigitalCopyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Print quantity row
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jumlah Cetak',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '1 lembar termasuk harga dasar'
                        '${pricePerExtra > 0 ? ' \u2022 +${Formatters.formatRupiah(pricePerExtra)}/lembar' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StepperButton(
                        icon: Icons.remove,
                        enabled: printQty > 1,
                        onTap: () => onQtyChanged(printQty - 1),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '$printQty',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      _StepperButton(
                        icon: Icons.add,
                        enabled: printQty < 10,
                        onTap: () => onQtyChanged(printQty + 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
            ),
            color: AppColors.border,
          ),

          // Digital copy row
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
                      Text(
                        'Salinan Digital',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        digitalCopyPrice > 0
                            ? '+${Formatters.formatRupiah(digitalCopyPrice)}'
                            : 'Gratis',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: hasDigitalCopy,
                  onChanged: onDigitalCopyChanged,
                  activeTrackColor: AppColors.brandPrimary,
                  activeThumbColor: AppColors.brandAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.textPrimary : AppColors.textDisabled,
        ),
      ),
    );
  }
}

// ─── Price Summary ──────────────────────────────────────────────

class _PriceSummary extends StatelessWidget {
  final _PriceInfo price;
  final int printQty;

  const _PriceSummary({
    required this.price,
    required this.printQty,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _PriceRow(
            label: 'Harga dasar (1 cetak)',
            amount: price.basePrice,
          ),
          if (printQty > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            _PriceRow(
              label:
                  'Cetak tambahan (${printQty - 1}x \u00d7 ${Formatters.formatRupiah(price.extraPrintPrice)})',
              amount: price.extraPrintTotal,
            ),
          ],
          if (price.digitalCopyTotal > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            _PriceRow(
              label: 'Salinan digital',
              amount: price.digitalCopyTotal,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 1,
                ),
              ),
              Text(
                Formatters.formatRupiah(price.total),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final int amount;

  const _PriceRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          Formatters.formatRupiah(amount),
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Confirm Section (Payment Method + Button) ─────────────────

class _ConfirmSection extends StatelessWidget {
  final int total;
  final String paymentMode;
  final VoidCallback onConfirm;

  const _ConfirmSection({
    required this.total,
    required this.paymentMode,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (paymentLabel, paymentIcon) = switch (paymentMode) {
      'CASH' => ('Tunai (Cash)', Icons.payments_outlined),
      'STATIC_QRIS' => ('QRIS Statis', Icons.qr_code_2),
      'PG' => ('Payment Gateway', Icons.credit_card_outlined),
      _ => ('Tunai (Cash)', Icons.payments_outlined),
    };

    final buttonLabel = switch (paymentMode) {
      'CASH' || 'STATIC_QRIS' => 'KONFIRMASI PEMBAYARAN',
      'PG' => 'BAYAR SEKARANG',
      _ => 'KONFIRMASI',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
        AppSpacing.screenHorizontal,
        AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Payment method indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(paymentIcon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                paymentLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: AppSpacing.touchTarget + 8,
            child: FilledButton(
              onPressed: onConfirm,
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
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────

Color? _parseHexColor(String hex) {
  hex = hex.replaceFirst('#', '');
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return null;
  return Color(hex.length == 6 ? 0xFF000000 | value : value);
}

