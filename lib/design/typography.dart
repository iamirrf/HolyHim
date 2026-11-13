import 'package:flutter/widgets.dart';

import 'themes.dart';

/// "First Watch" type: two families, each with one job, always upright.
///
/// * Source Serif 4 Display (optical size 36): titles, verse pull-quotes,
///   numerals, "Amen" and the wordmark. Sturdy, low-contrast serifs that hold
///   up on photographs and dark paper.
/// * Source Serif 4 (optical size 20): lesson prose at 18 to 21 pt.
/// * Manrope: interface. Buttons, labels, tabs and settings.
class HolyTypography {
  HolyTypography._();
  static const _display = 'SourceSerif4Display';
  static const _reading = 'SourceSerif4';
  static const _ui = 'Manrope';

  static const display = TextStyle(
      fontFamily: _display,
      fontSize: 42,
      height: 1.06,
      fontWeight: FontWeight.w700,
      letterSpacing: -.9);
  static const title = TextStyle(
      fontFamily: _display,
      fontSize: 31,
      height: 1.1,
      fontWeight: FontWeight.w600,
      letterSpacing: -.6);
  static const headline = TextStyle(
      fontFamily: _display,
      fontSize: 24,
      height: 1.16,
      fontWeight: FontWeight.w600,
      letterSpacing: -.3);

  /// Scripture as a pull-quote: upright, measured, never decorative.
  static const verse = TextStyle(
      fontFamily: _display,
      fontSize: 25,
      height: 1.32,
      fontWeight: FontWeight.w500,
      letterSpacing: -.2);

  /// Long-form lesson prose.
  static const reading = TextStyle(
      fontFamily: _reading,
      fontSize: 19,
      height: 1.56,
      fontWeight: FontWeight.w400);

  /// Secondary prose lines (teasers, summaries). Upright: HolyHim has no
  /// italic cut, and a synthesised slant would look broken.
  static const readingItalic = TextStyle(
      fontFamily: _reading,
      fontSize: 19,
      height: 1.5,
      fontWeight: FontWeight.w500);

  static const ui = TextStyle(
      fontFamily: _ui,
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w500);
  static const body = TextStyle(
      fontFamily: _ui,
      fontSize: 15,
      height: 1.45,
      fontWeight: FontWeight.w500);
  static const label = TextStyle(
      fontFamily: _ui,
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w700);
  static const caption = TextStyle(
      fontFamily: _ui,
      fontSize: 13,
      height: 1.35,
      fontWeight: FontWeight.w500);
  static const button = TextStyle(
      fontFamily: _ui,
      fontSize: 16,
      height: 1.2,
      fontWeight: FontWeight.w800,
      letterSpacing: .2);
  static const eyebrow = TextStyle(
      fontFamily: _ui,
      fontSize: 11.5,
      height: 1.3,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.8);

  /// Numerals in counters and dates.
  static const numeral = TextStyle(
      fontFamily: _display,
      fontSize: 40,
      height: 1,
      fontWeight: FontWeight.w700,
      fontFeatures: [FontFeature.liningFigures()]);

  /// The closing word, e.g. "Amen."
  static const accent = TextStyle(
      fontFamily: _display,
      fontSize: 36,
      height: 1.1,
      fontWeight: FontWeight.w700,
      letterSpacing: -.4);

  static const wordmark = TextStyle(
      fontFamily: _display,
      fontSize: 40,
      height: 1,
      fontWeight: FontWeight.w700,
      letterSpacing: -.8);
}

/// **Holy** in the given colour, **Him** in brass. Upright, one weight.
class Wordmark extends StatelessWidget {
  final double size;
  final Color color;

  /// Colour of "Him". Defaults to brass on photographs and the theme accent
  /// on paper.
  final Color? accent;
  const Wordmark({super.key, this.size = 40, required this.color, this.accent});
  @override
  Widget build(BuildContext context) {
    final him = accent ??
        (color == HolyTheme.photoInk
            ? HolyTheme.photoBrass
            : HolyThemeScope.of(context).accent);
    return Semantics(
        label: 'HolyHim',
        excludeSemantics: true,
        child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Holy'),
              TextSpan(text: 'Him', style: TextStyle(color: him)),
            ]),
            textScaler: TextScaler.noScaling,
            style: HolyTypography.wordmark
                .copyWith(fontSize: size, color: color)));
  }
}
