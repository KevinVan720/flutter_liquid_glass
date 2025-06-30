import 'package:flutter/material.dart';
import '../utils/bezier_utils.dart';

// ============================================================================
// NORMALIZATION UTILITIES
// ============================================================================

/// Shape bounding rectangle for normalization
const Rect shapeRect = Rect.fromLTWH(0, 0, 400, 300);

/// Normalize point to [-1, 1] coordinate space
Offset normalizePoint(Offset point) {
  final normalizedX =
      (point.dx - shapeRect.center.dx) / (shapeRect.width * 0.5);
  final normalizedY =
      (point.dy - shapeRect.center.dy) / (shapeRect.height * 0.5);
  return Offset(normalizedX.clamp(-1.0, 1.0), normalizedY.clamp(-1.0, 1.0));
}

// ============================================================================
// PATH PROCESSING FUNCTIONS
// ============================================================================

/// Process path segments for character contours in connected quadratic format
List<Offset> processCharacterPathSegment(
  List<Offset> pathSegment,
  bool isFirstSegment,
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
        points.addAll(segment.map(normalizePoint));
      } else {
        // For other segments, skip the start point (it's shared)
        points.addAll(segment.skip(1).map(normalizePoint));
      }
    }
  } else if (pathSegment.length == 3) {
    // Quadratic Bézier curve - use directly
    if (isFirstSegment) {
      // For the first segment, add all 3 points
      points.addAll(pathSegment.map(normalizePoint));
    } else {
      // For other segments, skip the start point (it's shared)
      points.addAll(pathSegment.skip(1).map(normalizePoint));
    }
  } else if (pathSegment.length == 2) {
    // Linear segment - convert to quadratic
    final quadraticPoints = convertLinearToQuadratic(
      pathSegment[0],
      pathSegment[1],
    );
    if (isFirstSegment) {
      // For the first segment, add all 3 points
      points.addAll(quadraticPoints.map(normalizePoint));
    } else {
      // For other segments, skip the start point (it's shared)
      points.addAll(quadraticPoints.skip(1).map(normalizePoint));
    }
  }

  return points;
}

/// Ensure contour follows connected quadratic format with even number of points
List<Offset> ensureConnectedFormat(List<Offset> contour) {
  if (contour.isEmpty) return contour;

  // The contour should already be in connected format from processCharacterPathSegment
  // But let's ensure it's properly closed and has even number of points

  List<Offset> result = List.from(contour);

  // Check if the last point is close to the first point (indicating a closed path)
  if (result.length >= 3) {
    final first = result.first;
    final last = result.last;
    final distance = (last - first).distance;

    // If they're very close, remove the duplicate
    if (distance < 0.01) {
      result.removeLast();
    }
  }

  // For connected quadratic curves, we need an even number of points
  // If we have odd number, add a control point
  if (result.length % 2 == 1 && result.length >= 3) {
    // Add a control point between the last and first point
    final lastPoint = result.last;
    final firstPoint = result.first;
    final controlPoint = Offset(
      (lastPoint.dx + firstPoint.dx) * 0.5,
      (lastPoint.dy + firstPoint.dy) * 0.5,
    );
    result.add(controlPoint);
  }

  return result;
}
