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
  // Constants
  static const int cubicSubdivisionSegments = 3;
  static const Rect shapeRect = Rect.fromLTWH(0, 0, 400, 300);

  ui.FragmentShader? shader;

  final List<String> shapeNames = [
    'Rounded Rectangle',
    'Circle',
    'Star',
    'Heart',
    'Morphable Shape',
  ];

  String selectedShape = 'Circle';

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  @override
  void dispose() {
    shader?.dispose();
    super.dispose();
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

  List<Offset> _generateControlPointsFromShape() {
    return _generateControlPointsFromMorphableShape();
  }

  List<Offset> _generateControlPointsFromMorphableShape() {
    ShapeBorder shapeBorder;

    try {
      shapeBorder = _createShapeBorder();

      if (shapeBorder is OutlinedShapeBorder) {
        return _extractControlPointsFromOutlinedShapeBorder(shapeBorder);
      } else {
        return _createFallbackControlPoints();
      }
    } catch (e) {
      debugPrint('Error creating morphable shape: $e');
      return _createFallbackControlPoints();
    }
  }

  ShapeBorder _createShapeBorder() {
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

  List<Offset> _extractControlPointsFromOutlinedShapeBorder(
      OutlinedShapeBorder shapeBorder) {
    try {
      final dynamicPath = shapeBorder.generateInnerDynamicPath(shapeRect);
      return _extractControlPointsFromDynamicPath(dynamicPath);
    } catch (e) {
      debugPrint('Error extracting control points: $e');
      return _createFallbackControlPoints();
    }
  }

  List<Offset> _extractControlPointsFromDynamicPath(DynamicPath dynamicPath) {
    final controlPoints = <Offset>[];

    try {
      for (int i = 0; i < dynamicPath.nodes.length; i++) {
        final pathSegment = dynamicPath.getNextPathControlPointsAt(i);
        final processedPoints = _processPathSegment(pathSegment, i == 0);
        controlPoints.addAll(processedPoints);
      }
    } catch (e) {
      debugPrint('Error processing DynamicPath: $e');
      return _createFallbackControlPoints();
    }

    return controlPoints;
  }

  List<Offset> _processPathSegment(
      List<Offset> pathSegment, bool isFirstSegment) {
    final points = <Offset>[];

    if (pathSegment.length == 4) {
      // Cubic Bézier curve
      final subdivided = _subdivideCubicBezier(
        pathSegment[0],
        pathSegment[1],
        pathSegment[2],
        pathSegment[3],
      );
      final startIndex = isFirstSegment ? 0 : 1;
      points.addAll(subdivided.skip(startIndex).map(_normalizePoint));
    } else if (pathSegment.length == 2) {
      // Linear segment - convert to quadratic
      final quadraticPoints =
          _convertLinearToQuadratic(pathSegment[0], pathSegment[1]);
      final startIndex = isFirstSegment ? 0 : 1;
      points.addAll(quadraticPoints.skip(startIndex).map(_normalizePoint));
    }

    return points;
  }

  List<Offset> _subdivideCubicBezier(
      Offset p0, Offset p1, Offset p2, Offset p3) {
    final points = <Offset>[];
    for (int i = 0; i <= cubicSubdivisionSegments; i++) {
      final t = i / cubicSubdivisionSegments;
      points.add(_cubicBezierPoint(p0, p1, p2, p3, t));
    }
    return points;
  }

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

  List<Offset> _convertLinearToQuadratic(Offset startPoint, Offset endPoint) {
    final controlPoint = Offset(
      (startPoint.dx + endPoint.dx) * 0.5,
      (startPoint.dy + endPoint.dy) * 0.5,
    );
    return [startPoint, controlPoint, endPoint];
  }

  Offset _normalizePoint(Offset point) {
    final normalizedX =
        (point.dx - shapeRect.center.dx) / (shapeRect.width * 0.5);
    final normalizedY =
        (point.dy - shapeRect.center.dy) / (shapeRect.height * 0.5);
    return Offset(normalizedX.clamp(-1.0, 1.0), normalizedY.clamp(-1.0, 1.0));
  }

  List<Offset> _createFallbackControlPoints() {
    // Create a simple rounded rectangle as fallback
    final points = <Offset>[];
    const numPoints = 12;

    for (int i = 0; i < numPoints; i++) {
      final t = i / numPoints;
      final angle = t * 2 * math.pi;
      final x = math.cos(angle) * 0.6;
      final y = math.sin(angle) * 0.4;
      points.add(Offset(x, y));
    }

    return points;
  }

  Future<ui.Image> _createControlPointsTexture(List<Offset> points) async {
    final width = points.length;
    const height = 1;
    final pixels = Uint8List(width * height * 4);

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final pixelIndex = i * 4;

      // Convert from [-1, 1] to [0, 1] texture space
      final x = (point.dx + 1.0) * 0.5;
      final y = (point.dy + 1.0) * 0.5;

      pixels[pixelIndex] = (x * 255).round().clamp(0, 255); // Red = X
      pixels[pixelIndex + 1] = (y * 255).round().clamp(0, 255); // Green = Y
      pixels[pixelIndex + 2] = 0; // Blue = unused
      pixels[pixelIndex + 3] = 255; // Alpha = 1.0
    }

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
          ? const Center(child: _LoadingWidget())
          : Column(
              children: [
                _ShapeSelector(),
                Expanded(child: _ShaderView(controlPoints)),
                _InfoPanel(controlPoints),
              ],
            ),
    );
  }

  Widget _ShapeSelector() {
    return Container(
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
                  color:
                      selectedShape == name ? Colors.white : Colors.grey[300],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _ShaderView(List<Offset> controlPoints) {
    return FutureBuilder<ui.Image>(
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
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Widget _InfoPanel(List<Offset> controlPoints) {
    return Container(
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
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Text(
            'Total Points: ${controlPoints.length}',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text(
          'Loading shader...',
          style: TextStyle(color: Colors.white),
        ),
      ],
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
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant ShaderPainter oldDelegate) {
    return oldDelegate.controlPointsTexture != controlPointsTexture ||
        oldDelegate.numPoints != numPoints;
  }
}
