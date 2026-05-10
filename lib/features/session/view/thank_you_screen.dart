import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../di.dart';
import '../../../shared/core/theme/app_colors.dart';
import '../../../shared/core/theme/app_spacing.dart';
import '../../../shared/core/widgets/page_background.dart';
import '../../../shared/data/datasources/storage_service.dart';
import '../../../shared/data/models/kiosk_config.dart';

/// Thank You screen — shows result after processing.
///
/// - hasDigitalCopy true + downloadUrl → QR code shown immediately
/// - hasDigitalCopy false → "Terima Kasih!" message
/// - Countdown timer → auto-navigate to screensaver
class ThankYouScreen extends StatefulWidget {
  final String? transactionId;
  final bool hasDigitalCopy;

  const ThankYouScreen({
    super.key,
    this.transactionId,
    required this.hasDigitalCopy,
  });

  @override
  State<ThankYouScreen> createState() => _ThankYouScreenState();
}

class _ThankYouScreenState extends State<ThankYouScreen> {
  late int _secondsRemaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = sl<StorageService>().thankYouDuration;
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsRemaining <= 1) {
        _timer?.cancel();
        if (mounted) context.go('/screensaver');
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String? _buildPreviewUrl() {
    if (widget.transactionId == null) return null;
    final storage = sl<StorageService>();
    final configJson = storage.kioskConfigJson;
    if (configJson == null) return null;
    final config = KioskConfig.fromJsonString(configJson);
    final baseUrl = config.sessionPreviewUrl;
    if (baseUrl == null || baseUrl.isEmpty) return null;
    // Remove trailing slash if present, then append transaction ID
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$base/${widget.transactionId}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewUrl = widget.hasDigitalCopy ? _buildPreviewUrl() : null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          const Positioned.fill(child: PageBackground(pageKey: 'thankYou')),
          SafeArea(
            child: Column(
              children: [
                // ── Main content (centered) ──
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenHorizontal,
                        vertical: AppSpacing.lg,
                      ),
                      child: previewUrl != null
                          ? _QrContent(downloadUrl: previewUrl)
                          : const _SimpleContent(),
                    ),
                  ),
                ),

                // ── Buttons + countdown (pinned bottom) ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.sm,
                    AppSpacing.screenHorizontal,
                    AppSpacing.md,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Kembali ke layar utama dalam $_secondsRemaining detik',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textDisabled,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: AppSpacing.touchTarget,
                              child: OutlinedButton(
                                onPressed: () =>
                                    context.go('/select-template'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary,
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2,
                                  ),
                                ),
                                child: const Text('SESI BARU'),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: SizedBox(
                              height: AppSpacing.touchTarget,
                              child: FilledButton(
                                onPressed: () =>
                                    context.go('/screensaver'),
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      AppColors.brandPrimary,
                                  foregroundColor:
                                      AppColors.brandAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2,
                                  ),
                                ),
                                child: const Text('SELESAI'),
                              ),
                            ),
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

// ─── QR Content (hasDigitalCopy) ────────────────────────────────

class _QrContent extends StatelessWidget {
  final String downloadUrl;
  const _QrContent({required this.downloadUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Terima Kasih!',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Jangan lupa ambil foto cetakanmu.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: QrImageView(
            data: downloadUrl,
            version: QrVersions.auto,
            size: 200,
            backgroundColor: AppColors.surface,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppColors.brandPrimary,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppColors.brandPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Scan QR untuk download',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Arahkan kamera HP kamu ke QR code di atas\n'
          'untuk mendapatkan salinan digital foto.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── Simple Content (no digital copy) ───────────────────────────

class _SimpleContent extends StatelessWidget {
  const _SimpleContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Terima Kasih!',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Jangan lupa ambil foto cetakanmu.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
