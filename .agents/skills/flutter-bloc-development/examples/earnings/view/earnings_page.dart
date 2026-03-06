// Example: Earnings Feature - Main Page
// Path: lib/earnings/view/earnings_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Feature imports using barrel file
import '../earnings.dart';
import '../data/models/earnings_summary.dart';

// Shared design system imports
// import '../../shared/utils/colors.dart';
// import '../../shared/utils/constants.dart';
// import '../../shared/utils/typography.dart';
// import '../../shared/widgets/gradient_scaffold.dart';

/// Earnings page demonstrating proper BLoC integration and design system usage
/// 
/// Key patterns:
/// - BlocConsumer for listening (errors) + building (UI states)
/// - All colors from AppColors
/// - All spacing from AppSpacing
/// - All typography from AppTypography
class EarningsPage extends StatelessWidget {
  final String driverId;

  const EarningsPage({super.key, required this.driverId});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SafeArea(
        child: BlocConsumer<EarningsBloc, EarningsState>(
          // Listener handles side effects (SnackBars, navigation)
          listener: (context, state) {
            if (state is EarningsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          // Builder renders UI based on state
          builder: (context, state) {
            return Column(
              children: [
                // Header - always visible
                _buildHeader(context),

                // Content - state dependent
                Expanded(
                  child: _buildContent(context, state),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Earnings',
            style: AppTypography.headlineLarge,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            color: AppColors.textPrimary,
            onPressed: () => _showDatePicker(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, EarningsState state) {
    // Handle each state explicitly
    if (state is EarningsLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    }

    if (state is EarningsLoaded) {
      return RefreshIndicator(
        onRefresh: () async {
          context.read<EarningsBloc>().add(const EarningsRefreshRequested());
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EarningsSummaryCard(summary: state.summary),
              const SizedBox(height: AppSpacing.lg),
              DailyEarningsList(dailyEarnings: state.summary.dailyBreakdown),
            ],
          ),
        ),
      );
    }

    // Initial or error state - show empty state
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No earnings data',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showDatePicker(BuildContext context) {
    // Date picker implementation
  }
}
