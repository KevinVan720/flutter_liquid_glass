import 'package:flutter/material.dart';
import 'package:morphable_shape/morphable_shape.dart';

import '../utils/path_processing.dart';
import 'shape_generators.dart';

// ============================================================================
// MORPHABLE SHAPE UTILITIES
// ============================================================================

/// Create a ShapeBorder based on the selected shape type
ShapeBorder createShapeBorder(String selectedShape) {
  switch (selectedShape) {
    case 'Rounded Rectangle':
      return RectangleShapeBorder(
        borderRadius: DynamicBorderRadius.all(
          DynamicRadius.circular(60.toPXLength),
        ),
      );
    case 'Circle':
      return const CircleShapeBorder();
    case 'Star':
      return StarShapeBorder(
        corners: 5,
        inset: 50.toPercentLength,
        cornerRadius: 20.toPXLength,
        cornerStyle: CornerStyle.rounded,
      );
    case 'Heart':
    case 'Morphable Shape':
      return PolygonShapeBorder(
        sides: selectedShape == 'Heart' ? 8 : 6,
        cornerRadius: 30.toPercentLength,
        cornerStyle: CornerStyle.rounded,
      );
    default:
      return RectangleShapeBorder(
        borderRadius: DynamicBorderRadius.all(
          DynamicRadius.circular(40.toPXLength),
        ),
      );
  }
}

/// Extract control points from an OutlinedShapeBorder
List<Offset> extractControlPointsFromOutlinedShapeBorder(
  OutlinedShapeBorder shapeBorder,
) {
  try {
    final dynamicPath = shapeBorder.generateInnerDynamicPath(shapeRect);
    return extractControlPointsFromDynamicPath(dynamicPath);
  } catch (e) {
    debugPrint('Error extracting control points: $e');
    return createFallbackControlPoints();
  }
}

/// Extract control points from a DynamicPath
List<Offset> extractControlPointsFromDynamicPath(DynamicPath dynamicPath) {
  final controlPoints = <Offset>[];

  try {
    for (int i = 0; i < dynamicPath.nodes.length; i++) {
      final pathSegment = dynamicPath.getNextPathControlPointsAt(i);
      final processedPoints = processCharacterPathSegment(pathSegment, i == 0);
      controlPoints.addAll(processedPoints);
    }

    // For connected curves, we need an odd number of points: 2*n + 1
    // where n is the number of curves
    // If we don't have the right format, we might need to adjust
  } catch (e) {
    debugPrint('Error processing DynamicPath: $e');
    return createFallbackControlPoints();
  }

  return controlPoints;
}

/// Generate control points from a morphable shape
List<Offset> generateControlPointsFromShape(String selectedShape) {
  ShapeBorder shapeBorder;

  try {
    shapeBorder = createShapeBorder(selectedShape);

    if (shapeBorder is OutlinedShapeBorder) {
      return extractControlPointsFromOutlinedShapeBorder(shapeBorder);
    } else {
      return createFallbackControlPoints();
    }
  } catch (e) {
    debugPrint('Error creating morphable shape: $e');
    return createFallbackControlPoints();
  }
}
