import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/core/utils/result.dart';
import '../../../shared/data/datasources/storage_service.dart';
import '../../../shared/data/models/template.dart';
import '../../../shared/data/services/print_channel.dart';
import '../../app/bloc/app_cubit.dart';
import '../../startup/data/repositories/startup_repository.dart';
import '../data/services/camera_test_service.dart';
import '../data/services/printer_test_service.dart';
import 'settings_state.dart';

/// Settings Cubit — handles camera test, printer management, and template sync.
///
/// Camera always uses front camera at max resolution (no user config).
/// Printer list is retained across state transitions so scan results
/// are never lost when camera states change.
class SettingsCubit extends Cubit<SettingsState> {
  final CameraTestService _cameraService;
  final PrinterTestService _printerService;
  final StorageService _storageService;
  final StartupRepository _startupRepository;
  final AppCubit _appCubit;

  SettingsCubit({
    required CameraTestService cameraService,
    required PrinterTestService printerService,
    required StorageService storageService,
    required StartupRepository startupRepository,
    required AppCubit appCubit,
  })  : _cameraService = cameraService,
        _printerService = printerService,
        _storageService = storageService,
        _startupRepository = startupRepository,
        _appCubit = appCubit,
        super(const SettingsInitial());

  /// The camera controller for preview widget access.
  CameraController? get cameraController => _cameraService.controller;

  /// The currently saved default printer (null if none saved).
  PrinterInfo? get savedPrinter {
    if (!_storageService.hasDefaultPrinter) return null;
    return PrinterInfo(
      name: _storageService.defaultPrinterName ?? '',
      address: _storageService.defaultPrinterMac ?? '',
      connectionType: PrinterConnectionType.fromKey(
        _storageService.defaultPrinterConnectionType,
      ),
    );
  }

  // ─── Camera Test ──────────────────────────────────────────────

  /// Start camera test — front camera, max resolution.
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
      final printers = await _printerService.scanBluetoothPrinters();
      emit(PrinterScanComplete(printers: printers));
    } on Exception catch (e) {
      emit(PrinterTestError(
        message: 'Scan gagal: $e',
        printer: savedPrinter ?? const PrinterInfo(name: '', address: ''),
      ));
    }
  }

  /// Scan for USB printers connected via OTG.
  Future<void> scanUsbPrinters() async {
    emit(const PrinterScanInProgress());

    try {
      final printers = await _printerService.scanUsbPrinters();
      emit(PrinterScanComplete(printers: printers));
    } on Exception catch (e) {
      emit(PrinterTestError(
        message: 'Scan USB gagal: $e',
        printer: savedPrinter ?? const PrinterInfo(name: '', address: ''),
      ));
    }
  }

  /// Select a printer — auto-saves as default.
  Future<void> selectPrinter(PrinterInfo printer) async {
    await _storageService.setDefaultPrinter(
      name: printer.name,
      mac: printer.address,
      connectionType: printer.connectionType.key,
    );
    emit(PrinterSaved(printer: printer));
  }

  /// Perform a test print on the saved printer.
  Future<void> testPrint(PrinterInfo printer) async {
    emit(PrinterTestInProgress(printer: printer));

    try {
      await _printerService.testPrint(printer);
      emit(PrinterTestSuccess(printer: printer));
    } on Exception catch (e) {
      emit(PrinterTestError(message: 'Test print gagal: $e', printer: printer));
    }
  }

  /// Clear saved default printer and reset printer section.
  Future<void> clearDefaultPrinter() async {
    await _storageService.clearDefaultPrinter();
    emit(const SettingsInitial());
  }

  // ─── Template Sync ───────────────────────────────────────────

  /// Sync templates from backend and update AppCubit.
  Future<void> syncTemplates() async {
    emit(const TemplateSyncInProgress());

    final result = await _startupRepository.syncTemplates();

    switch (result) {
      case Ok<List<Template>>(:final value):
        _appCubit.onStartupComplete(templates: value);
        emit(TemplateSyncSuccess(count: value.length));
      case Error(:final error):
        emit(TemplateSyncError(message: error.toString()));
    }
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
