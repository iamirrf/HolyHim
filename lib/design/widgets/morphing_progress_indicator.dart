import 'package:flutter/material.dart';

/// Step progress as a row of dots, where the current step is a wide pill.
///
/// Completed and current steps are filled; upcoming steps are outlined. The
/// width animates between 8 and 32, so advancing a step reads as the indicator
/// flowing forward rather than a bar jumping.
class MorphingProgressIndicator extends StatelessWidget {
  final int totalSteps;

  /// Zero-indexed.
  final int currentStep;

  final Color accentColor;

  const MorphingProgressIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isCompleted = index < currentStep;
        final isCurrent = index == currentStep;
        final isFilled = isCompleted || isCurrent;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            width: isCurrent ? 32 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isFilled ? accentColor : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: isFilled
                  ? null
                  : Border.all(
                      color: accentColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}
