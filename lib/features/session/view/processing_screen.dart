import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../shared/core/theme/app_colors.dart';
import '../../../shared/core/widgets/global_session_countdown_bar.dart';
import '../../../shared/core/widgets/page_background.dart';
import '../../../shared/core/theme/app_spacing.dart';
import '../../../shared/core/utils/formatters.dart';
import '../bloc/processing_cubit.dart';
import '../bloc/processing_state.dart';

/// Processing screen — payment → render → print → upload.
///
/// Shows different UI per payment method during the awaiting payment phase,
/// then standard progress views for render/print/upload.
class ProcessingScreen extends StatelessWidget {
  const ProcessingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          const Positioned.fill(child: PageBackground(pageKey: 'processing')),
          SafeArea(
            child: BlocConsumer<ProcessingCubit, ProcessingState>(
              listener: (context, state) {
                if (state is ProcessingComplete) {
                  context.go('/thank-you', extra: {
                    'transactionId': state.transaction.id,
                    'hasDigitalCopy': state.transaction.hasDigitalCopy,
                  });
                }
              },
              builder: (context, state) => switch (state) {
                ProcessingInitial() => const _LoadingView(
                  message: 'Mempersiapkan...',
                ),
                ProcessingCreatingTransaction() =>
                  const _CreatingTransactionView(),
                ProcessingAwaitingPayment() => _PgPaymentView(state: state),
                ProcessingCheckingPayment() => const _LoadingView(
                  message: 'Memeriksa pembayaran...',
                ),
                ProcessingPaymentFailed() =>
                  _PaymentFailedView(state: state),
                ProcessingRendering() => const _RenderingView(),
                ProcessingPrinting() => _PrintingView(state: state),
                ProcessingPrintError() => _PrintErrorView(state: state),
                ProcessingUploading() => const _LoadingView(
                  message: 'Memproses...',
                ),
                ProcessingUploadError() => const _LoadingView(
                  message: 'Memproses...',
                ),
                ProcessingComplete() => const _LoadingView(
                  message: 'Selesai!',
                ),
                ProcessingError() => _FatalErrorView(state: state),
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Loading View ───────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final String message;
  const _LoadingView({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── PG (Dynamic QRIS) Payment View ────────────────────────────

class _PgPaymentView extends StatefulWidget {
  final ProcessingAwaitingPayment state;
  const _PgPaymentView({required this.state});

  @override
  State<_PgPaymentView> createState() => _PgPaymentViewState();
}

class _PgPaymentViewState extends State<_PgPaymentView> {
  bool _isChecking = false;

  Future<void> _checkPayment() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    HapticFeedback.selectionClick();

    final status = await context.read<ProcessingCubit>().checkPgPayment();

    if (mounted) {
      setState(() => _isChecking = false);

      if (status == 'PENDING') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran belum diterima. Silakan coba lagi.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _handleCancel() {
    context.go('/screensaver');
  }

  @override
  Widget build(BuildContext context) {
    final qrString = widget.state.qrString;

    return Column(
      children: [
        // ── Header with cancel + title + timer chip ──
        _PaymentHeader(onCancel: _handleCancel),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.md,
              AppSpacing.screenHorizontal,
              AppSpacing.xxl,
            ),
            child: Column(
              children: [
                // ── Step instructions ──
                const _PaymentSteps(),
                const SizedBox(height: AppSpacing.lg),

                // ── Modern QR card ──
                _QrCard(qrString: qrString),
                const SizedBox(height: AppSpacing.md),

                // ── Expiry chip ──
                if (widget.state.paymentExpiresAt != null)
                  _ExpiryCountdown(
                    expiresAt: widget.state.paymentExpiresAt!,
                    onExpired: () {
                      if (context.mounted) context.go('/screensaver');
                    },
                  ),
                const SizedBox(height: AppSpacing.lg),

                // ── Amount highlight ──
                _AmountHighlight(
                  amount: widget.state.transaction.totalAmount,
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Primary: Cek Pembayaran ──
                _PrimaryButton(
                  label: 'Cek Pembayaran',
                  icon: Icons.refresh_rounded,
                  loading: _isChecking,
                  onPressed: _checkPayment,
                ),
                const SizedBox(height: AppSpacing.sm),

                // ── Secondary: Batalkan ──
                _GhostButton(
                  label: 'Batalkan',
                  icon: Icons.close_rounded,
                  onPressed: _handleCancel,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Payment Header (cancel + title + timer chip) ──────────────

class _PaymentHeader extends StatelessWidget {
  final VoidCallback onCancel;
  const _PaymentHeader({required this.onCancel});

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
          Expanded(
            child: Center(
              child: Text(
                'Pembayaran QRIS',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const GlobalSessionCountdownBar(compact: true),
        ],
      ),
    );
  }
}

// ─── Step Instructions ─────────────────────────────────────────

class _PaymentSteps extends StatelessWidget {
  const _PaymentSteps();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepItem(num: 1, label: 'Buka e-wallet'),
        _StepConnector(),
        _StepItem(num: 2, label: 'Scan QR'),
        _StepConnector(),
        _StepItem(num: 3, label: 'Konfirmasi'),
      ],
    );
  }
}

class _StepItem extends StatelessWidget {
  final int num;
  final String label;
  const _StepItem({required this.num, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.brandPrimary,
          ),
          alignment: Alignment.center,
          child: Text(
            '$num',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 1.5,
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.border,
    );
  }
}

// ─── QR Card ───────────────────────────────────────────────────

class _QrCard extends StatelessWidget {
  final String? qrString;
  const _QrCard({required this.qrString});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      height: 290,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: qrString != null && qrString!.isNotEmpty
          ? QrImageView(
              data: qrString!,
              version: QrVersions.auto,
              size: 250,
              backgroundColor: Colors.white,
              errorStateBuilder: (_, _) => const _QrPlaceholder(),
            )
          : const _QrPlaceholder(),
    );
  }
}

// ─── Amount Highlight ──────────────────────────────────────────

class _AmountHighlight extends StatelessWidget {
  final int amount;
  const _AmountHighlight({required this.amount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Column(
        children: [
          Text(
            'Total Pembayaran',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            Formatters.formatRupiah(amount),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Expiry Countdown (modern pill chip) ───────────────────────

class _ExpiryCountdown extends StatefulWidget {
  final String expiresAt;
  final VoidCallback? onExpired;
  const _ExpiryCountdown({required this.expiresAt, this.onExpired});

  @override
  State<_ExpiryCountdown> createState() => _ExpiryCountdownState();
}

class _ExpiryCountdownState extends State<_ExpiryCountdown> {
  late final DateTime _expiry;
  late Duration _remaining;
  bool _expiredHandled = false;

  @override
  void initState() {
    super.initState();
    _expiry = DateTime.tryParse(widget.expiresAt) ?? DateTime.now();
    _remaining = _expiry.difference(DateTime.now());
    _startTicker();
  }

  void _startTicker() {
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _remaining = _expiry.difference(DateTime.now());
      });
      if (_remaining.inSeconds <= 0 && !_expiredHandled) {
        _expiredHandled = true;
        widget.onExpired?.call();
        return false;
      }
      return _remaining.inSeconds > 0 && mounted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _remaining.isNegative || _remaining.inSeconds <= 0;
    final isLow = _remaining.inSeconds <= 30;
    final minutes = _remaining.inMinutes.clamp(0, 99);
    final seconds = (_remaining.inSeconds % 60).clamp(0, 59);
    final text = isExpired
        ? 'QR Kedaluwarsa'
        : 'Kedaluwarsa dalam ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final bg = isExpired || isLow
        ? AppColors.error
        : AppColors.surfaceVariant;
    final fg = isExpired || isLow ? Colors.white : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isExpired
                ? Icons.error_outline_rounded
                : Icons.access_time_rounded,
            size: 15,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── QR Placeholder ─────────────────────────────────────────────

class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_2, size: 64, color: AppColors.textDisabled),
          SizedBox(height: AppSpacing.sm),
          Text(
            'QR tidak tersedia',
            style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─── Payment Failed View ────────────────────────────────────────

class _PaymentFailedView extends StatelessWidget {
  final ProcessingPaymentFailed state;
  const _PaymentFailedView({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<ProcessingCubit>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withValues(alpha: 0.1),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.payment_outlined,
                size: 36,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Pembayaran Gagal',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                state.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _PrimaryButton(
              label: 'Coba Lagi',
              icon: Icons.refresh_rounded,
              onPressed: cubit.retryPayment,
            ),
            const SizedBox(height: AppSpacing.sm),
            _GhostButton(
              label: 'Kembali',
              icon: Icons.arrow_back_rounded,
              onPressed: () => context.go('/screensaver'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Creating Transaction View (engaging) ──────────────────────

class _CreatingTransactionView extends StatefulWidget {
  const _CreatingTransactionView();

  @override
  State<_CreatingTransactionView> createState() =>
      _CreatingTransactionViewState();
}

class _CreatingTransactionViewState extends State<_CreatingTransactionView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated receipt icon — "filling in" lines
            SizedBox(
              width: 100,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Receipt paper
                  Container(
                    width: 90,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                  // Animated lines filling in
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (_, _) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (i) {
                            final delay = i * 0.18;
                            final t = ((_controller.value - delay).clamp(0.0, 1.0));
                            final widthFactor = Curves.easeOut.transform(t);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3.5),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: widthFactor,
                                  child: Container(
                                    height: i == 0 ? 5 : 3,
                                    decoration: BoxDecoration(
                                      color: i == 0
                                          ? AppColors.brandPrimary
                                          : AppColors.textDisabled,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),
                  // Pulsing icon badge bottom-right
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (_, child) {
                        final pulse =
                            0.85 + 0.15 * (1 - (_controller.value - 0.5).abs() * 2).clamp(0.0, 1.0);
                        return Transform.scale(scale: pulse, child: child);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.brandPrimary,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Membuat Transaksi',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Sebentar ya, kami sedang menyiapkan pesanan Anda',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Rendering View (engaging — composite preview + processing) ───

class _RenderingView extends StatefulWidget {
  const _RenderingView();

  @override
  State<_RenderingView> createState() => _RenderingViewState();
}

class _RenderingViewState extends State<_RenderingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<ProcessingCubit>();
    final template = cubit.template;
    final capturedPhotos = cubit.capturedPhotos;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview with shimmer overlay
            if (template != null && capturedPhotos != null)
              _PreviewWithOverlay(
                template: template,
                capturedPhotos: capturedPhotos,
                controller: _controller,
                overlayType: _OverlayType.shimmer,
                maxHeight: 440,
              )
            else
              const SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.brandPrimary,
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Memproses Foto',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Menggabungkan foto dengan template kamu',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Printing View (engaging — preview + scanning line + progress) ───

class _PrintingView extends StatefulWidget {
  final ProcessingPrinting state;
  const _PrintingView({required this.state});

  @override
  State<_PrintingView> createState() => _PrintingViewState();
}

class _PrintingViewState extends State<_PrintingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<ProcessingCubit>();
    final template = cubit.template;
    final capturedPhotos = cubit.capturedPhotos;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview with scanning line overlay
            if (template != null && capturedPhotos != null)
              _PreviewWithOverlay(
                template: template,
                capturedPhotos: capturedPhotos,
                controller: _controller,
                overlayType: _OverlayType.scanLine,
                maxHeight: 440,
              )
            else
              const Icon(
                Icons.print_rounded,
                size: 64,
                color: AppColors.brandPrimary,
              ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Sedang Mencetak',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Lembar ${widget.state.currentCopy} dari ${widget.state.totalCopies}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Dots indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.state.totalCopies, (i) {
                final copyNum = i + 1;
                final isDone = copyNum < widget.state.currentCopy;
                final isActive = copyNum == widget.state.currentCopy;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: isActive ? 28 : (isDone ? 14 : 10),
                    height: isActive ? 10 : (isDone ? 14 : 10),
                    decoration: BoxDecoration(
                      shape: isActive ? BoxShape.rectangle : BoxShape.circle,
                      borderRadius: isActive ? BorderRadius.circular(5) : null,
                      color: isActive
                          ? AppColors.brandPrimary
                          : isDone
                              ? AppColors.success
                              : AppColors.textDisabled.withValues(alpha: 0.5),
                    ),
                    child: isDone && !isActive
                        ? const Icon(Icons.check, size: 9, color: Colors.white)
                        : null,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Preview With Animated Overlay ─────────────────────────────

enum _OverlayType { shimmer, scanLine }

class _PreviewWithOverlay extends StatelessWidget {
  final dynamic template;
  final Map<int, String> capturedPhotos;
  final AnimationController controller;
  final _OverlayType overlayType;
  final double maxHeight;

  const _PreviewWithOverlay({
    required this.template,
    required this.capturedPhotos,
    required this.controller,
    required this.overlayType,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final canvasW = (template.width as int).toDouble();
    final canvasH = (template.height as int).toDouble();
    final aspect = canvasW / canvasH;
    final boxH = maxHeight;
    final boxW = boxH * aspect;

    return Container(
      width: boxW,
      height: boxH,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Composite preview
          _CompositeRender(
            template: template,
            capturedPhotos: capturedPhotos,
          ),
          // Animated overlay
          AnimatedBuilder(
            animation: controller,
            builder: (_, _) {
              final t = controller.value;
              return IgnorePointer(
                child: CustomPaint(
                  painter: overlayType == _OverlayType.shimmer
                      ? _ShimmerPainter(progress: t)
                      : _ScanLinePainter(progress: t),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Composite Render (simplified, no interaction) ─────────────

class _CompositeRender extends StatelessWidget {
  final dynamic template;
  final Map<int, String> capturedPhotos;

  const _CompositeRender({
    required this.template,
    required this.capturedPhotos,
  });

  @override
  Widget build(BuildContext context) {
    final canvasW = (template.width as int).toDouble();
    final canvasH = (template.height as int).toDouble();

    final elements =
        List.from(template.elements as List)..sort(
          (a, b) => (a.sequence as int).compareTo(b.sequence as int),
        );

    final slots = elements
        .where((e) => e.type == 'PHOTO_SLOT')
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / canvasW;
        return Stack(
          children: [
            _buildBackground(),
            ...elements.map((el) => _buildElement(
                  el,
                  scale,
                  canvasH,
                  slots,
                )),
          ],
        );
      },
    );
  }

  Widget _buildBackground() {
    final localPath = template.localBackgroundPath as String?;
    if (localPath != null && File(localPath).existsSync()) {
      return Positioned.fill(
        child: Image.file(
          File(localPath),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      );
    }
    final url = template.backgroundUrl as String?;
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
    dynamic el,
    double scale,
    double canvasH,
    List<dynamic> slots,
  ) {
    Widget child = const SizedBox.shrink();
    if (el.type == 'PHOTO_SLOT') {
      final idx = slots.indexOf(el);
      final path = capturedPhotos[idx];
      if (path != null) {
        child = ClipRect(
          child: Transform.flip(
            flipX: true,
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        );
      }
    }

    return Positioned(
      left: (el.x as int) * scale,
      top: (el.y as int) * scale,
      width: (el.width as int) * scale,
      height: (el.height as int) * scale,
      child: Opacity(
        opacity: (el.normalizedOpacity as double),
        child: child,
      ),
    );
  }
}

// ─── Animated Overlay Painters ─────────────────────────────────

/// Shimmer band moving diagonally across the preview.
class _ShimmerPainter extends CustomPainter {
  final double progress;

  _ShimmerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final bandWidth = size.width * 0.4;
    final travel = size.width + bandWidth * 2;
    final x = -bandWidth + travel * progress;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.0),
        Colors.white.withValues(alpha: 0.35),
        Colors.white.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    canvas.save();
    canvas.clipRect(rect);
    final shaderRect = Rect.fromLTWH(x, 0, bandWidth, size.height);
    final paint = Paint()..shader = gradient.createShader(shaderRect);
    canvas.drawRect(shaderRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}

/// Horizontal scan line moving top-to-bottom (printer-head style).
class _ScanLinePainter extends CustomPainter {
  final double progress;

  _ScanLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Ping-pong: 0 → 1 → 0
    final t = progress < 0.5 ? progress * 2 : (1 - progress) * 2;
    final y = size.height * t;

    // Glow band (gradient fade above/below the line)
    final bandH = size.height * 0.18;
    final bandRect = Rect.fromLTWH(0, y - bandH / 2, size.width, bandH);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.brandPrimary.withValues(alpha: 0.0),
        AppColors.brandPrimary.withValues(alpha: 0.18),
        AppColors.brandPrimary.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    canvas.drawRect(
      bandRect,
      Paint()..shader = gradient.createShader(bandRect),
    );

    // The hard line itself
    final linePaint = Paint()
      ..color = AppColors.brandPrimary.withValues(alpha: 0.85)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}

// ─── Print Error View ───────────────────────────────────────────

class _PrintErrorView extends StatelessWidget {
  final ProcessingPrintError state;
  const _PrintErrorView({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<ProcessingCubit>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withValues(alpha: 0.1),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.print_disabled_outlined,
                size: 36,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Gagal Mencetak',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Mohon hubungi petugas untuk bantuan',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Lembar ${state.currentCopy} dari ${state.totalCopies}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _PrimaryButton(
              label: 'Coba Lagi',
              icon: Icons.refresh_rounded,
              onPressed: cubit.retryPrint,
            ),
            const SizedBox(height: AppSpacing.sm),
            _GhostButton(
              label: 'Lewati Cetak',
              icon: Icons.skip_next_rounded,
              onPressed: cubit.skipPrint,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Fatal Error View ───────────────────────────────────────────

class _FatalErrorView extends StatelessWidget {
  final ProcessingError state;
  const _FatalErrorView({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<ProcessingCubit>();
    final canRetry = state.transaction != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withValues(alpha: 0.1),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.error_outline,
                size: 36,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Terjadi Kesalahan',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                state.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (canRetry) ...[
              _PrimaryButton(
                label: 'Coba Lagi',
                icon: Icons.refresh_rounded,
                onPressed: cubit.retryProcessing,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            _GhostButton(
              label: 'Kembali',
              icon: Icons.arrow_back_rounded,
              onPressed: () => context.go('/screensaver'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Primary Button (modern pill, dominant) ────────────────────

class _PrimaryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.loading;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTapUp: disabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onPressed();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: disabled ? 0.7 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: disabled
                  ? const [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ]
                  : [
                      Icon(widget.icon, size: 22, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        widget.label,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.6,
                            ),
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Ghost/Text Button (secondary action) ──────────────────────

class _GhostButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _GhostButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<_GhostButton> {
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
      child: AnimatedOpacity(
        opacity: _pressed ? 0.55 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.3,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
