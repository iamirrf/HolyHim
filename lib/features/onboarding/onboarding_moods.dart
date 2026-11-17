// Ported from Cognein; see store/v2-design-ports.json.
import 'package:flutter/material.dart';
import '../../design/widgets/animated_mesh_background.dart';

/// One step's light: the dark field, the bright colour for the controls on
/// it, and the soft colour of the light drifting in its cards.
@immutable
class OnboardingMood {
  final MeshTheme mesh;

  /// Selection, progress, checks and small headings. Light enough to read
  /// on the dark field, and to carry dark ink when it fills a control.
  final Color accent;

  /// The light the field is lit with, for particles and glowing cards.
  final Color glow;
  const OnboardingMood(this.mesh, this.accent, this.glow);

  static OnboardingMood lerp(OnboardingMood a, OnboardingMood b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    return OnboardingMood(MeshTheme.lerp(a.mesh, b.mesh, t),
        Color.lerp(a.accent, b.accent, t)!, Color.lerp(a.glow, b.glow, t)!);
  }
}

/// The light behind each step of the welcome: the hour before sunrise.
///
/// A dark field with one low light drifting through it, and the bright
/// colour kept for the controls. Every mood is one hue laid onto the same
/// five roles, so the field moves from one to the next as a single change
/// of colour while a page turns.
///
/// The welcome is a watch kept until morning: blue hour while he gives his
/// name, slate and iron while he says what he needs and where he is, ember
/// as the questions get honest, brass as his first week and his road
/// appear, and first light on Day 1 and the offer.
///
/// Each field's brightest light stays under the line where bone ink keeps
/// 7:1 and secondary text 4.5:1 (test/welcome_contrast_test.dart).
class OnboardingMoods {
  const OnboardingMoods._();

  /// * base gradient  `[abyss, elevated, accentBright, accentMid, deep]`
  /// * blob 1 (drift) `elevated -> accentMid`
  /// * blob 2 (large) `deep -> abyss`, which keeps the field dark
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

  /// Navy before dawn, brass to press.
  static final blueHour = _mood(
      0xFF0A0E14, 0xFF0D131C, 0xFF121A26, 0xFF1C2C42, 0xFF2B4466, 0xFFD8A657);

  /// Cold stone, light slate blue.
  static final slate = _mood(
      0xFF0C0F13, 0xFF11151B, 0xFF171C24, 0xFF27303D, 0xFF3E4B5C, 0xFFB8C7D9);

  /// Charcoal and steel.
  static final iron = _mood(
      0xFF0E0F10, 0xFF131416, 0xFF1A1C1E, 0xFF2A2D31, 0xFF44484E, 0xFFCDD2D8);

  /// A low fire: deep brown, copper.
  static final ember = _mood(
      0xFF100B09, 0xFF160F0B, 0xFF1E140F, 0xFF3A2115, 0xFF6A361C, 0xFFE8924D);

  /// The sky warming over the horizon: brass.
  static final brassDawn = _mood(
      0xFF0E0F12, 0xFF13130F, 0xFF1A1812, 0xFF33291A, 0xFF5A4424, 0xFFE2B66A);

  /// The first line of sun: navy with a warm horizon, pale gold.
  static final firstLight = _mood(
      0xFF0B0F15, 0xFF101620, 0xFF161E2A, 0xFF3A3123, 0xFF5E4A2C, 0xFFF2D7A6);

  /// The engine's names for the moods its screens ask for by name: the
  /// offer stands in first light with brass for its controls and its card.
  static final pearl = firstLight;
  static final rose = brassDawn;

  /// Every mood, for checks.
  static final all = [blueHour, slate, iron, ember, brassDawn, firstLight];

  /// One mood per step, in step order.
  static final steps = <OnboardingMood>[
    blueHour, // name
    slate, // birthday
    iron, // what he needs
    ember, // where he is right now
    blueHour, // a word about the Bible
    brassDawn, // his first week
    slate, // his daily note
    iron, // building
    ember, // his letter
    firstLight, // Day 1
    firstLight, // the offer
  ];
}
