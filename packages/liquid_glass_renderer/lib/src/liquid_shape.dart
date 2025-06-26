import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:morphable_shape/morphable_shape.dart';

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

/// Represents an arbitrary morphable shape that can be used by a [LiquidGlass] widget.
///
/// This shape uses control points generated from a [morphable_shape] package's
/// [OutlinedShapeBorder] to create liquid glass effects for complex shapes.
class MorphableShape extends LiquidShape {
  /// Creates a new [MorphableShape] with the given [morphableShapeBorder].
  const MorphableShape({
    required this.morphableShapeBorder,
  });

  /// The morphable shape border that defines the shape.
  final MorphableShapeBorder morphableShapeBorder;

  @override
  OutlinedBorder get _equivalentOutlinedBorder => const OvalBorder();

  @override
  ShapeBorder scale(double t) {
    return MorphableShape(
      morphableShapeBorder: morphableShapeBorder,
    );
  }

  @override
  OutlinedBorder copyWith({BorderSide? side}) {
    return MorphableShape(
      morphableShapeBorder: morphableShapeBorder,
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return morphableShapeBorder.getInnerPath(
      rect,
      textDirection: textDirection,
    );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return morphableShapeBorder.getOuterPath(
      rect,
      textDirection: textDirection,
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    morphableShapeBorder.paint(canvas, rect, textDirection: textDirection);
  }

  @override
  List<Object?> get props => [morphableShapeBorder];
}

/// Represents a quadratic bezier curve segment with start, control, and end points.
class BezierSegment extends Equatable {
  /// Creates a new [BezierSegment] with the given start, control, and end points.
  const BezierSegment({
    required this.startPoint,
    required this.controlPoint,
    required this.endPoint,
  });

  /// The starting point for the quadratic bezier curve.
  final Offset startPoint;

  /// The control point for the quadratic bezier curve.
  final Offset controlPoint;

  /// The end point for the quadratic bezier curve.
  final Offset endPoint;

  @override
  List<Object?> get props => [startPoint, controlPoint, endPoint];
}

/// Represents a custom bezier shape that can be used by a [LiquidGlass] widget.
///
/// This shape is defined by a series of quadratic bezier curve segments.
/// Each segment contains its own start point, control point, and end point.
class BezierShape extends LiquidShape {
  /// Creates a new [BezierShape] with the given bezier segments.
  const BezierShape({
    required this.segments,
    super.side = BorderSide.none,
  });

  /// The list of quadratic bezier curve segments.
  final List<BezierSegment> segments;

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

    if (segments.isEmpty) {
      return path;
    }

    // Scale the points to fit within the rect
    final scaleX = rect.width;
    final scaleY = rect.height;
    final offsetX = rect.left;
    final offsetY = rect.top;

    // Move to the starting point of the first segment (scaled to rect)
    final firstSegment = segments.first;
    final scaledStartPoint = Offset(
      offsetX + firstSegment.startPoint.dx * scaleX,
      offsetY + firstSegment.startPoint.dy * scaleY,
    );
    path.moveTo(scaledStartPoint.dx, scaledStartPoint.dy);

    // Add each quadratic bezier curve segment
    for (final segment in segments) {
      final controlPoint = Offset(
        offsetX + segment.controlPoint.dx * scaleX,
        offsetY + segment.controlPoint.dy * scaleY,
      );
      final endPoint = Offset(
        offsetX + segment.endPoint.dx * scaleX,
        offsetY + segment.endPoint.dy * scaleY,
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
    List<BezierSegment>? segments,
    bool? closePath,
  }) {
    return BezierShape(
      side: side ?? this.side,
      segments: segments ?? this.segments,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return BezierShape(
      segments: segments
          .map((segment) => BezierSegment(
                startPoint: segment.startPoint * t,
                controlPoint: segment.controlPoint * t,
                endPoint: segment.endPoint * t,
              ))
          .toList(),
      side: side.scale(t),
    );
  }

  @override
  List<Object?> get props => [...super.props, segments];
}
