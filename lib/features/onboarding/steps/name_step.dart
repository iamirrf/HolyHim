import 'package:flutter/material.dart';
import '../../../design/design.dart';
import '../onboarding_copy.dart';
import '../widgets/onboarding_tokens.dart';
import '../widgets/step_title.dart';

/// Her first name. The field opens with the keyboard up, and the button
/// below rides the keyboard, so the whole step is one line of typing.
class NameStep extends StatelessWidget {
  final TextEditingController controller;
  final String? error;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  const NameStep(
      {super.key,
      required this.controller,
      required this.error,
      required this.onChanged,
      required this.onSubmitted});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      // A backstop for very large text with the keyboard up; at normal
      // sizes there is nothing to scroll.
      physics: const ClampingScrollPhysics(),
      padding: OnboardingTokens.pageInsets(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const StepTitle(
            text: OnboardingCopy.nameTitle,
            subtitle: OnboardingCopy.nameSubtitle),
        const SizedBox(height: OnboardingTokens.titleGap),
        Rise(
            delay: const Duration(milliseconds: 320),
            child: HolyField(
                controller: controller,
                label: OnboardingCopy.nameField,
                autofocus: true,
                error: error,
                maxLength: 40,
                capitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.givenName],
                textInputAction: TextInputAction.done,
                onChanged: onChanged,
                onSubmitted: (_) => onSubmitted())),
      ]));
}
