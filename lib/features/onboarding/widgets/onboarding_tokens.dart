// Ported from Cognein; see store/v2-design-ports.json.
import 'package:flutter/material.dart';

/// Surface tokens for the welcome: white glass on a pale, moving field.
///
/// Cognein's light set in HolyHim's colours: plum ink for words, white glass
/// at part opacity for cards, and one solid plum for the button, so the only
/// strong colour on a step is the thing to press and what she has chosen.
class OnboardingTokens {
  const OnboardingTokens._();

  /// The First Light theme's plum ink.
  static const Color ink = Color(0xFF33202A);
  static const Color textPrimary = ink;

  /// 7:1 on white glass, 5:1 on the field's deepest tint.
  static const Color textSecondary = Color(0xFF6A525D);

  /// 5:1 on white glass: small print on glass or a bar, never on the orb.
  static const Color textTertiary = Color(0xFF7F6873);

  /// The button and anything that must look pressable.
  static const Color plum = Color(0xFF4A2638);
  static const Color onPlum = Color(0xFFFFF8F2);

  static const Color white = Colors.white;

  /// A hairline of plum, for edges on white.
  static Color get hairline => ink.withValues(alpha: .10);

  /// Unselected card: white glass with a bright rim.
  static Color get cardFillTop => white.withValues(alpha: .80);
  static Color get cardFillBottom => white.withValues(alpha: .60);
  static Color get cardBorder => white.withValues(alpha: .95);

  /// Selected card: the step's colour washed into the glass, with its rim.
  static Color selectedFillTop(Color accent) =>
      Color.alphaBlend(accent.withValues(alpha: .12), white);
  static Color selectedFillBottom(Color accent) => Color.alphaBlend(
      accent.withValues(alpha: .06), white.withValues(alpha: .86));
  static Color selectedBorder(Color accent) => accent.withValues(alpha: .78);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
            color: plum.withValues(alpha: .08),
            blurRadius: 18,
            offset: const Offset(0, 6)),
      ];

  static List<BoxShadow> selectedShadow(Color accent) => [
        BoxShadow(
            color: accent.withValues(alpha: .22),
            blurRadius: 20,
            offset: const Offset(0, 6)),
      ];

  /// The button, waiting for an answer: the same plum, faded back.
  static Color get ctaDisabledFill => plum.withValues(alpha: .16);
  static Color get ctaDisabledLabel => plum.withValues(alpha: .46);
  static List<BoxShadow> get ctaShadow => [
        BoxShadow(
            color: plum.withValues(alpha: .30),
            blurRadius: 24,
            offset: const Offset(0, 10)),
      ];

  /// A content surface: the first-week card, the letter, the Day 1 card.
  static Color get panelFillTop => white.withValues(alpha: .82);
  static Color get panelFillBottom => white.withValues(alpha: .62);
  static Color get panelBorder => white.withValues(alpha: .95);

  /// The base of a card with light drifting in it: near-white, so the
  /// step's own colour does the glowing.
  static const List<Color> glowBase = [Color(0xFFFFFFFF), Color(0xFFFFF8F4)];

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

  static const Duration pageTransition = Duration(milliseconds: 680);
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
