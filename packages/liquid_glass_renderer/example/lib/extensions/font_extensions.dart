import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:text_to_path_maker/text_to_path_maker.dart';
import '../utils/path_processing.dart';

// ============================================================================
// FONT EXTENSIONS
// ============================================================================

extension PMFontExtension on PMFont {
  /// Converts a character into contours for liquid glass rendering
  List<List<Offset>> generateContoursForCharacter(int cIndex, Rect bounds) {
    var svgPath = generateSVGPathForCharacter(cIndex);
    debugPrint(
      'SVG path for character ${String.fromCharCode(cIndex)}: $svgPath',
    );

    if (svgPath.isEmpty) {
      debugPrint('Empty SVG path for character ${String.fromCharCode(cIndex)}');
      return [];
    }

    // Split path into individual commands (M, L, Q, C, Z)
    final regex = RegExp(r"(?=[MLQCZ])", caseSensitive: false);
    var commands = svgPath.split(regex).where((s) => s.isNotEmpty).toList();
    debugPrint('Found ${commands.length} path commands');

    // --- Pass 1: Collect all points to find bounding box ---
    final allPoints = <Offset>[];
    for (final command in commands) {
      if (command.isEmpty) continue;
      final type = command[0].toUpperCase();
      final coords = command.substring(1).split(',');
      try {
        if (type == 'M' || type == 'L') {
          allPoints.add(
            Offset(double.parse(coords[0]), double.parse(coords[1])),
          );
        } else if (type == 'Q') {
          allPoints.add(
            Offset(double.parse(coords[0]), double.parse(coords[1])),
          );
          allPoints.add(
            Offset(double.parse(coords[2]), double.parse(coords[3])),
          );
        } else if (type == 'C') {
          allPoints.add(
            Offset(double.parse(coords[0]), double.parse(coords[1])),
          );
          allPoints.add(
            Offset(double.parse(coords[2]), double.parse(coords[3])),
          );
          allPoints.add(
            Offset(double.parse(coords[4]), double.parse(coords[5])),
          );
        }
      } catch (e) {
        debugPrint('Error parsing command: $command, error: $e');
      }
    }

    if (allPoints.isEmpty) {
      debugPrint('No points found in SVG path');
      return [];
    }

    debugPrint('Found ${allPoints.length} points in SVG path');

    // --- Calculate transform to fit points in bounds ---
    double minX = double.infinity,
        minY = double.infinity,
        maxX = -double.infinity,
        maxY = -double.infinity;

    for (var p in allPoints) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }

    final cx = (minX + maxX) * 0.5;
    final cy = (minY + maxY) * 0.5;
    final width = maxX - minX;
    final height = maxY - minY;

    debugPrint(
      'Character bounds: ($minX, $minY) to ($maxX, $maxY), size: ${width}x$height',
    );

    if (width == 0 || height == 0) {
      debugPrint('Character has zero width or height');
      return [];
    }

    // Improved centering: use a consistent padding and center properly
    const double paddingFactor = 0.7; // Slightly more padding
    final maxFitWidth = bounds.width * paddingFactor;
    final maxFitHeight = bounds.height * paddingFactor;
    final scale = math.min(maxFitWidth / width, maxFitHeight / height);

    debugPrint(
      'Transform: scale=$scale, center=($cx, $cy), target bounds=$bounds',
    );

    // Transform function that centers the character properly
    Offset transformPoint(double x, double y) {
      // First, translate to origin
      final translatedX = x - cx;
      final translatedY = y - cy;

      // Then scale
      final scaledX = translatedX * scale;
      final scaledY = translatedY * scale;

      // Finally, translate to center of bounds (this ensures centering)
      final finalX = scaledX + bounds.center.dx;
      final finalY = -scaledY + bounds.center.dy; // Flip Y axis

      return Offset(finalX, finalY);
    }

    // --- Pass 2: Process commands with transform ---
    List<List<Offset>> contours = [];
    List<Offset> contour = [];
    Offset startPoint = Offset.zero;
    bool isFirstSegment = true;

    for (final command in commands) {
      if (command.isEmpty) continue;
      final type = command[0].toUpperCase();
      final coords = command.substring(1).split(',');

      try {
        if (type == 'M') {
          if (contour.isNotEmpty) {
            contours.add(List.from(contour));
          }
          contour = [];
          startPoint = transformPoint(
            double.parse(coords[0]),
            double.parse(coords[1]),
          );
          isFirstSegment = true;
        } else if (type == 'L') {
          final p1 = transformPoint(
            double.parse(coords[0]),
            double.parse(coords[1]),
          );
          contour.addAll(
            processCharacterPathSegment(
              [startPoint, p1],
              isFirstSegment,
              bounds,
            ),
          );
          isFirstSegment = false;
          startPoint = p1;
        } else if (type == 'Q') {
          final p1 = transformPoint(
            double.parse(coords[0]),
            double.parse(coords[1]),
          );
          final p2 = transformPoint(
            double.parse(coords[2]),
            double.parse(coords[3]),
          );
          contour.addAll(
            processCharacterPathSegment(
              [startPoint, p1, p2],
              isFirstSegment,
              bounds,
            ),
          );
          isFirstSegment = false;
          startPoint = p2;
        } else if (type == 'C') {
          final p1 = transformPoint(
            double.parse(coords[0]),
            double.parse(coords[1]),
          );
          final p2 = transformPoint(
            double.parse(coords[2]),
            double.parse(coords[3]),
          );
          final p3 = transformPoint(
            double.parse(coords[4]),
            double.parse(coords[5]),
          );
          contour.addAll(
            processCharacterPathSegment(
              [startPoint, p1, p2, p3],
              isFirstSegment,
              bounds,
            ),
          );
          isFirstSegment = false;
          startPoint = p3;
        } else if (type == 'Z') {
          if (contour.isNotEmpty) {
            // Convert to proper connected format and ensure even number of points
            final processedContour = ensureConnectedFormat(contour);
            contours.add(processedContour);
            contour = [];
          }
          isFirstSegment = true;
        }
      } catch (e) {
        debugPrint('Error processing command: $command, error: $e');
      }
    }
    if (contour.isNotEmpty) {
      // Convert to proper connected format and ensure even number of points
      final processedContour = ensureConnectedFormat(contour);
      contours.add(processedContour);
    }

    debugPrint(
      'Generated ${contours.length} contours with ${contours.fold(0, (sum, c) => sum + c.length)} total points',
    );

    // Contours are now properly formatted for connected quadratic curves
    return contours;
  }
}
