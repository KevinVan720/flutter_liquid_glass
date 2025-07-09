import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ============================================================================
// TEXTURE CREATION UTILITIES
// ============================================================================

/// Calculate signed area to determine contour orientation (CCW > 0, CW < 0)
double calculateSignedArea(List<Offset> pts) {
  double area = 0;
  for (int i = 0; i < pts.length; i++) {
    final j = (i + 1) % pts.length;
    area += pts[i].dx * pts[j].dy - pts[j].dx * pts[i].dy;
  }
  return area * 0.5;
}

/// Create texture containing all contours with separators and orientation encoding
ui.Image createControlPointsTextureFromContours(List<List<Offset>> contours) {
  final totalPoints =
      contours.fold<int>(0, (sum, c) => sum + c.length) +
      (contours.length - 1); // + separators

  final width = totalPoints;
  const height = 1;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
  );

  int pixelCursor = 0;

  for (int ci = 0; ci < contours.length; ci++) {
    final contour = contours[ci];

    // Detect orientation automatically
    final orientationSign = calculateSignedArea(contour) >= 0
        ? 1
        : -1; // CCW ➜ +1

    final double orientationEncoded = orientationSign > 0
        ? 0.25
        : 0.75; // encode into blue channel

    for (int pi = 0; pi < contour.length; pi++) {
      final point = contour[pi];

      // Normalise from [-1,1] to [0,1]
      final x = (point.dx + 1.0) * 0.5;
      final y = (point.dy + 1.0) * 0.5;

      final red = (x * 255).round().clamp(0, 255);
      final green = (y * 255).round().clamp(0, 255);
      final blue = pi == 0
          ? (orientationEncoded * 255).round()
          : 0; // orientation only on first point
      final alpha = 255;

      // Draw a 1x1 pixel rectangle with the exact color
      final paint = Paint()
        ..color = Color.fromARGB(alpha, red, green, blue)
        ..style = PaintingStyle.fill;

      canvas.drawRect(Rect.fromLTWH(pixelCursor.toDouble(), 0, 1, 1), paint);

      pixelCursor++;
    }

    // Insert separator (except after last contour)
    if (ci < contours.length - 1) {
      final paint = Paint()
        ..color =
            const Color.fromARGB(255, 0, 0, 255) // blue = 1.0 ➜ separator
        ..style = PaintingStyle.fill;

      canvas.drawRect(Rect.fromLTWH(pixelCursor.toDouble(), 0, 1, 1), paint);
      pixelCursor++;
    }
  }

  final picture = recorder.endRecording();
  return picture.toImageSync(width, height);
}
