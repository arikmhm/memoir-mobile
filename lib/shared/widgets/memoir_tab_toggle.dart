import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Custom tab toggle — replaces Material SegmentedButton.
///
/// Matches memoir dashboard web design: subtle border, underline on selected.
class MemoirTabToggle<T> extends StatelessWidget {
  final List<MemoirTabItem<T>> items;
  final T selected;
  final ValueChanged<T>? onChanged;

  const MemoirTabToggle({
    super.key,
    required this.items,
    required this.selected,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSelected = item.value == selected;
          final isFirst = index == 0;
          final isLast = index == items.length - 1;

          return Expanded(
            child: GestureDetector(
              onTap: onChanged != null ? () => onChanged!(item.value) : null,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.textPrimary
                      : Colors.transparent,
                  borderRadius: BorderRadius.horizontal(
                    left: isFirst ? const Radius.circular(7) : Radius.zero,
                    right: isLast ? const Radius.circular(7) : Radius.zero,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.icon != null) ...[
                      Icon(
                        item.icon,
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class MemoirTabItem<T> {
  final T value;
  final String label;
  final IconData? icon;

  const MemoirTabItem({
    required this.value,
    required this.label,
    this.icon,
  });
}
