import 'package:flutter/material.dart';
import 'widgets/animated_mesh_background.dart';

/// HolyHim's adaptation of SunRize's whole-surface theme model.
@immutable
class HolyTheme {
  final String id, name;
  final bool isDark;
  final Color ink, muted, accent, glassTint, particle, navTint;
  final List<Color> colors;
  final List<Color> accentGradient;
  final List<Color> buttonGradient;
  Color get buttonInk => const Color(0xFF171106);
  Color get holdFill => Colors.black.withValues(alpha: .10);
  const HolyTheme(
      {required this.id,
      required this.name,
      required this.colors,
      required this.accent,
      this.isDark = false,
      this.ink = const Color(0xFFF2EFE9),
      this.muted = const Color(0xFF9AA3AB),
      this.glassTint = const Color(0xB8171C22),
      this.particle = const Color(0x66C9A227),
      this.navTint = const Color(0x26C9A227),
      this.accentGradient = const [Color(0xFFD4AF37), Color(0xFFC9A227)],
      this.buttonGradient = const [Color(0xFFD4AF37), Color(0xFFC9A227)]});

  MeshTheme meshAt(double mood) {
    final t = (mood / 3).clamp(0.0, 1.0);
    final c = List.generate(
        5, (i) => Color.lerp(colors[i], colors[(i + 1) % 5], t * .24)!);
    return MeshTheme(
        baseColors: c,
        b1Start: c[1].withValues(alpha: .65),
        b1End: c[3].withValues(alpha: .18),
        b2Start: c[2].withValues(alpha: .55),
        b2End: c[4].withValues(alpha: .28),
        b3Start: c[3].withValues(alpha: .55),
        b3End: c[0].withValues(alpha: .15),
        b4Start: c[4].withValues(alpha: .6),
        b4Mid: c[1].withValues(alpha: .25),
        b4End: c[0].withValues(alpha: 0));
  }

  MeshTheme get mesh => meshAt(0);

  static HolyTheme lerp(HolyTheme a, HolyTheme b, double t) => HolyTheme(
      id: b.id,
      name: b.name,
      isDark: t < .5 ? a.isDark : b.isDark,
      colors: List.generate(5, (i) => Color.lerp(a.colors[i], b.colors[i], t)!),
      ink: Color.lerp(a.ink, b.ink, t)!,
      muted: Color.lerp(a.muted, b.muted, t)!,
      accent: Color.lerp(a.accent, b.accent, t)!,
      glassTint: Color.lerp(a.glassTint, b.glassTint, t)!,
      particle: Color.lerp(a.particle, b.particle, t)!,
      navTint: Color.lerp(a.navTint, b.navTint, t)!,
      accentGradient: List.generate(
          2, (i) => Color.lerp(a.accentGradient[i], b.accentGradient[i], t)!),
      buttonGradient: List.generate(
          2, (i) => Color.lerp(a.buttonGradient[i], b.buttonGradient[i], t)!));
}

class HolyThemes {
  HolyThemes._();
  static const charcoal =
      HolyTheme(id: 'charcoal', name: 'Charcoal', isDark: true, accent: Color(0xFFC9A227), colors: [
    Color(0xFF0E1116),
    Color(0xFF101418),
    Color(0xFF171C22),
    Color(0xFF1F262E),
    Color(0xFF131920)
  ]);
  static const ember =
      HolyTheme(id: 'ember', name: 'Ember', isDark: true, accent: Color(0xFFD98E32), glassTint: Color(0xB81E1A16), particle: Color(0x66D98E32), navTint: Color(0x26D98E32), colors: [
    Color(0xFF120F0C),
    Color(0xFF171310),
    Color(0xFF1E1A16),
    Color(0xFF26201A),
    Color(0xFF15110D)
  ], accentGradient: [Color(0xFFE0A458), Color(0xFFC47F2A)], buttonGradient: [Color(0xFFD98E32), Color(0xFFC47F2A)]);
  static const bronze =
      HolyTheme(id: 'bronze', name: 'Bronze', isDark: true, accent: Color(0xFFA67C37), glassTint: Color(0xB81B1712), colors: [
    Color(0xFF100E0A),
    Color(0xFF14110C),
    Color(0xFF1B1712),
    Color(0xFF241E16),
    Color(0xFF120F0B)
  ], accentGradient: [Color(0xFFC9A227), Color(0xFFA67C37)], buttonGradient: [Color(0xFFD4AF37), Color(0xFFC9A227)]);
  static const slate =
      HolyTheme(id: 'slate', name: 'Slate', isDark: true, accent: Color(0xFFC9A227), glassTint: Color(0xB8171E26), colors: [
    Color(0xFF0D1117),
    Color(0xFF11161D),
    Color(0xFF171E26),
    Color(0xFF1F2831),
    Color(0xFF10151C)
  ]);
  static const forest =
      HolyTheme(id: 'forest', name: 'Forest', isDark: true, accent: Color(0xFFC9A227), glassTint: Color(0xB8161E17), colors: [
    Color(0xFF0C120E),
    Color(0xFF10160F),
    Color(0xFF161E17),
    Color(0xFF1E2A20),
    Color(0xFF0F150F)
  ]);
  static const iron =
      HolyTheme(id: 'iron', name: 'Iron', isDark: true, accent: Color(0xFFD4AF37), glassTint: Color(0xB81A1A1C), colors: [
    Color(0xFF0F0F10),
    Color(0xFF131315),
    Color(0xFF1A1A1C),
    Color(0xFF232326),
    Color(0xFF111113)
  ]);
  static const midnight =
      HolyTheme(id: 'midnight', name: 'Midnight', isDark: true, accent: Color(0xFFC9A227), glassTint: Color(0xB8121826), colors: [
    Color(0xFF090C12),
    Color(0xFF0C1017),
    Color(0xFF121826),
    Color(0xFF182031),
    Color(0xFF0B0E14)
  ]);
  static const goldfield =
      HolyTheme(id: 'goldfield', name: 'Gold', isDark: true, accent: Color(0xFFE3B93E), glassTint: Color(0xB81C1710), particle: Color(0x66E3B93E), navTint: Color(0x26E3B93E), colors: [
    Color(0xFF100D06),
    Color(0xFF14100A),
    Color(0xFF1C1710),
    Color(0xFF262017),
    Color(0xFF120E07)
  ], accentGradient: [Color(0xFFF0CE6B), Color(0xFFD4AF37)], buttonGradient: [Color(0xFFD4AF37), Color(0xFFB08A29)]);
  static const all = [
    charcoal,
    ember,
    bronze,
    slate,
    forest,
    iron,
    midnight,
    goldfield
  ];
  static HolyTheme byId(String id) => all.firstWhere((t) => t.id == id,
      orElse: () => charcoal);
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
      HolyThemes.charcoal;
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
