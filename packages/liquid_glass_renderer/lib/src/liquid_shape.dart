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
  /// Creates a new [BezierShape] with the given control points.
  ///
  /// The [controlPoints] should contain points in groups of 3, where each group
  /// represents a quadratic bezier curve: [start, control, end].
  /// Points should be normalized between 0.0 and 1.0.
  const BezierShape({
    required this.controlPoints,
    super.side = BorderSide.none,
  });

  /// The list of control points forming quadratic bezier curves.
  ///
  /// Every 3 consecutive points form a quadratic bezier curve.
  /// Points should be normalized (0.0 to 1.0).
  final List<Offset> controlPoints;

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

    if (controlPoints.isEmpty) {
      return path;
    }

    // Ensure we have at least 3 points for a quadratic bezier curve
    if (controlPoints.length < 3) {
      return path;
    }

    // Scale the points to fit within the rect
    final scaleX = rect.width;
    final scaleY = rect.height;
    final offsetX = rect.left;
    final offsetY = rect.top;

    // Move to the starting point (first control point, scaled to rect)
    final scaledStartPoint = Offset(
      offsetX + controlPoints[0].dx * scaleX,
      offsetY + controlPoints[0].dy * scaleY,
    );
    path.moveTo(scaledStartPoint.dx, scaledStartPoint.dy);

    // Process control points in groups of 3 (start, control, end)
    // Skip the first point since we already moved to it
    for (int i = 1; i < controlPoints.length - 1; i += 2) {
      // Check if we have enough points for a complete bezier curve
      if (i + 1 >= controlPoints.length) break;

      final controlPoint = Offset(
        offsetX + controlPoints[i].dx * scaleX,
        offsetY + controlPoints[i].dy * scaleY,
      );
      final endPoint = Offset(
        offsetX + controlPoints[i + 1].dx * scaleX,
        offsetY + controlPoints[i + 1].dy * scaleY,
      );

      path.quadraticBezierTo(
        controlPoint.dx,
        controlPoint.dy,
        endPoint.dx,
        endPoint.dy,
      );
    }

    path.close();

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
    List<Offset>? controlPoints,
    bool? closePath,
  }) {
    return BezierShape(
      side: side ?? this.side,
      controlPoints: controlPoints ?? this.controlPoints,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return BezierShape(
      controlPoints: controlPoints.map((point) => point * t).toList(),
      side: side.scale(t),
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        controlPoints,
      ];
}
