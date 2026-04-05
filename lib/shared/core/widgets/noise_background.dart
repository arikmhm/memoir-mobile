import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Subtle grain/noise texture overlay.
///
/// Generates a small tiled noise texture once, then paints it across the
/// full widget area via [ImageShader] with [TileMode.repeated].
/// Wrap in [RepaintBoundary] to avoid unnecessary repaints.
class NoiseBackground extends StatefulWidget {
  /// Opacity of each noise dot (0–255). Lower = more subtle.
  final int intensity;

  const NoiseBackground({super.key, this.intensity = 18});

  @override
  State<NoiseBackground> createState() => _NoiseBackgroundState();
}

class _NoiseBackgroundState extends State<NoiseBackground> {
  ui.Image? _noiseImage;

  @override
  void initState() {
    super.initState();
    _generateNoise();
  }

  void _generateNoise() {
    const size = 128;
    final rng = math.Random(42);
    final maxAlpha = widget.intensity.clamp(0, 255);
    final pixels = List<int>.generate(
      size * size * 4,
      (i) {
        if (i % 4 == 3) {
          return rng.nextInt(maxAlpha + 1);
        }
        return rng.nextInt(2) == 0 ? 0 : 255;
      },
    );

    ui.decodeImageFromPixels(
      Uint8List.fromList(pixels),
      size,
      size,
      ui.PixelFormat.rgba8888,
      (image) {
        if (mounted) setState(() => _noiseImage = image);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_noiseImage == null) return const SizedBox.shrink();
    return CustomPaint(painter: _NoisePainter(_noiseImage!));
  }
}

class _NoisePainter extends CustomPainter {
  final ui.Image noiseImage;

  _NoisePainter(this.noiseImage);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = ImageShader(
        noiseImage,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_NoisePainter oldDelegate) =>
      oldDelegate.noiseImage != noiseImage;
}
