import 'package:flutter/material.dart';
import '../../../design/design.dart';
import 'onboarding_tokens.dart';

/// The question at the top of a step, with an optional line beneath it.
///
/// The words arrive one after another in place. Every word is laid out from
/// the first frame and only its opacity changes, so the answers beneath
/// never shift while the question is still arriving.
class StepTitle extends StatelessWidget {
  final String text;
  final String? subtitle;
  final TextAlign textAlign;

  /// Larger, for the reveal steps that have no answers beneath them.
  final bool large;
  const StepTitle(
      {super.key,
      required this.text,
      this.subtitle,
      this.textAlign = TextAlign.start,
      this.large = false});

  @override
  Widget build(BuildContext context) {
    final centred = textAlign == TextAlign.center;
    final style = HolyTypography.title.copyWith(
        fontSize: large ? 36 : 32, color: OnboardingTokens.textPrimary);
    return ConstrainedBox(
        constraints: BoxConstraints(
            minHeight: subtitle == null ? OnboardingTokens.titleSlotHeight : 0),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: centred
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.stretch,
            children: [
              Semantics(
                  header: true,
                  // Reduce Motion gets the finished line as plain text.
                  child: MediaQuery.disableAnimationsOf(context)
                      ? Text(text, textAlign: textAlign, style: style)
                      : WordReveal(
                          key: ValueKey(text),
                          text: text,
                          textAlign: textAlign,
                          style: style)),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Rise(
                    delay: const Duration(milliseconds: 240),
                    distance: 8,
                    child: Text(subtitle!,
                        textAlign: textAlign,
                        style: HolyTypography.body
                            .copyWith(color: OnboardingTokens.textSecondary))),
              ],
            ]));
  }
}
