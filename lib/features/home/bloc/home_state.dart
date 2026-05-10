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

sealed class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

final class HomeInitial extends HomeState {
  const HomeInitial();
}

// ─── Camera Test States ────────────────────────────────────────────

final class CameraTestInProgress extends HomeState {
  const CameraTestInProgress();
}

final class CameraTestSuccess extends HomeState {
  const CameraTestSuccess();
}

final class CameraTestError extends HomeState {
  final String message;

  const CameraTestError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ─── Printer Test States ───────────────────────────────────────────

final class PrinterScanInProgress extends HomeState {
  const PrinterScanInProgress();
}

final class PrinterScanComplete extends HomeState {
  final List<PrinterInfo> printers;

  const PrinterScanComplete({required this.printers});

  @override
  List<Object?> get props => [printers];
}

final class PrinterSaved extends HomeState {
  final PrinterInfo printer;

  const PrinterSaved({required this.printer});

  @override
  List<Object?> get props => [printer];
}

/// Printer test print in progress.
final class PrinterTestInProgress extends HomeState {
  final PrinterInfo printer;

  const PrinterTestInProgress({required this.printer});

  @override
  List<Object?> get props => [printer];
}

/// Printer test print succeeded.
final class PrinterTestSuccess extends HomeState {
  final PrinterInfo printer;

  const PrinterTestSuccess({required this.printer});

  @override
  List<Object?> get props => [printer];
}

/// Printer test print failed.
final class PrinterTestError extends HomeState {
  final String message;
  final PrinterInfo printer;

  const PrinterTestError({required this.message, required this.printer});

  @override
  List<Object?> get props => [message, printer];
}

// ─── Template Sync States ─────────────────────────────────────────

/// Template sync in progress.
final class TemplateSyncInProgress extends HomeState {
  const TemplateSyncInProgress();
}

/// Template sync succeeded.
final class TemplateSyncSuccess extends HomeState {
  final int count;

  const TemplateSyncSuccess({required this.count});

  @override
  List<Object?> get props => [count];
}

/// Template sync failed.
final class TemplateSyncError extends HomeState {
  final String message;

  const TemplateSyncError({required this.message});

  @override
  List<Object?> get props => [message];
}
