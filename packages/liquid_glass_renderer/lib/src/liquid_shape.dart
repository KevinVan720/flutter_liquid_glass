import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// Represents a shape that can be used by a [LiquidGlass] widget.
sealed class LiquidShape extends OutlinedBorder with EquatableMixin {
  const LiquidShape({super.side = BorderSide.none});

  @protected
  OutlinedBorder get _equivalentOutlinedBorder;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _equivalentOutlinedBorder.getInnerPath(
      rect,
      textDirection: textDirection,
    );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _equivalentOutlinedBorder.getOuterPath(
      rect,
      textDirection: textDirection,
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    _equivalentOutlinedBorder.paint(canvas, rect, textDirection: textDirection);
  }

  @override
  List<Object?> get props => [side];
}

/// Represents a squircle shape that can be used by a [LiquidGlass] widget.
///
/// Works like a [RoundedSuperellipseBorder].
class LiquidRoundedSuperellipse extends LiquidShape {
  /// Creates a new [LiquidRoundedSuperellipse] with the given [borderRadius].
  const LiquidRoundedSuperellipse({
    required this.borderRadius,
    super.side = BorderSide.none,
  });

  /// The radius of the squircle.
  ///
  /// This is the radius of the corners of the squircle.
  final Radius borderRadius;

  @override
  OutlinedBorder get _equivalentOutlinedBorder => RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(borderRadius),
        side: side,
      );

  @override
  LiquidRoundedSuperellipse copyWith({
    BorderSide? side,
    Radius? borderRadius,
  }) {
    return LiquidRoundedSuperellipse(
      side: side ?? this.side,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return LiquidRoundedSuperellipse(
      borderRadius: borderRadius * t,
      side: side.scale(t),
    );
  }

  @override
  List<Object?> get props => [...super.props, borderRadius];
}

/// Represents an ellipse shape that can be used by a [LiquidGlass] widget.
///
/// Works like an [OvalBorder].
class LiquidOval extends LiquidShape {
  /// Creates a new [LiquidOval] with the given [side].
  const LiquidOval({super.side = BorderSide.none});

  @override
  OutlinedBorder get _equivalentOutlinedBorder => const OvalBorder();

  @override
  OutlinedBorder copyWith({BorderSide? side}) {
    return LiquidOval(
      side: side ?? this.side,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return LiquidOval(
      side: side.scale(t),
    );
  }
}

/// Represents a rounded rectangle shape that can be used by a [LiquidGlass]
/// widget.
///
/// Works like a [RoundedRectangleBorder].
class LiquidRoundedRectangle extends LiquidShape {
  /// Creates a new [LiquidRoundedRectangle] with the given [borderRadius].
  const LiquidRoundedRectangle({
    required this.borderRadius,
    super.side = BorderSide.none,
  });

  /// The radius of the rounded rectangle.
  ///
  /// This is the radius of the corners of the rounded rectangle.
  final Radius borderRadius;

  @override
  OutlinedBorder get _equivalentOutlinedBorder => RoundedRectangleBorder(
        borderRadius: BorderRadius.all(borderRadius),
        side: side,
      );

  @override
  LiquidRoundedRectangle copyWith({
    BorderSide? side,
    Radius? borderRadius,
  }) {
    return LiquidRoundedRectangle(
      side: side ?? this.side,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return LiquidRoundedRectangle(
      borderRadius: borderRadius * t,
      side: side.scale(t),
    );
  }

  @override
  List<Object?> get props => [...super.props, borderRadius];
}

/// Represents a custom bezier shape that can be used by a [LiquidGlass] widget.
///
/// This shape is defined by a flat list of control points that form quadratic
/// bezier curves. Every 3 consecutive points form a quadratic bezier curve:
/// [startPoint, controlPoint, endPoint, startPoint2, controlPoint2, endPoint2, ...]
///
/// The points should be normalized (0.0 to 1.0) and will be scaled to fit
/// within the widget bounds.
class BezierShape extends LiquidShape {
  /// Creates a [BezierShape]. You can pass either a flat list of control points
  /// (legacy API) or the new, recommended `contours` parameter which allows
  /// multiple closed paths.
  ///
  /// Each contour is a list of points that form quadratic Bézier curves in
  /// groups of three: `[start, control, end, start2, control2, end2, ...]`.
  /// All points must be normalised to the unit square.
  BezierShape({
    List<Offset>? controlPoints,
    List<List<Offset>>? contours,
    super.side = BorderSide.none,
  })  : assert(controlPoints != null || contours != null,
            'Either controlPoints or contours must be provided'),
        // Wrap legacy flat list into a single-contour list for internal use.
        contours = contours ?? [controlPoints!];

  /// All contours that make up this shape. Immutable after construction.
  final List<List<Offset>> contours;

  @override
  OutlinedBorder get _equivalentOutlinedBorder => const OvalBorder();

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _createBezierPath(rect);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _createBezierPath(rect);
  }

  Path _createBezierPath(Rect rect) {
    final path = Path();

    if (contours.isEmpty) return path;

    final scaleX = rect.width;
    final scaleY = rect.height;
    final offsetX = rect.left;
    final offsetY = rect.top;

    for (final contour in contours) {
      if (contour.length < 3) continue;

      // Move to first point of contour
      final start = contour.first;
      path.moveTo(offsetX + start.dx * scaleX, offsetY + start.dy * scaleY);

      // iterate groups (skip first)
      for (int i = 1; i < contour.length - 1; i += 2) {
        if (i + 1 >= contour.length) break;
        final control = contour[i];
        final end = contour[i + 1];
        path.quadraticBezierTo(
          offsetX + control.dx * scaleX,
          offsetY + control.dy * scaleY,
          offsetX + end.dx * scaleX,
          offsetY + end.dy * scaleY,
        );
      }

      path.close();
    }

    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side == BorderSide.none) {
      return;
    }

    final paint = Paint()
      ..color = side.color
      ..strokeWidth = side.width
      ..style = PaintingStyle.stroke;

    canvas.drawPath(_createBezierPath(rect), paint);
  }

  @override
  BezierShape copyWith({
    BorderSide? side,
    List<List<Offset>>? contours,
    List<Offset>? controlPoints, // legacy
  }) {
    return BezierShape(
      side: side ?? this.side,
      contours: contours ?? this.contours,
      controlPoints: controlPoints,
    );
  }

  @override
  ShapeBorder scale(double t) {
    final scaled = contours
        .map((c) => c.map((p) => p * t).toList())
        .toList(growable: false);
    return BezierShape(
      contours: scaled,
      side: side.scale(t),
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        contours,
      ];
}
