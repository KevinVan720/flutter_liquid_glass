import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ============================================================================
// SUPPORT WIDGETS
// ============================================================================

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

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
