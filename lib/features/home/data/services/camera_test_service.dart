import 'package:camera/camera.dart';

/// Service wrapper for the camera plugin.
///
/// Always uses front camera (selfie/mirror) at the highest available
/// resolution. No user-configurable direction or resolution.
class CameraTestService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  /// Whether the camera is currently initialized.
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// The current camera controller (for preview widget).
  CameraController? get controller => _controller;

  /// Available cameras on the device.
  List<CameraDescription> get cameras => _cameras;

  /// Initialize the front camera at max resolution.
  ///
  /// Discovers available cameras, selects front camera (fallback to first),
  /// and uses [ResolutionPreset.max] for best quality.
  Future<void> initialize() async {
    // Dispose previous controller if any.
    await dispose();

    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
    }

    if (_cameras.isEmpty) {
      throw CameraException(
        'NoCameraAvailable',
        'Tidak ada kamera yang tersedia di device ini.',
      );
    }

    final selected = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      selected,
      ResolutionPreset.max,
      enableAudio: false,
    );

    await _controller!.initialize();
  }

  /// Capture a still image and return its file path.
  ///
  /// Camera must be initialized first via [initialize]. The plugin writes
  /// the image to a temporary cache file and returns its path.
  Future<String> takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw CameraException(
        'CameraNotInitialized',
        'Kamera belum siap. Aktifkan kamera terlebih dahulu.',
      );
    }
    if (controller.value.isTakingPicture) {
      throw CameraException(
        'AlreadyCapturing',
        'Kamera sedang memproses pengambilan gambar.',
      );
    }
    final file = await controller.takePicture();
    return file.path;
  }

  /// Dispose the camera controller and free resources.
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
