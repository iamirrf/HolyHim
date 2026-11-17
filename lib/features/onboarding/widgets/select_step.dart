// Ported from Cognein; see store/v2-design-ports.json.
import 'package:flutter/material.dart';
import '../../../design/design.dart';
import '../../../domain/onboarding_flow.dart';
import 'centered_step_content.dart';
import 'glass_option_card.dart';
import 'onboarding_tokens.dart';
import 'staggered_entrance.dart';
import 'step_title.dart';

/// A question with answers to tap: one answer, or up to [max].
///
/// Every answer is on screen at once. A question you have to scroll to read
/// is a question you answer badly, so when the answers would not fit one
/// column at a comfortable size they tighten, and then go two abreast.
class SelectStep extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Choice> choices;
  final List<String> selected;

  /// One for a single answer; more lets several be chosen.
  final int max;
  final Color accent;

  /// Receives the answer that was tapped. The step decides nothing itself.
  final ValueChanged<String> onTap;

  /// Asks for two columns whenever there is room for them.
  final bool preferGrid;
  const SelectStep(
      {super.key,
      required this.title,
      required this.choices,
      required this.selected,
      required this.accent,
      required this.onTap,
      this.subtitle,
      this.max = 1,
      this.preferGrid = false});

  void _tap(String id) {
    final chosen = selected.contains(id);
    if (!chosen && max > 1 && selected.length >= max) {
      // At the cap: say no with the hand, not with a message.
      HolyHaptics.error();
      return;
    }
    chosen && max > 1 ? HolyHaptics.chipDeselect() : HolyHaptics.chipSelect();
    onTap(id);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: OnboardingTokens.pageInsets(context),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StepTitle(text: title, subtitle: subtitle),
          const SizedBox(height: OnboardingTokens.titleGap),
          Expanded(child: CenteredStepContent(builder: (context, available) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final details = choices.any((c) => c.detail != null);
            final rowHeight = (details ? 62 : 56) * scale.clamp(1.0, 1.6);
            final compactHeight = (details ? 52 : 46) * scale.clamp(1.0, 1.6);
            final n = choices.length;
            final fitsRoomy =
                n * rowHeight + (n - 1) * OnboardingTokens.optionSpacing <=
                    available;
            final fitsCompact = n * compactHeight +
                    (n - 1) * OnboardingTokens.optionSpacingCompact <=
                available;
            final grid = preferGrid || !(fitsRoomy || fitsCompact);
            final compact = grid ? false : !fitsRoomy;
            final spacing = compact
                ? OnboardingTokens.optionSpacingCompact
                : OnboardingTokens.optionSpacing;
            final cards = [
              for (final c in choices)
                GlassOptionCard(
                    label: c.label,
                    detail: c.detail,
                    emoji: c.emoji,
                    selected: selected.contains(c.id),
                    accent: accent,
                    compact: compact,
                    tile: grid,
                    onTap: () => _tap(c.id)),
            ];
            return StaggeredEntrance(
                children: cards,
                builder: (items) => grid
                    ? _Grid(spacing: 10, children: items)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            for (var i = 0; i < items.length; i++) ...[
                              if (i > 0) SizedBox(height: spacing),
                              items[i],
                            ]
                          ]));
          })),
        ]));
  }
}

/// Two abreast, each row as tall as its taller card.
class _Grid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  const _Grid({required this.children, required this.spacing});
  @override
  Widget build(BuildContext context) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i += 2) ...[
              if (i > 0) SizedBox(height: spacing),
              IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Expanded(child: children[i]),
                    SizedBox(width: spacing),
                    Expanded(
                        child: i + 1 < children.length
                            ? children[i + 1]
                            : const SizedBox.shrink()),
                  ])),
            ]
          ]);
}
