import 'package:holyher/services/reading_streak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/widgets/holy_material.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/core/theme/app_theme.dart';

/// Shared fading tint adapted from AppTopBar's .70/.58/.38/.16/0 ramp.
class HolyHeader extends ConsumerWidget {
  final VoidCallback onProgress;
  const HolyHeader({super.key, required this.onProgress});
  @override
  Widget build(BuildContext context, WidgetRef ref) => useHolyPalette(
      context,
      () => HolyFadingMaterial(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(children: [
                const HolyMark(size: 36),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('HolyHer',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600))),
                HolyPressable(
                    label:
                        'Your calendar, ${ref.watch(readingStreakProvider).current} day streak',
                    onPressed: onProgress,
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                            color: AppColors.pearl.withValues(alpha: .72),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.pearl)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.local_fire_department_outlined,
                              size: 20, color: AppColors.accent),
                          const SizedBox(width: 6),
                          Text('${ref.watch(readingStreakProvider).current}',
                              style: HolyTypography.action.copyWith(
                                  color: AppColors.accentDark,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ])),
                        ])))
              ]))));
}
