import 'package:flutter/material.dart';

/// "First Light": a quiet morning in a printed devotional.
///
/// Every theme is a set of semantic tokens. Screens ask for a role (paper,
/// ink, accent), never a hex value, so the eight saved theme IDs can be
/// retuned without touching a screen.
@immutable
class HolyTheme {
  final String id, name;
  final bool isDark;

  /// The page itself: warm paper behind every screen.
  final Color paper;

  /// Raised reading surfaces: cards, sheets, fields.
  final Color surface;

  /// Pressed, recessed or secondary fills.
  final Color sunk;

  /// Body text and icons.
  final Color ink;

  /// Secondary text. Still at least 4.5:1 on [paper] and [surface].
  final Color muted;

  /// One-pixel rules and outlines.
  final Color hairline;

  /// Rosewood: selection, progress, links, emphasis.
  final Color accent;

  /// Filled primary controls and the ink that sits on them.
  final Color primary, onPrimary;

  /// Antique gold, for ornament only (never for text that must be read).
  final Color gold;

  /// Olive, for growth and completion.
  final Color olive;

  const HolyTheme(
      {required this.id,
      required this.name,
      required this.paper,
      required this.surface,
      required this.sunk,
      required this.ink,
      required this.muted,
      required this.hairline,
      required this.accent,
      required this.primary,
      required this.onPrimary,
      this.gold = const Color(0xFFB4904F),
      this.olive = const Color(0xFF68724A),
      this.isDark = false});

  // Compatibility roles for widgets that predate the token names.
  Color get buttonInk => onPrimary;
  Color get holdFill => (isDark ? Colors.black : Colors.white)
      .withValues(alpha: isDark ? .16 : .12);
  List<Color> get buttonGradient => [primary, primary];
  List<Color> get accentGradient => [accent, accent];
  List<Color> get colors => [paper, surface, sunk, paper, surface];
  Color get glassTint => surface.withValues(alpha: isDark ? .72 : .78);
  Color get particle => gold.withValues(alpha: isDark ? .55 : .42);
  Color get navTint => surface.withValues(alpha: .62);

  /// Text on photographs always uses this pair, independent of theme.
  static const photoInk = Color(0xFFFFFBF6);
  static const photoShade = Color(0xFF1E1216);

  static HolyTheme lerp(HolyTheme a, HolyTheme b, double t) => HolyTheme(
      id: b.id,
      name: b.name,
      isDark: t < .5 ? a.isDark : b.isDark,
      paper: Color.lerp(a.paper, b.paper, t)!,
      surface: Color.lerp(a.surface, b.surface, t)!,
      sunk: Color.lerp(a.sunk, b.sunk, t)!,
      ink: Color.lerp(a.ink, b.ink, t)!,
      muted: Color.lerp(a.muted, b.muted, t)!,
      hairline: Color.lerp(a.hairline, b.hairline, t)!,
      accent: Color.lerp(a.accent, b.accent, t)!,
      primary: Color.lerp(a.primary, b.primary, t)!,
      onPrimary: Color.lerp(a.onPrimary, b.onPrimary, t)!,
      gold: Color.lerp(a.gold, b.gold, t)!,
      olive: Color.lerp(a.olive, b.olive, t)!);

  @override
  bool operator ==(Object other) =>
      other is HolyTheme &&
      other.id == id &&
      other.paper == paper &&
      other.ink == ink &&
      other.accent == accent &&
      other.primary == primary;

  @override
  int get hashCode => Object.hash(id, paper, ink, accent, primary);
}

class HolyThemes {
  HolyThemes._();

  /// The default: ivory paper, plum-brown ink, rosewood.
  static const blush = HolyTheme(
      id: 'blush',
      name: 'First Light',
      paper: Color(0xFFF8F1E9),
      surface: Color(0xFFFFFBF6),
      sunk: Color(0xFFF0E5DA),
      ink: Color(0xFF33202A),
      muted: Color(0xFF6E5560),
      hairline: Color(0xFFE5D6C9),
      accent: Color(0xFF9B4560),
      primary: Color(0xFF4A2638),
      onPrimary: Color(0xFFFFF8F2));
  static const rose = HolyTheme(
      id: 'rose',
      name: 'Rosé',
      paper: Color(0xFFFAEEEE),
      surface: Color(0xFFFFF9F8),
      sunk: Color(0xFFF3E1E2),
      ink: Color(0xFF38202A),
      muted: Color(0xFF725560),
      hairline: Color(0xFFEBD3D6),
      accent: Color(0xFFA2405C),
      primary: Color(0xFF6B2840),
      onPrimary: Color(0xFFFFF7F6));
  static const lavender = HolyTheme(
      id: 'lavender',
      name: 'Lavender',
      paper: Color(0xFFF3EFF5),
      surface: Color(0xFFFCFAFD),
      sunk: Color(0xFFE8E1EE),
      ink: Color(0xFF2D2238),
      muted: Color(0xFF64576F),
      hairline: Color(0xFFDDD3E5),
      accent: Color(0xFF74558E),
      primary: Color(0xFF473161),
      onPrimary: Color(0xFFFBF8FF));
  static const sunrise = HolyTheme(
      id: 'sunrise',
      name: 'Sunrise',
      paper: Color(0xFFFAEFE3),
      surface: Color(0xFFFFFAF3),
      sunk: Color(0xFFF2E1D0),
      ink: Color(0xFF3A2419),
      muted: Color(0xFF725A4C),
      hairline: Color(0xFFEBD7C4),
      accent: Color(0xFFA0552F),
      primary: Color(0xFF5B301E),
      onPrimary: Color(0xFFFFF8F0));
  static const pearl = HolyTheme(
      id: 'pearl',
      name: 'Pearl',
      paper: Color(0xFFF5F2ED),
      surface: Color(0xFFFFFDFA),
      sunk: Color(0xFFEAE4DC),
      ink: Color(0xFF2E2725),
      muted: Color(0xFF675B57),
      hairline: Color(0xFFDFD7CF),
      accent: Color(0xFF85605A),
      primary: Color(0xFF3D3130),
      onPrimary: Color(0xFFFFFBF7));
  static const sage = HolyTheme(
      id: 'sage',
      name: 'Olive Grove',
      paper: Color(0xFFF1F1E6),
      surface: Color(0xFFFCFCF5),
      sunk: Color(0xFFE5E6D6),
      ink: Color(0xFF25302A),
      muted: Color(0xFF58655A),
      hairline: Color(0xFFD9DCC9),
      accent: Color(0xFF52704C),
      primary: Color(0xFF33463A),
      onPrimary: Color(0xFFF9FBF2),
      olive: Color(0xFF52704C));
  static const midnightRose = HolyTheme(
      id: 'midnight-rose',
      name: 'Evening',
      isDark: true,
      paper: Color(0xFF1B1317),
      surface: Color(0xFF271B21),
      sunk: Color(0xFF140E11),
      ink: Color(0xFFF6EAE5),
      muted: Color(0xFFC5AFB6),
      hairline: Color(0xFF3D2C34),
      accent: Color(0xFFE6A3B7),
      primary: Color(0xFFF3DCE2),
      onPrimary: Color(0xFF2A1720),
      gold: Color(0xFFD8B67C),
      olive: Color(0xFFB4BF8E));
  static const starlight = HolyTheme(
      id: 'starlight',
      name: 'Starlight',
      isDark: true,
      paper: Color(0xFF141526),
      surface: Color(0xFF1F2035),
      sunk: Color(0xFF0F1020),
      ink: Color(0xFFF2EFFA),
      muted: Color(0xFFB7B3CC),
      hairline: Color(0xFF35364F),
      accent: Color(0xFFC9B8F1),
      primary: Color(0xFFE8E1FA),
      onPrimary: Color(0xFF1E1D36),
      gold: Color(0xFFDCC28A),
      olive: Color(0xFFB9C69A));
  static const all = [
    blush,
    rose,
    lavender,
    sunrise,
    pearl,
    sage,
    midnightRose,
    starlight
  ];
  static HolyTheme byId(String id) => all.firstWhere((t) => t.id == id,
      orElse: () => id == 'midnight' ? midnightRose : blush);
}

class HolyThemeScope extends InheritedWidget {
  final HolyTheme theme;
  final bool reduceTransparency;
  const HolyThemeScope(
      {super.key,
      required this.theme,
      this.reduceTransparency = false,
      required super.child});
  static HolyTheme of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HolyThemeScope>()?.theme ??
      HolyThemes.blush;
  static bool opaqueOf(BuildContext context) =>
      (context
              .dependOnInheritedWidgetOfExactType<HolyThemeScope>()
              ?.reduceTransparency ??
          false) ||
      MediaQuery.highContrastOf(context);
  @override
  bool updateShouldNotify(HolyThemeScope old) =>
      theme != old.theme || reduceTransparency != old.reduceTransparency;
}
