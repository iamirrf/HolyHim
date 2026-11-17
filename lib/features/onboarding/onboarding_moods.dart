// Ported from Cognein; see store/v2-design-ports.json.
import 'package:flutter/material.dart';
import '../../design/widgets/animated_mesh_background.dart';

/// One step's light: the pale field, the strong colour for the controls on
/// it, and the soft colour of the light drifting in its cards.
@immutable
class OnboardingMood {
  final MeshTheme mesh;

  /// Selection, progress, checks and small headings. Deep enough to read on
  /// the near-white field.
  final Color accent;

  /// The pastel the field is lit with, for particles and glowing cards.
  final Color glow;
  const OnboardingMood(this.mesh, this.accent, this.glow);

  static OnboardingMood lerp(OnboardingMood a, OnboardingMood b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    return OnboardingMood(MeshTheme.lerp(a.mesh, b.mesh, t),
        Color.lerp(a.accent, b.accent, t)!, Color.lerp(a.glow, b.glow, t)!);
  }
}

/// The light behind each step of the welcome.
///
/// Cognein's light-mode pattern: a near-white field with one pastel orb
/// drifting through it, and strong colour kept for the controls. Every mood
/// is one hue laid onto the same five roles, so the field moves from one to
/// the next as a single change of colour while a page turns.
///
/// The walk is a morning: blush while she introduces herself, cream gold for
/// her birthday, rose and lilac while she says what she carries, peach as her
/// first week appears, and pearl as her walk is made.
class OnboardingMoods {
  const OnboardingMoods._();

  /// * base gradient  `[abyss, elevated, accentBright, accentMid, deep]`
  /// * blob 1 (drift) `elevated -> accentMid`
  /// * blob 2 (large) `deep -> abyss`, which keeps the field pale
  /// * blob 3 (drift) `accentMid -> abyss`
  /// * blob 4 (orb)   `accentBright -> accentMid -> abyss`
  static OnboardingMood _mood(int abyss, int deep, int elevated, int accentMid,
          int accentBright, int accent) =>
      OnboardingMood(
          MeshTheme(
              baseColors: [
                Color(abyss),
                Color(elevated),
                Color(accentBright),
                Color(accentMid),
                Color(deep)
              ],
              b1Start: Color(elevated),
              b1End: Color(accentMid),
              b2Start: Color(deep),
              b2End: Color(abyss),
              b3Start: Color(accentMid),
              b3End: Color(abyss),
              b4Start: Color(accentBright),
              b4Mid: Color(accentMid),
              b4End: Color(abyss)),
          Color(accent),
          Color(accentBright));

  static final blush = _mood(
      0xFFFFFAF7, 0xFFFCEFEA, 0xFFF8E0DA, 0xFFF1C8C6, 0xFFE5A3AE, 0xFF9B4560);
  static final creamGold = _mood(
      0xFFFFFCF5, 0xFFFBF2E1, 0xFFF5E5C6, 0xFFEED5A4, 0xFFE2BA74, 0xFF8F6220);
  static final rose = _mood(
      0xFFFFF9FA, 0xFFFCEDF1, 0xFFF7DAE2, 0xFFF0BDCB, 0xFFE293AA, 0xFFA2405C);
  static final lilac = _mood(
      0xFFFCFAFF, 0xFFF3EEFA, 0xFFE7DDF4, 0xFFD6C5EC, 0xFFB99EDD, 0xFF6F5290);
  static final peach = _mood(
      0xFFFFFAF6, 0xFFFDEFE5, 0xFFF9DCC8, 0xFFF3C3A3, 0xFFEBA17C, 0xFF9C4F2B);
  static final pearl = _mood(
      0xFFFEFCF9, 0xFFF8F3EC, 0xFFF0E7DC, 0xFFE4D6C6, 0xFFD7BFA2, 0xFF7E5A55);

  /// One mood per step, in step order.
  static final steps = <OnboardingMood>[
    blush, // name
    creamGold, // birthday
    rose, // heart
    lilac, // season
    blush, // a word about the Bible
    peach, // your first week
    creamGold, // your daily note
    pearl, // building
    rose, // your letter
    peach, // Day 1
    pearl, // the offer
  ];
}
