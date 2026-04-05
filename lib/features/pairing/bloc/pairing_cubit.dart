import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/datasources/pairing_datasource.dart';
import '../data/repositories/pairing_repository.dart';
import 'pairing_state.dart';

/// Pairing Cubit — handles 6-digit code submission.
///
/// Per PRD-05 FEAT-MR-01:
/// Flow: Enter code → validate format → POST /kiosk/pair
///     → receive device_token → store securely.
class PairingCubit extends Cubit<PairingState> {
  final PairingRepository _repository;

  PairingCubit({required PairingRepository repository})
    : _repository = repository,
      super(const PairingInitial());

  /// Submit a 6-digit pairing code.
  ///
  /// Validates format (exactly 6 digits), then calls repository.
  Future<void> submitPairingCode(String code) async {
    final trimmed = code.trim();

    // Client-side format validation
    if (!_repository.isValidCode(trimmed)) {
      emit(const PairingError(message: 'Kode pairing harus 6 digit angka'));
      return;
    }

    emit(const PairingLoading());

    try {
      await _repository.pair(trimmed);
      emit(const PairingSuccess());
    } on PairingException catch (e) {
      emit(PairingError(message: e.message));
    } on FormatException catch (e) {
      emit(PairingError(message: e.message));
    } on Exception catch (_) {
      emit(
        const PairingError(
          message: 'Terjadi kesalahan. Silakan coba lagi.',
        ),
      );
    }
  }

  /// Reset to initial state.
  void reset() {
    emit(const PairingInitial());
  }
}
