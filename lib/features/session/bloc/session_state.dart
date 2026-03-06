import 'package:equatable/equatable.dart';

/// Session states for the photo session flow.
///
/// Per PRD-05 Section 5.2:
/// Idle → TemplateSelected → Capturing → Previewing → Confirming → Processing → Complete
sealed class SessionState extends Equatable {
  const SessionState();

  @override
  List<Object?> get props => [];
}

/// Idle — screensaver displayed, waiting for customer tap.
final class SessionIdle extends SessionState {
  const SessionIdle();
}

/// Template selected — customer chose a template.
final class SessionTemplateSelected extends SessionState {
  final String templateId;

  const SessionTemplateSelected({required this.templateId});

  @override
  List<Object?> get props => [templateId];
}

/// Capturing — photo session in progress.
final class SessionCapturing extends SessionState {
  final int currentSlot;
  final int totalSlots;

  const SessionCapturing({required this.currentSlot, required this.totalSlots});

  @override
  List<Object?> get props => [currentSlot, totalSlots];
}

/// Previewing — composite preview shown, retake allowed.
final class SessionPreviewing extends SessionState {
  const SessionPreviewing();
}

/// Confirming — payment and print options selection.
final class SessionConfirming extends SessionState {
  const SessionConfirming();
}

/// Processing — printing and/or uploading in progress.
final class SessionProcessing extends SessionState {
  const SessionProcessing();
}

/// Complete — thank you screen, QR displayed.
final class SessionComplete extends SessionState {
  const SessionComplete();
}
