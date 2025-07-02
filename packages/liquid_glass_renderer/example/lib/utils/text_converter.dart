import 'dart:math';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:text_to_path_maker/text_to_path_maker.dart';
import '../extensions/font_extensions.dart';

// ============================================================================
// TEXT TO BEZIER SHAPE CONVERSION
// ============================================================================

/// Convert text to BezierShape using font
BezierShape textToBezierShape(String text, PMFont? font) {
  if (font == null || text.isEmpty) {
    debugPrint('Font is null or text is empty, using fallback');
    return BezierShape(contours: [_createFallbackControlPoints()]);
  }

  try {
    debugPrint('Converting text: "$text"');
    // Use a centered bounds for better centering
    final bounds = const Rect.fromLTWH(
      -0.5,
      -0.5,
      1.0,
      1.0,
    ); // Centered at origin
    final allContours = <List<Offset>>[];

    // For single character, center it properly
    if (text.length == 1) {
      final charCode = text.codeUnitAt(0);
      debugPrint(
        'Processing single character: ${String.fromCharCode(charCode)} (code: $charCode)',
      );
      final charContours = font.generateContoursForCharacter(charCode, bounds);
      debugPrint('Generated ${charContours.length} contours for character');

      for (int i = 0; i < charContours.length; i++) {
        final contour = charContours[i];
        debugPrint('Contour $i has ${contour.length} points');

        // Validate contour
        if (contour.length < 4) {
          debugPrint(
            'Warning: Contour $i has only ${contour.length} points, skipping',
          );
          continue;
        }

        if (contour.length % 2 != 0) {
          debugPrint(
            'Warning: Contour $i has odd number of points (${contour.length}), may cause rendering issues',
          );
        }

        // Debug: print coordinate ranges
        if (contour.isNotEmpty) {
          final xCoords = contour.map((p) => p.dx);
          final yCoords = contour.map((p) => p.dy);
          final minX = xCoords.reduce(min);
          final maxX = xCoords.reduce(max);
          final minY = yCoords.reduce(min);
          final maxY = yCoords.reduce(max);
          debugPrint('  Contour $i bounds: x[$minX, $maxX], y[$minY, $maxY]');
        }

        allContours.add(contour);
      }
    } else {
      // For multiple characters, space them out
      final characterWidth = 0.8 / text.length;

      for (int i = 0; i < text.length; i++) {
        final charCode = text.codeUnitAt(i);
        debugPrint(
          'Processing character $i: ${String.fromCharCode(charCode)} (code: $charCode)',
        );

        // Create bounds for this character
        final charBounds = Rect.fromLTWH(
          i * characterWidth + characterWidth * 0.1, // Small padding
          0.1,
          characterWidth * 0.8,
          0.8,
        );

        final charContours = font.generateContoursForCharacter(
          charCode,
          charBounds,
        );
        debugPrint(
          'Generated ${charContours.length} contours for character $i',
        );

        for (final contour in charContours) {
          if (contour.length >= 4) {
            allContours.add(contour);
          }
        }
      }
    }

    debugPrint('Total valid contours: ${allContours.length}');

    if (allContours.isEmpty) {
      debugPrint('No valid contours generated, using fallback');
      return BezierShape(contours: [_createFallbackControlPoints()]);
    }

    // Final validation
    final validContours = allContours
        .where(
          (contour) =>
              contour.length >= 4 &&
              contour.every(
                (point) =>
                    point.dx.isFinite &&
                    point.dy.isFinite &&
                    point.dx.abs() <= 2.0 &&
                    point.dy.abs() <= 2.0,
              ),
        )
        .toList();

    debugPrint('Final contours after validation: ${validContours.length}');

    if (validContours.isEmpty) {
      debugPrint('No valid contours after validation, using fallback');
      return BezierShape(contours: [_createFallbackControlPoints()]);
    }

    return BezierShape(contours: validContours);
  } catch (e) {
    debugPrint('Error converting text to BezierShape: $e');
    return BezierShape(contours: [_createFallbackControlPoints()]);
  }
}

/// Create fallback control points for a simple circle
List<Offset> _createFallbackControlPoints() {
  final points = <Offset>[];
  const numSegments = 8;
  const center = Offset(0.0, 0.0); // Center at origin
  const radius = 0.4;

  for (int i = 0; i < numSegments; i++) {
    final angle = (i * 2 * pi) / numSegments;
    final nextAngle = ((i + 1) * 2 * pi) / numSegments;

    final startPoint = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );

    final endPoint = Offset(
      center.dx + radius * cos(nextAngle),
      center.dy + radius * sin(nextAngle),
    );

    // Control point for smooth circular curve
    final controlAngle = (angle + nextAngle) * 0.5;
    final controlRadius = radius * 1.2;
    final controlPoint = Offset(
      center.dx + controlRadius * cos(controlAngle),
      center.dy + controlRadius * sin(controlAngle),
    );

    if (i == 0) {
      points.add(startPoint);
    }
    points.addAll([controlPoint, endPoint]);
  }

  return points;
}
