import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'themes.dart';
import 'typography.dart';

/// Spacing on a 4-point grid.
class HolySpace {
  HolySpace._();
  static const xxs = 4.0,
      xs = 8.0,
      s = 12.0,
      m = 16.0,
      l = 20.0,
      xl = 24.0,
      xxl = 32.0,
      xxxl = 44.0;

  /// Side gutter for full-width compositions.
  static const gutter = 24.0;
}

/// Continuous-corner radii. Nested surfaces subtract their inset from the
/// outer radius so corners stay concentric: see [HolyRadius.inner].
class HolyRadius {
  HolyRadius._();
  static const chip = 10.0,
      field = 14.0,
      button = 14.0,
      card = 20.0,
      sheet = 28.0,
      photo = 24.0;
  static double inner(double outer, double inset) =>
      (outer - inset).clamp(4.0, outer);
}

class HolyDepth {
  HolyDepth._();

  /// One physically plausible shadow: a close contact shadow plus a broad
  /// ambient one, cool and neutral.
  static List<BoxShadow> paper(HolyTheme t, {double lift = 1}) => t.isDark
      ? [
          BoxShadow(
              color: Colors.black.withValues(alpha: .22 * lift),
              blurRadius: 4,
              offset: const Offset(0, 1)),
          BoxShadow(
              color: Colors.black.withValues(alpha: .38 * lift),
              blurRadius: 26 * lift,
              offset: Offset(0, 14 * lift)),
        ]
      : [
          BoxShadow(
              color: const Color(0xFF0B0E13).withValues(alpha: .07 * lift),
              blurRadius: 2,
              offset: const Offset(0, 1)),
          BoxShadow(
              color: const Color(0xFF0B0E13).withValues(alpha: .12 * lift),
              blurRadius: 30 * lift,
              offset: Offset(0, 14 * lift)),
        ];

  /// Two layers, as light really falls: a broad ambient shadow that hugs the
  /// surface, and a key shadow cast from above that lands 12 to 24 px below
  /// it as the surface rises.
  static List<BoxShadow> shadows(int level, {bool dark = false}) {
    final n = level.clamp(0, 5).toDouble();
    if (n == 0) return const [];
    final shade = dark ? Colors.black : const Color(0xFF0B0E13);
    return [
      BoxShadow(
          color: shade.withValues(alpha: dark ? .20 : .045),
          blurRadius: 6 + n * 2,
          offset: Offset(0, 1 + n * .5)),
      BoxShadow(
          color: shade.withValues(alpha: dark ? .30 : .05 + n * .012),
          blurRadius: 16 + n * 6,
          offset: Offset(0, 9 + n * 3)),
    ];
  }

  /// A metal face in five stops: a shaded foot, the true colour, a lit band
  /// just above the middle, the true colour again, and a shaded crown. It reads
  /// as brass lit from above in First Watch, and as the same metal in the
  /// other themes because every stop comes from [base].
  static LinearGradient metal(Color base) {
    final hsl = HSLColor.fromColor(base);
    Color shift(double l) =>
        hsl.withLightness((hsl.lightness + l).clamp(0.0, 1.0)).toColor();
    return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [shift(.06), base, shift(.11), base, shift(-.09)],
        stops: const [0, .22, .46, .7, 1]);
  }

  /// The soft bloom behind a brass element (the primary button, a medallion,
  /// Amen). Never behind body text.
  static BoxShadow bloom(Color base, {double strength = 1}) => BoxShadow(
      color: base.withValues(alpha: .26 * strength),
      blurRadius: 30,
      spreadRadius: -6,
      offset: const Offset(0, 8));

  /// The key and ambient shadows under a metal button.
  static List<BoxShadow> metalShadows(Color base, {required bool dark}) => [
        BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .28 : .10),
            blurRadius: 4,
            offset: const Offset(0, 1)),
        BoxShadow(
            color: (dark ? Colors.black : base)
                .withValues(alpha: dark ? .34 : .20),
            blurRadius: 20,
            offset: const Offset(0, 12)),
        bloom(base, strength: dark ? 1 : .6),
      ];

  static ShapeBorder shape(double radius, {BorderSide side = BorderSide.none}) =>
      RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(radius), side: side);
}

class HolyThemeData {
  HolyThemeData._();
  static ThemeData build(HolyTheme t) {
    final brightness = t.isDark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(
            seedColor: t.accent, brightness: brightness)
        .copyWith(
            primary: t.primary,
            onPrimary: t.onPrimary,
            secondary: t.accent,
            surface: t.surface,
            onSurface: t.ink,
            outline: t.hairline,
            outlineVariant: t.hairline);
    return ThemeData(
        useMaterial3: true,
        fontFamily: 'Manrope',
        brightness: brightness,
        colorScheme: scheme,
        scaffoldBackgroundColor: t.paper,
        canvasColor: t.paper,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        dividerColor: t.hairline,
        textSelectionTheme: TextSelectionThemeData(
            cursorColor: t.accent,
            selectionColor: t.accent.withValues(alpha: .22),
            selectionHandleColor: t.accent),
        cupertinoOverrideTheme: CupertinoThemeData(
            primaryColor: t.accent, brightness: brightness),
        textTheme: TextTheme(
            displayLarge: HolyTypography.display.copyWith(color: t.ink),
            headlineMedium: HolyTypography.title.copyWith(color: t.ink),
            titleLarge: HolyTypography.headline.copyWith(color: t.ink),
            bodyLarge: HolyTypography.ui.copyWith(color: t.ink),
            bodyMedium: HolyTypography.body.copyWith(color: t.ink),
            labelLarge: HolyTypography.button.copyWith(color: t.ink)),
        appBarTheme: AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            foregroundColor: t.ink),
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        }),
        bottomSheetTheme: BottomSheetThemeData(
            backgroundColor: t.surface,
            modalBackgroundColor: t.surface,
            showDragHandle: true,
            dragHandleColor: t.hairline,
            shape: const RoundedSuperellipseBorder(
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(HolyRadius.sheet)))));
  }
}
