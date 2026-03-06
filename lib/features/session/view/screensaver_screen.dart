import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/core/theme/app_colors.dart';
import '../../../shared/core/theme/app_spacing.dart';

/// Screensaver screen — attract/idle screen for the kiosk.
///
/// Per PRD-05 FEAT-MR-03: displays image/video. Tap to proceed.
/// Per PRD-05 FEAT-MR-10: hidden access to Settings (Operator)
/// via 5x tap in < 2 seconds on the bottom-left corner.
class ScreensaverScreen extends StatefulWidget {
  const ScreensaverScreen({super.key});

  @override
  State<ScreensaverScreen> createState() => _ScreensaverScreenState();
}

class _ScreensaverScreenState extends State<ScreensaverScreen> {
  /// Tracks timestamps of recent taps on the hidden access zone.
  final List<DateTime> _hiddenTaps = [];

  /// Number of taps required to access settings.
  static const int _requiredTaps = 5;

  /// Maximum duration window for all required taps.
  static const Duration _tapWindow = Duration(seconds: 2);

  void _onHiddenTap() {
    final now = DateTime.now();

    // Remove taps older than the window.
    _hiddenTaps.removeWhere((t) => now.difference(t) > _tapWindow);
    _hiddenTaps.add(now);

    if (_hiddenTaps.length >= _requiredTaps) {
      _hiddenTaps.clear();
      context.push('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main screensaver content — tap to start session
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              context.go('/select-template');
            },
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: AppColors.surface,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'memoir.',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Tap untuk mulai',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Hidden access zone — bottom-left corner, invisible 80×80 area.
          // Per PRD-05 FEAT-MR-10: 5x tap within 2 seconds → Settings.
          Positioned(
            left: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onHiddenTap,
              child: const SizedBox(width: 80, height: 80),
            ),
          ),
        ],
      ),
    );
  }
}
