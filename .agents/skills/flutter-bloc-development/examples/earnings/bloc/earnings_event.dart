// Example: Earnings Feature - Event Definitions
// Path: lib/earnings/bloc/earnings_event.dart

import 'package:equatable/equatable.dart';

/// Base class for all earnings-related events
abstract class EarningsEvent extends Equatable {
  const EarningsEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when the earnings screen loads
class EarningsLoadRequested extends EarningsEvent {
  final String driverId;
  final DateTime? startDate;
  final DateTime? endDate;

  const EarningsLoadRequested({
    required this.driverId,
    this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [driverId, startDate, endDate];
}

/// Triggered when user pulls to refresh
class EarningsRefreshRequested extends EarningsEvent {
  const EarningsRefreshRequested();
}

/// Triggered when user selects a different date range
class EarningsDateRangeChanged extends EarningsEvent {
  final DateTime startDate;
  final DateTime endDate;

  const EarningsDateRangeChanged({
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props => [startDate, endDate];
}
