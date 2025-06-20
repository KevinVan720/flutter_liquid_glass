// ignore_for_file: avoid_setters_without_getters

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:liquid_glass_renderer/src/liquid_glass.dart';
import 'package:liquid_glass_renderer/src/liquid_glass_settings.dart';
import 'package:liquid_glass_renderer/src/liquid_shape.dart';
import 'package:liquid_glass_renderer/src/raw_shapes.dart';
import 'package:meta/meta.dart';
import 'package:morphable_shape/morphable_shape.dart';

/// Represents a layer of multiple [LiquidGlass] shapes that can flow together
/// and have shared [LiquidGlassSettings].
///
/// If you create a [LiquidGlassLayer] with one or more [LiquidGlass.inLayer]
/// widgets, the liquid glass effect will be rendered where this layer is.
/// Make sure not to stack any other widgets between the [LiquidGlassLayer] and
/// the [LiquidGlass] widgets, otherwise the liquid glass effect will be behind
/// them.
///
/// > [!WARNING]
/// > A maximum of two shapes are supported per layer at the moment.
/// >
/// > This will likely increase to at least four in the future.
///
/// ## Example
///
/// ```dart
/// Widget build(BuildContext context) {
///   return LiquidGlassLayer(
///     child: Column(
///       children: [
///         LiquidGlass.inLayer(
///           shape: LiquidGlassSquircle(
///             borderRadius: Radius.circular(10),
///           ),
///           child: SizedBox.square(
///             dimension: 100,
///           ),
///         ),
///         const SizedBox(height: 100),
///         LiquidGlass.inLayer(
///           shape: LiquidGlassSquircle(
///             borderRadius: Radius.circular(50),
///           ),
///           child: SizedBox.square(
///             dimension: 100,
///           ),
///         ),
///       ],
///     ),
///   );
/// }
class LiquidGlassLayer extends StatefulWidget {
  /// Creates a new [LiquidGlassLayer] with the given [child] and [settings].
  const LiquidGlassLayer({
    required this.child,
    this.settings = const LiquidGlassSettings(),
    super.key,
  });

  /// The subtree in which you should include at least one [LiquidGlass] widget.
  ///
  /// The [LiquidGlassLayer] will automatically register all [LiquidGlass]
  /// widgets in the subtree as shapes and render them.
  final Widget child;

  /// The settings for the liquid glass effect for all shapes in this layer.
  final LiquidGlassSettings settings;

  @override
  State<LiquidGlassLayer> createState() => _LiquidGlassLayerState();
}

class _LiquidGlassLayerState extends State<LiquidGlassLayer>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    if (!ui.ImageFilter.isShaderFilterSupported) {
      assert(
        ui.ImageFilter.isShaderFilterSupported,
        'liquid_glass_renderer is only supported when using Impeller at the '
        'moment. Please enable Impeller, or check '
        'ImageFilter.isShaderFilterSupported before you use liquid glass '
        'widgets.',
      );
      return widget.child;
    }

    return ShaderBuilder(
      assetKey:
          'packages/liquid_glass_renderer/lib/assets/shaders/liquid_glass.frag',
      (context, shader, child) => _RawShapes(
        shader: shader,
        settings: widget.settings,
        debugRenderRefractionMap: false,
        vsync: this,
        child: child!,
      ),
      child: widget.child,
    );
  }
}

class _RawShapes extends SingleChildRenderObjectWidget {
  const _RawShapes({
    required this.shader,
    required this.settings,
    required this.debugRenderRefractionMap,
    required this.vsync,
    required Widget super.child,
  });

  final FragmentShader shader;
  final LiquidGlassSettings settings;
  final bool debugRenderRefractionMap;

  final TickerProvider vsync;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderLiquidGlassLayer(
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      shader: shader,
      settings: settings,
      debugRenderRefractionMap: debugRenderRefractionMap,
      ticker: vsync,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLiquidGlassLayer renderObject,
  ) {
    renderObject
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context)
      ..settings = settings
      ..ticker = vsync
      ..debugRenderRefractionMap = debugRenderRefractionMap;
  }
}

@internal
class RenderLiquidGlassLayer extends RenderProxyBox {
  RenderLiquidGlassLayer({
    required double devicePixelRatio,
    required FragmentShader shader,
    required LiquidGlassSettings settings,
    required TickerProvider ticker,
    bool debugRenderRefractionMap = false,
  })  : _devicePixelRatio = devicePixelRatio,
        _shader = shader,
        _settings = settings,
        _tickerProvider = ticker,
        _debugRenderRefractionMap = debugRenderRefractionMap {
    _ticker = _tickerProvider.createTicker((_) {
      markNeedsPaint();
    });
  }

  // Registry to allow shapes to find their parent layer
  static final Expando<RenderLiquidGlassLayer> layerRegistry = Expando();

  final Set<RenderLiquidGlass> registeredShapes = {};

  // Control points texture management
  ui.Image? _controlPointsTexture;
  List<Offset> _lastControlPoints = [];

  // Constants for control points generation
  static const int cubicSubdivisionSegments = 3;

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  final FragmentShader _shader;

  LiquidGlassSettings _settings;
  set settings(LiquidGlassSettings value) {
    if (_settings == value) return;
    _settings = value;
    markNeedsPaint();
  }

  bool _debugRenderRefractionMap;
  set debugRenderRefractionMap(bool value) {
    if (_debugRenderRefractionMap == value) return;
    _debugRenderRefractionMap = value;
    markNeedsPaint();
  }

  TickerProvider _tickerProvider;
  set ticker(TickerProvider value) {
    if (_tickerProvider == value) return;
    _tickerProvider = value;
    markNeedsPaint();
  }

  /// Ticker to animate the liquid glass effect.
  ///
  // TODO(timcreatedit): this is maybe not the best for performance, but I can't
  // come up with a better solution right now.
  Ticker? _ticker;

  void registerShape(RenderLiquidGlass shape) {
    if (registeredShapes.length >= 3) {
      throw UnsupportedError('Only three shapes are supported at the moment!');
    }
    registeredShapes.add(shape);
    layerRegistry[shape] = this;
    markNeedsPaint();

    if (registeredShapes.length == 1) {
      _ticker?.start();
    }
  }

  void unregisterShape(RenderLiquidGlass shape) {
    registeredShapes.remove(shape);
    layerRegistry[shape] = null;
    markNeedsPaint();
    if (registeredShapes.isEmpty) {
      _ticker?.stop();
    }
  }

  List<(RenderLiquidGlass, RawShape)> collectShapes() {
    final result = <(RenderLiquidGlass, RawShape)>[];

    for (final shapeRender in registeredShapes) {
      if (shapeRender.attached && shapeRender.hasSize) {
        try {
          // Get transform relative to global coordinates
          final transform = shapeRender.getTransformTo(null);

          final rect = MatrixUtils.transformRect(
            transform,
            Offset.zero & shapeRender.size,
          );

          result.add(
            (
              shapeRender,
              RawShape.fromLiquidGlassShape(
                shapeRender.shape,
                center: rect.center,
                size: rect.size,
              ),
            ),
          );
        } catch (e) {
          // Skip shapes that can't be transformed
          debugPrint('Failed to collect shape: $e');
        }
      }
    }

    return result;
  }

  /// Generate control points for morphable shapes
  List<Offset> _generateControlPointsFromShape(LiquidShape shape, Rect rect) {
    if (shape is MorphableShape) {
      return _extractControlPointsFromMorphableShape(
          shape.morphableShapeBorder, rect);
    } else {
      // For other shapes, create a fallback control points representation
      return _createFallbackControlPoints(rect);
    }
  }

  List<Offset> _extractControlPointsFromMorphableShape(
      MorphableShapeBorder shapeBorder, Rect rect) {
    try {
      final dynamicPath = shapeBorder.generateInnerDynamicPath(rect);
      return _extractControlPointsFromDynamicPath(dynamicPath);
    } catch (e) {
      debugPrint('Error extracting control points: $e');
      return _createFallbackControlPoints(rect);
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
      return [];
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
      points.addAll(subdivided.skip(startIndex));
    } else if (pathSegment.length == 2) {
      // Linear segment - convert to quadratic
      final quadraticPoints =
          _convertLinearToQuadratic(pathSegment[0], pathSegment[1]);
      final startIndex = isFirstSegment ? 0 : 1;
      points.addAll(quadraticPoints.skip(startIndex));
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

  List<Offset> _createFallbackControlPoints(Rect rect) {
    // Create a simple rounded rectangle as fallback
    final points = <Offset>[];
    const numPoints = 12;

    final center = rect.center;
    final radiusX = rect.width * 0.5 * 0.8;
    final radiusY = rect.height * 0.5 * 0.8;

    for (int i = 0; i < numPoints; i++) {
      final t = i / numPoints;
      final angle = t * 2 * math.pi;
      final x = center.dx + radiusX * math.cos(angle);
      final y = center.dy + radiusY * math.sin(angle);
      points.add(Offset(x, y));
    }

    return points;
  }

  /// Generate control points for all registered shapes
  List<Offset> _collectAllControlPoints() {
    final allControlPoints = <Offset>[];
    final layerGlobalOffset = localToGlobal(Offset.zero);

    for (final shapeRender in registeredShapes) {
      if (shapeRender.attached && shapeRender.hasSize) {
        try {
          // Use layerGlobalOffset to calculate actual relative position
          final shapeGlobalOffset = shapeRender.localToGlobal(Offset.zero);
          final shapeRelativeToLayer = shapeGlobalOffset - layerGlobalOffset;

          // Create rect for the shape positioned within the layer
          final shapeRect = shapeRelativeToLayer & shapeRender.size;

          final controlPoints =
              _generateControlPointsFromShape(shapeRender.shape, shapeRect);

          // Scale control points by device pixel ratio only
          final transformedPoints = controlPoints.map((point) {
            return Offset(
              (point.dx + shapeGlobalOffset.dx) * _devicePixelRatio,
              (point.dy + shapeGlobalOffset.dy) * _devicePixelRatio,
            );
          }).toList();

          allControlPoints.addAll(transformedPoints);
        } catch (e) {
          debugPrint('Failed to collect control points for shape: $e');
        }
      }
    }

    return allControlPoints;
  }

  Future<ui.Image> _createControlPointsTexture(List<Offset> points) async {
    if (points.isEmpty) {
      // Create a dummy texture with one point
      points = [const Offset(0, 0)];
    }

    final width = points.length;
    const height = 1;
    final pixels = Uint8List(width * height * 4);

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final pixelIndex = i * 4;

      // Encode pixel coordinates in texture channels
      // The shader will decode these back to actual coordinates
      final x = point.dx.clamp(0.0, 4095.0);
      final y = point.dy.clamp(0.0, 4095.0);

      // Store as 12-bit values in RGBA channels
      final xInt = x.round();
      final yInt = y.round();

      pixels[pixelIndex] = (xInt & 0xFF); // Red = X lower 8 bits
      pixels[pixelIndex + 1] = (yInt & 0xFF); // Green = Y lower 8 bits
      pixels[pixelIndex + 2] = ((xInt >> 8) & 0x0F) |
          (((yInt >> 8) & 0x0F) << 4); // Blue = upper 4 bits
      pixels[pixelIndex + 3] = 255; // Alpha = 1.0
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      (image) => completer.complete(image),
    );

    return completer.future;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final shapes = collectShapes();

    if (_settings.thickness <= 0) {
      _paintShapeContents(context, offset, shapes, glassContainsChild: true);
      _paintShapeContents(context, offset, shapes, glassContainsChild: false);
      return;
    }

    // Check if we have any shapes at all
    if (shapes.isEmpty) {
      // No shapes registered, just render children
      _paintShapeContents(context, offset, shapes, glassContainsChild: true);
      _paintShapeContents(context, offset, shapes, glassContainsChild: false);
      return;
    }

    // Try to use morphable shapes first, fallback to basic shapes if needed
    final controlPoints = _collectAllControlPoints();
    final hasValidControlPoints = controlPoints.length >= 3;

    if (!hasValidControlPoints) {
      // Fallback to the original simple shape rendering
      final shape1 = shapes.firstOrNull?.$2 ?? RawShape.none;
      final shape2 = shapes.length > 1 ? shapes.elementAt(1).$2 : RawShape.none;
      final shape3 = shapes.length > 2 ? shapes.elementAt(2).$2 : RawShape.none;

      try {
        _shader
          ..setFloat(0, size.width * _devicePixelRatio) // uSizeW
          ..setFloat(1, size.height * _devicePixelRatio) // uSizeH
          ..setFloat(2, _settings.chromaticAberration) // uChromaticAberration
          ..setFloat(3, _settings.glassColor.r) // uGlassColorR
          ..setFloat(4, _settings.glassColor.g) // uGlassColorG
          ..setFloat(5, _settings.glassColor.b) // uGlassColorB
          ..setFloat(6, _settings.glassColor.a) // uGlassColorA
          ..setFloat(7, _settings.lightAngle) // uLightAngle
          ..setFloat(8, _settings.lightIntensity) // uLightIntensity
          ..setFloat(9, _settings.ambientStrength) // uAmbientStrength
          ..setFloat(10, _settings.thickness) // uThickness
          ..setFloat(11, 1.51) // refractive index
          ..setFloat(12, 0.0); // uNumPoints = 0 (use basic shapes)
      } catch (e) {
        debugPrint('Error setting basic shader uniforms: $e');
      }
    } else {
      // Use morphable shapes with control points
      // Update control points texture if needed
      if (!_listsEqual(_lastControlPoints, controlPoints)) {
        _lastControlPoints = List.from(controlPoints);
        _controlPointsTexture = null;
      }

      // Create control points texture if needed (async, non-blocking)
      if (_controlPointsTexture == null) {
        _createControlPointsTexture(controlPoints).then((texture) {
          _controlPointsTexture = texture;
          markNeedsPaint(); // Repaint when texture is ready
        }).catchError((e) {
          debugPrint('Failed to create control points texture: $e');
        });
        // Continue rendering without early return to avoid crashes
      }

      try {
        // Set shader uniforms for morphable shapes
        _shader
          ..setFloat(0, size.width * _devicePixelRatio) // uSizeW
          ..setFloat(1, size.height * _devicePixelRatio) // uSizeH
          ..setFloat(2, _settings.chromaticAberration) // uChromaticAberration
          ..setFloat(3, _settings.glassColor.r) // uGlassColorR
          ..setFloat(4, _settings.glassColor.g) // uGlassColorG
          ..setFloat(5, _settings.glassColor.b) // uGlassColorB
          ..setFloat(6, _settings.glassColor.a) // uGlassColorA
          ..setFloat(7, _settings.lightAngle) // uLightAngle
          ..setFloat(8, _settings.lightIntensity) // uLightIntensity
          ..setFloat(9, _settings.ambientStrength) // uAmbientStrength
          ..setFloat(10, _settings.thickness) // uThickness
          ..setFloat(11, 1.51) // uRefractiveIndex
          ..setFloat(12, controlPoints.length.toDouble()); // uNumPoints

        // Set control points texture to sampler 1 (sampler 0 is auto-provided by BackdropFilterLayer)
        if (_controlPointsTexture != null) {
          try {
            _shader.setImageSampler(1, _controlPointsTexture!);
          } catch (e) {
            debugPrint('Failed to set control points texture: $e');
          }
        }
      } catch (e) {
        debugPrint('Error setting morphable shader uniforms: $e');
      }
    }

    _paintShapeBlurs(context, offset, shapes);

    _paintShapeContents(context, offset, shapes, glassContainsChild: true);

    context.pushLayer(
      BackdropFilterLayer(
        filter: ui.ImageFilter.shader(_shader),
      ),
      (context, offset) {
        super.paint(context, offset);
        _paintShapeContents(
          context,
          offset,
          shapes,
          glassContainsChild: false,
        );
      },
      offset,
    );
  }

  bool _listsEqual<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }

  void _paintShapeContents(
    PaintingContext context,
    Offset offset,
    List<(RenderLiquidGlass, RawShape)> shapes, {
    required bool glassContainsChild,
  }) {
    final layerGlobalOffset = localToGlobal(Offset.zero);
    for (final (render, _) in shapes) {
      if (render.glassContainsChild == glassContainsChild) {
        final shapeGlobalOffset = render.localToGlobal(Offset.zero);
        final relativeOffset = shapeGlobalOffset - layerGlobalOffset;
        render.paintFromLayer(context, offset + relativeOffset);
      }
    }
  }

  void _paintShapeBlurs(
    PaintingContext context,
    Offset offset,
    List<(RenderLiquidGlass, RawShape)> shapes,
  ) {
    final layerGlobalOffset = localToGlobal(Offset.zero);
    for (final (render, _) in shapes) {
      final shapeGlobalOffset = render.localToGlobal(Offset.zero);
      final relativeOffset = shapeGlobalOffset - layerGlobalOffset;
      render.paintBlur(context, offset + relativeOffset);
    }
  }
}
