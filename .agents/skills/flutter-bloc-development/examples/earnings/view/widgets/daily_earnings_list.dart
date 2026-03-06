// Example: Earnings Feature - Daily Earnings List Widget
// Path: lib/earnings/view/widgets/daily_earnings_list.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/earnings_summary.dart';

// Shared design system imports
// import '../../../shared/utils/colors.dart';
// import '../../../shared/utils/constants.dart';
// import '../../../shared/utils/typography.dart';

/// Feature-specific widget for displaying daily earnings breakdown
class DailyEarningsList extends StatelessWidget {
  final List<DailyEarning> dailyEarnings;

  const DailyEarningsList({super.key, required this.dailyEarnings});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Breakdown',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...dailyEarnings.map((earning) => _buildDailyItem(earning)),
      ],
    );
  }

  Widget _buildDailyItem(DailyEarning earning) {
    final dateFormat = DateFormat('EEE, MMM d');
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateFormat.format(earning.date),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${earning.trips} trips',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Text(
            '\$${earning.amount.toStringAsFixed(2)}',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
