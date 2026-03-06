import 'package:equatable/equatable.dart';

/// App lifecycle states.
///
/// Per PRD-05 Section 5.2:
/// AppInitial → AppStartup → AppPairing or AppReady
/// AppLocked when subscription expired.
sealed class AppState extends Equatable {
  const AppState();

  @override
  List<Object?> get props => [];
}

/// Initial state — app just launched, nothing checked yet.
final class AppInitial extends AppState {
  const AppInitial();
}

/// Startup in progress — checking token, syncing templates.
final class AppStartup extends AppState {
  const AppStartup();
}

/// No device token — need to pair via 6-digit code.
final class AppPairing extends AppState {
  const AppPairing();
}

/// Device locked — subscription expired or other lockout.
final class AppLocked extends AppState {
  final String reason;

  const AppLocked({required this.reason});

  @override
  List<Object?> get props => [reason];
}

/// App ready — paired and templates synced. GoRouter handles screens.
final class AppReady extends AppState {
  const AppReady();
}
