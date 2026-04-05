import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../di.dart';
import '../../../shared/core/theme/app_colors.dart';
import '../../../shared/core/widgets/noise_background.dart';
import '../../../shared/core/widgets/session_countdown_bar.dart';
import '../../../shared/core/theme/app_spacing.dart';
import '../../../shared/core/utils/formatters.dart';
import '../../../shared/data/datasources/storage_service.dart';
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
          const Positioned.fill(
            child: RepaintBoundary(
              child: NoiseBackground(),
            ),
          ),
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
                ProcessingCreatingTransaction() => const _LoadingView(
                  message: 'Membuat transaksi...',
                ),
                ProcessingAwaitingPayment() => Column(
                  children: [
                    SessionCountdownBar(
                      perPageTimeout:
                          sl<StorageService>().paymentTimeout,
                    ),
                    Expanded(
                      child: _AwaitingPaymentView(state: state),
                    ),
                  ],
                ),
                ProcessingCheckingPayment() => const _LoadingView(
                  message: 'Memeriksa pembayaran...',
                ),
                ProcessingPaymentFailed() =>
                  _PaymentFailedView(state: state),
                ProcessingRendering() => const _LoadingView(
                  message: 'Memproses foto...',
                ),
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

// ─── Awaiting Payment View ──────────────────────────────────────

class _AwaitingPaymentView extends StatelessWidget {
  final ProcessingAwaitingPayment state;
  const _AwaitingPaymentView({required this.state});

  @override
  Widget build(BuildContext context) {
    return switch (state.paymentMethod) {
      'CASH' => _CashPaymentView(state: state),
      'STATIC_QRIS' => _StaticQrisPaymentView(state: state),
      'PG' => _PgPaymentView(state: state),
      _ => _CashPaymentView(state: state),
    };
  }
}

// ─── CASH Payment View ──────────────────────────────────────────

class _CashPaymentView extends StatelessWidget {
  final ProcessingAwaitingPayment state;
  const _CashPaymentView({required this.state});

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
            const Icon(
              Icons.payments_outlined,
              size: 72,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Pembayaran Tunai',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Silakan lakukan pembayaran ke petugas',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Total Pembayaran',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              Formatters.formatRupiah(state.transaction.totalAmount),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.touchTarget + 8,
              child: FilledButton(
                onPressed: cubit.confirmCashPayment,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.brandAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'SUDAH BAYAR',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/screensaver'),
                child: const Text('BATALKAN'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── STATIC QRIS Payment View ───────────────────────────────────

class _StaticQrisPaymentView extends StatelessWidget {
  final ProcessingAwaitingPayment state;
  const _StaticQrisPaymentView({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<ProcessingCubit>();
    final imagePath = state.staticQrisImagePath;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scan QRIS untuk Membayar',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Arahkan kamera HP ke QR code di bawah',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            // Static QRIS image
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 2),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: imagePath != null && File(imagePath).existsSync()
                  ? Image.file(
                      File(imagePath),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const _QrPlaceholder(),
                    )
                  : const _QrPlaceholder(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Total Pembayaran',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              Formatters.formatRupiah(state.transaction.totalAmount),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.touchTarget + 8,
              child: FilledButton(
                onPressed: cubit.confirmCashPayment,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.brandAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'SUDAH BAYAR',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/screensaver'),
                child: const Text('BATALKAN'),
              ),
            ),
          ],
        ),
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


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qrString = widget.state.qrString;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scan QRIS untuk Membayar',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Arahkan kamera HP ke QR code di bawah',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            // Dynamic QR code
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 2),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: qrString != null && qrString.isNotEmpty
                  ? QrImageView(
                      data: qrString,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                      errorStateBuilder: (_, _) => const _QrPlaceholder(),
                    )
                  : const _QrPlaceholder(),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Expiry info
            if (widget.state.paymentExpiresAt != null)
              _ExpiryCountdown(
                expiresAt: widget.state.paymentExpiresAt!,
                onExpired: () {
                  if (context.mounted) context.go('/screensaver');
                },
              ),
            const SizedBox(height: AppSpacing.lg),
            // Amount display
            Text(
              'Total Pembayaran',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              Formatters.formatRupiah(widget.state.transaction.totalAmount),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.touchTarget + 8,
              child: FilledButton(
                onPressed: _isChecking ? null : _checkPayment,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.brandAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: _isChecking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brandAccent,
                        ),
                      )
                    : const Text(
                        'CEK PEMBAYARAN',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/screensaver'),
                child: const Text('BATALKAN'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Expiry Countdown ───────────────────────────────────────────

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

  @override
  void initState() {
    super.initState();
    _expiry = DateTime.tryParse(widget.expiresAt) ?? DateTime.now();
    _remaining = _expiry.difference(DateTime.now());
    _startTicker();
  }

  bool _expiredHandled = false;

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
    final theme = Theme.of(context);
    final isExpired = _remaining.isNegative || _remaining.inSeconds <= 0;
    final minutes = _remaining.inMinutes.clamp(0, 99);
    final seconds = (_remaining.inSeconds % 60).clamp(0, 59);
    final text = isExpired
        ? 'QR kedaluwarsa'
        : 'Berlaku ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: isExpired ? AppColors.error : AppColors.textSecondary,
        fontWeight: FontWeight.w500,
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
            const Icon(
              Icons.payment_outlined,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Pembayaran Gagal',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: cubit.retryPayment,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.brandAccent,
                ),
                child: const Text('COBA LAGI'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/screensaver'),
                child: const Text('KEMBALI'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Printing View ──────────────────────────────────────────────

class _PrintingView extends StatelessWidget {
  final ProcessingPrinting state;
  const _PrintingView({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = state.currentCopy / state.totalCopies;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.print_outlined,
              size: 56,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Mencetak...',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Lembar ${state.currentCopy} dari ${state.totalCopies}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.surfaceContainer,
                valueColor: const AlwaysStoppedAnimation(
                  AppColors.brandPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
            const Icon(
              Icons.print_disabled_outlined,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Gagal Mencetak',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Lembar ${state.currentCopy} dari ${state.totalCopies}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: cubit.retryPrint,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.brandAccent,
                ),
                child: const Text('COBA LAGI'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: cubit.skipPrint,
                child: const Text('LEWATI CETAK'),
              ),
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
            const Icon(
              Icons.error_outline,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Terjadi Kesalahan',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (canRetry) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: cubit.retryProcessing,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandAccent,
                  ),
                  child: const Text('COBA LAGI'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/screensaver'),
                child: const Text('KEMBALI'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
