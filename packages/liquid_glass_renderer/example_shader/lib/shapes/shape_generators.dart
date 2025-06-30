import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';

// ============================================================================
// SHAPE GENERATORS
// ============================================================================

// ============================================================================
// CIRCULAR CONTOUR GENERATION
// ============================================================================

/// Create circular contour with specified parameters
List<Offset> createCircularContour(
  double radiusX,
  double radiusY,
  int numPoints, {
  bool ccw = true,
  Offset center = Offset.zero,
}) {
  final points = <Offset>[];
  for (int i = 0; i < numPoints; i++) {
    final t = i / numPoints;
    final angle = t * 2 * math.pi;
    // For clockwise, negate the angle
    final actualAngle = ccw ? angle : -angle;
    final x = center.dx + math.cos(actualAngle) * radiusX;
    final y = center.dy + math.sin(actualAngle) * radiusY;
    points.add(Offset(x, y));
  }
  return points;
}

// ============================================================================
// COMPLEX SHAPE GENERATORS
// ============================================================================

/// Generate donut shape with outer and inner circular contours
List<List<Offset>> generateDonutContours() {
  const int outerPoints = 20;
  const int innerPoints = 16;

  final outer = createCircularContour(0.6, 0.6, outerPoints, ccw: true);
  final inner = createCircularContour(0.4, 0.4, innerPoints, ccw: false);

  return [outer, inner];
}

/// Generate gear shape with alternating radii (teeth)
List<Offset> generateGearContour({
  int teeth = 20,
  double innerRadius = 0.55,
  double outerRadius = 0.7,
}) {
  final pts = <Offset>[];
  final toothStep = 2 * math.pi / teeth;
  for (int i = 0; i < teeth; i++) {
    final angleBase = i * toothStep;
    // Outer vertex
    pts.add(
      Offset(
        math.cos(angleBase) * outerRadius,
        math.sin(angleBase) * outerRadius,
      ),
    );
    // Inner vertex halfway to next tooth
    final angleInner = angleBase + toothStep / 2;
    pts.add(
      Offset(
        math.cos(angleInner) * innerRadius,
        math.sin(angleInner) * innerRadius,
      ),
    );
  }
  return pts;
}

/// Generate figure 8 shape: two separate circles side-by-side
List<List<Offset>> generateFigure8Contours() {
  const int ptsPer = 40;
  final left = createCircularContour(
    0.4,
    0.4,
    ptsPer,
    center: const Offset(-0.5, 0),
    ccw: true,
  );
  final right = createCircularContour(
    0.4,
    0.4,
    ptsPer,
    center: const Offset(0.5, 0),
    ccw: true,
  );
  return [left, right];
}

/// Generate clover shape: three small circles arranged in tri-foil pattern
List<List<Offset>> generateCloverContours() {
  const int ptsPer = 30;
  final top = createCircularContour(
    0.35,
    0.35,
    ptsPer,
    center: const Offset(0, 0.5),
    ccw: true,
  );
  final left = createCircularContour(
    0.35,
    0.35,
    ptsPer,
    center: const Offset(-0.45, -0.2),
    ccw: true,
  );
  final right = createCircularContour(
    0.35,
    0.35,
    ptsPer,
    center: const Offset(0.45, -0.2),
    ccw: true,
  );
  return [top, left, right];
}

/// Create fallback control points for a simple circle using connected quadratic Bézier curves
List<Offset> createFallbackControlPoints() {
  // Create a simple circle using connected quadratic Bézier curves
  final points = <Offset>[];

  // Create a circle using 4 connected quadratic Bézier curves (8 points total)
  // Format: P0(start), P1(control), P2(end), P3(control), P4(end), P5(control), P6(end), P7(control)
  // Last curve closes from P6 back to P0 using P7 as control
  const double radius = 0.6;
  final double controlDistance = radius * 4.0 / 3.0 * math.tan(math.pi / 8);

  // Connected quadratic curves for a circle
  points.addAll([
    // First curve: right -> top (P0 -> P1 -> P2)
    Offset(radius, 0), // P0: start point
    Offset(radius, -controlDistance), // P1: control point
    Offset(0, -radius), // P2: end point (shared with next curve)
    // Second curve: top -> left (P2 -> P3 -> P4)
    Offset(-controlDistance, -radius), // P3: control point
    Offset(-radius, 0), // P4: end point (shared with next curve)
    // Third curve: left -> bottom (P4 -> P5 -> P6)
    Offset(-radius, controlDistance), // P5: control point
    Offset(0, radius), // P6: end point (shared with next curve)
    // Fourth curve: bottom -> right (P6 -> P7 -> P0, closes the loop)
    Offset(controlDistance, radius), // P7: control point
  ]);

  return points;
}
