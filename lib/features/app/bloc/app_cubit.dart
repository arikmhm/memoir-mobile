import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/data/datasources/storage_service.dart';
import 'app_state.dart';

/// App lifecycle Cubit.
///
/// Manages the top-level app state:
/// 1. Check if device token exists
/// 2. If yes → startup sequence (status check + template sync)
/// 3. If no → navigate to pairing screen
///
/// Per PRD-05: No login — auth via device_token from pairing.
class AppCubit extends Cubit<AppState> {
  final StorageService _storageService;

  AppCubit({required StorageService storageService})
    : _storageService = storageService,
      super(const AppInitial());

  /// Initialize the app — check for existing device token.
  ///
  /// Jika token ada → AppStartup → route ke /startup screen
  /// Jika tidak ada → AppPairing → route ke /pairing screen
  Future<void> initialize() async {
    try {
      final hasToken = await _storageService.hasDeviceToken();

      if (!hasToken) {
        emit(const AppPairing());
        return;
      }

      // Token exists → navigate to startup screen for
      // status check + template sync (FEAT-MR-02)
      emit(const AppStartup());
    } on Exception catch (e) {
      emit(AppLocked(reason: 'Startup failed: $e'));
    }
  }

  /// Called after successful pairing — run startup sequence.
  ///
  /// Per PRD-05: After pairing, device perlu sync sebelum siap.
  void onPairingComplete() {
    emit(const AppStartup());
  }

  /// Called by StartupCubit when startup sequence completes successfully.
  void onStartupComplete({List<dynamic> templates = const []}) {
    emit(AppReady(templates: templates));
  }

  /// Called when device token is invalidated (401 from backend).
  void onAuthError() {
    emit(const AppPairing());
  }

  /// Reset to pairing state (e.g., from settings "Unpair").
  Future<void> unpair() async {
    await _storageService.clearDeviceToken();
    emit(const AppPairing());
  }
}
