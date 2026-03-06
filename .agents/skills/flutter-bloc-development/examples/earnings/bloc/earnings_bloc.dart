// Example: Earnings Feature - BLoC Implementation
// Path: lib/earnings/bloc/earnings_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'earnings_event.dart';
import 'earnings_state.dart';
import '../data/repositories/earnings_repository.dart';

class EarningsBloc extends Bloc<EarningsEvent, EarningsState> {
  final EarningsRepository _repository;
  
  String? _currentDriverId;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  EarningsBloc({required EarningsRepository repository})
      : _repository = repository,
        super(EarningsInitial()) {
    on<EarningsLoadRequested>(_onLoadRequested);
    on<EarningsRefreshRequested>(_onRefreshRequested);
    on<EarningsDateRangeChanged>(_onDateRangeChanged);
  }

  Future<void> _onLoadRequested(
    EarningsLoadRequested event,
    Emitter<EarningsState> emit,
  ) async {
    // Always emit Loading before async work
    emit(EarningsLoading());

    _currentDriverId = event.driverId;
    _startDate = event.startDate ?? _startDate;
    _endDate = event.endDate ?? _endDate;

    try {
      final summary = await _repository.getEarnings(
        driverId: event.driverId,
        startDate: _startDate,
        endDate: _endDate,
      );

      emit(EarningsLoaded(
        summary: summary,
        startDate: _startDate,
        endDate: _endDate,
      ));
    } catch (e) {
      // User-friendly error message
      emit(const EarningsError('Unable to load earnings. Please try again.'));
    }
  }

  Future<void> _onRefreshRequested(
    EarningsRefreshRequested event,
    Emitter<EarningsState> emit,
  ) async {
    if (_currentDriverId == null) return;

    emit(EarningsLoading());

    try {
      final summary = await _repository.getEarnings(
        driverId: _currentDriverId!,
        startDate: _startDate,
        endDate: _endDate,
      );

      emit(EarningsLoaded(
        summary: summary,
        startDate: _startDate,
        endDate: _endDate,
      ));
    } catch (e) {
      emit(const EarningsError('Unable to refresh earnings. Please try again.'));
    }
  }

  Future<void> _onDateRangeChanged(
    EarningsDateRangeChanged event,
    Emitter<EarningsState> emit,
  ) async {
    if (_currentDriverId == null) return;

    _startDate = event.startDate;
    _endDate = event.endDate;

    emit(EarningsLoading());

    try {
      final summary = await _repository.getEarnings(
        driverId: _currentDriverId!,
        startDate: _startDate,
        endDate: _endDate,
      );

      emit(EarningsLoaded(
        summary: summary,
        startDate: _startDate,
        endDate: _endDate,
      ));
    } catch (e) {
      emit(const EarningsError('Unable to update date range. Please try again.'));
    }
  }
}
