// Ported from Cognein; see store/v2-design-ports.json.
import 'package:flutter/material.dart';

/// Step progress as a row of dots, where the current step is a wide pill.
///
/// Steps behind him are filled, steps ahead are outlined. The pill's width
/// animates, so moving on reads as the row flowing forward.
class ProgressDots extends StatelessWidget {
  final int totalSteps;

  /// Zero-indexed.
  final int currentStep;
  final Color accentColor;
  const ProgressDots(
      {super.key,
      required this.totalSteps,
      required this.currentStep,
      required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
        label: 'Step ${currentStep + 1} of $totalSteps',
        child: ExcludeSemantics(
            child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < totalSteps; i++)
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: AnimatedContainer(
                            duration: reduced
                                ? Duration.zero
                                : const Duration(milliseconds: 520),
                            curve: Curves.easeOutCubic,
                            width: i == currentStep ? 26 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                                color: i <= currentStep
                                    ? accentColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: i <= currentStep
                                    ? null
                                    : Border.all(
                                        color:
                                            accentColor.withValues(alpha: .34)),
                                boxShadow: i == currentStep
                                    ? [
                                        BoxShadow(
                                            color: accentColor.withValues(
                                                alpha: .42),
                                            blurRadius: 8,
                                            spreadRadius: 1)
                                      ]
                                    : null))),
                ]))));
  }
}
