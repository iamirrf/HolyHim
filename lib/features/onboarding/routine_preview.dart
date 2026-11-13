import 'package:flutter/material.dart';
import '../../design/chapter_catalog.g.dart';
import '../../design/design.dart';
import '../../domain/personalized_plan.dart';
import '../common.dart';

class RoutinePreview extends StatelessWidget {
  final PersonalizedPlan plan;
  const RoutinePreview({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    final theme = HolyThemeScope.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Your daily rhythm',
          textAlign: TextAlign.center, style: HolyTypography.display),
      const SizedBox(height: 12),
      Text(plan.context, textAlign: TextAlign.center, style: muted(context)),
      const SizedBox(height: 26),
      Glass(
          radius: 28,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('THE MOMENT YOU CHOSE',
                style: HolyTypography.eyebrow.copyWith(color: theme.accent)),
            const SizedBox(height: 12),
            Text(plan.pace, style: HolyTypography.title),
            const SizedBox(height: 7),
            Text(
                plan.minutes == null
                    ? 'A flexible daily moment, with no planned minute total.'
                    : '${plan.minutes! * 30} minutes planned over 30 days',
                style: muted(context)),
            const SizedBox(height: 18),
            Text(plan.reminder, style: ui(context)),
            const SizedBox(height: 16),
            Text(plan.orientation, style: muted(context)),
            const SizedBox(height: 8),
            Text(plan.advice, style: muted(context)),
            const SizedBox(height: 8),
            Text(plan.encouragement, style: muted(context)),
          ])),
      const SizedBox(height: 24),
      const Text('Your first three chapters', style: HolyTypography.title),
      const SizedBox(height: 12),
      Row(
        children: [
          for (final day in [1, 6, 11])
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                              height: 140,
                              child: ArtImage(day: day, animate: false))),
                      const SizedBox(height: 7),
                      Text(ChapterCatalog.forDay(day)!.title,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: HolyTypography.ui.copyWith(fontSize: 11)),
                    ])))
        ],
      ),
    ]);
  }
}
