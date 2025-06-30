import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
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
Future<ui.Image> createControlPointsTextureFromContours(
  List<List<Offset>> contours,
) async {
  final totalPoints =
      contours.fold<int>(0, (sum, c) => sum + c.length) +
      (contours.length - 1); // + separators

  final width = totalPoints;
  const height = 1;
  final pixels = Uint8List(width * 4);

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
      final pxIdx = pixelCursor * 4;

      // Normalise from [-1,1] to [0,1]
      final x = (point.dx + 1.0) * 0.5;
      final y = (point.dy + 1.0) * 0.5;

      pixels[pxIdx] = (x * 255).round().clamp(0, 255);
      pixels[pxIdx + 1] = (y * 255).round().clamp(0, 255);
      pixels[pxIdx + 2] = pi == 0
          ? (orientationEncoded * 255).round()
          : 0; // orientation only on first point
      pixels[pxIdx + 3] = 255; // alpha

      pixelCursor++;
    }

    // Insert separator (except after last contour)
    if (ci < contours.length - 1) {
      final pxIdx = pixelCursor * 4;
      pixels[pxIdx] = 0;
      pixels[pxIdx + 1] = 0;
      pixels[pxIdx + 2] = 255; // blue = 1.0 ➜ separator
      pixels[pxIdx + 3] = 255;
      pixelCursor++;
    }
  }

  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );

  return completer.future;
}
