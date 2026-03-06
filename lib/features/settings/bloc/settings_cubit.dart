import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/data/datasources/storage_service.dart';
import '../data/services/camera_test_service.dart';
import '../data/services/printer_test_service.dart';
import 'settings_state.dart';

/// Settings Cubit — handles device diagnostic tests and default printer.
///
/// Per PRD-05 FEAT-MR-10:
/// - Camera test: initialize camera → show preview → report success/error
/// - Printer test: scan paired printers → test print → report success/error
/// - Save/load default printer for auto-connect in future sessions
class SettingsCubit extends Cubit<SettingsState> {
  final CameraTestService _cameraService;
  final PrinterTestService _printerService;
  final StorageService _storageService;

  SettingsCubit({
    required CameraTestService cameraService,
    required PrinterTestService printerService,
    required StorageService storageService,
  })  : _cameraService = cameraService,
        _printerService = printerService,
        _storageService = storageService,
        super(const SettingsInitial());

  /// The camera controller for preview widget access.
  CameraController? get cameraController => _cameraService.controller;

  /// The currently saved default printer (null if none saved).
  PrinterInfo? get savedPrinter {
    if (!_storageService.hasDefaultPrinter) return null;
    return PrinterInfo(
      name: _storageService.defaultPrinterName ?? '',
      address: _storageService.defaultPrinterMac ?? '',
    );
  }

  // ─── Camera Test ──────────────────────────────────────────────

  /// Start camera diagnostic test.
  Future<void> startCameraTest() async {
    emit(const CameraTestInProgress());

    try {
      await _cameraService.initialize();
      emit(const CameraTestSuccess());
    } on CameraException catch (e) {
      emit(
        CameraTestError(message: e.description ?? 'Gagal mengakses kamera.'),
      );
    } on Exception catch (e) {
      emit(CameraTestError(message: 'Kamera error: $e'));
    }
  }

  /// Stop camera test and release resources.
  Future<void> stopCameraTest() async {
    await _cameraService.dispose();
    emit(const SettingsInitial());
  }

  // ─── Printer Test ─────────────────────────────────────────────

  /// Scan for paired Bluetooth printers.
  Future<void> scanPrinters() async {
    emit(const PrinterScanInProgress());

    try {
      final printers = await _printerService.scanPrinters();
      emit(PrinterScanComplete(printers: printers));
    } on Exception catch (e) {
      emit(PrinterTestError(message: 'Scan gagal: $e', printers: const []));
    }
  }

  /// Perform a test print on the selected printer.
  Future<void> testPrint(PrinterInfo printerInfo) async {
    final currentPrinters = _currentPrinters;

    emit(PrinterTestInProgress(printers: currentPrinters));

    try {
      await _printerService.testPrint(printerInfo);
      emit(PrinterTestSuccess(printers: currentPrinters));
    } on Exception catch (e) {
      emit(
        PrinterTestError(
          message: 'Test print gagal: $e',
          printers: currentPrinters,
        ),
      );
    }
  }

  // ─── Default Printer ──────────────────────────────────────────

  /// Save printer as default for auto-connect.
  Future<void> saveDefaultPrinter(PrinterInfo printer) async {
    await _storageService.setDefaultPrinter(
      name: printer.name,
      mac: printer.address,
    );
    // Re-emit current state to trigger UI rebuild showing saved printer.
    final s = state;
    if (s is PrinterScanComplete) {
      emit(PrinterScanComplete(printers: s.printers));
    } else if (s is PrinterTestSuccess) {
      emit(PrinterTestSuccess(printers: s.printers));
    }
  }

  /// Clear saved default printer.
  Future<void> clearDefaultPrinter() async {
    await _storageService.clearDefaultPrinter();
    // Re-emit to trigger UI rebuild.
    final s = state;
    if (s is PrinterScanComplete) {
      emit(PrinterScanComplete(printers: s.printers));
    } else if (s is PrinterTestSuccess) {
      emit(PrinterTestSuccess(printers: s.printers));
    }
  }

  /// Extract printer list from current state.
  List<PrinterInfo> get _currentPrinters {
    final s = state;
    if (s is PrinterScanComplete) return s.printers;
    if (s is PrinterTestInProgress) return s.printers;
    if (s is PrinterTestSuccess) return s.printers;
    if (s is PrinterTestError) return s.printers;
    return const [];
  }

  /// Reset to initial state.
  void reset() {
    emit(const SettingsInitial());
  }

  @override
  Future<void> close() async {
    await _cameraService.dispose();
    await _printerService.dispose();
    return super.close();
  }
}
