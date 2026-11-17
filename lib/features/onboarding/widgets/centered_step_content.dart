// Ported from Cognein; see store/v2-design-ports.json.
import 'package:flutter/material.dart';

/// Centres a step's content in the space left below its question.
///
/// Onboarding never scrolls, so a step has to fit whatever room the chrome
/// leaves it. This centres the block rather than stretching it, which keeps a
/// two-option question and a five-option one both balanced instead of one being
/// spread across the screen.
///
/// The scroll view is a backstop, not a feature: its physics never let it move.
/// It is here so that content which beats every density lever — the largest
/// accessibility text sizes — clips instead of throwing an overflow.
class CenteredStepContent extends StatelessWidget {
  /// Built with the height available, so callers can pick a density before
  /// laying anything out.
  final Widget Function(BuildContext context, double available) builder;

  /// Forms must remain reachable when the keyboard or large text reduces room.
  final bool scrollable;

  const CenteredStepContent({
    super.key,
    required this.builder,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: scrollable
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: builder(context, constraints.maxHeight),
          ),
        );
      },
    );
  }
}
