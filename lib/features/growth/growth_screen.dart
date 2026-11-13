import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design/design.dart';
import '../../domain/badges.dart';
import '../../domain/calendar.dart';
import '../../domain/streak.dart';
import '../../services/repository.dart';
import '../../services/badge_share.dart';
import '../common.dart';

const _months = [
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

class GrowthScreen extends ConsumerStatefulWidget {
  const GrowthScreen({super.key});
  @override
  ConsumerState<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends ConsumerState<GrowthScreen> {
  final _scroll = ScrollController();
  DateTime? _month;
  double _offset = 0;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (mounted) setState(() => _offset = _scroll.offset);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _showBadge(WalkBadge badge, int index) {
    showBadgeReveal(context,
        title: badge.title,
        description: badge.description,
        earned: badge.earned,
        badgeId: badge.id,
        progress: '${badge.progress.clamp(0, badge.goal)} / ${badge.goal}',
        icon: _badgeIcon(index),
        onShare: badge.earned
            ? () => shareBadgeImage(context, badge, icon: _badgeIcon(index))
            : null);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(repositoryProvider);
    final now = localNow(DateTime.now(), state.profile.timeZone);
    final month = _month ?? DateTime(now.year, now.month);
    final streak =
        streakFor(state.completed, DateTime.now(), state.profile.timeZone);
    final stats = WalkStats.from(state.completed, state.saved);
    final badges = badgesFor(
        completed: state.completed,
        saved: state.saved,
        streak: streak,
        promiseStartedAt: state.profile.promiseStartedAt,
        timeZone: state.profile.timeZone);
    final dates = state.completed.values.toSet();
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: GlassTopBar(
            title: const Text('Growth', style: HolyTypography.title),
            centerTitle: false,
            automaticallyImplyLeading: false,
            scrollOffset: _offset,
            trailing:
                const Icon(CupertinoIcons.leaf_arrow_circlepath, color: rose)),
        body: PageBody(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.paddingOf(context).top + 86, 24, 150),
            children: [
              const Eyebrow('Small moments. Deep roots.'),
              const SizedBox(height: 12),
              const Text('Look how far\nyou have come.',
                  style: HolyTypography.display),
              const SizedBox(height: 28),
              Reveal(
                  child: _GrowthHeroSurface(
                      empty: state.completed.isEmpty,
                      child: Glass(
                          elevation: 3,
                          child: Column(children: [
                            const Icon(CupertinoIcons.flame_fill,
                                size: 34, color: rose),
                            const SizedBox(height: 10),
                            FittedBox(
                                fit: BoxFit.scaleDown,
                                child: RollingNumber(
                                    value: streak.current,
                                    style: HolyTypography.display.copyWith(
                                        fontSize: 78,
                                        height: 1.1,
                                        color: rose))),
                            Text(
                                streak.current == 1
                                    ? 'day of faithfulness'
                                    : 'days of faithfulness',
                                style: HolyTypography.reading
                                    .copyWith(fontSize: 18)),
                            const SizedBox(height: 24),
                            Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 28,
                                runSpacing: 14,
                                children: [
                                  _LittleStat(
                                      label: 'Longest streak',
                                      value: '${streak.longest} days'),
                                  _LittleStat(
                                      label: 'Grace days',
                                      value: '${streak.graceDays} of 2')
                                ]),
                            const SizedBox(height: 20),
                            Text(
                                'A grace day is earned for every seven days in a row. It gently carries your streak through a missed day.',
                                textAlign: TextAlign.center,
                                style: muted(context).copyWith(fontSize: 12))
                          ])))),
              const SizedBox(height: 26),
              Glass(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Row(children: [
                      IconButton(
                          tooltip: 'Previous month',
                          onPressed: () => setState(() =>
                              _month = DateTime(month.year, month.month - 1)),
                          icon: const Icon(CupertinoIcons.chevron_left,
                              size: 18)),
                      Expanded(
                          child: Text(
                              '${_months[month.month - 1]} ${month.year}',
                              textAlign: TextAlign.center,
                              style:
                                  HolyTypography.title.copyWith(fontSize: 21))),
                      IconButton(
                          tooltip: 'Next month',
                          onPressed:
                              month.year == now.year && month.month == now.month
                                  ? null
                                  : () => setState(() => _month =
                                      DateTime(month.year, month.month + 1)),
                          icon: const Icon(CupertinoIcons.chevron_right,
                              size: 18))
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                        Expanded(
                            child: Center(
                                child: Text(day,
                                    style: HolyTypography.eyebrow
                                        .copyWith(fontSize: 10, color: rose))))
                    ]),
                    const SizedBox(height: 10),
                    LayoutBuilder(builder: (context, constraints) {
                      final cell = constraints.maxWidth / 7;
                      return Wrap(children: [
                        for (final date
                            in monthCalendar(month.year, month.month))
                          SizedBox(
                              width: cell,
                              height: cell + 8,
                              child: date == null
                                  ? null
                                  : _CalendarDay(
                                      date: date,
                                      read: dates.contains(dateKey(date)),
                                      grace: streak.graceDates
                                          .contains(dateKey(date)),
                                      today: dateKey(date) == dateKey(now)))
                      ]);
                    }),
                    const SizedBox(height: 12),
                    const Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 18,
                        runSpacing: 8,
                        children: [
                          _CalendarKey(
                              icon: CupertinoIcons.heart_fill,
                              label: 'A moment with God'),
                          _CalendarKey(
                              icon: CupertinoIcons.sparkles, label: 'Grace day')
                        ])
                  ])),
              const SizedBox(height: 24),
              LayoutBuilder(builder: (context, constraints) {
                final columns =
                    MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 2 : 3;
                final width =
                    (constraints.maxWidth - 12 * (columns - 1)) / columns;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  _StatCard(
                      value: stats.daysRead,
                      label: 'Days read',
                      icon: CupertinoIcons.book,
                      width: width),
                  _StatCard(
                      value: stats.minutesWithGod,
                      label: 'Minutes with God',
                      icon: CupertinoIcons.clock,
                      width: width),
                  _StatCard(
                      value: stats.versesKept,
                      label: 'Verses kept',
                      icon: CupertinoIcons.heart,
                      width: width)
                ]);
              }),
              const SizedBox(height: 36),
              const Eyebrow('Little signs of a growing faith'),
              const SizedBox(height: 10),
              const Text('Your keepsakes', style: HolyTypography.title),
              const SizedBox(height: 10),
              Text('Every one tells the story of showing up.',
                  style: muted(context)),
              const SizedBox(height: 28),
              LayoutBuilder(builder: (context, constraints) {
                final columns =
                    MediaQuery.textScalerOf(context).scale(1) > 1.4 ||
                            constraints.maxWidth < 310
                        ? 2
                        : 3;
                final width =
                    (constraints.maxWidth - 24 * (columns - 1)) / columns;
                return Wrap(spacing: 24, runSpacing: 30, children: [
                  for (var index = 0; index < badges.length; index++)
                    SizedBox(
                        width: width,
                        child: Badge3D(
                            badgeId: badges[index].id,
                            icon: _badgeIcon(index),
                            label: badges[index].title,
                            earned: badges[index].earned,
                            progress:
                                '${badges[index].progress.clamp(0, badges[index].goal)} / ${badges[index].goal}',
                            onPressed: () => _showBadge(badges[index], index)))
                ]);
              })
            ]));
  }
}

IconData _badgeIcon(int index) => [
      CupertinoIcons.sparkles,
      CupertinoIcons.leaf_arrow_circlepath,
      CupertinoIcons.heart_fill,
      CupertinoIcons.sun_max_fill,
      CupertinoIcons.star_fill,
      CupertinoIcons.rosette
    ][index % 6];

class _LittleStat extends StatelessWidget {
  final String label, value;
  const _LittleStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: ui(context).copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(label, style: muted(context).copyWith(fontSize: 11))
      ]);
}

class _StatCard extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final double width;
  const _StatCard(
      {required this.value,
      required this.label,
      required this.icon,
      required this.width});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: width,
      child: Glass(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
          radius: 22,
          child: Column(children: [
            Icon(icon, color: rose, size: 21),
            const SizedBox(height: 10),
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('$value',
                    style: HolyTypography.title.copyWith(fontSize: 27))),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: muted(context).copyWith(fontSize: 10))
          ])));
}

class _CalendarKey extends StatelessWidget {
  final IconData icon;
  final String label;
  const _CalendarKey({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: rose),
        const SizedBox(width: 6),
        Flexible(
            child: Text(label, style: muted(context).copyWith(fontSize: 10)))
      ]);
}

class _CalendarDay extends StatelessWidget {
  final DateTime date;
  final bool read, grace, today;
  const _CalendarDay(
      {required this.date,
      required this.read,
      required this.grace,
      required this.today});
  @override
  Widget build(BuildContext context) => Semantics(
      label:
          '${dateKey(date)}, ${read ? 'read' : grace ? 'grace day' : 'not read'}${today ? ', today' : ''}',
      child: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: read ? rose.withValues(alpha: .16) : null,
                  border: today ? Border.all(color: rose, width: 1.5) : null),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('${date.day}',
                            maxLines: 1,
                            style: ui(context).copyWith(
                                fontSize: 12,
                                fontWeight: read || today
                                    ? FontWeight.w700
                                    : FontWeight.w500))),
                    if (read || grace)
                      Icon(
                          read
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.sparkles,
                          size: 8,
                          color: rose)
                  ]))));
}

class _GrowthHeroSurface extends StatelessWidget {
  final bool empty;
  final Widget child;
  const _GrowthHeroSurface({required this.empty, required this.child});
  @override
  Widget build(BuildContext context) => empty
      ? ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SceneArt(
              scene: 'growth-empty',
              fallback: const SizedBox.expand(),
              child: child))
      : child;
}
