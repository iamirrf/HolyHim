import 'package:flutter/material.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/features/home/saved_tab.dart';

/// Shared chrome keeps the reading gesture and bookmark in the same places.
class LessonHeader extends StatelessWidget {
  final int day, index, count;
  final VoidCallback? onClose;
  const LessonHeader(
      {super.key,
      required this.day,
      required this.index,
      required this.count,
      required this.onClose});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(children: [
            Row(children: [
              IconButton(
                  tooltip: 'Close lesson',
                  onPressed: onClose,
                  icon: const Icon(Icons.close)),
              Expanded(
                  child: Text('Day $day · ${index + 1} of $count',
                      textAlign: TextAlign.center, style: HolyTypography.body)),
              SaveLessonButton(day: day),
            ]),
            Semantics(
                label: 'Lesson progress',
                value: '${index + 1} of $count cards',
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                        tween: Tween(end: (index + 1) / count),
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 380),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => LinearProgressIndicator(
                            value: value,
                            minHeight: 10,
                            backgroundColor: AppColors.divider)))),
          ])));
}

class LessonRecoveryFrame extends StatelessWidget {
  final Widget child;
  const LessonRecoveryFrame({super.key, required this.child});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => Column(children: [
            Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: IconButton(
                        tooltip: 'Close lesson',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close)))),
            Expanded(
                child: Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24), child: child))),
          ]));
}
