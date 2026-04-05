import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../di.dart';
import '../../data/datasources/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Reusable session countdown bar.
///
/// Reads timeout settings from [StorageService] and displays a subtle
/// countdown. When expired, auto-navigates to screensaver.
///
/// Supports two modes:
/// - **Global**: shared timer across all pages (reads remaining from service)
/// - **Per page**: independent timer per screen
///
/// If timeout is 0 or mode doesn't apply, renders [SizedBox.shrink].
class SessionCountdownBar extends StatefulWidget {
  /// The per-page timeout key. Used when mode is 'per_page'.
  /// Pass the timeout seconds directly (e.g. storageService.selectTemplateTimeout).
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
  bool _visible = false;

  StorageService get _storage => sl<StorageService>();

  @override
  void initState() {
    super.initState();
    _initTimer();
  }

  void _initTimer() {
    // Off mode — no countdown at all.
    if (_storage.isTimeoutOff) return;

    if (_storage.isGlobalTimeout) {
      _remaining = _storage.globalRemainingSeconds;
    } else {
      _remaining = widget.perPageTimeout;
    }

    if (_remaining <= 0) {
      // Already expired — navigate immediately.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onExpired();
      });
      return;
    }

    _visible = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }

      if (_storage.isGlobalTimeout) {
        _remaining = _storage.globalRemainingSeconds;
      } else {
        _remaining--;
      }

      if (_remaining <= 0) {
        _timer?.cancel();
        _onExpired();
      } else {
        setState(() {});
      }
    });
  }

  void _onExpired() {
    _storage.clearSessionTimer();
    if (mounted) context.go('/screensaver');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final minutes = _remaining ~/ 60;
    final seconds = _remaining % 60;
    final timeStr = minutes > 0
        ? '$minutes:${seconds.toString().padLeft(2, '0')}'
        : '$seconds detik';

    final isLow = _remaining <= 30;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 13,
            color: isLow ? AppColors.error : AppColors.textDisabled,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isLow ? AppColors.error : AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}
