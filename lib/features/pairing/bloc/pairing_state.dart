import 'package:equatable/equatable.dart';

/// Pairing feature states.
///
/// Flow: Initial → Loading → Success / Error
/// Per PRD-05 FEAT-MR-01: 6-digit code → POST /kiosk/pair → device_token
sealed class PairingState extends Equatable {
  const PairingState();

  @override
  List<Object?> get props => [];
}

/// Initial state — waiting for user to enter pairing code.
final class PairingInitial extends PairingState {
  const PairingInitial();
}

/// Loading — submitting pairing code to backend.
final class PairingLoading extends PairingState {
  const PairingLoading();
}

/// Success — device_token received and stored.
final class PairingSuccess extends PairingState {
  const PairingSuccess();
}

/// Error — pairing failed (invalid code, network error, etc.)
final class PairingError extends PairingState {
  final String message;

  const PairingError({required this.message});

  @override
  List<Object?> get props => [message];
}
