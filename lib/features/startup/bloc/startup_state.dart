import 'package:equatable/equatable.dart';

import '../../../shared/data/models/kiosk_config.dart';
import '../../../shared/data/models/template.dart';

/// Startup sequence states.
///
/// Per PRD-05 FEAT-MR-02: Status check + template sync saat aplikasi dijalankan.
/// Flow: CheckingDevice → SyncingTemplates → Complete
sealed class StartupState extends Equatable {
  const StartupState();

  @override
  List<Object?> get props => [];
}

/// Initial state — startup belum dimulai.
final class StartupInitial extends StartupState {
  const StartupInitial();
}

/// Step 1: Mengecek status device via GET /kiosk/me.
final class StartupCheckingDevice extends StartupState {
  const StartupCheckingDevice();
}

/// Step 2: Sinkronisasi template via GET /kiosk/templates.
final class StartupSyncingTemplates extends StartupState {
  const StartupSyncingTemplates();
}

/// Startup selesai — device siap digunakan.
final class StartupComplete extends StartupState {
  final KioskConfig kioskConfig;
  final List<Template> templates;

  const StartupComplete({
    required this.kioskConfig,
    required this.templates,
  });

  @override
  List<Object?> get props => [kioskConfig, templates];
}

/// Error saat startup — bisa retry.
final class StartupError extends StartupState {
  final String message;

  const StartupError({required this.message});

  @override
  List<Object?> get props => [message];
}
