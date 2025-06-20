// ignore_for_file: dead_code, deprecated_member_use_from_same_package

import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/src/liquid_shape.dart';
import 'package:meta/meta.dart';
import 'package:morphable_shape/morphable_shape.dart';

@internal
enum RawShapeType {
  none,
  squircle,
  ellipse,
  roundedRectangle,
  morphable,
}

/// Cached data for morphable shapes to avoid recomputation
@internal
class MorphableShapeCache with EquatableMixin {
  const MorphableShapeCache({
    required this.shapeBorder,
    required this.rect,
    required this.controlPoints,
    this.texture,
  });

  final MorphableShapeBorder shapeBorder;
  final Rect rect;
  final List<Offset> controlPoints;
  final ui.Image? texture;

  /// Create a copy with updated texture
  MorphableShapeCache copyWith({
    ui.Image? texture,
  }) {
    return MorphableShapeCache(
      shapeBorder: shapeBorder,
      rect: rect,
      controlPoints: controlPoints,
      texture: texture ?? this.texture,
    );
  }

  @override
  List<Object?> get props => [shapeBorder, rect, controlPoints, texture];
}

@internal
class RawShape with EquatableMixin {
  const RawShape({
    required this.type,
    required this.center,
    required this.size,
    required this.cornerRadius,
    this.morphableCache,
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
      case MorphableShape():
        // For morphable shapes, we'll handle caching separately
        return RawShape(
          type: RawShapeType.morphable,
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
  final MorphableShapeCache? morphableCache;

  Offset get topLeft =>
      Offset(center.dx - size.width / 2, center.dy - size.height / 2);

  Rect get rect => topLeft & size;

  /// Create a copy with morphable cache
  RawShape copyWith({
    MorphableShapeCache? morphableCache,
  }) {
    return RawShape(
      type: type,
      center: center,
      size: size,
      cornerRadius: cornerRadius,
      morphableCache: morphableCache,
    );
  }

  @override
  List<Object?> get props => [type, center, size, cornerRadius, morphableCache];
}

void _assertSameRadius(Radius borderRadius) {
  assert(
    borderRadius.x == borderRadius.y,
    'The radius must have equal x and y values for a liquid glass shape.',
  );
}
