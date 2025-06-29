import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:morphable_shape/morphable_shape.dart';
import 'package:rivership/rivership.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

void main() {
  runApp(const MainApp());
}

final thicknessNotifier = ValueNotifier<double>(20);

final blurFactorNotifier = ValueNotifier<double>(0.0);

final cornerRadiusNotifier = ValueNotifier<double>(100);

final glassColorNotifier = ValueNotifier<Color>(
  const Color.fromARGB(0, 255, 255, 255),
);

final lightIntensityNotifier = ValueNotifier<double>(5);

final blendNotifier = ValueNotifier<double>(50);

final chromaticAberrationNotifier = ValueNotifier<double>(1);

final ambientStrengthNotifier = ValueNotifier<double>(0.5);

/// Convert a MorphableShapeBorder to a BezierShape by extracting control points
BezierShape morphableShapeToBezierShape(MorphableShapeBorder shapeBorder) {
  try {
    // Use a normalized rect to extract control points
    const rect = Rect.fromLTWH(0, 0, 1, 1);
    final dynamicPath = shapeBorder.generateInnerDynamicPath(rect);
    final outer = _extractControlPointsFromDynamicPath(dynamicPath);

    // Build inner contour: same points scaled about center (0.5,0.5) by 0.5
    const center = Offset(0.5, 0.5);
    final inner = outer
        .map(
          (p) => Offset(
            center.dx + (p.dx - center.dx) * 0.5,
            center.dy + (p.dy - center.dy) * 0.5,
          ),
        )
        .toList()
        .reversed // reverse orientation to mark as hole
        .toList();

    return BezierShape(contours: [outer, inner]);
  } catch (e) {
    debugPrint('Error converting MorphableShape to BezierShape: $e');
    // Fallback to a simple circle
    return BezierShape(contours: [_createFallbackControlPoints()]);
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
  const cubicSubdivisionSegments = 3;

  if (pathSegment.length == 4) {
    // Cubic Bézier curve - subdivide into quadratic segments
    final subdivided = _subdivideCubicBezier(
      pathSegment[0],
      pathSegment[1],
      pathSegment[2],
      pathSegment[3],
      cubicSubdivisionSegments,
    );
    final startIndex = isFirstSegment ? 0 : 1;
    points.addAll(subdivided.skip(startIndex));
  } else if (pathSegment.length == 2) {
    // Linear segment - convert to quadratic
    final quadraticPoints = _convertLinearToQuadratic(
      pathSegment[0],
      pathSegment[1],
    );
    final startIndex = isFirstSegment ? 0 : 1;
    points.addAll(quadraticPoints.skip(startIndex));
  }

  return points;
}

List<Offset> _subdivideCubicBezier(
  Offset p0,
  Offset p1,
  Offset p2,
  Offset p3,
  int segments,
) {
  final points = <Offset>[];
  for (int i = 0; i <= segments; i++) {
    final t = i / segments;
    points.add(_cubicBezierPoint(p0, p1, p2, p3, t));
  }
  return points;
}

Offset _cubicBezierPoint(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
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

List<Offset> _createFallbackControlPoints() {
  // Create a simple circle as fallback
  final points = <Offset>[];
  const numSegments = 8;
  const center = Offset(0.5, 0.5);
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

/// Interpolate between two BezierShapes
BezierShape lerpBezierShapes(BezierShape a, BezierShape b, double t) {
  final flatA = a.contours.expand((c) => c).toList();
  final flatB = b.contours.expand((c) => c).toList();

  final maxLength = max(flatA.length, flatB.length);
  final result = <Offset>[];

  for (int i = 0; i < maxLength; i++) {
    final pointA = i < flatA.length ? flatA[i] : flatA.last;
    final pointB = i < flatB.length ? flatB[i] : flatB.last;
    result.add(Offset.lerp(pointA, pointB, t)!);
  }

  return BezierShape(contours: [result]);
}

class MainApp extends HookWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final thicknessVisible = useState(true);

    // Add state to track the glass position
    final glassOffset = useState<Offset>(Offset.zero);

    final blend = useValueListenable(blendNotifier);

    final chromaticAberration = useValueListenable(chromaticAberrationNotifier);

    final spring = Spring.bouncy.copyWith(durationSeconds: .8, bounce: 0.3);

    final thickness = useSingleMotion(
      value: thicknessVisible.value ? thicknessNotifier.value : 0,
      motion: SpringMotion(spring),
    );

    final blur = thickness * blurFactorNotifier.value;

    final lightAngleController = useAnimationController(
      duration: const Duration(seconds: 5),
      lowerBound: 0,
      upperBound: 2 * pi,
    )..repeat();

    final lightAngle = useAnimation(lightAngleController);

    final cornerRadius = useSingleMotion(
      value: cornerRadiusNotifier.value,
      motion: SpringMotion(spring.copyWithDamping(durationSeconds: 1.2)),
    );

    final color = useTweenAnimation(
      ColorTween(
        begin: glassColorNotifier.value,
        end: glassColorNotifier.value,
      ),
    )!;

    final colorScheme = ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: Color(0xFF287390),
    );

    final beginShape = StarShapeBorder(
      corners: 6,
      inset: 40.toPercentLength,
      cornerRadius: 25.toPercentLength,
      insetRadius: 25.toPercentLength,
      cornerStyle: CornerStyle.rounded,
      insetStyle: CornerStyle.rounded,
    );

    final endShape = CircleShapeBorder();

    final shapeTweenController = useAnimationController(
      duration: const Duration(
        seconds: 5,
      ), // Double the duration for full cycle
      lowerBound: 0,
      upperBound: 1,
    )..repeat();

    final shapeTweenCurved = CurvedAnimation(
      parent: shapeTweenController,
      curve: Curves.easeInOut,
    );

    final shapeTweenRaw = useAnimation(shapeTweenCurved);

    // Create back-and-forth motion: 0->1->0 within one full cycle
    final shapeTweenValue = shapeTweenRaw <= 0.5
        ? shapeTweenRaw *
              2 // 0 to 0.5 becomes 0 to 1
        : (1 - shapeTweenRaw) * 2; // 0.5 to 1 becomes 1 to 0

    final shapeTween = MorphableShapeBorderTween(
      begin: beginShape,
      end: endShape,
    );

    // Use AnimatedBuilder to rebuild when animation changes
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.from(
        colorScheme: colorScheme,
        textTheme: GoogleFonts.lexendDecaTextTheme().apply(
          displayColor: colorScheme.onSurface,
          bodyColor: colorScheme.onSurface,
        ),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Background(
              child: Stack(
                children: [
                  Positioned(
                    left:
                        glassOffset.value.dx +
                        MediaQuery.of(context).size.width / 2 -
                        150, // Center offset (300/2 = 150)
                    top:
                        glassOffset.value.dy +
                        MediaQuery.of(context).size.height / 2 -
                        150,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        glassOffset.value = glassOffset.value + details.delta;
                      },
                      behavior: HitTestBehavior.opaque,
                      child: LiquidGlass(
                        blur: 2,
                        glassContainsChild: true,
                        settings: LiquidGlassSettings(
                          thickness: thickness,
                          lightIntensity: lightIntensityNotifier.value,
                          ambientStrength: ambientStrengthNotifier.value,
                          chromaticAberration: chromaticAberration,
                          glassColor: color.withValues(
                            alpha: color.a * thickness / 10,
                          ),
                          lightAngle: lightAngle,
                          blend: blend,
                        ),
                        shape: morphableShapeToBezierShape(
                          shapeTween.lerp(shapeTweenValue)!,
                        ),
                        child: SizedBox(width: 300, height: 300),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class Background extends HookWidget {
  const Background({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Container(
          decoration: ShapeDecoration(
            image: DecorationImage(
              image: AssetImage('assets/wallpaper.webp'),
              fit: BoxFit.cover,
            ),
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(64)),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Liquid\nGlass\nRenderer',
                    style: GoogleFonts.lexendDecaTextTheme().headlineLarge
                        ?.copyWith(
                          fontSize: 120,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF287390),
                        ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
