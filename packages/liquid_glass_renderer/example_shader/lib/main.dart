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
  // Constants - adaptive subdivision based on shape complexity
  static const int baseCubicSubdivisionSegments = 2; // Reduced for small shapes
  static const Rect shapeRect = Rect.fromLTWH(0, 0, 400, 300);

  ui.FragmentShader? shader;

  final List<String> shapeNames = [
    'Rounded Rectangle',
    'Circle',
    'Star',
    'Heart',
    'Morphable Shape',
    'Donut',
    'Gear',
    'Figure 8',
    'Clover',
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
      final program = await ui.FragmentProgram.fromAsset(
        'assets/shaders/sdf.frag',
      );
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
    OutlinedShapeBorder shapeBorder,
  ) {
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
    List<Offset> pathSegment,
    bool isFirstSegment,
  ) {
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
      final quadraticPoints = _convertLinearToQuadratic(
        pathSegment[0],
        pathSegment[1],
      );
      final startIndex = isFirstSegment ? 0 : 1;
      points.addAll(quadraticPoints.skip(startIndex).map(_normalizePoint));
    }

    return points;
  }

  List<Offset> _subdivideCubicBezier(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
  ) {
    final points = <Offset>[];
    for (int i = 0; i <= baseCubicSubdivisionSegments; i++) {
      final t = i / baseCubicSubdivisionSegments;
      points.add(_cubicBezierPoint(p0, p1, p2, p3, t));
    }
    return points;
  }

  Offset _cubicBezierPoint(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
    double t,
  ) {
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

  // ‑-- NEW: generate a list of closed contours so we can handle multiple paths (e.g. glyphs)
  List<List<Offset>> _generateContoursFromShape() {
    switch (selectedShape) {
      case 'Donut':
        return _generateDonutContours();
      case 'Gear':
        return [_generateGearContour()];
      case 'Figure 8':
        return _generateFigure8Contours();
      case 'Clover':
        return _generateCloverContours();
      default:
        break;
    }
    // Default: single contour
    return [_generateControlPointsFromShape()];
  }

  // ‑-- NEW: signed area to determine contour orientation (CCW > 0, CW < 0)
  double _signedArea(List<Offset> pts) {
    double area = 0;
    for (int i = 0; i < pts.length; i++) {
      final j = (i + 1) % pts.length;
      area += pts[i].dx * pts[j].dy - pts[j].dx * pts[i].dy;
    }
    return area * 0.5;
  }

  // ‑-- NEW: build a 1-pixel-high texture that contains all contours, inserting a
  // separator pixel (blue = 1.0) between them and encoding the orientation in the
  // first pixel of every contour (blue = 0.25 for CCW, 0.75 for CW).
  Future<ui.Image> _createControlPointsTextureFromContours(
    List<List<Offset>> contours,
  ) async {
    final totalPoints =
        contours.fold<int>(0, (sum, c) => sum + c.length) +
        (contours.length - 1); // + separators

    final width = totalPoints;
    const height = 1;
    final pixels = Uint8List(width * 4);

    int pixelCursor = 0;

    for (int ci = 0; ci < contours.length; ci++) {
      final contour = contours[ci];

      // Detect orientation automatically
      final orientationSign = _signedArea(contour) >= 0 ? 1 : -1; // CCW ➜ +1

      final double orientationEncoded = orientationSign > 0
          ? 0.25
          : 0.75; // encode into blue channel

      for (int pi = 0; pi < contour.length; pi++) {
        final point = contour[pi];
        final pxIdx = pixelCursor * 4;

        // Normalise from [-1,1] to [0,1]
        final x = (point.dx + 1.0) * 0.5;
        final y = (point.dy + 1.0) * 0.5;

        pixels[pxIdx] = (x * 255).round().clamp(0, 255);
        pixels[pxIdx + 1] = (y * 255).round().clamp(0, 255);
        pixels[pxIdx + 2] = pi == 0
            ? (orientationEncoded * 255).round()
            : 0; // orientation only on first point
        pixels[pxIdx + 3] = 255; // alpha

        pixelCursor++;
      }

      // Insert separator (except after last contour)
      if (ci < contours.length - 1) {
        final pxIdx = pixelCursor * 4;
        pixels[pxIdx] = 0;
        pixels[pxIdx + 1] = 0;
        pixels[pxIdx + 2] = 255; // blue = 1.0 ➜ separator
        pixels[pxIdx + 3] = 255;
        pixelCursor++;
      }
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
    final contours = _generateContoursFromShape();
    // Flattened length including separators for uniform uNumPoints.
    final totalEncodedPoints =
        contours.fold<int>(0, (sum, c) => sum + c.length) +
        (contours.length - 1);

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
                Expanded(child: _ShaderView(contours, totalEncodedPoints)),
                _InfoPanel(totalEncodedPoints),
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
                  color: selectedShape == name
                      ? Colors.white
                      : Colors.grey[300],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _ShaderView(List<List<Offset>> contours, int encodedPointCount) {
    return FutureBuilder<ui.Image>(
      future: _createControlPointsTextureFromContours(contours),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return CustomPaint(
            painter: ShaderPainter(
              shader: shader!,
              controlPointsTexture: snapshot.data!,
              numPoints: encodedPointCount,
            ),
            size: Size.infinite,
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Widget _InfoPanel(int encodedPointCount) {
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
            'Encoded Points (incl. separators): $encodedPointCount',
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

  // --- DONUT helper ---------------------------------------------------------
  List<List<Offset>> _generateDonutContours() {
    // Use more points for better Bézier approximation
    const int outerPoints = 20;
    const int innerPoints = 16;

    final outer = _createCircularContour(0.6, 0.6, outerPoints, ccw: true);
    final inner = _createCircularContour(0.4, 0.4, innerPoints, ccw: false);

    return [outer, inner];
  }

  List<Offset> _createCircularContour(
    double radiusX,
    double radiusY,
    int numPoints, {
    bool ccw = true,
    Offset center = Offset.zero,
  }) {
    final points = <Offset>[];
    for (int i = 0; i < numPoints; i++) {
      final t = i / numPoints;
      final angle = t * 2 * math.pi;
      // For clockwise, negate the angle
      final actualAngle = ccw ? angle : -angle;
      final x = center.dx + math.cos(actualAngle) * radiusX;
      final y = center.dy + math.sin(actualAngle) * radiusY;
      points.add(Offset(x, y));
    }
    return points;
  }

  // Gear: create a single contour with alternating radii (teeth)
  List<Offset> _generateGearContour({
    int teeth = 20,
    double innerRadius = 0.55,
    double outerRadius = 0.7,
  }) {
    final pts = <Offset>[];
    final toothStep = 2 * math.pi / teeth;
    for (int i = 0; i < teeth; i++) {
      final angleBase = i * toothStep;
      // Outer vertex
      pts.add(
        Offset(
          math.cos(angleBase) * outerRadius,
          math.sin(angleBase) * outerRadius,
        ),
      );
      // Inner vertex halfway to next tooth
      final angleInner = angleBase + toothStep / 2;
      pts.add(
        Offset(
          math.cos(angleInner) * innerRadius,
          math.sin(angleInner) * innerRadius,
        ),
      );
    }
    return pts;
  }

  // Figure 8: two separate circles side-by-side
  List<List<Offset>> _generateFigure8Contours() {
    const int ptsPer = 40;
    final left = _createCircularContour(
      0.4,
      0.4,
      ptsPer,
      center: const Offset(-0.5, 0),
      ccw: true,
    );
    final right = _createCircularContour(
      0.4,
      0.4,
      ptsPer,
      center: const Offset(0.5, 0),
      ccw: true,
    );
    return [left, right];
  }

  // Clover: three small circles arranged in tri-foil pattern
  List<List<Offset>> _generateCloverContours() {
    const int ptsPer = 30;
    final top = _createCircularContour(
      0.35,
      0.35,
      ptsPer,
      center: const Offset(0, 0.5),
      ccw: true,
    );
    final left = _createCircularContour(
      0.35,
      0.35,
      ptsPer,
      center: const Offset(-0.45, -0.2),
      ccw: true,
    );
    final right = _createCircularContour(
      0.35,
      0.35,
      ptsPer,
      center: const Offset(0.45, -0.2),
      ccw: true,
    );
    return [top, left, right];
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
        Text('Loading shader...', style: TextStyle(color: Colors.white)),
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
