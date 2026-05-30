import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/core/utils/result.dart';
import '../../../shared/data/datasources/storage_service.dart';
import '../../../shared/data/models/template.dart';
import '../../../shared/data/services/print_channel.dart';
import '../../app/bloc/app_cubit.dart';
import '../../session/data/services/composite_render_service.dart';
import '../../startup/data/repositories/startup_repository.dart';
import '../data/services/camera_test_service.dart';
import '../data/services/printer_test_service.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final CameraTestService _cameraService;
  final PrinterTestService _printerService;
  final CompositeRenderService _renderService;
  final StorageService _storageService;
  final StartupRepository _startupRepository;
  final AppCubit _appCubit;

  /// Captured photo path retained between rerenders. Set after a successful
  /// capture; cleared on [stopImageProcessingTest].
  String? _capturedPhotoPath;

  /// Monotonic counter to ignore stale render results when a newer render
  /// has been requested before the previous one finished.
  int _previewRequestId = 0;

  HomeCubit({
    required CameraTestService cameraService,
    required PrinterTestService printerService,
    required CompositeRenderService renderService,
    required StorageService storageService,
    required StartupRepository startupRepository,
    required AppCubit appCubit,
  })  : _cameraService = cameraService,
        _printerService = printerService,
        _renderService = renderService,
        _storageService = storageService,
        _startupRepository = startupRepository,
        _appCubit = appCubit,
        super(const HomeInitial());

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
    emit(const HomeInitial());
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
    emit(const HomeInitial());
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
    emit(const HomeInitial());
  }

  // ─── Image Processing Test ───────────────────────────────────

  /// Camera controller exposed for the live preview widget.
  CameraController? get imageProcessingController => _cameraService.controller;

  /// Whether a captured photo is available for re-rendering.
  bool get hasCapturedPreviewPhoto => _capturedPhotoPath != null;

  /// Initialize the camera for image-processing live tuning.
  Future<void> startImageProcessingTest() async {
    emit(const ImageProcessingInitializing());
    try {
      await _cameraService.initialize();
      emit(const ImageProcessingCameraReady());
    } on CameraException catch (e) {
      emit(ImageProcessingError(
        message: e.description ?? 'Gagal mengakses kamera.',
      ));
    } on Exception catch (e) {
      emit(ImageProcessingError(message: 'Kamera error: $e'));
    }
  }

  /// Capture a still and immediately render its preview with the given
  /// settings. After this completes the camera is disposed — the captured
  /// file is retained for re-rendering on slider changes.
  Future<void> captureForImageProcessing(ProcessingSettings settings) async {
    emit(const ImageProcessingCapturing());
    try {
      final path = await _cameraService.takePicture();
      _capturedPhotoPath = path;
      // Camera is no longer needed once we have the still — free it so
      // the preview area can take over the screen and resources are
      // released for the render isolate.
      await _cameraService.dispose();
      await _renderPreview(settings: settings);
    } on CameraException catch (e) {
      emit(ImageProcessingError(
        message: e.description ?? 'Gagal mengambil foto.',
      ));
    } on Exception catch (e) {
      emit(ImageProcessingError(message: 'Capture error: $e'));
    }
  }

  /// Re-render the existing captured photo with new settings.
  ///
  /// Safe to call from a debounced slider listener. If a newer render is
  /// requested before this one finishes, the stale result is discarded.
  Future<void> rerenderPreview(ProcessingSettings settings) async {
    if (_capturedPhotoPath == null) return;
    await _renderPreview(settings: settings);
  }

  Future<void> _renderPreview({required ProcessingSettings settings}) async {
    final path = _capturedPhotoPath;
    if (path == null) return;

    final myId = ++_previewRequestId;

    // Keep the previous bytes visible so the UI doesn't flash blank
    // while the new render is in flight.
    Uint8List? previousBytes;
    final current = state;
    if (current is ImageProcessingPreviewReady) {
      previousBytes = current.previewBytes;
    } else if (current is ImageProcessingPreviewRendering) {
      previousBytes = current.previousBytes;
    }

    emit(ImageProcessingPreviewRendering(
      photoPath: path,
      previousBytes: previousBytes,
    ));

    try {
      final bytes = await _renderService.previewSinglePhoto(
        photoPath: path,
        settings: settings,
      );
      // Discard result if a newer render was requested.
      if (myId != _previewRequestId) return;
      emit(ImageProcessingPreviewReady(
        photoPath: path,
        previewBytes: bytes,
      ));
    } on Exception catch (e) {
      if (myId != _previewRequestId) return;
      emit(ImageProcessingError(message: 'Render gagal: $e'));
    }
  }

  /// Discard captured photo and dispose camera. Returns to initial state.
  Future<void> stopImageProcessingTest() async {
    _capturedPhotoPath = null;
    _previewRequestId++; // invalidate any in-flight render
    await _cameraService.dispose();
    emit(const HomeInitial());
  }

  /// Send the captured photo to the saved printer using current [settings].
  ///
  /// Renders ESC/POS bands via the same pipeline as a real session and
  /// pushes them through the native channel. Throws on any failure
  /// (no printer configured, render error, connection error, write error).
  /// The caller is responsible for catching and showing a user message.
  Future<void> printPreviewTest(ProcessingSettings settings) async {
    final path = _capturedPhotoPath;
    if (path == null) {
      throw Exception('Belum ada foto. Ambil foto terlebih dahulu.');
    }
    final printer = savedPrinter;
    if (printer == null) {
      throw Exception(
        'Belum ada printer default. Atur printer di menu Perangkat.',
      );
    }

    final bands = await _renderService.printPreviewPhoto(
      photoPath: path,
      settings: settings,
    );
    await _printerService.printBands(printer, bands);
  }

  @override
  Future<void> close() async {
    await _cameraService.dispose();
    await _printerService.dispose();
    return super.close();
  }
}
