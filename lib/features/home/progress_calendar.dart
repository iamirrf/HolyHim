import 'package:holyher/services/reading_streak.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/streak_service.dart';

class ProgressCalendar extends ConsumerStatefulWidget {
  const ProgressCalendar({super.key});
  @override
  ConsumerState<ProgressCalendar> createState() => _ProgressCalendarState();
}

class _ProgressCalendarState extends ConsumerState<ProgressCalendar> {
  DateTime? _month, _selected;
  static const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final progress = ref.watch(progressProvider),
        streak = ref.watch(readingStreakProvider);
    final today =
        accountCalendarTime(ref.read(localClockProvider)(), progress.timeZone);
    final completedDates = {
      ...progress.readingDates,
      ...progress.completionDates.values
    };
    _month ??= DateTime(today.year, today.month);
    final month = _month!,
        days = DateTime(month.year, month.month + 1, 0).day,
        offset = month.weekday % 7;
    final completedThisMonth = completedDates
        .where((date) => date.startsWith(
            '${month.year}-${month.month.toString().padLeft(2, '0')}'))
        .length;
    String key(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    bool same(DateTime? a, DateTime b) =>
        a != null && a.year == b.year && a.month == b.month && a.day == b.day;
    return HolyScaffold(
        title: 'Your journey',
        body: ReadingWidth(
            child: ListView(padding: const EdgeInsets.all(24), children: [
          Row(children: [
            Expanded(
                child: Text('${months[month.month - 1]} ${month.year}',
                    style: HolyTypography.heading)),
            IconButton(
                tooltip: 'Previous month',
                onPressed: () => setState(
                    () => _month = DateTime(month.year, month.month - 1)),
                icon: const Icon(Icons.chevron_left)),
            IconButton(
                tooltip: 'Next month',
                onPressed: () => setState(
                    () => _month = DateTime(month.year, month.month + 1)),
                icon: const Icon(Icons.chevron_right))
          ]),
          const SizedBox(height: 12),
          Text(
              '$completedThisMonth ${completedThisMonth == 1 ? 'day' : 'days'} with a completed lesson',
              style: HolyTypography.supporting
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          Row(children: [
            for (final d in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
              Expanded(
                  child: Text(d,
                      textAlign: TextAlign.center, style: HolyTypography.label))
          ]),
          const SizedBox(height: 8),
          LayoutBuilder(
              builder: (context, box) => Column(children: [
                    for (var row = 0; row < ((offset + days) / 7).ceil(); row++)
                      Row(children: [
                        for (var col = 0; col < 7; col++)
                          Expanded(child: Builder(builder: (context) {
                            final n = row * 7 + col - offset + 1;
                            if (n < 1 || n > days) {
                              return const SizedBox(height: 48);
                            }
                            final date = DateTime(month.year, month.month, n),
                                complete = completedDates.contains(key(date)),
                                selected = same(_selected, date),
                                isToday = same(today, date);
                            return Semantics(
                                label:
                                    '${months[month.month - 1]} $n, ${complete ? 'lesson completed' : 'no recorded completion'}${isToday ? ', today' : ''}',
                                selected: selected,
                                child: HolyPressable(
                                    onPressed: () =>
                                        setState(() => _selected = date),
                                    child: Container(
                                        margin: const EdgeInsets.all(2),
                                        constraints:
                                            const BoxConstraints(minHeight: 44),
                                        decoration: BoxDecoration(
                                            color: selected
                                                ? AppColors.accent
                                                : complete
                                                    ? AppColors.surface
                                                    : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                                selected ? 14 : 24),
                                            border: isToday
                                                ? Border.all(
                                                    color: AppColors.accent,
                                                    width: 1.5)
                                                : null),
                                        child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text('$n',
                                                  style: HolyTypography
                                                      .supporting
                                                      .copyWith(
                                                          color: selected
                                                              ? Colors.white
                                                              : AppColors
                                                                  .textPrimary,
                                                          fontFeatures: const [
                                                        FontFeature
                                                            .tabularFigures()
                                                      ])),
                                              if (complete)
                                                Icon(Icons.check_rounded,
                                                    size: 12,
                                                    color: selected
                                                        ? Colors.white
                                                        : AppColors.accent)
                                            ]))));
                          }))
                      ])
                  ])),
          const SizedBox(height: 20),
          if (_selected != null)
            InlineMessage(
                '${months[_selected!.month - 1]} ${_selected!.day} · ${completedDates.contains(key(_selected!)) ? 'A lesson completed.' : 'No recorded completion on this date.'}'),
          const SizedBox(height: 12),
          Row(children: [
            for (final stat in [
              ('Current streak', streak.current),
              ('Longest streak', streak.longest)
            ])
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('${stat.$2}',
                        style: HolyTypography.heading.copyWith(
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ])),
                    const SizedBox(height: 4),
                    Text(stat.$1,
                        style: HolyTypography.supporting
                            .copyWith(color: AppColors.textSecondary))
                  ]))
          ]),
          const SizedBox(height: 16),
          const SizedBox(height: 8),
          Text('Journey timezone · ${progress.timeZone ?? 'Not yet set'}',
              style: HolyTypography.supporting
                  .copyWith(color: AppColors.textSecondary)),
          if (progress.completedCount > progress.completionDates.length)
            const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                    'Earlier lessons are counted in your total. Their completion dates are not available.',
                    style: HolyTypography.supporting)),
          const SectionLabel('Milestones'),
          for (final n in [1, 7, 30, 90, 180, 365])
            _MilestoneRow(
                goal: n,
                completed: progress.completedCount,
                permanentlyEarned: progress.earnedBadges.contains(n)),
        ])));
  }
}

class _MilestoneRow extends StatelessWidget {
  final int goal, completed;
  final bool permanentlyEarned;
  const _MilestoneRow(
      {required this.goal,
      required this.completed,
      this.permanentlyEarned = false});
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final earned = permanentlyEarned || completed >= goal;
    final measure = TextPainter(
        text: TextSpan(text: '$goal', style: HolyTypography.action),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context))
      ..layout();
    final diameter = math.max(52.0, measure.width + 18);
    measure.dispose();
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          SizedBox(
              width: diameter + 4,
              height: diameter + 4,
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                    width: diameter,
                    height: diameter,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: earned
                                ? [Colors.white, AppColors.surface]
                                : [
                                    const Color(0xFFF9F4F7),
                                    const Color(0xFFEDE2E9)
                                  ]),
                        border: Border.all(
                            color: earned
                                ? AppColors.accent.withValues(alpha: .3)
                                : Colors.white,
                            width: 1.3),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.accentDark
                                  .withValues(alpha: earned ? .07 : .025),
                              blurRadius: 12,
                              offset: const Offset(0, 5))
                        ]),
                    child: Text('$goal',
                        style: HolyTypography.action.copyWith(
                            color: earned
                                ? AppColors.accentDark
                                : AppColors.textSecondary))),
                if (earned)
                  Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.background, width: 2)),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 12)))
              ])),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('$goal lessons', style: HolyTypography.action),
                const SizedBox(height: 5),
                Text(
                    earned
                        ? 'Milestone reached'
                        : '${(goal - completed).clamp(0, goal)} lessons to go',
                    style: HolyTypography.supporting.copyWith(
                        color: earned
                            ? AppColors.success
                            : AppColors.textSecondary))
              ])),
          if (!earned)
            Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Icon(Icons.lock_outline_rounded,
                    size: 18, color: AppColors.textSecondary))
        ]));
  }
}
