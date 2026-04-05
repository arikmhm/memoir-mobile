import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Inline banner — replaces Material SnackBar.
///
/// Matches memoir dashboard web design: subtle background, icon + text + optional badge.
enum MemoirBannerType { success, error, info }

class MemoirBanner extends StatefulWidget {
  final String message;
  final MemoirBannerType type;
  final Duration? autoDismiss;
  final VoidCallback? onDismiss;

  const MemoirBanner({
    super.key,
    required this.message,
    this.type = MemoirBannerType.info,
    this.autoDismiss = const Duration(seconds: 4),
    this.onDismiss,
  });

  @override
  State<MemoirBanner> createState() => _MemoirBannerState();
}

class _MemoirBannerState extends State<MemoirBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    if (widget.autoDismiss != null) {
      Future.delayed(widget.autoDismiss!, () {
        if (mounted) {
          _controller.reverse().then((_) => widget.onDismiss?.call());
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (widget.type) {
      MemoirBannerType.success => (AppColors.success, Icons.check_circle_outline, 'Berhasil'),
      MemoirBannerType.error => (AppColors.error, Icons.error_outline, 'Gagal'),
      MemoirBannerType.info => (AppColors.textSecondary, Icons.info_outline, 'Info'),
    };

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                widget.message,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
