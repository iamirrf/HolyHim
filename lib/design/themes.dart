import 'package:flutter/material.dart';

/// "First Watch": the hour before sunrise. Dark paper, bone ink, brass.
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

  /// Brass or bronze: selection, progress, links, emphasis.
  final Color accent;

  /// Filled primary controls and the ink that sits on them.
  final Color primary, onPrimary;

  /// Brass, for ornament only (never for text that must be read).
  final Color gold;

  /// Pine, for growth and completion.
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
      this.gold = const Color(0xFFD8A657),
      this.olive = const Color(0xFF8FB08A),
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
  static const photoInk = Color(0xFFF5F1EA);
  static const photoShade = Color(0xFF0B0E13);

  /// Brass for accents that sit on photographs (the wordmark's "Him").
  static const photoBrass = Color(0xFFE2B66A);

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

  // Dart names and stored IDs are kept from the shared engine so saved
  // profiles and merges stay stable; the names people see are HolyHim's.

  /// The default: charcoal-navy before dawn, bone text, brass.
  static const blush = HolyTheme(
      id: 'blush',
      name: 'First Watch',
      isDark: true,
      paper: Color(0xFF0E1217),
      surface: Color(0xFF171D25),
      sunk: Color(0xFF0A0D11),
      ink: Color(0xFFF2EDE4),
      muted: Color(0xFFA7AEB8),
      hairline: Color(0xFF27303C),
      accent: Color(0xFFD8A657),
      primary: Color(0xFFD8A657),
      onPrimary: Color(0xFF14110B),
      gold: Color(0xFFD8A657),
      olive: Color(0xFF8FB08A));

  /// Daylight: stone-white paper, graphite ink, bronze.
  static const rose = HolyTheme(
      id: 'rose',
      name: 'Limestone',
      paper: Color(0xFFEFECE6),
      surface: Color(0xFFFBFAF7),
      sunk: Color(0xFFE4E0D8),
      ink: Color(0xFF1A1F26),
      muted: Color(0xFF545B66),
      hairline: Color(0xFFD7D2C8),
      accent: Color(0xFF85561C),
      primary: Color(0xFF1F2630),
      onPrimary: Color(0xFFF5F1E8),
      gold: Color(0xFFA77B33),
      olive: Color(0xFF4E6B4A));
  static const lavender = HolyTheme(
      id: 'lavender',
      name: 'Iron',
      isDark: true,
      paper: Color(0xFF121314),
      surface: Color(0xFF1C1D1F),
      sunk: Color(0xFF0B0C0D),
      ink: Color(0xFFEDEDED),
      muted: Color(0xFFA3A6AA),
      hairline: Color(0xFF2E3033),
      accent: Color(0xFFC9CED4),
      primary: Color(0xFFE4E6E9),
      onPrimary: Color(0xFF141516),
      gold: Color(0xFFC9A15F),
      olive: Color(0xFF9DB394));
  static const sunrise = HolyTheme(
      id: 'sunrise',
      name: 'Ember',
      isDark: true,
      paper: Color(0xFF140F0C),
      surface: Color(0xFF1F1813),
      sunk: Color(0xFF0D0907),
      ink: Color(0xFFF4EAE0),
      muted: Color(0xFFBCA999),
      hairline: Color(0xFF352A21),
      accent: Color(0xFFE8924D),
      primary: Color(0xFFE8924D),
      onPrimary: Color(0xFF1A0F08),
      gold: Color(0xFFE2A55B),
      olive: Color(0xFFA3B57F));
  static const pearl = HolyTheme(
      id: 'pearl',
      name: 'Sandstone',
      paper: Color(0xFFF3EDE3),
      surface: Color(0xFFFCF9F3),
      sunk: Color(0xFFE9E0D2),
      ink: Color(0xFF2A231C),
      muted: Color(0xFF625646),
      hairline: Color(0xFFDDD2C0),
      accent: Color(0xFF925529),
      primary: Color(0xFF3A2E24),
      onPrimary: Color(0xFFFBF6EE),
      gold: Color(0xFFA7793A),
      olive: Color(0xFF5A6B45));
  static const sage = HolyTheme(
      id: 'sage',
      name: 'Cedar',
      isDark: true,
      paper: Color(0xFF0F1512),
      surface: Color(0xFF17201B),
      sunk: Color(0xFF0A0F0C),
      ink: Color(0xFFEBF0EA),
      muted: Color(0xFFA4B2A7),
      hairline: Color(0xFF27332C),
      accent: Color(0xFFA9C79A),
      primary: Color(0xFFA9C79A),
      onPrimary: Color(0xFF0F1A12),
      gold: Color(0xFFCDB077),
      olive: Color(0xFFA9C79A));
  static const midnightRose = HolyTheme(
      id: 'midnight-rose',
      name: 'Midnight',
      isDark: true,
      paper: Color(0xFF0B1020),
      surface: Color(0xFF141B30),
      sunk: Color(0xFF070A15),
      ink: Color(0xFFEEF1F8),
      muted: Color(0xFFA8B1C7),
      hairline: Color(0xFF242D47),
      accent: Color(0xFF93B4FF),
      primary: Color(0xFFDCE5FF),
      onPrimary: Color(0xFF10172B),
      gold: Color(0xFFD6B672),
      olive: Color(0xFF9FC29A));
  static const starlight = HolyTheme(
      id: 'starlight',
      name: 'Slate',
      paper: Color(0xFFECEFF2),
      surface: Color(0xFFFAFBFC),
      sunk: Color(0xFFDFE4E9),
      ink: Color(0xFF18202A),
      muted: Color(0xFF4F5B68),
      hairline: Color(0xFFD1D8DF),
      accent: Color(0xFF2D5A86),
      primary: Color(0xFF1E2B3A),
      onPrimary: Color(0xFFF2F5F8),
      gold: Color(0xFF9E7A3A),
      olive: Color(0xFF4C6A4F));
  static const all = [
    blush,
    rose,
    lavender,
    sunrise,
    sage,
    midnightRose,
    pearl,
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
