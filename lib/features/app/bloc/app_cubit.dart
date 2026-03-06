import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/data/datasources/storage_service.dart';
import 'app_state.dart';

/// App lifecycle Cubit.
///
/// Manages the top-level app state:
/// 1. Check if device token exists
/// 2. If yes → startup sequence (sync templates, check status)
/// 3. If no → navigate to pairing screen
///
/// Per PRD-05: No login — auth via device_token from pairing.
class AppCubit extends Cubit<AppState> {
  final StorageService _storageService;

  AppCubit({required StorageService storageService})
    : _storageService = storageService,
      super(const AppInitial());

  /// Initialize the app — check for existing device token.
  Future<void> initialize() async {
    emit(const AppStartup());

    try {
      final hasToken = await _storageService.hasDeviceToken();

      if (!hasToken) {
        emit(const AppPairing());
        return;
      }

      // TODO: Call GET /kiosk/me to check status
      // TODO: Sync templates via GET /kiosk/templates
      // For now, go directly to ready state with mock data.
      emit(const AppReady());
    } on Exception catch (e) {
      emit(AppLocked(reason: 'Startup failed: $e'));
    }
  }

  /// Called after successful pairing — transition to ready.
  void onPairingComplete() {
    emit(const AppReady());
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
