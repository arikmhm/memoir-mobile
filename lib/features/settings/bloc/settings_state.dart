import 'package:equatable/equatable.dart';

import '../../../shared/data/services/print_channel.dart';

/// Printer info for discovered printers (Bluetooth or USB).
class PrinterInfo extends Equatable {
  final String name;
  final String address;
  final PrinterConnectionType connectionType;
  final bool isConnected;

  const PrinterInfo({
    required this.name,
    required this.address,
    this.connectionType = PrinterConnectionType.bluetooth,
    this.isConnected = false,
  });

  @override
  List<Object?> get props => [name, address, connectionType, isConnected];
}

/// Settings feature states.
///
/// Per PRD-05 FEAT-MR-10: Device diagnostic — camera test & printer test.
sealed class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

/// Initial state — settings loaded, no test running.
final class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

// ─── Camera Test States ────────────────────────────────────────────

/// Camera test is initializing.
final class CameraTestInProgress extends SettingsState {
  const CameraTestInProgress();
}

/// Camera test succeeded — camera is active and preview available.
final class CameraTestSuccess extends SettingsState {
  const CameraTestSuccess();
}

/// Camera test failed.
final class CameraTestError extends SettingsState {
  final String message;

  const CameraTestError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ─── Printer Test States ───────────────────────────────────────────

/// Scanning for BLE printers.
final class PrinterScanInProgress extends SettingsState {
  const PrinterScanInProgress();
}

/// Scan complete — list of discovered printers for selection.
final class PrinterScanComplete extends SettingsState {
  final List<PrinterInfo> printers;

  const PrinterScanComplete({required this.printers});

  @override
  List<Object?> get props => [printers];
}

/// Printer selected & saved — ready for test print.
final class PrinterSaved extends SettingsState {
  final PrinterInfo printer;

  const PrinterSaved({required this.printer});

  @override
  List<Object?> get props => [printer];
}

/// Printer test print in progress.
final class PrinterTestInProgress extends SettingsState {
  final PrinterInfo printer;

  const PrinterTestInProgress({required this.printer});

  @override
  List<Object?> get props => [printer];
}

/// Printer test print succeeded.
final class PrinterTestSuccess extends SettingsState {
  final PrinterInfo printer;

  const PrinterTestSuccess({required this.printer});

  @override
  List<Object?> get props => [printer];
}

/// Printer test print failed.
final class PrinterTestError extends SettingsState {
  final String message;
  final PrinterInfo printer;

  const PrinterTestError({required this.message, required this.printer});

  @override
  List<Object?> get props => [message, printer];
}

// ─── Template Sync States ─────────────────────────────────────────

/// Template sync in progress.
final class TemplateSyncInProgress extends SettingsState {
  const TemplateSyncInProgress();
}

/// Template sync succeeded.
final class TemplateSyncSuccess extends SettingsState {
  final int count;

  const TemplateSyncSuccess({required this.count});

  @override
  List<Object?> get props => [count];
}

/// Template sync failed.
final class TemplateSyncError extends SettingsState {
  final String message;

  const TemplateSyncError({required this.message});

  @override
  List<Object?> get props => [message];
}
