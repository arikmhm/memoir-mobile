import 'package:flutter/material.dart';

import '../../../../../shared/core/theme/app_colors.dart';
import '../../../../../shared/core/theme/app_spacing.dart';

class TimeoutOptionChips extends StatelessWidget {
  final List<int> options;
  final int selected;
  final ValueChanged<int> onSelected;

  const TimeoutOptionChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((seconds) {
        final label = seconds < 60 ? '${seconds}s' : '${seconds ~/ 60}m';
        final isSelected = selected == seconds;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: seconds == options.last ? 0 : AppSpacing.xs,
            ),
            child: TimeoutChip(
              label: label,
              isActive: isSelected,
              onTap: () => onSelected(seconds),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class TimeoutChip extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const TimeoutChip({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<TimeoutChip> createState() => _TimeoutChipState();
}

class _TimeoutChipState extends State<TimeoutChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: widget.isActive ? AppColors.brandPrimary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isActive ? AppColors.brandPrimary : AppColors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: widget.isActive ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
