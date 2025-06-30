import 'dart:ui';

// ============================================================================
// BÉZIER CURVE CONVERSION FUNCTIONS
// ============================================================================

// Linear interpolation between two points
Offset lerp(Offset a, Offset b, double t) {
  return Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
}

// Convert linear segment to quadratic Bézier
List<Offset> convertLinearToQuadratic(Offset startPoint, Offset endPoint) {
  final controlPoint = Offset(
    (startPoint.dx + endPoint.dx) * 0.5,
    (startPoint.dy + endPoint.dy) * 0.5,
  );
  return [startPoint, controlPoint, endPoint];
}

// Subdivide cubic Bézier at parameter t using De Casteljau's algorithm
List<Offset> subdivideCubicAt(
  Offset p0,
  Offset p1,
  Offset p2,
  Offset p3,
  double t,
) {
  final q0 = lerp(p0, p1, t);
  final q1 = lerp(p1, p2, t);
  final q2 = lerp(p2, p3, t);

  final r0 = lerp(q0, q1, t);
  final r1 = lerp(q1, q2, t);

  final s = lerp(r0, r1, t);

  return [p0, q0, r0, s, r1, q2, p3];
}

// Approximate a cubic Bézier with a quadratic Bézier using midpoint method
List<Offset> cubicToQuadraticApprox(
  Offset p0,
  Offset p1,
  Offset p2,
  Offset p3,
) {
  final controlPoint = Offset(
    (3 * p1.dx + 3 * p2.dx - p0.dx - p3.dx) / 4,
    (3 * p1.dy + 3 * p2.dy - p0.dy - p3.dy) / 4,
  );
  return [p0, controlPoint, p3];
}

// Convert a cubic Bézier curve to quadratic segments
List<List<Offset>> convertCubicToQuadratic(
  Offset p0,
  Offset p1,
  Offset p2,
  Offset p3,
) {
  // Split cubic at t=0.5 for better approximation
  final mid = subdivideCubicAt(p0, p1, p2, p3, 0.5);

  // Convert each half to quadratic
  final quad1 = cubicToQuadraticApprox(mid[0], mid[1], mid[2], mid[3]);
  final quad2 = cubicToQuadraticApprox(mid[3], mid[4], mid[5], mid[6]);

  return [quad1, quad2];
}
