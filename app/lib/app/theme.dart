import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Editorial palette. See docs/diseno/principios.md: every colour means something.
abstract final class Palette {
  static const paper = Color(0xFFF5F2EB);
  static const paperDeep = Color(0xFFEDE8DD);
  static const ink = Color(0xFF15140F);
  static const inkSoft = Color(0xFF5A574E);
  static const inkFaint = Color(0xFF8C887D);
  static const rule = Color(0xFFD9D3C5);

  static const verde = Color(0xFF1E8E3E);
  static const ambar = Color(0xFFD99A00);
  static const rojo = Color(0xFFC62828);
}

/// ONDA's three layers, each with its own colour.
enum Capa {
  bolsillo('Tu bolsillo', Color(0xFF0B6E4F)),
  pais('Tu país', Color(0xFF1F3A93)),
  mundo('El mundo', Color(0xFFB8471E));

  const Capa(this.etiqueta, this.color);
  final String etiqueta;
  final Color color;
}

const _serif = 'Newsreader';
const _sans = 'IBMPlexSans';

/// Variable fonts: set the weight axis explicitly so every platform renders it.
List<FontVariation> _weight(double w) => [FontVariation('wght', w)];

abstract final class OndaText {
  /// Big editorial headline.
  static TextStyle titular(double size, {Color color = Palette.ink}) => TextStyle(
        fontFamily: _serif,
        fontSize: size,
        height: 1.08,
        letterSpacing: -0.4,
        fontWeight: FontWeight.w600,
        fontVariations: [..._weight(600), FontVariation('opsz', 72)],
        color: color,
      );

  /// Large figures (prices, savings). Serif with tabular numbers.
  static TextStyle cifra(double size, {Color color = Palette.ink}) => TextStyle(
        fontFamily: _serif,
        fontSize: size,
        height: 1,
        letterSpacing: -1,
        fontWeight: FontWeight.w500,
        fontVariations: [..._weight(500), FontVariation('opsz', 72)],
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color,
      );

  static TextStyle cuerpo(double size, {Color color = Palette.ink, double weight = 400}) => TextStyle(
        fontFamily: _sans,
        fontSize: size,
        height: 1.45,
        fontWeight: FontWeight.values[(weight ~/ 100) - 1],
        fontVariations: _weight(weight),
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color,
      );

  /// Small uppercase label above a headline ("antetítulo").
  static TextStyle antetitulo({Color color = Palette.inkSoft}) => TextStyle(
        fontFamily: _sans,
        fontSize: 11,
        height: 1.2,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w600,
        fontVariations: _weight(600),
        color: color,
      );
}

ThemeData ondaTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Capa.bolsillo.color).copyWith(
    surface: Palette.paper,
    onSurface: Palette.ink,
    primary: Palette.ink,
    onPrimary: Palette.paper,
    outline: Palette.rule,
    outlineVariant: Palette.rule,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.paper,
    fontFamily: _sans,
    splashFactory: NoSplash.splashFactory,
    dividerTheme: const DividerThemeData(color: Palette.rule, thickness: 1, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.paper,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => OndaText.cuerpo(
            11,
            weight: states.contains(WidgetState.selected) ? 600 : 400,
            color: states.contains(WidgetState.selected) ? Palette.ink : Palette.inkFaint,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? Palette.ink : Palette.inkFaint,
          )),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(),
    ),
  );
}

/// Lets mouse and trackpad drag the PageViews on web and desktop, not only touch.
class OndaScrollBehavior extends MaterialScrollBehavior {
  const OndaScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}
