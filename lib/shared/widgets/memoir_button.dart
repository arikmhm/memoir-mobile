import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Custom button — replaces Material ElevatedButton/OutlinedButton/FilledButton.
///
/// Uses scale + opacity animation on press instead of Material ripple.
/// Matches memoir dashboard web design language.
enum MemoirButtonVariant { filled, outlined, text }

class MemoirButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final MemoirButtonVariant variant;
  final bool isLoading;
  final Color? color;
  final bool expand;

  const MemoirButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = MemoirButtonVariant.filled,
    this.isLoading = false,
    this.color,
    this.expand = true,
  });

  const MemoirButton.filled({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.color,
    this.expand = true,
  }) : variant = MemoirButtonVariant.filled;

  const MemoirButton.outlined({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.color,
    this.expand = true,
  }) : variant = MemoirButtonVariant.outlined;

  const MemoirButton.text({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.color,
    this.expand = true,
  }) : variant = MemoirButtonVariant.text;

  @override
  State<MemoirButton> createState() => _MemoirButtonState();
}

class _MemoirButtonState extends State<MemoirButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  void _onTapDown(TapDownDetails _) {
    if (!_enabled) return;
    setState(() => _pressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    if (!_enabled) return;
    setState(() => _pressed = false);
    widget.onPressed?.call();
  }

  void _onTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.textPrimary;
    final disabled = !_enabled;

    final child = AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.7 : (disabled ? 0.4 : 1.0),
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: _decoration(color, disabled),
          child: Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading) ...[
                MemoirLoadingIndicator(
                  size: 16,
                  color: _foregroundColor(color, disabled),
                ),
                const SizedBox(width: AppSpacing.sm),
              ] else if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 18,
                  color: _foregroundColor(color, disabled),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _foregroundColor(color, disabled),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }

  BoxDecoration _decoration(Color color, bool disabled) {
    switch (widget.variant) {
      case MemoirButtonVariant.filled:
        return BoxDecoration(
          color: disabled ? AppColors.surfaceContainer : color,
          borderRadius: BorderRadius.circular(8),
        );
      case MemoirButtonVariant.outlined:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: disabled ? AppColors.border : (widget.color ?? AppColors.border),
            width: 1,
          ),
        );
      case MemoirButtonVariant.text:
        return const BoxDecoration();
    }
  }

  Color _foregroundColor(Color color, bool disabled) {
    if (disabled) return AppColors.textDisabled;
    switch (widget.variant) {
      case MemoirButtonVariant.filled:
        return Colors.white;
      case MemoirButtonVariant.outlined:
      case MemoirButtonVariant.text:
        return widget.color ?? AppColors.textPrimary;
    }
  }
}

/// Custom loading indicator — replaces CircularProgressIndicator.
///
/// Three pulsing dots animation.
class MemoirLoadingIndicator extends StatefulWidget {
  final double size;
  final Color? color;

  const MemoirLoadingIndicator({
    super.key,
    this.size = 20,
    this.color,
  });

  @override
  State<MemoirLoadingIndicator> createState() => _MemoirLoadingIndicatorState();
}

class _MemoirLoadingIndicatorState extends State<MemoirLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotSize = widget.size * 0.3;
    final color = widget.color ?? AppColors.textSecondary;

    return SizedBox(
      width: widget.size,
      height: dotSize,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = (_controller.value + delay) % 1.0;
            final opacity = (t < 0.5) ? (0.3 + 0.7 * (t / 0.5)) : (1.0 - 0.7 * ((t - 0.5) / 0.5));
            return Opacity(
              opacity: opacity,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
