// Example: Earnings Feature - Summary Card Widget
// Path: lib/earnings/view/widgets/earnings_summary_card.dart

import 'package:flutter/material.dart';
import '../../data/models/earnings_summary.dart';

// Shared design system imports
// import '../../../shared/utils/colors.dart';
// import '../../../shared/utils/constants.dart';
// import '../../../shared/utils/typography.dart';

/// Feature-specific widget for displaying earnings summary
/// 
/// This widget belongs to the earnings feature and is not shared.
/// Shared widgets go in lib/shared/widgets/
class EarningsSummaryCard extends StatelessWidget {
  final EarningsSummary summary;

  const EarningsSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        children: [
          Text(
            '\$${summary.totalEarnings.toStringAsFixed(2)}',
            style: AppTypography.displayMedium.copyWith(
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Total Earnings',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('Tips', '\$${summary.tips.toStringAsFixed(2)}'),
              _buildStatItem('Bonuses', '\$${summary.bonuses.toStringAsFixed(2)}'),
              _buildStatItem('Trips', '${summary.completedTrips}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
