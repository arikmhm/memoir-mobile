import 'package:camera/camera.dart';

/// Service wrapper for the camera plugin.
///
/// Provides camera initialization, controller access, and cleanup
/// for the device diagnostic camera test.
///
/// Per PRD-05 FEAT-MR-10: Validate camera access and preview.
class CameraTestService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  /// Whether the camera is currently initialized.
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// The current camera controller (for preview widget).
  CameraController? get controller => _controller;

  /// Available cameras on the device.
  List<CameraDescription> get cameras => _cameras;

  /// Initialize the camera.
  ///
  /// Discovers available cameras, then initializes the first rear camera
  /// (or first available) at medium resolution.
  Future<void> initialize() async {
    _cameras = await availableCameras();

    if (_cameras.isEmpty) {
      throw CameraException(
        'NoCameraAvailable',
        'Tidak ada kamera yang tersedia di device ini.',
      );
    }

    // Prefer rear camera (default for photobooth), fallback to first available.
    final selected = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      selected,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();
  }

  /// Dispose the camera controller and free resources.
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
