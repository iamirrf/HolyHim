import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppColors {
  static const background = Color(0xFFFFFAFB);
  static const surface = Color(0xFFFFF3F6);
  static const surfaceLight = Color(0xFFF6DFE8);
  static const accent = Color(0xFF8B365C);
  static const accentDark = Color(0xFF64243F);
  static const textPrimary = Color(0xFF382331);
  static const textSecondary = Color(0xFF735867);
  static const divider = Color(0xFFE9D4DF);
  static const flame = Color(0xFFAC542F);
  static const success = Color(0xFF397064);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Lexend',
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
          primary: AppColors.accent,
          onPrimary: Colors.white,
          surface: AppColors.background,
          onSurface: AppColors.textPrimary,
          secondary: AppColors.textSecondary,
          outline: AppColors.divider,
          error: Color(0xFF9C263B)));
  return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme:
          base.textTheme.apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary).copyWith(
              headlineLarge: const TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 34,
                  height: 1.18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.2,
                  color: AppColors.textPrimary),
              headlineMedium: const TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 27,
                  height: 1.22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.8,
                  color: AppColors.textPrimary),
              titleLarge: const TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 21,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.4,
                  color: AppColors.textPrimary),
              bodyLarge: const TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 16,
                  height: 1.65,
                  color: AppColors.textPrimary),
              bodyMedium: const TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 14,
                  height: 1.6,
                  color: AppColors.textSecondary),
              labelLarge: const TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w600)),
      appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          systemOverlayStyle: SystemUiOverlayStyle.dark),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: .85),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: AppColors.divider)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: AppColors.divider)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide:
                  const BorderSide(color: AppColors.accent, width: 1.5))),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.textPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      dividerTheme:
          const DividerThemeData(color: AppColors.divider, thickness: 1),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.accent),
      textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppColors.accent,
          selectionColor: AppColors.accent.withValues(alpha: .18)));
}
