import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repositories/pairing_repository.dart';
import 'pairing_state.dart';

/// Pairing Cubit — handles 6-digit code submission.
///
/// Per PRD-05 FEAT-MR-01:
/// Flow: Enter code → POST /kiosk/pair → receive device_token → store securely.
class PairingCubit extends Cubit<PairingState> {
  final PairingRepository _repository;

  PairingCubit({required PairingRepository repository})
    : _repository = repository,
      super(const PairingInitial());

  /// Submit a 6-digit pairing code.
  Future<void> submitPairingCode(String code) async {
    if (code.length != 6) {
      emit(const PairingError(message: 'Kode pairing harus 6 digit'));
      return;
    }

    emit(const PairingLoading());

    try {
      await _repository.pair(code);
      emit(const PairingSuccess());
    } on Exception catch (e) {
      emit(PairingError(message: 'Pairing gagal: $e'));
    }
  }

  /// Reset to initial state.
  void reset() {
    emit(const PairingInitial());
  }
}
