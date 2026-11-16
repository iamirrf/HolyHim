import 'package:flutter/widgets.dart';

/// Three families, each with one job.
///
/// * Cormorant Garamond: display and accent. Titles, verse pull-quotes,
///   numerals, "Amen" and the wordmark. Never below 22 pt: its fine hairlines
///   and small x-height need size to read.
/// * Lora: reading. Lesson prose at 19 to 22 pt.
/// * Manrope: interface. Buttons, labels, tabs and settings.
class HolyTypography {
  HolyTypography._();
  static const _display = 'CormorantGaramond';
  static const _reading = 'Lora';
  static const _ui = 'Manrope';

  /// Emoji in any style come from the system's colour emoji font. iOS falls
  /// back to it anyway; naming it lets screenshot renders draw it too.
  static const _emoji = ['Apple Color Emoji'];

  static const display = TextStyle(
      fontFamily: _display,
      fontFamilyFallback: _emoji,
      fontSize: 46,
      height: 1.02,
      fontWeight: FontWeight.w600,
      letterSpacing: -.6);
  static const title = TextStyle(
      fontFamily: _display,
      fontFamilyFallback: _emoji,
      fontSize: 34,
      height: 1.08,
      fontWeight: FontWeight.w600,
      letterSpacing: -.3);
  static const headline = TextStyle(
      fontFamily: _display,
      fontFamilyFallback: _emoji,
      fontSize: 27,
      height: 1.12,
      fontWeight: FontWeight.w600,
      letterSpacing: -.1);

  /// Scripture as a pull-quote.
  static const verse = TextStyle(
      fontFamily: _display,
      fontFamilyFallback: _emoji,
      fontSize: 29,
      height: 1.24,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.italic);

  /// Long-form lesson prose.
  static const reading = TextStyle(
      fontFamily: _reading,
      fontFamilyFallback: _emoji,
      fontSize: 20,
      height: 1.55,
      fontWeight: FontWeight.w400);
  static const readingItalic = TextStyle(
      fontFamily: _reading,
      fontFamilyFallback: _emoji,
      fontSize: 20,
      height: 1.55,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.italic);

  static const ui = TextStyle(
      fontFamily: _ui,
      fontFamilyFallback: _emoji,
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w500);
  static const body = TextStyle(
      fontFamily: _ui,
      fontFamilyFallback: _emoji,
      fontSize: 15,
      height: 1.45,
      fontWeight: FontWeight.w500);
  static const label = TextStyle(
      fontFamily: _ui,
      fontFamilyFallback: _emoji,
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w600);
  static const caption = TextStyle(
      fontFamily: _ui,
      fontFamilyFallback: _emoji,
      fontSize: 13,
      height: 1.35,
      fontWeight: FontWeight.w500);
  static const button = TextStyle(
      fontFamily: _ui,
      fontFamilyFallback: _emoji,
      fontSize: 16,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: .1);
  static const eyebrow = TextStyle(
      fontFamily: _ui,
      fontFamilyFallback: _emoji,
      fontSize: 11.5,
      height: 1.3,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6);

  /// Numerals in counters and dates.
  static const numeral = TextStyle(
      fontFamily: _display,
      fontFamilyFallback: _emoji,
      fontSize: 40,
      height: 1,
      fontWeight: FontWeight.w600,
      fontFeatures: [FontFeature.liningFigures()]);

  /// Accent line in italic display, e.g. "Amen."
  static const accent = TextStyle(
      fontFamily: _display,
      fontFamilyFallback: _emoji,
      fontSize: 36,
      height: 1.1,
      fontWeight: FontWeight.w600,
      fontStyle: FontStyle.italic);

  static const wordmark = TextStyle(
      fontFamily: _display,
      fontFamilyFallback: _emoji,
      fontSize: 40,
      height: 1,
      fontWeight: FontWeight.w600,
      letterSpacing: -.4);
}

/// **Holy** in roman, *Her* in italic.
class Wordmark extends StatelessWidget {
  final double size;
  final Color color;
  const Wordmark({super.key, this.size = 40, required this.color});
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'HolyHim',
      excludeSemantics: true,
      child: Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Holy'),
            TextSpan(
                text: 'Her',
                style: const TextStyle(fontStyle: FontStyle.italic)
                    .copyWith(letterSpacing: -.2)),
          ]),
          textScaler: TextScaler.noScaling,
          style:
              HolyTypography.wordmark.copyWith(fontSize: size, color: color)));
}
