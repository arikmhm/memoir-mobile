import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/core/utils/result.dart';
import '../data/repositories/startup_repository.dart';
import 'startup_state.dart';

/// Startup sequence Cubit.
///
/// Per PRD-05 FEAT-MR-02: Menjalankan startup sequence saat app dibuka.
/// Flow:
/// 1. Check device status (GET /kiosk/me)
/// 2. Sync templates (GET /kiosk/templates)
/// 3. Jika semua berhasil → StartupComplete
/// 4. Jika gagal → StartupError (bisa retry)
class StartupCubit extends Cubit<StartupState> {
  final StartupRepository _repository;

  StartupCubit({required StartupRepository repository})
    : _repository = repository,
      super(const StartupInitial());

  /// Jalankan startup sequence lengkap.
  ///
  /// Dipanggil saat startup screen pertama kali ditampilkan
  /// atau saat user menekan tombol retry.
  Future<void> runStartup() async {
    // Step 1: Check device status
    emit(const StartupCheckingDevice());

    final statusResult = await _repository.checkDeviceStatus();

    switch (statusResult) {
      case Error(:final error):
        emit(StartupError(message: error.toString()));
        return;
      case Ok(:final value):
        final kioskConfig = value;

        // Step 2: Sync templates
        emit(const StartupSyncingTemplates());

        final templatesResult = await _repository.syncTemplates();

        switch (templatesResult) {
          case Error(:final error):
            emit(StartupError(message: error.toString()));
            return;
          case Ok(:final value):
            // Startup complete — device siap digunakan
            emit(StartupComplete(
              kioskConfig: kioskConfig,
              templates: value,
            ));
        }
    }
  }

  /// Reset state untuk retry.
  void reset() {
    emit(const StartupInitial());
  }
}
