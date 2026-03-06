// Example: Earnings Feature - Data Models
// Path: lib/earnings/data/models/earnings_summary.dart

import 'package:equatable/equatable.dart';

/// Domain entity for earnings data
class EarningsSummary extends Equatable {
  final double totalEarnings;
  final double tips;
  final double bonuses;
  final int completedTrips;
  final double onlineHours;
  final List<DailyEarning> dailyBreakdown;

  const EarningsSummary({
    required this.totalEarnings,
    required this.tips,
    required this.bonuses,
    required this.completedTrips,
    required this.onlineHours,
    required this.dailyBreakdown,
  });

  @override
  List<Object?> get props => [
        totalEarnings,
        tips,
        bonuses,
        completedTrips,
        onlineHours,
        dailyBreakdown,
      ];
}

class DailyEarning extends Equatable {
  final DateTime date;
  final double amount;
  final int trips;

  const DailyEarning({
    required this.date,
    required this.amount,
    required this.trips,
  });

  @override
  List<Object?> get props => [date, amount, trips];
}
