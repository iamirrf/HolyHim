import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:holyher/core/theme/holy_typography.dart';
export 'package:holyher/core/theme/holy_typography.dart';
export 'holy_palette.dart';
import 'holy_palette.dart';

abstract final class AppColors {
  static HolyPalette palette = HolyPalette.all.first;
  static Color get background => palette.background;
  static Color get pearl => palette.card;
  static Color get surface => palette.blush;
  static Color get surfaceLight => palette.edge;
  static Color get accent => palette.accent;
  static Color get accentDark => palette.isDark
      ? palette.accent
      : Color.lerp(palette.accent, palette.ink, .35)!;
  static Color get textPrimary => palette.ink;
  static Color get textSecondary => palette.muted;
  static Color get divider => palette.edge;
  static const flame = Color(0xFFAC542F);
  static const success = Color(0xFF397064);
  static const error = Color(0xFF9C263B);
}

ThemeData buildAppTheme({String theme = 'pearl'}) {
  AppColors.palette = HolyPalette.byId(theme);
  final text = const TextTheme(
    displayLarge: HolyTypography.display,
    displayMedium: HolyTypography.display,
    displaySmall: HolyTypography.heading,
    headlineLarge: HolyTypography.display,
    headlineMedium: HolyTypography.heading,
    headlineSmall: HolyTypography.section,
    titleLarge: HolyTypography.section,
    titleMedium: HolyTypography.action,
    titleSmall: HolyTypography.label,
    bodyLarge: HolyTypography.body,
    bodyMedium: HolyTypography.body,
    bodySmall: HolyTypography.supporting,
    labelLarge: HolyTypography.action,
    labelMedium: HolyTypography.label,
    labelSmall: HolyTypography.label,
  ).apply(
      bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);
  final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: AppColors.textSecondary));
  return ThemeData(
    useMaterial3: true,
    fontFamily: HolyTypography.family,
    textTheme: text,
    scaffoldBackgroundColor: Colors.transparent,
    brightness: AppColors.palette.isDark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness:
            AppColors.palette.isDark ? Brightness.dark : Brightness.light,
        primary: AppColors.accent,
        onPrimary:
            AppColors.palette.isDark ? AppColors.background : Colors.white,
        surface: AppColors.background,
        onSurface: AppColors.textPrimary,
        secondary: AppColors.textSecondary,
        outline: AppColors.textSecondary,
        error: AppColors.error),
    appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: TextStyle(
            fontFamily: HolyTypography.family,
            fontSize: 17,
            height: 22 / 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
        systemOverlayStyle: SystemUiOverlayStyle.dark),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.pearl.withValues(alpha: .88),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        border: border,
        enabledBorder: border.copyWith(
            borderSide: BorderSide(
                color: AppColors.textSecondary.withValues(alpha: .78))),
        focusedBorder: border.copyWith(
            borderSide: BorderSide(color: AppColors.accent, width: 1.5)),
        errorMaxLines: 3,
        helperMaxLines: 3,
        labelStyle: HolyTypography.body,
        helperStyle: HolyTypography.supporting),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            textStyle: HolyTypography.action, minimumSize: const Size(44, 44))),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            textStyle: HolyTypography.action, minimumSize: const Size(44, 56))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            textStyle: HolyTypography.body,
            minimumSize: const Size(44, 44),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)))),
    chipTheme: ChipThemeData(
        labelStyle:
            HolyTypography.supporting.copyWith(color: AppColors.textPrimary),
        backgroundColor: AppColors.pearl,
        selectedColor: AppColors.surface,
        side: BorderSide(color: AppColors.textSecondary.withValues(alpha: .78)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)))),
    dialogTheme: DialogThemeData(
        backgroundColor: AppColors.pearl,
        titleTextStyle:
            HolyTypography.section.copyWith(color: AppColors.textPrimary),
        contentTextStyle:
            HolyTypography.body.copyWith(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
    snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle:
            HolyTypography.supporting.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
    dividerTheme: DividerThemeData(color: AppColors.divider, thickness: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.accent),
    textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.accent.withValues(alpha: .18)),
  );
}

/// Registers runtime palette dependence without changing retained route state.
Widget useHolyPalette(BuildContext context, Widget Function() build) {
  Theme.of(context);
  return build();
}
