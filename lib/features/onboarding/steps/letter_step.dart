import 'package:flutter/material.dart';
import '../../../design/design.dart';
import '../../../domain/onboarding_flow.dart';
import '../letter.dart';
import '../onboarding_copy.dart';
import '../widgets/onboarding_tokens.dart';
import '../widgets/step_title.dart';

/// Her letter, in the same card the checklist drew itself in a moment ago.
class LetterStep extends StatelessWidget {
  final String name;
  final OnboardingAnswers answers;
  final bool reminderOn;
  final int reminderMinutes;

  /// The step's light, drifting in the card.
  final Color glow;
  const LetterStep(
      {super.key,
      required this.name,
      required this.answers,
      required this.reminderOn,
      required this.reminderMinutes,
      required this.glow});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 720;
    return Padding(
        padding: OnboardingTokens.pageInsets(context),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StepTitle(text: OnboardingCopy.letterTitle(name)),
          const SizedBox(height: 18),
          Expanded(
              child: GlowCard(
                  colors: OnboardingTokens.glowBase,
                  glow: glow,
                  blobScale: .75,
                  borderRadius: OnboardingTokens.panelRadius,
                  borderColor: OnboardingTokens.panelBorder,
                  shadows: OnboardingTokens.cardShadow,
                  padding: EdgeInsets.zero,
                  child: Center(
                      child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                              horizontal: compact ? 20 : 24,
                              vertical: compact ? 18 : 24),
                          child: PersonalLetter(
                              framed: false,
                              name: name,
                              answers: answers,
                              reminderOn: reminderOn,
                              reminderMinutes: reminderMinutes))))),
        ]));
  }
}
