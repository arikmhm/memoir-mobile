import 'package:equatable/equatable.dart';

/// Printer info for discovered BLE printers.
class PrinterInfo extends Equatable {
  final String name;
  final String address;
  final bool isConnected;

  const PrinterInfo({
    required this.name,
    required this.address,
    this.isConnected = false,
  });

  @override
  List<Object?> get props => [name, address, isConnected];
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

/// Scan complete — list of discovered printers.
final class PrinterScanComplete extends SettingsState {
  final List<PrinterInfo> printers;

  const PrinterScanComplete({required this.printers});

  @override
  List<Object?> get props => [printers];
}

/// Printer test print in progress.
final class PrinterTestInProgress extends SettingsState {
  final List<PrinterInfo> printers;

  const PrinterTestInProgress({required this.printers});

  @override
  List<Object?> get props => [printers];
}

/// Printer test print succeeded.
final class PrinterTestSuccess extends SettingsState {
  final List<PrinterInfo> printers;

  const PrinterTestSuccess({required this.printers});

  @override
  List<Object?> get props => [printers];
}

/// Printer test print failed.
final class PrinterTestError extends SettingsState {
  final String message;
  final List<PrinterInfo> printers;

  const PrinterTestError({required this.message, required this.printers});

  @override
  List<Object?> get props => [message, printers];
}
