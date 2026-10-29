import 'package:flutter/material.dart';

/// Design tokens for HolyHer: light pink + white, women-focused.
/// Theme-flip slice (2026-10-27): Cognein's dark palette is gone. Every
/// text/background pair below was contrast-checked against WCAG AA:
/// accent #AD1457 on white 6.97:1, body text #2E1A24 on white 16.29:1,
/// secondary #5F4B55 on white 8.00:1, accent on light pink #F9DCE4
/// 5.44:1. No white text sits on a light background anywhere in v1;
/// the flame icon is a 32pt icon, above the 3:1 large-graphic threshold.
abstract final class AppColors {
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFDF0F3);
  static const surfaceLight = Color(0xFFF9DCE4);
  static const accent = Color(0xFFAD1457);
  static const textPrimary = Color(0xFF2E1A24);
  static const textSecondary = Color(0xFF5F4B55);
  static const divider = Color(0xFFEAD7DE);
  static const flame = Color(0xFFE64A19);
}

ThemeData buildAppTheme() {
  final base = ThemeData(fontFamily: 'Lexend', brightness: Brightness.light);
  final text = base.textTheme.apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.accent,
      onPrimary: AppColors.background,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    ),
    textTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: AppColors.background,
      centerTitle: true,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.background,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
