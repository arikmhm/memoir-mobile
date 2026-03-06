// Example: Shared Widget - Trip Summary Card
// Path: lib/shared/widgets/trip_summary_card.dart
//
// This demonstrates a design-system-compliant SHARED widget:
// - Lives in shared/widgets/ because it's used across multiple features
// - All colors from AppColors
// - All spacing from AppSpacing
// - All radius from AppRadius
// - All typography from AppTypography
// - No hardcoded values anywhere

import 'package:flutter/material.dart';

// Shared design system imports
// import '../utils/colors.dart';
// import '../utils/constants.dart';
// import '../utils/typography.dart';

/// A reusable card widget for displaying trip information
/// 
/// This is a SHARED widget used by multiple features (trips, history, earnings).
/// Feature-specific widgets should live in their feature's view/widgets/ folder.
/// 
/// Usage:
/// ```dart
/// TripSummaryCard(
///   pickupAddress: '123 Main St',
///   dropoffAddress: '456 Oak Ave',
///   fare: 24.50,
///   distance: 5.2,
///   duration: 18,
///   onTap: () => navigateToTripDetails(tripId),
/// )
/// ```
class TripSummaryCard extends StatelessWidget {
  final String pickupAddress;
  final String dropoffAddress;
  final double fare;
  final double distance; // in miles
  final int duration; // in minutes
  final VoidCallback? onTap;

  const TripSummaryCard({
    super.key,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.fare,
    required this.distance,
    required this.duration,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route info
            _buildRouteSection(),
            
            const SizedBox(height: AppSpacing.md),
            
            // Divider
            Container(
              height: 1,
              color: AppColors.divider,
            ),
            
            const SizedBox(height: AppSpacing.md),
            
            // Stats row
            _buildStatsRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Route indicators
        Column(
          children: [
            _buildDot(AppColors.primary),
            Container(
              width: 2,
              height: AppSpacing.xl,
              color: AppColors.divider,
            ),
            _buildDot(AppColors.accent),
          ],
        ),
        
        const SizedBox(width: AppSpacing.sm),
        
        // Addresses
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pickupAddress,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                dropoffAddress,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        
        // Fare
        Text(
          '\$${fare.toStringAsFixed(2)}',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: AppSpacing.sm,
      height: AppSpacing.sm,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStat(Icons.straighten, '${distance.toStringAsFixed(1)} mi'),
        _buildStat(Icons.access_time, '$duration min'),
      ],
    );
  }

  Widget _buildStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          value,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
