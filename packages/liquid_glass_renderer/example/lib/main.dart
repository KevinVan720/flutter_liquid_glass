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
      duration:
          const Duration(seconds: 8), // Double the duration for full cycle
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
        ? shapeTweenRaw * 2 // 0 to 0.5 becomes 0 to 1
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
                    left: glassOffset.value.dx +
                        MediaQuery.of(context).size.width / 2 -
                        150, // Center offset (300/2 = 150)
                    top: glassOffset.value.dy +
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
                        shape: MorphableShape(
                          //morphableShapeBorder: shapeTween.lerp(shapeTweenValue)!,
                          morphableShapeBorder: beginShape,
                        ),
                        child: SizedBox(
                          width: 300,
                          height: 300,
                        ),
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
