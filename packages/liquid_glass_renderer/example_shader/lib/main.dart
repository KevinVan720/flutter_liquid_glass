import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:morphable_shape/morphable_shape.dart';
import 'package:text_to_path_maker/text_to_path_maker.dart';

void main() {
  runApp(const ShaderApp());
}

// Shape bounding rectangle for normalization
const Rect shapeRect = Rect.fromLTWH(0, 0, 400, 300);

List<Offset> _processPathSegment(
  List<Offset> pathSegment,
  bool isFirstSegment,
) {
  final points = <Offset>[];

  if (pathSegment.length == 4) {
    // Cubic Bézier curve - convert to quadratic segments
    final quadraticSegments = _convertCubicToQuadratic(
      pathSegment[0],
      pathSegment[1],
      pathSegment[2],
      pathSegment[3],
    );

    for (int i = 0; i < quadraticSegments.length; i++) {
      final segment = quadraticSegments[i];
      final skipStart = (isFirstSegment && i == 0) ? 0 : 1;
      points.addAll(segment.skip(skipStart).map(_normalizePoint));
    }
  } else if (pathSegment.length == 3) {
    // Quadratic Bézier curve - pass control points directly
    final startIndex = isFirstSegment ? 0 : 1;
    points.addAll(pathSegment.skip(startIndex).map(_normalizePoint));
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

// Convert a cubic Bézier curve to quadratic segments
// Using the standard approach of approximating with multiple quadratic curves
List<List<Offset>> _convertCubicToQuadratic(
  Offset p0,
  Offset p1,
  Offset p2,
  Offset p3,
) {
  // For simplicity, we'll split the cubic into 2 quadratic segments
  // This provides a good balance between accuracy and performance

  // Split cubic at t=0.5
  final mid = _subdivideCubicAt(p0, p1, p2, p3, 0.5);

  // Convert each half to quadratic
  final quad1 = _cubicToQuadraticApprox(mid[0], mid[1], mid[2], mid[3]);
  final quad2 = _cubicToQuadraticApprox(mid[3], mid[4], mid[5], mid[6]);

  return [quad1, quad2];
}

// Subdivide cubic Bézier at parameter t
List<Offset> _subdivideCubicAt(
  Offset p0,
  Offset p1,
  Offset p2,
  Offset p3,
  double t,
) {
  // De Casteljau's algorithm
  final q0 = _lerp(p0, p1, t);
  final q1 = _lerp(p1, p2, t);
  final q2 = _lerp(p2, p3, t);

  final r0 = _lerp(q0, q1, t);
  final r1 = _lerp(q1, q2, t);

  final s = _lerp(r0, r1, t);

  return [p0, q0, r0, s, r1, q2, p3];
}

// Linear interpolation between two points
Offset _lerp(Offset a, Offset b, double t) {
  return Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
}

// Approximate a cubic Bézier with a quadratic Bézier
List<Offset> _cubicToQuadraticApprox(
  Offset p0,
  Offset p1,
  Offset p2,
  Offset p3,
) {
  // Use the midpoint approximation method
  // The control point is chosen to minimize the maximum error
  final controlPoint = Offset(
    (3 * p1.dx + 3 * p2.dx - p0.dx - p3.dx) / 4,
    (3 * p1.dy + 3 * p2.dy - p0.dy - p3.dy) / 4,
  );

  return [p0, controlPoint, p3];
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
    'Character SDF',
  ];

  String selectedShape = 'Circle';
  String selectedCharacter = 'A';
  final TextEditingController _characterController = TextEditingController(
    text: 'A',
  );

  // Text-to-path maker font
  PMFont? _pmFont;
  bool _fontLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _loadFont();
  }

  @override
  void dispose() {
    shader?.dispose();
    _characterController.dispose();
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

  Future<void> _loadFont() async {
    try {
      // Load the font asset
      final data = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');

      // Create font reader and parse font
      final reader = PMFontReader();
      final font = reader.parseTTFAsset(data);

      setState(() {
        _pmFont = font;
        _fontLoaded = true;
      });
    } catch (e) {
      debugPrint('Error loading font: $e');
      setState(() {
        _fontLoaded = false;
      });
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

      // For connected curves, we need an odd number of points: 2*n + 1
      // where n is the number of curves
      // If we don't have the right format, we might need to adjust
    } catch (e) {
      debugPrint('Error processing DynamicPath: $e');
      return _createFallbackControlPoints();
    }

    return controlPoints;
  }

  List<Offset> _createFallbackControlPoints() {
    // Create a simple circle using connected quadratic Bézier curves
    final points = <Offset>[];

    // Create a circle using 4 connected quadratic Bézier curves (8 points total)
    // Format: P0(start), P1(control), P2(end), P3(control), P4(end), P5(control), P6(end), P7(control)
    // Last curve closes from P6 back to P0 using P7 as control
    const double radius = 0.6;
    final double controlDistance = radius * 4.0 / 3.0 * math.tan(math.pi / 8);

    // Connected quadratic curves for a circle
    points.addAll([
      // First curve: right -> top (P0 -> P1 -> P2)
      Offset(radius, 0), // P0: start point
      Offset(radius, -controlDistance), // P1: control point
      Offset(0, -radius), // P2: end point (shared with next curve)
      // Second curve: top -> left (P2 -> P3 -> P4)
      Offset(-controlDistance, -radius), // P3: control point
      Offset(-radius, 0), // P4: end point (shared with next curve)
      // Third curve: left -> bottom (P4 -> P5 -> P6)
      Offset(-radius, controlDistance), // P5: control point
      Offset(0, radius), // P6: end point (shared with next curve)
      // Fourth curve: bottom -> right (P6 -> P7 -> P0, closes the loop)
      Offset(controlDistance, radius), // P7: control point
    ]);

    return points;
  }

  // Generate contours from character - mimics generatePathForCharacter but returns contours directly
  List<List<Offset>> _generateCharacterContours(String character) {
    // Check if font is loaded and extract contours directly
    if (_fontLoaded && _pmFont != null && character.isNotEmpty) {
      try {
        // Get character code
        final charCode = character.codeUnitAt(0);
        // The extension method now handles all transformation and processing.
        return _pmFont!.generateContoursForCharacter(charCode);
      } catch (e) {
        debugPrint('Error with direct contour extraction: $e');
      }
    }

    // Fallback: Create a manual character shape
    return [];
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
      case 'Character SDF':
        return _generateCharacterContours(selectedCharacter);
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
          // Show character input when Character SDF is selected
          if (selectedShape == 'Character SDF') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Character: ',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _characterController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                      hintText: _fontLoaded
                          ? 'Enter any character (A, 中, 🌟, etc.)'
                          : 'Enter a character (A, B, O, etc.)',
                      hintStyle: const TextStyle(color: Colors.grey),
                    ),
                    maxLength: 1,
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        setState(() {
                          selectedCharacter = value.toUpperCase();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _fontLoaded
                  ? 'Any character supported via text_to_path_maker!'
                  : 'Font loading... Manual shapes: A, B, O (others show as rectangle)',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
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
            selectedShape == 'Character SDF'
                ? 'Displaying SDF for character "$selectedCharacter".\n${_fontLoaded ? "Using text_to_path_maker package with Roboto font." : "Font loading... Using fallback shapes for now."}'
                : 'Using morphable_shape to generate control points for "$selectedShape".\nRed lines show the control polygon.',
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

// Process path segments for character contours in connected quadratic format
List<Offset> _processCharacterPathSegment(
  List<Offset> pathSegment,
  bool isFirstSegment,
) {
  final points = <Offset>[];

  if (pathSegment.length == 4) {
    // Cubic Bézier curve - convert to quadratic segments
    final quadraticSegments = _convertCubicToQuadratic(
      pathSegment[0],
      pathSegment[1],
      pathSegment[2],
      pathSegment[3],
    );

    for (int i = 0; i < quadraticSegments.length; i++) {
      final segment = quadraticSegments[i];
      if (isFirstSegment && i == 0) {
        // For the very first segment, add all 3 points
        points.addAll(segment.map(_normalizePoint));
      } else {
        // For other segments, skip the start point (it's shared)
        points.addAll(segment.skip(1).map(_normalizePoint));
      }
    }
  } else if (pathSegment.length == 3) {
    // Quadratic Bézier curve - use directly
    if (isFirstSegment) {
      // For the first segment, add all 3 points
      points.addAll(pathSegment.map(_normalizePoint));
    } else {
      // For other segments, skip the start point (it's shared)
      points.addAll(pathSegment.skip(1).map(_normalizePoint));
    }
  } else if (pathSegment.length == 2) {
    // Linear segment - convert to quadratic
    final quadraticPoints = _convertLinearToQuadratic(
      pathSegment[0],
      pathSegment[1],
    );
    if (isFirstSegment) {
      // For the first segment, add all 3 points
      points.addAll(quadraticPoints.map(_normalizePoint));
    } else {
      // For other segments, skip the start point (it's shared)
      points.addAll(quadraticPoints.skip(1).map(_normalizePoint));
    }
  }

  return points;
}

// Ensure contour follows connected quadratic format with even number of points
List<Offset> _ensureConnectedFormat(List<Offset> contour) {
  if (contour.isEmpty) return contour;

  // The contour should already be in connected format from _processCharacterPathSegment
  // But let's ensure it's properly closed and has even number of points

  List<Offset> result = List.from(contour);

  // Check if the last point is close to the first point (indicating a closed path)
  if (result.length >= 3) {
    final first = result.first;
    final last = result.last;
    final distance = (last - first).distance;

    // If they're very close, remove the duplicate
    if (distance < 0.01) {
      result.removeLast();
    }
  }

  // For connected quadratic curves, we need an even number of points
  // If we have odd number, add a control point
  if (result.length % 2 == 1 && result.length >= 3) {
    // Add a control point between the last and first point
    final lastPoint = result.last;
    final firstPoint = result.first;
    final controlPoint = Offset(
      (lastPoint.dx + firstPoint.dx) * 0.5,
      (lastPoint.dy + firstPoint.dy) * 0.5,
    );
    result.add(controlPoint);
  }
  return result;
}

extension PMFontExtension on PMFont {
  /// Converts a character into a Flutter [Path] you can
  /// directly draw on a [Canvas]
  List<List<Offset>> generateContoursForCharacter(cIndex) {
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
            _processCharacterPathSegment([startPoint, p1], isFirstSegment),
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
            _processCharacterPathSegment([startPoint, p1, p2], isFirstSegment),
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
            _processCharacterPathSegment([
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
            final processedContour = _ensureConnectedFormat(contour);
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
      final processedContour = _ensureConnectedFormat(contour);
      contours.add(processedContour);
    }

    // Contours are now properly formatted for connected quadratic curves

    return contours;
  }
}
