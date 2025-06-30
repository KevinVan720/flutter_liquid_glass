import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:text_to_path_maker/text_to_path_maker.dart';

// Local imports
import 'utils/texture_utils.dart';
import 'shapes/shape_generators.dart';
import 'shapes/morphable_shapes.dart';
import 'extensions/font_extensions.dart';
import 'widgets/shader_painter.dart';

void main() {
  runApp(const ShaderApp());
}

// ============================================================================
// MAIN APPLICATION
// ============================================================================

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
  // ============================================================================
  // STATE VARIABLES
  // ============================================================================

  ui.FragmentShader? shader;
  PMFont? _pmFont;
  bool _fontLoaded = false;

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

  // ============================================================================
  // LIFECYCLE METHODS
  // ============================================================================

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

  // ============================================================================
  // INITIALIZATION METHODS
  // ============================================================================

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

  // ============================================================================
  // CONTOUR GENERATION METHODS
  // ============================================================================

  /// Generate a list of closed contours for the selected shape
  List<List<Offset>> _generateContoursFromShape() {
    switch (selectedShape) {
      case 'Donut':
        return generateDonutContours();
      case 'Gear':
        return [generateGearContour()];
      case 'Figure 8':
        return generateFigure8Contours();
      case 'Clover':
        return generateCloverContours();
      case 'Character SDF':
        return _generateCharacterContours(selectedCharacter);
      default:
        // Default: single contour from morphable shapes
        return [generateControlPointsFromShape(selectedShape)];
    }
  }

  /// Generate contours from character using text_to_path_maker
  List<List<Offset>> _generateCharacterContours(String character) {
    if (_fontLoaded && _pmFont != null && character.isNotEmpty) {
      try {
        final charCode = character.codeUnitAt(0);
        return _pmFont!.generateContoursForCharacter(charCode);
      } catch (e) {
        debugPrint('Error with direct contour extraction: $e');
      }
    }
    // Fallback: empty list
    return [];
  }

  // ============================================================================
  // UI METHODS
  // ============================================================================

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
          ? const Center(child: LoadingWidget())
          : Column(
              children: [
                _buildShapeSelector(),
                Expanded(child: _buildShaderView(contours, totalEncodedPoints)),
                _buildInfoPanel(totalEncodedPoints),
              ],
            ),
    );
  }

  Widget _buildShapeSelector() {
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

  Widget _buildShaderView(List<List<Offset>> contours, int encodedPointCount) {
    return FutureBuilder<ui.Image>(
      future: createControlPointsTextureFromContours(contours),
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

  Widget _buildInfoPanel(int encodedPointCount) {
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
}
