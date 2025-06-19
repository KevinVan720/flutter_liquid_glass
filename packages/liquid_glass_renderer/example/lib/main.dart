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
                    left: glassOffset.value.dx,
                    top: glassOffset.value.dy,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        // Get the render box to calculate relative position
                        final RenderBox renderBox =
                            context.findRenderObject() as RenderBox;
                        final size = renderBox.size;

                        final x = glassOffset.value.dx + details.delta.dx;
                        final y = glassOffset.value.dy + details.delta.dy;

                        // Clamp the values to stay within bounds
                        glassOffset.value = Offset(
                          x.clamp(0, size.width),
                          y.clamp(0, size.height),
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: LiquidGlass(
                          blur: 2,
                          glassContainsChild: false,
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
                          shape: MorphableShape(
                            morphableShapeBorder: PolygonShapeBorder(
                              sides: 6,
                              cornerRadius: Length(30),
                            ),
                          ),
                          child: SizedBox(
                            width: 240,
                            height: 240,
                          )),
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
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(64),
              ),
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
                    style: GoogleFonts.lexendDecaTextTheme()
                        .headlineLarge
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
