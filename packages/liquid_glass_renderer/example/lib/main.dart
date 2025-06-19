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
                  Align(
                    alignment: Alignment.center,
                    child: LiquidGlass(
                        blur: 8,
                        glassContainsChild: false,
                        settings: LiquidGlassSettings(
                          thickness: 30,
                          lightIntensity: .6,
                          ambientStrength: 2,
                          chromaticAberration: 4,
                          glassColor: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.5),
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
    final showHint = useDelayed(
      delay: Duration(seconds: 1),
      before: false,
      after: true,
    );
    useEffect(() {
      if (showHint) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Drag Glass or tap anywhere!",
                style: GoogleFonts.lexendDecaTextTheme().bodyLarge!.copyWith(
                      color: Theme.of(context).colorScheme.onInverseSurface,
                    ),
              ),
            ),
          );
        });
      }
      return null;
    }, [showHint]);

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
          child: Padding(
            padding: const EdgeInsets.all(64.0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Align(
                  alignment: Alignment.bottomLeft,
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
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
