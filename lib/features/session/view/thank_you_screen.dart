import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _ThankYouScreenState extends State<ThankYouScreen>
    with TickerProviderStateMixin {
  late int _secondsRemaining;
  Timer? _timer;

  late final AnimationController _entranceController;
  late final Animation<double> _entranceScale;
  late final Animation<double> _entranceFade;

  late final AnimationController _badgePulseController;
  late final Animation<double> _badgePulseAnimation;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = sl<StorageService>().thankYouDuration;
    _startCountdown();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entranceScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutBack,
      ),
    );
    _entranceFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _entranceController.forward();

    _badgePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _badgePulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _badgePulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Light celebratory haptic
    HapticFeedback.lightImpact();
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
    _entranceController.dispose();
    _badgePulseController.dispose();
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
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$base/${widget.transactionId}';
  }

  @override
  Widget build(BuildContext context) {
    final previewUrl = widget.hasDigitalCopy ? _buildPreviewUrl() : null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          const Positioned.fill(child: PageBackground(pageKey: 'thankYou')),
          SafeArea(
            child: Column(
              children: [
                // ── Main content (centered, animated entrance) ──
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenHorizontal,
                        vertical: AppSpacing.lg,
                      ),
                      child: AnimatedBuilder(
                        animation: _entranceController,
                        builder: (_, child) => Opacity(
                          opacity: _entranceFade.value,
                          child: Transform.scale(
                            scale: _entranceScale.value,
                            child: child,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Celebration badge
                            _CelebrationBadge(
                              pulseAnimation: _badgePulseAnimation,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            // Title
                            Text(
                              'Terima Kasih!',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            // Subtitle (context-aware)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              child: Text(
                                previewUrl != null
                                    ? 'Foto cetakanmu sudah siap! Scan QR untuk download salinan digital.'
                                    : 'Foto cetakanmu sudah siap di mesin. Selamat menikmati!',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.5,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            // QR card or printer icon (context-aware)
                            if (previewUrl != null)
                              _QrCard(downloadUrl: previewUrl)
                            else
                              const _PrinterIcon(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Buttons + countdown (pinned bottom) ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.md,
                    AppSpacing.screenHorizontal,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Countdown pill chip
                      _CountdownChip(seconds: _secondsRemaining),
                      const SizedBox(height: AppSpacing.md),
                      // Primary: Sesi Baru
                      _PrimaryButton(
                        label: 'Sesi Baru',
                        icon: Icons.add_rounded,
                        onPressed: () => context.go('/select-template'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      // Secondary: Selesai
                      _GhostButton(
                        label: 'Selesai',
                        icon: Icons.close_rounded,
                        onPressed: () => context.go('/screensaver'),
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

// ─── Celebration Badge ──────────────────────────────────────────

class _CelebrationBadge extends StatelessWidget {
  final Animation<double> pulseAnimation;

  const _CelebrationBadge({required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (_, _) {
        final ringScale = 1.0 + pulseAnimation.value * 0.25;
        final ringOpacity = (1.0 - pulseAnimation.value) * 0.5;
        return SizedBox(
          width: 110,
          height: 110,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing halo ring
              Transform.scale(
                scale: ringScale,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success.withValues(alpha: ringOpacity),
                  ),
                ),
              ),
              // Solid badge
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── QR Card (modern) ───────────────────────────────────────────

class _QrCard extends StatelessWidget {
  final String downloadUrl;
  const _QrCard({required this.downloadUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Label badge above QR
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.brandPrimary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_download_rounded,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                'Salinan Digital',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // QR card with shadow elevation
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: QrImageView(
            data: downloadUrl,
            version: QrVersions.auto,
            size: 220,
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
        const SizedBox(height: AppSpacing.md),
        Text(
          'Arahkan kamera HP ke QR di atas',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── Printer Icon (no-digital-copy fallback) ───────────────────

class _PrinterIcon extends StatelessWidget {
  const _PrinterIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceVariant,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        Icons.local_printshop_outlined,
        size: 64,
        color: AppColors.brandPrimary,
      ),
    );
  }
}

// ─── Countdown Chip ────────────────────────────────────────────

class _CountdownChip extends StatelessWidget {
  final int seconds;
  const _CountdownChip({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final isUrgent = seconds <= 5;
    final bg = isUrgent ? AppColors.error : AppColors.surfaceVariant;
    final fg = isUrgent ? Colors.white : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            'Otomatis kembali dalam ${seconds}s',
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

// ─── Primary Button (modern pill) ──────────────────────────────

class _PrimaryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
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
            children: [
              Icon(widget.icon, size: 22, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Ghost Button (secondary) ──────────────────────────────────

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
              Icon(widget.icon, size: 18, color: AppColors.textSecondary),
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
