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
  final Map<RenderLiquidGlass, RawShape> _shapeCache = {};

  List<List<Offset>> _lastContours = [];

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

  List<RawShape> _collectShapes() {
    final newCache = <RenderLiquidGlass, RawShape>{};
    final shapesToRender = <RawShape>[];

    for (final shapeRender in registeredShapes) {
      if (shapeRender.attached && shapeRender.hasSize) {
        final shapeSize = shapeRender.size;
        final lastKnownShape = _shapeCache[shapeRender];
        RawShape newShape;

        // Check if we can reuse the cached shape object
        if (lastKnownShape != null &&
            lastKnownShape.bezierCache?.rect.size == shapeSize) {
          newShape = lastKnownShape;
        } else {
          // If not, create a new RawShape and, if it's a BezierShape,
          // calculate and cache its geometry.
          final shapeRect = Offset.zero & shapeSize;
          var rawShape = RawShape.fromLiquidGlassShape(
            shapeRender.shape,
            center: shapeRect.center,
            size: shapeSize,
          );

          if (rawShape.type == RawShapeType.bezier) {
            final bezierShape = shapeRender.shape as BezierShape;
            final contours =
                _extractContoursFromBezierShape(bezierShape, shapeRect);
            rawShape = rawShape.copyWith(
              bezierCache: BezierShapeCache(
                rect: shapeRect,
                scaledControlPoints: contours,
              ),
            );
          }
          newShape = rawShape;
        }

        newCache[shapeRender] = newShape;
        shapesToRender.add(newShape);
      }
    }

    _shapeCache
      ..clear()
      ..addAll(newCache);
    return shapesToRender;
  }

  List<List<Offset>> _extractContoursFromBezierShape(
    BezierShape bezierShape,
    Rect rect,
  ) {
    try {
      final scaledContours = <List<Offset>>[];

      final double scale;
      final Offset translation;

      // Fit the unit square shape into the destination rect, preserving aspect ratio.
      if (rect.width > rect.height) {
        // Letterbox (landscape rect)
        scale = rect.height;
        translation =
            Offset(rect.left + (rect.width - rect.height) / 2.0, rect.top);
      } else {
        // Pillarbox (portrait rect)
        scale = rect.width;
        translation =
            Offset(rect.left, rect.top + (rect.height - rect.width) / 2.0);
      }

      for (final contour in bezierShape.contours) {
        final scaledContour = <Offset>[];
        for (final point in contour) {
          scaledContour.add(Offset(
            point.dx * scale + translation.dx,
            point.dy * scale + translation.dy,
          ));
        }
        scaledContours.add(scaledContour);
      }

      return scaledContours;
    } catch (e) {
      debugPrint('Error extracting control points from BezierShape: $e');
      return [_createFallbackControlPoints(rect)];
    }
  }

  List<Offset> _createFallbackControlPoints(Rect rect) {
    // Create a simple circle as fallback
    final points = <Offset>[];
    const numPoints = 12;

    final center = rect.center;
    final radius = math.min(rect.width, rect.height) * 0.5 * 0.8;

    for (int i = 0; i < numPoints; i++) {
      final t = i / numPoints;
      final angle = t * 2 * math.pi;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      points.add(Offset(x, y));
    }

    return points;
  }

  /// Generate control points for all registered shapes using cached data
  List<List<Offset>> _collectAllContours(List<RawShape> shapes) {
    final allContours = <List<Offset>>[];

    // This lookup is a bit awkward, but it's necessary to get the transform
    // from the original RenderObject.
    final renderObjectLookup = {
      for (final e in _shapeCache.entries) e.value: e.key
    };

    for (final rawShape in shapes) {
      final shapeRender = renderObjectLookup[rawShape];
      if (shapeRender != null && shapeRender.attached && shapeRender.hasSize) {
        try {
          List<List<Offset>> localLogicalContours;

          if (rawShape.type == RawShapeType.bezier &&
              rawShape.bezierCache != null) {
            // Use cached geometry
            localLogicalContours = rawShape.bezierCache!.scaledControlPoints;
          } else {
            // Fallback for non-bezier shapes
            final shapeRect = Offset.zero & rawShape.size;
            localLogicalContours = [_createFallbackControlPoints(shapeRect)];
          }

          // 3. Get the transformation matrix from the shape's local space to the
          //    global screen space.
          final transform = shapeRender.getTransformTo(null);

          // 4. Apply the transformation to each point and convert to physical pixels.
          for (final contour in localLogicalContours) {
            allContours.add(
              contour.map((p) {
                // Transform point from local logical to global logical coordinates.
                final globalLogicalPoint =
                    MatrixUtils.transformPoint(transform, p);
                // Convert global logical coordinates to global physical coordinates.
                return Offset(
                  globalLogicalPoint.dx * _devicePixelRatio,
                  globalLogicalPoint.dy * _devicePixelRatio,
                );
              }).toList(),
            );
          }
        } catch (e) {
          debugPrint('Failed to collect control points for shape: $e');
        }
      }
    }
    return allContours;
  }

  Future<ui.Image> _encodeContoursToTexture(
    List<List<Offset>> contours,
  ) async {
    // Flatten with separators
    final totalPoints = contours.fold<int>(0, (sum, c) => sum + c.length) +
        (contours.length - 1);

    final width = totalPoints > 0 ? totalPoints : 1;
    const height = 1;
    final pixels = Uint8List(width * 4);
    int cursor = 0;

    for (int ci = 0; ci < contours.length; ci++) {
      final contour = contours[ci];
      if (contour.isEmpty) continue;

      final orientSign = _signedArea(contour) >= 0 ? 1 : -1;
      final orientationEncoded =
          orientSign > 0 ? 0.25 : 0.75; // CCW -> 0.25, CW -> 0.75

      for (int pi = 0; pi < contour.length; pi++) {
        final pt = contour[pi];
        final px = cursor * 4;

        // Encode coordinates directly using a 12-bit scheme for precision.
        final x = pt.dx.clamp(0.0, 4095.0).round();
        final y = pt.dy.clamp(0.0, 4095.0).round();

        pixels[px] = x & 0xFF; // Red: X lower 8 bits
        pixels[px + 1] = y & 0xFF; // Green: Y lower 8 bits
        pixels[px + 2] =
            ((x >> 8) & 0x0F) | (((y >> 8) & 0x0F) << 4); // Blue: upper 4 bits
        pixels[px + 3] = pi == 0
            ? (orientationEncoded * 255).round()
            : 255; // Alpha: orientation on first point, 1.0 otherwise

        cursor++;
      }

      // Separator, except after last contour
      if (ci < contours.length - 1) {
        final px = cursor * 4;
        pixels[px] = 0;
        pixels[px + 1] = 0;
        pixels[px + 2] = 0;
        pixels[px + 3] = 0; // Alpha 0 marks separator
        cursor++;
      }
    }

    if (cursor == 0) {
      // If no points, create a single separator pixel to avoid empty texture
      pixels[3] = 0;
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

  double _signedArea(List<Offset> pts) {
    double area = 0;
    for (int i = 0; i < pts.length; i++) {
      final j = (i + 1) % pts.length;
      area += pts[i].dx * pts[j].dy - pts[j].dx * pts[i].dy;
    }
    return area * 0.5;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final shapes = _collectShapes();

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
    final contours = _collectAllContours(shapes);
    final encodedPointCount = contours.isEmpty
        ? 0
        : contours.fold<int>(0, (s, c) => s + c.length) + contours.length - 1;
    final hasValidControlPoints = encodedPointCount >= 3;

    if (!hasValidControlPoints) {
      // Fallback to the original simple shape rendering
      final shape1 = shapes.firstOrNull ?? RawShape.none;
      final shape2 = shapes.length > 1 ? shapes.elementAt(1) : RawShape.none;
      final shape3 = shapes.length > 2 ? shapes.elementAt(2) : RawShape.none;

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
      // Use bezier shapes with control points
      if (!_listsEqual(_lastContours, contours)) {
        _lastContours = contours;

        // Create control points texture if needed (async, non-blocking)
        _encodeContoursToTexture(contours).then((texture) {
          // Update the cache for all shapes with the new texture
          for (final entry in _shapeCache.entries) {
            final shapeRender = entry.key;
            var rawShape = entry.value;

            if (rawShape.type == RawShapeType.bezier &&
                rawShape.bezierCache != null) {
              rawShape = rawShape.copyWith(
                bezierCache: rawShape.bezierCache!.copyWith(texture: texture),
              );
              _shapeCache[shapeRender] = rawShape;
            }
          }
          markNeedsPaint(); // Repaint when texture is ready
        }).catchError((e) {
          debugPrint('Failed to create control points texture: $e');
        });
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
          ..setFloat(12, encodedPointCount.toDouble()); // uNumPoints

        // Set control points texture to sampler 1.
        // All shapes share the same texture, so we can grab it from the first one.
        final textureToUse = shapes.firstOrNull?.bezierCache?.texture;
        if (textureToUse != null) {
          try {
            _shader.setImageSampler(1, textureToUse);
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
      if (a[i] is List && b[i] is List) {
        if (!_listsEqual(a[i] as List, b[i] as List)) return false;
      } else if (a[i] != b[i]) {
        return false;
      }
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
    List<RawShape> shapes, {
    required bool glassContainsChild,
  }) {
    // This lookup is a bit awkward, but it's necessary to get the transform
    // from the original RenderObject.
    final renderObjectLookup = {
      for (final e in _shapeCache.entries) e.value: e.key
    };
    final layerGlobalOffset = localToGlobal(Offset.zero);

    for (final rawShape in shapes) {
      final render = renderObjectLookup[rawShape];
      if (render != null && render.glassContainsChild == glassContainsChild) {
        final shapeGlobalOffset = render.localToGlobal(Offset.zero);
        final relativeOffset = shapeGlobalOffset - layerGlobalOffset;
        render.paintFromLayer(context, offset + relativeOffset);
      }
    }
  }

  void _paintShapeBlurs(
    PaintingContext context,
    Offset offset,
    List<RawShape> shapes,
  ) {
    // This lookup is a bit awkward, but it's necessary to get the transform
    // from the original RenderObject.
    final renderObjectLookup = {
      for (final e in _shapeCache.entries) e.value: e.key
    };

    final layerGlobalOffset = localToGlobal(Offset.zero);
    for (final rawShape in shapes) {
      final render = renderObjectLookup[rawShape];
      if (render != null) {
        final shapeGlobalOffset = render.localToGlobal(Offset.zero);
        final relativeOffset = shapeGlobalOffset - layerGlobalOffset;
        render.paintBlur(context, offset + relativeOffset);
      }
    }
  }
}
