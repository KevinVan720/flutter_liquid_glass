import 'package:flutter/material.dart';
import 'bezier_utils.dart';

// ============================================================================
// NORMALIZATION UTILITIES
// ============================================================================

/// Normalize point to [-1, 1] coordinate space while preserving centering
Offset normalizePoint(Offset point, Rect bounds) {
  // Since the point is already transformed to be centered in bounds,
  // we just need to normalize to [-1,1] relative to the bounds center
  final normalizedX = (point.dx - bounds.center.dx) / (bounds.width * 0.5);
  final normalizedY = (point.dy - bounds.center.dy) / (bounds.height * 0.5);

  // Clamp to ensure we stay within valid range for shader
  return Offset(normalizedX.clamp(-0.95, 0.95), normalizedY.clamp(-0.95, 0.95));
}

// ============================================================================
// PATH PROCESSING FUNCTIONS
// ============================================================================

/// Process path segments for character contours in connected quadratic format
List<Offset> processCharacterPathSegment(
  List<Offset> pathSegment,
  bool isFirstSegment,
  Rect bounds,
) {
  final points = <Offset>[];

  if (pathSegment.length == 4) {
    // Cubic Bézier curve - convert to quadratic segments
    final quadraticSegments = convertCubicToQuadratic(
      pathSegment[0],
      pathSegment[1],
      pathSegment[2],
      pathSegment[3],
    );

    for (int i = 0; i < quadraticSegments.length; i++) {
      final segment = quadraticSegments[i];
      if (isFirstSegment && i == 0) {
        // For the very first segment, add all 3 points
        points.addAll(segment.map((p) => normalizePoint(p, bounds)));
      } else {
        // For other segments, skip the start point (it's shared)
        points.addAll(segment.skip(1).map((p) => normalizePoint(p, bounds)));
      }
    }
  } else if (pathSegment.length == 3) {
    // Quadratic Bézier curve - use directly
    if (isFirstSegment) {
      // For the first segment, add all 3 points
      points.addAll(pathSegment.map((p) => normalizePoint(p, bounds)));
    } else {
      // For other segments, skip the start point (it's shared)
      points.addAll(pathSegment.skip(1).map((p) => normalizePoint(p, bounds)));
    }
  } else if (pathSegment.length == 2) {
    // Linear segment - convert to quadratic
    final quadraticPoints = convertLinearToQuadratic(
      pathSegment[0],
      pathSegment[1],
    );
    if (isFirstSegment) {
      // For the first segment, add all 3 points
      points.addAll(quadraticPoints.map((p) => normalizePoint(p, bounds)));
    } else {
      // For other segments, skip the start point (it's shared)
      points.addAll(
        quadraticPoints.skip(1).map((p) => normalizePoint(p, bounds)),
      );
    }
  }

  return points;
}

/// Ensure contour follows connected quadratic format with even number of points
List<Offset> ensureConnectedFormat(List<Offset> contour) {
  if (contour.isEmpty) return contour;

  List<Offset> result = List.from(contour);

  // For connected quadratic curves, we need an even number of points
  // Each pair represents: control_point, end_point (except first point which is start)

  // If we have an odd number of points, we need to add a closing segment
  if (result.length % 2 == 1 && result.length >= 3) {
    // Add a control point to create a smooth closing curve back to start
    final lastPoint = result.last;
    final firstPoint = result.first;

    // Create a control point that creates a smooth curve back to start
    final controlPoint = Offset(
      (lastPoint.dx + firstPoint.dx) * 0.5,
      (lastPoint.dy + firstPoint.dy) * 0.5,
    );
    result.add(controlPoint);
  }

  // Ensure we have at least 4 points for a valid shape (2 curves minimum)
  if (result.length < 4) {
    debugPrint(
      'Warning: Contour has only ${result.length} points, may not render properly',
    );
  }

  debugPrint(
    'Contour processed: ${result.length} points (${(result.length - 1) ~/ 2} curves)',
  );
  return result;
}
