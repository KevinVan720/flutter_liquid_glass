import 'dart:ui';
import 'dart:math' as math;
import 'package:text_to_path_maker/text_to_path_maker.dart';
import '../utils/path_processing.dart';

// ============================================================================
// FONT EXTENSIONS
// ============================================================================

extension PMFontExtension on PMFont {
  /// Converts a character into contours for SDF rendering
  List<List<Offset>> generateContoursForCharacter(int cIndex) {
    var svgPath = generateSVGPathForCharacter(cIndex);
    if (svgPath.isEmpty) return [];

    // Split path into individual commands (M, L, Q, C, Z)
    final regex = RegExp(r"(?=[MLQCZ])", caseSensitive: false);
    var commands = svgPath.split(regex).where((s) => s.isNotEmpty).toList();

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
        // malformed command
      }
    }

    if (allPoints.isEmpty) return [];

    // --- Calculate transform to fit points in shapeRect ---
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

    if (width == 0 || height == 0) return [];

    const double paddingFactor = 0.8;
    final maxFitWidth = shapeRect.width * paddingFactor;
    final maxFitHeight = shapeRect.height * paddingFactor;
    final scale = math.min(maxFitWidth / width, maxFitHeight / height);

    Offset transformPoint(double x, double y) {
      final nx = (x - cx) * scale + shapeRect.center.dx;
      final ny = (y - cy) * -scale + shapeRect.center.dy;
      return Offset(nx, ny);
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
            processCharacterPathSegment([startPoint, p1], isFirstSegment),
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
            processCharacterPathSegment([startPoint, p1, p2], isFirstSegment),
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
            processCharacterPathSegment([
              startPoint,
              p1,
              p2,
              p3,
            ], isFirstSegment),
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
        // malformed command
      }
    }
    if (contour.isNotEmpty) {
      // Convert to proper connected format and ensure even number of points
      final processedContour = ensureConnectedFormat(contour);
      contours.add(processedContour);
    }

    // Contours are now properly formatted for connected quadratic curves
    return contours;
  }
}
