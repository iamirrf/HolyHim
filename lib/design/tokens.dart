import 'package:flutter/material.dart';
import 'themes.dart';
import 'typography.dart';

class HolyDepth {
  HolyDepth._();
  static List<BoxShadow> shadows(int level, {bool dark = false}) {
    final n = level.clamp(0, 5).toDouble();
    return n == 0
        ? []
        : [
            BoxShadow(
                color: Color(dark ? 0xFF000000 : 0xFF000000)
                    .withValues(alpha: dark ? .22 : .08 + n * .008),
                blurRadius: 12 + n * 7,
                offset: Offset(0, n * 4)),
            BoxShadow(
                color:
                    const Color(0xFF000000).withValues(alpha: .025 + n * .008),
                blurRadius: 2 + n * 1.8,
                offset: Offset(0, n * 1.2))
          ];
  }

  static ShapeBorder shape(double radius) =>
      RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(radius));
}

class HolyThemeData {
  HolyThemeData._();
  static ThemeData build(HolyTheme t) {
    final scheme = ColorScheme.fromSeed(
            seedColor: t.accent,
            brightness: t.isDark ? Brightness.dark : Brightness.light)
        .copyWith(
            primary: t.accent,
            onSurface: t.ink,
            surface: t.colors.first,
            secondary: t.accentGradient.first);
    return ThemeData(
        useMaterial3: true,
        fontFamily: 'Manrope',
        brightness: t.isDark ? Brightness.dark : Brightness.light,
        colorScheme: scheme,
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: t.colors.first,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        textTheme: TextTheme(
            displayLarge: HolyTypography.display.copyWith(color: t.ink),
            headlineMedium: HolyTypography.title.copyWith(color: t.ink),
            bodyLarge: HolyTypography.ui.copyWith(color: t.ink),
            bodyMedium: HolyTypography.ui.copyWith(color: t.ink, fontSize: 14)),
        appBarTheme: AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            foregroundColor: t.ink),
        inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: t.glassTint,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: t.accent.withValues(alpha: .22))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide:
                    BorderSide(color: t.accent.withValues(alpha: .22)))),
        bottomSheetTheme: BottomSheetThemeData(
            backgroundColor: t.colors.first,
            showDragHandle: true,
            modalBackgroundColor: t.colors.first,
            shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(30)))));
  }
}
