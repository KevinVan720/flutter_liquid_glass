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
