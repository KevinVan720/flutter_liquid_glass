import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:text_to_path_maker/text_to_path_maker.dart';
import 'utils/text_converter.dart';

class TextExample extends StatefulWidget {
  const TextExample({super.key});

  @override
  State<TextExample> createState() => _TextExampleState();
}

class _TextExampleState extends State<TextExample> {
  PMFont? _pmFont;
  bool _fontLoaded = false;
  String _currentText = 'B';
  bool _useTestShape = true; // Start with test mode to debug
  int _testShapeIndex = 0; // Which test shape to use

  @override
  void initState() {
    super.initState();
    _loadFont();
  }

  Future<void> _loadFont() async {
    try {
      final data = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
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

  // Create different test shapes to understand the format
  BezierShape _createTestShape(int index) {
    debugPrint('Creating test shape $index');
    switch (index) {
      case 0:
        // Use the exact same fallback that works in morphable shapes
        debugPrint('Creating fallback circle like morphable shapes');
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

        debugPrint('Fallback circle has ${points.length} points');
        return BezierShape(contours: [points]);
      case 1:
        // Simple rectangle using connected quadratic curves (8 points = 4 curves)
        return BezierShape(
          contours: [
            [
              const Offset(0.3, 0.3), // P0: start (top left)
              const Offset(0.5, 0.25), // P1: control for curve 1
              const Offset(
                0.7,
                0.3,
              ), // P2: end curve 1 / start curve 2 (top right)
              const Offset(0.75, 0.5), // P3: control for curve 2
              const Offset(
                0.7,
                0.7,
              ), // P4: end curve 2 / start curve 3 (bottom right)
              const Offset(0.5, 0.75), // P5: control for curve 3
              const Offset(
                0.3,
                0.7,
              ), // P6: end curve 3 / start curve 4 (bottom left)
              const Offset(0.25, 0.5), // P7: control for curve 4 (back to P0)
            ],
          ],
        );
      default:
        // Simple circle using connected quadratic curves (8 points = 4 curves)
        return BezierShape(
          contours: [
            [
              const Offset(0.5, 0.2), // P0: start (top)
              const Offset(0.8, 0.2), // P1: control for curve 1
              const Offset(0.8, 0.5), // P2: end curve 1 / start curve 2 (right)
              const Offset(0.8, 0.8), // P3: control for curve 2
              const Offset(
                0.5,
                0.8,
              ), // P4: end curve 2 / start curve 3 (bottom)
              const Offset(0.2, 0.8), // P5: control for curve 3
              const Offset(0.2, 0.5), // P6: end curve 3 / start curve 4 (left)
              const Offset(0.2, 0.2), // P7: control for curve 4 (back to P0)
            ],
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Liquid Glass Text'),
        backgroundColor: Colors.black87,
        elevation: 0,
        actions: [
          // Test shape selector
          if (_useTestShape) ...[
            IconButton(
              icon: const Icon(Icons.skip_previous),
              onPressed: () {
                setState(() {
                  _testShapeIndex = (_testShapeIndex - 1) % 3;
                });
              },
            ),
            Text(
              '${_testShapeIndex + 1}/3',
              style: const TextStyle(color: Colors.white),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: () {
                setState(() {
                  _testShapeIndex = (_testShapeIndex + 1) % 3;
                });
              },
            ),
          ],
          // Character input
          if (!_useTestShape) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: SizedBox(
                  width: 60,
                  child: TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        setState(() {
                          _currentText = value.toUpperCase();
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
          // Toggle button for test mode
          IconButton(
            icon: Icon(_useTestShape ? Icons.text_fields : Icons.shape_line),
            onPressed: () {
              setState(() {
                _useTestShape = !_useTestShape;
              });
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              Color(0xFF2D1B69), // Deep purple center
              Color(0xFF1A0B3D), // Darker purple
              Color(0xFF0D0221), // Very dark purple/black
            ],
            stops: [0.0, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Subtle background pattern
            Positioned.fill(
              child: CustomPaint(painter: _BackgroundPatternPainter()),
            ),
            // Main content
            Center(
              child: _TextGlassWidget(
                text: _currentText,
                font: _pmFont,
                fontLoaded: _fontLoaded,
                useTestShape: _useTestShape,
                testShape: _createTestShape(_testShapeIndex),
                testShapeIndex: _testShapeIndex,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw subtle grid pattern
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TextGlassWidget extends HookWidget {
  const _TextGlassWidget({
    required this.text,
    required this.font,
    required this.fontLoaded,
    required this.useTestShape,
    required this.testShape,
    required this.testShapeIndex,
  });

  final String text;
  final PMFont? font;
  final bool fontLoaded;
  final bool useTestShape;
  final BezierShape testShape;
  final int testShapeIndex;

  // Generate test shapes directly in the widget
  BezierShape _generateTestShape(int index) {
    debugPrint('Generating test shape $index');

    switch (index) {
      case 0:
        // Use the exact same fallback that works in morphable shapes
        debugPrint('Creating fallback circle like morphable shapes');
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

        debugPrint('Fallback circle has ${points.length} points');
        return BezierShape(contours: [points]);
      case 1:
        // Simple rectangle using connected quadratic curves (8 points = 4 curves)
        debugPrint('Creating rectangle test shape');
        return BezierShape(
          contours: [
            [
              const Offset(0.3, 0.3), // P0: start (top left)
              const Offset(0.5, 0.25), // P1: control for curve 1
              const Offset(
                0.7,
                0.3,
              ), // P2: end curve 1 / start curve 2 (top right)
              const Offset(0.75, 0.5), // P3: control for curve 2
              const Offset(
                0.7,
                0.7,
              ), // P4: end curve 2 / start curve 3 (bottom right)
              const Offset(0.5, 0.75), // P5: control for curve 3
              const Offset(
                0.3,
                0.7,
              ), // P6: end curve 3 / start curve 4 (bottom left)
              const Offset(0.25, 0.5), // P7: control for curve 4 (back to P0)
            ],
          ],
        );
      default:
        // Simple triangle using connected quadratic curves (6 points = 3 curves)
        debugPrint('Creating triangle test shape');
        return BezierShape(
          contours: [
            [
              const Offset(0.5, 0.2), // P0: start (top)
              const Offset(0.3, 0.4), // P1: control for curve 1
              const Offset(
                0.2,
                0.7,
              ), // P2: end curve 1 / start curve 2 (bottom left)
              const Offset(0.5, 0.8), // P3: control for curve 2
              const Offset(
                0.8,
                0.7,
              ), // P4: end curve 2 / start curve 3 (bottom right)
              const Offset(0.7, 0.4), // P5: control for curve 3 (back to P0)
            ],
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Convert text to BezierShape or use test shape
    final BezierShape textShape;
    if (useTestShape) {
      debugPrint('Using test shape ${testShapeIndex + 1}');
      textShape = _generateTestShape(testShapeIndex);
      debugPrint('Test shape contours: ${textShape.contours.length}');
      if (textShape.contours.isNotEmpty) {
        debugPrint('First contour points: ${textShape.contours.first.length}');
        debugPrint(
          'First few points: ${textShape.contours.first.take(4).toList()}',
        );
      }
    } else {
      debugPrint('Using font-based text shape for: $text');
      textShape = textToBezierShape(text, font);
    }

    if (!fontLoaded && !useTestShape) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.purple),
            SizedBox(height: 16),
            Text(
              'Loading font...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Glass effect container - FIXED VERSION
        Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            color: Colors.red.withValues(
              alpha: 0.2,
            ), // Background to see the container
            border: Border.all(
              color: Colors.yellow,
              width: 2,
            ), // Border to see bounds
          ),
          child: LiquidGlass(
            blur: 5, // Small blur
            glassContainsChild: true,
            settings: LiquidGlassSettings(
              thickness: 25.0, // Reduced thickness
              lightIntensity: 4.0, // Reduced intensity
              ambientStrength: 0.5,
              chromaticAberration: 1, // No aberration for debugging
              glassColor: const Color.fromARGB(0, 255, 255, 255), // Less opaque
              lightAngle: 30.0,
              blend: 40.0, // Reduced blend
            ),
            shape: textShape,
            child: Container(
              width: 300,
              height: 300,
              color: Colors.transparent,
            ),
          ),
        ),
        const SizedBox(height: 30),
        // Info text
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(
                useTestShape
                    ? 'Test Shape ${(testShapeIndex + 1)}'
                    : 'Character: "$text"',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                useTestShape
                    ? 'Testing BezierShape Format'
                    : 'Font Mode (Roboto)',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
