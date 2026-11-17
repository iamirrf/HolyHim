// Ported from Cognein; see store/v2-design-ports.json.
import 'package:flutter/material.dart';

/// Surface tokens for the welcome: slate glass on a dark, moving field.
///
/// First Watch: bone ink for words, slate glass at part opacity for cards,
/// and one solid brass for the button, so the only strong colour on a step
/// is the thing to press and what he has chosen. The engine's names are
/// kept (`plum` is the button, `white` the glass) so upstream syncs stay
/// clean.
class OnboardingTokens {
  const OnboardingTokens._();

  /// Bone, the ink of every First Watch screen.
  static const Color ink = Color(0xFFF2EDE4);
  static const Color textPrimary = ink;

  /// 7:1 on the glass, 4.5:1 on the field's brightest light.
  static const Color textSecondary = Color(0xFFBFC6CF);

  /// 4.5:1 on the glass: small print on glass or a bar, never on the orb.
  static const Color textTertiary = Color(0xFFA2AAB5);

  /// The button and anything that must look pressable: brass.
  static const Color plum = Color(0xFFD8A657);
  static const Color onPlum = Color(0xFF14110B);

  /// The glass every card, bubble and panel is made of.
  static const Color white = Color(0xFF1A222D);

  /// Shadows fall dark on a dark field.
  static const Color shade = Color(0xFF000000);

  /// A hairline of bone, for edges on the glass.
  static Color get hairline => ink.withValues(alpha: .10);

  /// Unselected card: slate glass with a faint rim.
  static Color get cardFillTop => white.withValues(alpha: .80);
  static Color get cardFillBottom => white.withValues(alpha: .62);
  static Color get cardBorder => ink.withValues(alpha: .12);

  /// Selected card: the step's colour washed into the glass, with its rim.
  static Color selectedFillTop(Color accent) =>
      Color.alphaBlend(accent.withValues(alpha: .20), white);
  static Color selectedFillBottom(Color accent) => Color.alphaBlend(
      accent.withValues(alpha: .10), white.withValues(alpha: .88));
  static Color selectedBorder(Color accent) => accent.withValues(alpha: .85);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
            color: shade.withValues(alpha: .30),
            blurRadius: 18,
            offset: const Offset(0, 6)),
      ];

  static List<BoxShadow> selectedShadow(Color accent) => [
        BoxShadow(
            color: accent.withValues(alpha: .18),
            blurRadius: 20,
            offset: const Offset(0, 6)),
      ];

  /// The button, waiting for an answer: the same brass, faded back.
  static Color get ctaDisabledFill => plum.withValues(alpha: .16);
  static Color get ctaDisabledLabel => plum.withValues(alpha: .55);
  static List<BoxShadow> get ctaShadow => [
        BoxShadow(
            color: plum.withValues(alpha: .26),
            blurRadius: 24,
            offset: const Offset(0, 10)),
      ];

  /// A content surface: the first-week card, the letter, the Day 1 card.
  static Color get panelFillTop => white.withValues(alpha: .84);
  static Color get panelFillBottom => white.withValues(alpha: .68);
  static Color get panelBorder => ink.withValues(alpha: .12);

  /// The base of a card with light drifting in it: slate, so the step's own
  /// colour does the glowing.
  static const List<Color> glowBase = [Color(0xFF1C2430), Color(0xFF141B25)];

  static const double screenPadding = 24.0;
  static const double cardRadius = 18.0;
  static const double panelRadius = 26.0;
  static const double ctaRadius = 28.0;
  static const double ctaHeight = 56.0;

  /// Insets page content around the bars that float over it.
  ///
  /// The scaffold reports the heights of its top and bottom chrome through
  /// [MediaQuery] because the body runs behind both. A page uses this as
  /// padding, so rows can pass beneath the blur while the first and last
  /// controls rest clear of it.
  static EdgeInsets pageInsets(BuildContext context,
      {double top = 20, double bottom = 8}) {
    final chrome = MediaQuery.paddingOf(context);
    return EdgeInsets.fromLTRB(
        screenPadding, chrome.top + top, screenPadding, chrome.bottom + bottom);
  }

  /// The least room a title takes, so short and long questions start their
  /// answers at about the same height.
  static const double titleSlotHeight = 74.0;

  /// Gap between the question and the first answer.
  static const double titleGap = 22.0;

  static const double optionSpacing = 12.0;
  static const double optionSpacingCompact = 8.0;

  /// A step changing: the shared transition duration (320 ms).
  static const Duration pageTransition = Duration(milliseconds: 320);
  static const Curve pageCurve = Curves.easeInOutCubic;

  /// A glass panel in the flow's shape.
  static ShapeDecoration panel({double radius = panelRadius}) =>
      ShapeDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [panelFillTop, panelFillBottom]),
          shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(color: panelBorder)),
          shadows: cardShadow);
}
