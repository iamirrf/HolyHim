import 'package:flutter/material.dart';
import '../../../data/lessons.g.dart';
import '../../../design/art_catalog.dart';
import '../../../design/design.dart';
import '../onboarding_copy.dart';
import '../widgets/onboarding_tokens.dart';
import '../widgets/step_title.dart';

/// Day 1, shown as it is: its photograph, its title, its verse reference and
/// the line that opens it. The card rises into place.
class DayOneStep extends StatelessWidget {
  final Color accent;
  const DayOneStep({super.key, required this.accent});

  @override
  Widget build(BuildContext context) {
    final lesson = lessons.first;
    final radius = BorderRadius.circular(OnboardingTokens.panelRadius);
    return Padding(
        padding: OnboardingTokens.pageInsets(context),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(OnboardingCopy.dayOneLabel,
              style: HolyTypography.eyebrow.copyWith(color: accent)),
          const SizedBox(height: 6),
          const StepTitle(text: OnboardingCopy.dayOneTitle),
          const SizedBox(height: 10),
          Expanded(
              child: Rise(
                  delay: const Duration(milliseconds: 420),
                  distance: 34,
                  child: Semantics(
                      label:
                          'Day 1. ${lesson.title}. ${lesson.reference}. ${lesson.teaser}',
                      excludeSemantics: true,
                      child: DecoratedBox(
                          decoration:
                              BoxDecoration(borderRadius: radius, boxShadow: [
                            BoxShadow(
                                color: OnboardingTokens.shade
                                    .withValues(alpha: .45),
                                blurRadius: 32,
                                offset: const Offset(0, 16)),
                          ]),
                          child: ClipRRect(
                              borderRadius: radius,
                              child: Stack(fit: StackFit.expand, children: [
                                BundledArt(
                                    asset: HolyArtCatalog.assetForDay(1),
                                    alignment: const Alignment(0, -.2),
                                    fallback: const ColoredBox(
                                        color: HolyTheme.photoShade)),
                                // A veil under the words, so they read on
                                // any photograph.
                                DecoratedBox(
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            stops: const [
                                      .12,
                                      .58,
                                      1
                                    ],
                                            colors: [
                                      HolyTheme.photoShade.withValues(alpha: 0),
                                      HolyTheme.photoShade
                                          .withValues(alpha: .62),
                                      HolyTheme.photoShade
                                          .withValues(alpha: .94)
                                    ]))),
                                DecoratedBox(
                                    decoration: BoxDecoration(
                                        borderRadius: radius,
                                        border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: .7),
                                            width: 1.2))),
                                Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        22, 20, 22, 22),
                                    child: SingleChildScrollView(
                                        child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  lesson.reference
                                                      .toUpperCase(),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: HolyTypography.eyebrow
                                                      .copyWith(
                                                          color: HolyTheme
                                                              .photoInk
                                                              .withValues(
                                                                  alpha: .86))),
                                              const SizedBox(height: 6),
                                              Text(lesson.title,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: HolyTypography.headline
                                                      .copyWith(
                                                          fontSize: 30,
                                                          color: HolyTheme
                                                              .photoInk)),
                                              const SizedBox(height: 8),
                                              Text(lesson.teaser,
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: HolyTypography.ui
                                                      .copyWith(
                                                          fontSize: 15.5,
                                                          height: 1.42,
                                                          color: HolyTheme
                                                              .photoInk
                                                              .withValues(
                                                                  alpha: .9))),
                                            ]))),
                              ])))))),
        ]));
  }
}
