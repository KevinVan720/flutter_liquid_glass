// ignore_for_file: dead_code, deprecated_member_use_from_same_package

import 'dart:ui' as ui;
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/src/liquid_shape.dart';
import 'package:meta/meta.dart';

@internal
enum RawShapeType {
  none,
  squircle,
  ellipse,
  roundedRectangle,
  bezier,
}

/// Cached data for bezier shapes to avoid recomputation
@internal
class BezierShapeCache with EquatableMixin {
  const BezierShapeCache({
    required this.rect,
    required this.scaledControlPoints,
    this.texture,
  });

  final Rect rect;
  final List<Offset> scaledControlPoints;
  final ui.Image? texture;

  /// Create a copy with updated texture
  BezierShapeCache copyWith({
    ui.Image? texture,
  }) {
    return BezierShapeCache(
      rect: rect,
      scaledControlPoints: scaledControlPoints,
      texture: texture ?? this.texture,
    );
  }

  @override
  List<Object?> get props => [rect, scaledControlPoints, texture];
}

@internal
class RawShape with EquatableMixin {
  const RawShape({
    required this.type,
    required this.center,
    required this.size,
    required this.cornerRadius,
    this.bezierCache,
  });

  factory RawShape.fromLiquidGlassShape(
    LiquidShape shape, {
    required Offset center,
    required Size size,
  }) {
    switch (shape) {
      case LiquidRoundedSuperellipse():
        _assertSameRadius(shape.borderRadius);
        return RawShape(
          type: RawShapeType.squircle,
          center: center,
          size: size,
          cornerRadius: shape.borderRadius.x,
        );
      case LiquidOval():
        return RawShape(
          type: RawShapeType.ellipse,
          center: center,
          size: size,
          cornerRadius: 0,
        );
      case LiquidRoundedRectangle():
        _assertSameRadius(shape.borderRadius);
        return RawShape(
          type: RawShapeType.roundedRectangle,
          center: center,
          size: size,
          cornerRadius: shape.borderRadius.x,
        );
      case BezierShape():
        // For bezier shapes, we'll handle caching separately
        return RawShape(
          type: RawShapeType.bezier,
          center: center,
          size: size,
          cornerRadius: 0,
        );
    }
  }

  static const none = RawShape(
    type: RawShapeType.none,
    center: Offset.zero,
    size: Size.zero,
    cornerRadius: 0,
  );

  final RawShapeType type;
  final Offset center;
  final Size size;
  final double cornerRadius;
  final BezierShapeCache? bezierCache;

  Offset get topLeft =>
      Offset(center.dx - size.width / 2, center.dy - size.height / 2);

  Rect get rect => topLeft & size;

  /// Create a copy with bezier cache
  RawShape copyWith({
    BezierShapeCache? bezierCache,
  }) {
    return RawShape(
      type: type,
      center: center,
      size: size,
      cornerRadius: cornerRadius,
      bezierCache: bezierCache,
    );
  }

  @override
  List<Object?> get props => [type, center, size, cornerRadius, bezierCache];
}

void _assertSameRadius(Radius borderRadius) {
  assert(
    borderRadius.x == borderRadius.y,
    'The radius must have equal x and y values for a liquid glass shape.',
  );
}
