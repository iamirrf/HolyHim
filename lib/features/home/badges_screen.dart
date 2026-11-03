import 'package:holyher/core/widgets/keepsake_medallion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/reading_service.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});
  static const names = [
    'The first step',
    'A faithful week',
    'Roots of hope',
    'Growing in grace',
    'Steady in love',
    'A year with God'
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Theme.of(context);
    final progress = ref.watch(progressProvider);
    return HolyScaffold(
        title: 'Keepsakes from your walk',
        body: ReadingWidth(
            maxWidth: 640,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              const Text('Small steps. Lasting grace.',
                  style: HolyTypography.heading),
              const SizedBox(height: 14),
              const Text(
                  'Earned through distinct readings. Every keepsake you earn stays yours, even when you miss a day.'),
              const SizedBox(height: 28),
              for (var i = 0; i < readingBadgeThresholds.length; i++)
                Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: GlassSurface(
                        child: Row(children: [
                      KeepsakeMedallion(
                          milestone: readingBadgeThresholds[i],
                          earned: progress.earnedBadges
                              .contains(readingBadgeThresholds[i]),
                          size: 72),
                      const SizedBox(width: 18),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(names[i], style: HolyTypography.section),
                            const SizedBox(height: 6),
                            Text(
                                '${readingBadgeThresholds[i]} distinct ${readingBadgeThresholds[i] == 1 ? 'reading' : 'readings'} · ${progress.earnedBadges.contains(readingBadgeThresholds[i]) ? 'Earned' : 'Still ahead'}',
                                style: HolyTypography.supporting)
                          ])),
                    ]))),
            ])));
  }
}
