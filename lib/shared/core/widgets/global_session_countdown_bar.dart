import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../di.dart';
import '../../data/datasources/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Global session countdown bar.
///
/// Reads remaining time from [StorageService.globalRemainingSeconds] so the
/// countdown stays continuous across navigation (e.g. retake from preview
/// won't reset the timer). When the timer expires, navigates back to
/// the screensaver and clears the session.
class GlobalSessionCountdownBar extends StatefulWidget {
  /// When true, renders as a compact pill chip (suitable for header inline).
  /// When false (default), renders as a full-width centered bar.
  final bool compact;

  const GlobalSessionCountdownBar({super.key, this.compact = false});

  @override
  State<GlobalSessionCountdownBar> createState() =>
      _GlobalSessionCountdownBarState();
}

class _GlobalSessionCountdownBarState extends State<GlobalSessionCountdownBar> {
  Timer? _ticker;
  late final StorageService _storage;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _storage = sl<StorageService>();
    _remaining = _storage.globalRemainingSeconds;

    if (!_storage.hasActiveSession) return;

    if (_remaining <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onExpired());
      return;
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _ticker?.cancel();
        return;
      }
      final remaining = _storage.globalRemainingSeconds;
      setState(() => _remaining = remaining);
      if (_remaining <= 0) {
        _ticker?.cancel();
        _onExpired();
      }
    });
  }

  void _onExpired() {
    _storage.clearSessionTimer();
    if (mounted) context.go('/screensaver');
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_storage.hasActiveSession) return const SizedBox.shrink();

    final minutes = _remaining ~/ 60;
    final seconds = _remaining % 60;
    final timeStr = minutes > 0
        ? '$minutes:${seconds.toString().padLeft(2, '0')}'
        : '$seconds dtk';

    final isLow = _remaining <= 30;
    final color = isLow ? AppColors.error : AppColors.textSecondary;

    if (widget.compact) {
      final chipBg = isLow ? AppColors.error : AppColors.brandPrimary;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              timeStr,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_outlined, size: 18, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
