import 'package:flutter_bloc/flutter_bloc.dart';

import 'session_state.dart';

/// Session Cubit — manages the photo session flow.
///
/// Per PRD-05: foto dulu, bayar kemudian.
/// Flow: Screensaver → Select Template → Photo → Preview → Confirm → Process → Thank You
///
/// Currently stub implementation with mock state transitions.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit() : super(const SessionIdle());

  /// Customer tapped screensaver — go to template selection.
  void startSession() {
    // Stay in Idle so GoRouter navigates to template selection screen.
    // The actual state is managed by routing for now.
    emit(const SessionIdle());
  }

  /// Customer selected a template.
  void selectTemplate(String templateId) {
    emit(SessionTemplateSelected(templateId: templateId));
  }

  /// Begin photo capture for a slot.
  void startCapture({required int totalSlots}) {
    emit(SessionCapturing(currentSlot: 1, totalSlots: totalSlots));
  }

  /// Move to next photo slot.
  void nextSlot() {
    if (state is SessionCapturing) {
      final current = state as SessionCapturing;
      if (current.currentSlot < current.totalSlots) {
        emit(
          SessionCapturing(
            currentSlot: current.currentSlot + 1,
            totalSlots: current.totalSlots,
          ),
        );
      } else {
        emit(const SessionPreviewing());
      }
    }
  }

  /// Show composite preview.
  void showPreview() {
    emit(const SessionPreviewing());
  }

  /// Proceed to confirmation/payment.
  void confirm() {
    emit(const SessionConfirming());
  }

  /// Start processing (print + upload).
  void process() {
    emit(const SessionProcessing());
  }

  /// Session complete — show thank you.
  void complete() {
    emit(const SessionComplete());
  }

  /// Reset to idle (loop back for next customer).
  void reset() {
    emit(const SessionIdle());
  }
}
