import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:morphable_shape/morphable_shape.dart';

void main() {
  runApp(const ShaderApp());
}

class ShaderApp extends StatelessWidget {
  const ShaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SDF Bézier Shader Demo',
      theme: ThemeData.dark(),
      home: const ShaderScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ShaderScreen extends StatefulWidget {
  const ShaderScreen({super.key});

  @override
  State<ShaderScreen> createState() => _ShaderScreenState();
}

class _ShaderScreenState extends State<ShaderScreen> {
  ui.FragmentShader? shader;

  // Available shapes from morphable_shape
  final List<String> shapeNames = [
    'Custom Points',
    'Rounded Rectangle',
    'Circle',
    'Star',
    'Heart',
    'Morphable Shape',
  ];

  String selectedShape = 'Custom Points';

  // Custom control points
  final List<Offset> customControlPoints = [
    const Offset(-0.6, -0.4), // Bottom left
    const Offset(-0.2, -0.8), // Bottom curve
    const Offset(0.4, -0.6), // Bottom right
    const Offset(0.7, 0.2), // Right side
    const Offset(0.3, 0.8), // Top right
    const Offset(-0.5, 0.5), // Top left
    const Offset(-0.8, 0.0), // Extra point for more complex shape
    const Offset(-0.3, 0.3), // Another extra point
  ];

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program =
          await ui.FragmentProgram.fromAsset('assets/shaders/sdf.frag');
      setState(() {
        shader = program.fragmentShader();
      });
    } catch (e) {
      debugPrint('Error loading shader: $e');
    }
  }

  @override
  void dispose() {
    shader?.dispose();
    super.dispose();
  }

  List<Offset> _generateControlPointsFromShape() {
    // Use morphable shape integration for all shape types
    if (selectedShape == 'Custom Points') {
      return customControlPoints;
    } else {
      // All other shapes use the morphable shape extraction
      return _generateControlPointsFromMorphableShape();
    }
  }

  List<Offset> _generateRoundedRectanglePoints() {
    // Create a rounded rectangle using morphable_shape
    const rect = Rect.fromLTRB(-0.6, -0.4, 0.6, 0.4);
    const radius = 0.15;

    // Generate points around the rounded rectangle perimeter
    final points = <Offset>[];
    const numPoints = 12;

    for (int i = 0; i < numPoints; i++) {
      final t = i / numPoints;
      final angle = t * 2 * math.pi;

      // Create rounded corners effect
      var x = math.cos(angle) * 0.6;
      var y = math.sin(angle) * 0.4;

      // Apply rounding to corners
      final absX = x.abs();
      final absY = y.abs();
      if (absX > 0.6 - radius && absY > 0.4 - radius) {
        final cornerX = x > 0 ? 0.6 - radius : -(0.6 - radius);
        final cornerY = y > 0 ? 0.4 - radius : -(0.4 - radius);
        final dx = x - cornerX;
        final dy = y - cornerY;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist > 0) {
          x = cornerX + (dx / dist) * radius;
          y = cornerY + (dy / dist) * radius;
        }
      }

      points.add(Offset(x, y));
    }

    return points;
  }

  List<Offset> _generateCirclePoints() {
    final points = <Offset>[];
    const numPoints = 10;
    const radius = 0.5;

    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * math.pi;
      final x = math.cos(angle) * radius;
      final y = math.sin(angle) * radius;
      points.add(Offset(x, y));
    }

    return points;
  }

  List<Offset> _generateStarPoints() {
    final points = <Offset>[];
    const numPoints = 10; // 5 outer + 5 inner points
    const outerRadius = 0.6;
    const innerRadius = 0.3;

    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * math.pi - math.pi / 2;
      final radius = i % 2 == 0 ? outerRadius : innerRadius;
      final x = math.cos(angle) * radius;
      final y = math.sin(angle) * radius;
      points.add(Offset(x, y));
    }

    return points;
  }

  List<Offset> _generateHeartPoints() {
    final points = <Offset>[];
    const numPoints = 16;

    for (int i = 0; i < numPoints; i++) {
      final t = (i / numPoints) * 2 * math.pi;

      // Heart equation: x = 16sin³(t), y = 13cos(t) - 5cos(2t) - 2cos(3t) - cos(4t)
      final x = math.pow(math.sin(t), 3) * 0.4;
      final y = (13 * math.cos(t) -
              5 * math.cos(2 * t) -
              2 * math.cos(3 * t) -
              math.cos(4 * t)) *
          0.02;

      points.add(
          Offset(x.toDouble(), -y.toDouble())); // Flip Y to make heart upright
    }

    return points;
  }

  List<Offset> _generateControlPointsFromMorphableShape() {
    // Create real morphable shapes using morphable_shape package classes
    ShapeBorder shapeBorder;

    try {
      switch (selectedShape) {
        case 'Rounded Rectangle':
          shapeBorder = RectangleShapeBorder(
            borderRadius: DynamicBorderRadius.all(
              DynamicRadius.circular(60.toPXLength),
            ),
          );
          break;
        case 'Circle':
          shapeBorder = const CircleShapeBorder();
          break;
        case 'Star':
          shapeBorder = StarShapeBorder(
            corners: 5,
            inset: 50.toPercentLength,
            cornerRadius: 20.toPXLength,
            cornerStyle: CornerStyle.rounded,
          );
          break;
        case 'Heart':
          // Create a heart-like shape using PolygonShapeBorder
          shapeBorder = PolygonShapeBorder(
            sides: 8,
            cornerRadius: 30.toPercentLength,
            cornerStyle: CornerStyle.rounded,
          );
          break;
        case 'Morphable Shape':
          // Demonstrate with a hexagon
          shapeBorder = PolygonShapeBorder(
            sides: 6,
            cornerRadius: 25.toPercentLength,
            cornerStyle: CornerStyle.rounded,
          );
          break;
        default:
          shapeBorder = RectangleShapeBorder(
            borderRadius: DynamicBorderRadius.all(
              DynamicRadius.circular(40.toPXLength),
            ),
          );
      }

      // Extract control points from the morphable shape border
      debugPrint('Extracting control points from ${shapeBorder.runtimeType}');

      // Check if it's an OutlinedShapeBorder (has generateInnerDynamicPath method)
      if (shapeBorder is OutlinedShapeBorder) {
        return _extractControlPointsFromOutlinedShapeBorder(shapeBorder);
      } else {
        // For other ShapeBorder types, fall back to demonstration
        debugPrint(
            'Shape does not support generateInnerDynamicPath, using fallback');
        return _demonstrateCubicSubdivision();
      }
    } catch (e) {
      debugPrint('Error creating morphable shape: $e');
      // Fallback to demonstration
      return _demonstrateCubicSubdivision();
    }
  }

  /// Demonstrates how to subdivide cubic Bézier curves into control points
  /// This is the core concept for converting cubic curves to quadratic control polygons
  List<Offset> _demonstrateCubicSubdivision() {
    final controlPoints = <Offset>[];

    // Example cubic Bézier curves that could come from morphable_shape
    final cubicCurves = [
      // Curve 1: Top edge with curve
      [
        const Offset(-0.6, -0.4),
        const Offset(-0.2, -0.8),
        const Offset(0.2, -0.8),
        const Offset(0.6, -0.4)
      ],
      // Curve 2: Right edge
      [
        const Offset(0.6, -0.4),
        const Offset(0.8, -0.1),
        const Offset(0.8, 0.1),
        const Offset(0.6, 0.4)
      ],
      // Curve 3: Bottom edge with curve
      [
        const Offset(0.6, 0.4),
        const Offset(0.2, 0.8),
        const Offset(-0.2, 0.8),
        const Offset(-0.6, 0.4)
      ],
      // Curve 4: Left edge
      [
        const Offset(-0.6, 0.4),
        const Offset(-0.8, 0.1),
        const Offset(-0.8, -0.1),
        const Offset(-0.6, -0.4)
      ],
    ];

    // Process each cubic curve
    for (int i = 0; i < cubicCurves.length; i++) {
      final curve = cubicCurves[i];

      // Subdivide cubic Bézier into multiple control points
      final subdivided = _subdivideCubicBezier(
        curve[0], curve[1], curve[2], curve[3],
        segments: 3, // This creates 4 points per curve
      );

      // Add points (skip first point if not the first curve to avoid duplicates)
      final startIndex = (i == 0) ? 0 : 1;
      controlPoints.addAll(subdivided.skip(startIndex));
    }

    return _optimizeControlPoints(controlPoints);
  }

  /// Extracts control points from an OutlinedShapeBorder using generateInnerDynamicPath
  List<Offset> _extractControlPointsFromOutlinedShapeBorder(
      OutlinedShapeBorder shapeBorder) {
    try {
      // Use a larger rect that matches typical widget bounds
      // morphable_shape expects positive coordinate space
      const rect = Rect.fromLTWH(0, 0, 400, 300);

      debugPrint('Using rect bounds: $rect');
      debugPrint('Shape type: ${shapeBorder.runtimeType}');

      // 1. Get DynamicPath from OutlinedShapeBorder
      final dynamicPath = shapeBorder.generateInnerDynamicPath(rect);

      debugPrint('DynamicPath nodes count: ${dynamicPath.nodes.length}');

      // 2. Process the DynamicPath
      final points = _extractControlPointsFromDynamicPath(dynamicPath, rect);

      debugPrint('Extracted ${points.length} control points');
      if (points.isNotEmpty) {
        debugPrint('First few points: ${points.take(3).toList()}');
        debugPrint(
            'Last few points: ${points.reversed.take(3).toList().reversed}');
      }

      return points;
    } catch (e) {
      debugPrint('Error extracting control points: $e');
      return _demonstrateCubicSubdivision(); // Fallback
    }
  }

  /// Extracts control points from a DynamicPath by processing its segments
  List<Offset> _extractControlPointsFromDynamicPath(
      DynamicPath dynamicPath, Rect bounds) {
    final controlPoints = <Offset>[];

    try {
      debugPrint(
          'Processing DynamicPath with ${dynamicPath.nodes.length} nodes');

      // Process each segment using the getNextPathControlPointsAt method
      for (int i = 0; i < dynamicPath.nodes.length; i++) {
        final pathSegment = dynamicPath.getNextPathControlPointsAt(i);

        debugPrint(
            'Segment $i: ${pathSegment.length} points - ${pathSegment.take(2)}');

        if (pathSegment.length == 4) {
          // Cubic Bézier: [startPoint, control1, control2, endPoint]
          final subdivided = _subdivideCubicBezier(
            pathSegment[0],
            pathSegment[1],
            pathSegment[2],
            pathSegment[3],
            segments: 3,
          );

          // Add subdivided points (avoid duplicates)
          final startIndex = (i == 0) ? 0 : 1;
          for (int j = startIndex; j < subdivided.length; j++) {
            final rawPoint = subdivided[j];
            final normalized = _normalizePointFromRect(rawPoint, bounds);
            debugPrint('Raw point: $rawPoint -> Normalized: $normalized');
            controlPoints.add(normalized);
          }
        } else if (pathSegment.length == 2) {
          // Linear segment: [startPoint, endPoint]
          // Convert to quadratic by placing control point at midpoint
          final quadraticPoints = _convertLinearToQuadratic(
            pathSegment[0],
            pathSegment[1],
          );

          // Add quadratic points (avoid duplicates)
          final startIndex = (i == 0) ? 0 : 1;
          for (int j = startIndex; j < quadraticPoints.length; j++) {
            final rawPoint = quadraticPoints[j];
            final normalized = _normalizePointFromRect(rawPoint, bounds);
            debugPrint('Raw point: $rawPoint -> Normalized: $normalized');
            controlPoints.add(normalized);
          }
        }
      }
    } catch (e) {
      debugPrint('Error processing DynamicPath: $e');
      return _demonstrateCubicSubdivision(); // Fallback
    }

    final optimized = _optimizeControlPoints(controlPoints);
    debugPrint('Final optimized points: ${optimized.length}');
    return optimized;
  }

  /// Subdivides a cubic Bézier curve into multiple points for control polygon
  List<Offset> _subdivideCubicBezier(Offset p0, Offset p1, Offset p2, Offset p3,
      {int segments = 3}) {
    final points = <Offset>[];

    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final point = _cubicBezierPoint(p0, p1, p2, p3, t);
      points.add(point);
    }

    return points;
  }

  /// Calculates a point on a cubic Bézier curve at parameter t
  Offset _cubicBezierPoint(
      Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final u = 1 - t;
    final tt = t * t;
    final uu = u * u;
    final uuu = uu * u;
    final ttt = tt * t;

    return Offset(
      uuu * p0.dx + 3 * uu * t * p1.dx + 3 * u * tt * p2.dx + ttt * p3.dx,
      uuu * p0.dy + 3 * uu * t * p1.dy + 3 * u * tt * p2.dy + ttt * p3.dy,
    );
  }

  /// Converts a linear Bézier curve to a quadratic Bézier curve
  /// by placing the control point at the midpoint
  List<Offset> _convertLinearToQuadratic(Offset startPoint, Offset endPoint) {
    // For a linear segment from A to B, the quadratic representation is:
    // P0 = A (start point)
    // P1 = (A + B) / 2 (midpoint as control point)
    // P2 = B (end point)
    final controlPoint = Offset(
      (startPoint.dx + endPoint.dx) * 0.5,
      (startPoint.dy + endPoint.dy) * 0.5,
    );

    return [startPoint, controlPoint, endPoint];
  }

  /// Normalizes a point from rect coordinates to [-1, 1] space
  Offset _normalizePointFromRect(Offset point, Rect rect) {
    final normalizedX = (point.dx - rect.center.dx) / (rect.width * 0.5);
    final normalizedY = (point.dy - rect.center.dy) / (rect.height * 0.5);

    return Offset(
      normalizedX.clamp(-1.0, 1.0),
      normalizedY.clamp(-1.0, 1.0),
    );
  }

  /// Optimizes the control points list for shader performance
  List<Offset> _optimizeControlPoints(List<Offset> points) {
    if (points.length <= 24) {
      return points;
    }

    // If we have too many points, sample them evenly
    final step = points.length / 24.0;
    final optimized = <Offset>[];

    for (int i = 0; i < 24; i++) {
      final index = (i * step).floor().clamp(0, points.length - 1);
      optimized.add(points[index]);
    }

    return optimized;
  }

  Future<ui.Image> _createControlPointsTexture(List<Offset> points) async {
    // Create a 1D texture where each pixel represents a control point
    final width = points.length;
    const height = 1;

    // Create pixel data: RGBA format
    final pixels = Uint8List(width * height * 4);

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final pixelIndex = i * 4;

      // Encode coordinates in [0, 1] range for texture
      // Convert from [-1, 1] coordinate space to [0, 1] texture space
      final x = (point.dx + 1.0) * 0.5;
      final y = (point.dy + 1.0) * 0.5;

      pixels[pixelIndex] = (x * 255).round().clamp(0, 255); // Red = X
      pixels[pixelIndex + 1] = (y * 255).round().clamp(0, 255); // Green = Y
      pixels[pixelIndex + 2] = 0; // Blue = unused
      pixels[pixelIndex + 3] = 255; // Alpha = 1.0
    }

    // Create the image from pixel data
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );

    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final controlPoints = _generateControlPointsFromShape();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('SDF Bézier + Morphable Shape'),
        backgroundColor: Colors.black87,
        elevation: 0,
      ),
      body: shader == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading shader...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Shape selector
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[900],
                  child: Column(
                    children: [
                      const Text(
                        'Select Shape:',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: shapeNames.map((name) {
                          return ChoiceChip(
                            label: Text(name),
                            selected: selectedShape == name,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  selectedShape = name;
                                });
                              }
                            },
                            selectedColor: Colors.blue,
                            labelStyle: TextStyle(
                              color: selectedShape == name
                                  ? Colors.white
                                  : Colors.grey[300],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<ui.Image>(
                    future: _createControlPointsTexture(controlPoints),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return CustomPaint(
                          painter: ShaderPainter(
                            shader: shader!,
                            controlPointsTexture: snapshot.data!,
                            numPoints: controlPoints.length,
                          ),
                          size: Size.infinite,
                        );
                      } else {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black87,
                  child: Column(
                    children: [
                      const Text(
                        'SDF Bézier + Morphable Shape Integration',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Using morphable_shape to generate control points for "$selectedShape".\nRed lines show the control polygon.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Display control points count and some examples
                      Text(
                        'Total Points: ${controlPoints.length}\nFirst few: ${controlPoints.take(3).map((p) => '(${p.dx.toStringAsFixed(2)}, ${p.dy.toStringAsFixed(2)})').join(', ')}...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image controlPointsTexture;
  final int numPoints;

  ShaderPainter({
    required this.shader,
    required this.controlPointsTexture,
    required this.numPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Set shader uniforms
    shader.setFloat(0, size.width); // uResolutionW
    shader.setFloat(1, size.height); // uResolutionH
    shader.setFloat(2, numPoints.toDouble()); // uNumPoints

    // Set the texture containing control points
    shader.setImageSampler(0, controlPointsTexture);

    // Create paint with shader
    final paint = Paint()..shader = shader;

    // Draw the shader covering the entire canvas
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ShaderPainter oldDelegate) {
    return oldDelegate.controlPointsTexture != controlPointsTexture ||
        oldDelegate.numPoints != numPoints;
  }
}
