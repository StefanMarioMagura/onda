import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// "Neón nocturno" palette. See docs/diseno/principios.md.
abstract final class Palette {
  static const night = Color(0xFF0A0A0B);
  static const surface = Color(0xFF141416);
  static const surfaceHigh = Color(0xFF1D1D21);
  static const line = Color(0xFF2A2A30);
  static const text = Color(0xFFF4F4F2);
  static const textSoft = Color(0xFFA3A3A8);
  static const textFaint = Color(0xFF6B6B72);

  /// Signature colour: everything you can tap, progress, key figures.
  static const lime = Color(0xFFC6FF00);

  /// Rewards only: points, streak, level.
  static const gold = Color(0xFFFFC83D);

  /// Descubre label.
  static const descubre = Color(0xFFFF4FD8);

  /// "Las dos orillas": no party colours on purpose.
  static const sideLeft = Color(0xFF3DD9FF);
  static const sideRight = Color(0xFFFF7A1A);

  static const verde = Color(0xFF00E676);
  static const ambar = Color(0xFFFFB800);
  static const rojo = Color(0xFFFF3B5C);
}

const _family = 'Archivo';

/// Archivo is variable in weight and width: condensed and heavy for impact,
/// normal width for reading.
List<FontVariation> _axes(double weight, double width) =>
    [FontVariation('wght', weight), FontVariation('wdth', width)];

FontWeight _nearest(double weight) => FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)];

abstract final class OndaText {
  /// Big condensed headline, sports-app style.
  static TextStyle impacto(double size, {Color color = Palette.text}) => TextStyle(
        fontFamily: _family,
        fontSize: size,
        height: 0.98,
        letterSpacing: -0.2,
        fontWeight: FontWeight.w800,
        fontVariations: _axes(800, 62),
        color: color,
      );

  /// Large figures: condensed, heavy, tabular.
  static TextStyle cifra(double size, {Color color = Palette.text}) => TextStyle(
        fontFamily: _family,
        fontSize: size,
        height: 1,
        fontWeight: FontWeight.w800,
        fontVariations: _axes(800, 75),
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color,
      );

  static TextStyle cuerpo(double size, {Color color = Palette.text, double weight = 400}) => TextStyle(
        fontFamily: _family,
        fontSize: size,
        height: 1.42,
        fontWeight: _nearest(weight),
        fontVariations: _axes(weight, 100),
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color,
      );

  /// Small uppercase label.
  static TextStyle etiqueta({Color color = Palette.textSoft, double size = 11}) => TextStyle(
        fontFamily: _family,
        fontSize: size,
        height: 1.2,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
        fontVariations: _axes(700, 88),
        color: color,
      );
}

ThemeData ondaTheme() {
  final scheme = const ColorScheme.dark(
    surface: Palette.night,
    onSurface: Palette.text,
    primary: Palette.lime,
    onPrimary: Palette.night,
    secondary: Palette.gold,
    outline: Palette.line,
    outlineVariant: Palette.line,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.night,
    fontFamily: _family,
    splashFactory: NoSplash.splashFactory,
    dividerTheme: const DividerThemeData(color: Palette.line, thickness: 1, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.night,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 62,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => OndaText.etiqueta(
            size: 10,
            color: states.contains(WidgetState.selected) ? Palette.lime : Palette.textFaint,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? Palette.lime : Palette.textFaint,
          )),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
  );
}

/// Lets mouse and trackpad drag the PageViews on web and desktop, not only touch.
class OndaScrollBehavior extends MaterialScrollBehavior {
  const OndaScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}
