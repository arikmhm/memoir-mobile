// Example: Earnings Feature - State Definitions
// Path: lib/earnings/bloc/earnings_state.dart

import 'package:equatable/equatable.dart';
import '../data/models/earnings_summary.dart';

/// Base class for all earnings states
abstract class EarningsState extends Equatable {
  const EarningsState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any data is loaded
class EarningsInitial extends EarningsState {}

/// Loading state - shown during data fetch
class EarningsLoading extends EarningsState {}

/// Success state with earnings data
class EarningsLoaded extends EarningsState {
  final EarningsSummary summary;
  final DateTime startDate;
  final DateTime endDate;

  const EarningsLoaded({
    required this.summary,
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props => [summary, startDate, endDate];
}

/// Error state with user-friendly message
class EarningsError extends EarningsState {
  final String message;

  const EarningsError(this.message);

  @override
  List<Object?> get props => [message];
}
