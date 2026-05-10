import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../di.dart';
import '../../data/datasources/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Per-page session countdown bar.
///
/// Counts down from [perPageTimeout] seconds. When expired, navigates
/// to screensaver. Hidden if [perPageTimeout] is 0.
class SessionCountdownBar extends StatefulWidget {
  final int perPageTimeout;

  const SessionCountdownBar({
    super.key,
    required this.perPageTimeout,
  });

  @override
  State<SessionCountdownBar> createState() => _SessionCountdownBarState();
}

class _SessionCountdownBarState extends State<SessionCountdownBar> {
  Timer? _timer;
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.perPageTimeout;

    if (_remaining <= 0) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _timer?.cancel();
        _onExpired();
      }
    });
  }

  void _onExpired() {
    sl<StorageService>().clearSessionTimer();
    if (mounted) context.go('/screensaver');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.perPageTimeout <= 0) return const SizedBox.shrink();

    final minutes = _remaining ~/ 60;
    final seconds = _remaining % 60;
    final timeStr = minutes > 0
        ? '$minutes:${seconds.toString().padLeft(2, '0')}'
        : '$seconds detik';

    final isLow = _remaining <= 30;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 18,
            color: isLow ? AppColors.error : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isLow ? AppColors.error : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
