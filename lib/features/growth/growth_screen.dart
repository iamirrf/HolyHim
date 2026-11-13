import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design/design.dart';
import '../../domain/badges.dart';
import '../../domain/calendar.dart';
import '../../domain/streak.dart';
import '../../services/repository.dart';

/// Growth: the walk so far, this month, and the medallions, in one view.
class GrowthScreen extends ConsumerStatefulWidget {
  const GrowthScreen({super.key});
  @override
  ConsumerState<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends ConsumerState<GrowthScreen> {
  int monthOffset = 0;

  void _badge(WalkBadge badge) {
    final t = HolyThemeScope.of(context);
    showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Badge3D(
                      label: badge.title,
                      badgeId: badge.id,
                      earned: badge.earned,
                      size: 120,
                      showLabel: false),
                  const SizedBox(height: 16),
                  Text(badge.title,
                      textAlign: TextAlign.center,
                      style: HolyTypography.title
                          .copyWith(color: t.ink, fontSize: 30)),
                  const SizedBox(height: 6),
                  Text(badge.description,
                      textAlign: TextAlign.center,
                      style: HolyTypography.body.copyWith(color: t.muted)),
                  const SizedBox(height: 16),
                  ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                          value: badge.fraction,
                          minHeight: 5,
                          color: badge.earned ? t.olive : t.accent,
                          backgroundColor: t.hairline)),
                  const SizedBox(height: 8),
                  Text(
                      badge.earned
                          ? 'Earned'
                          : '${badge.progress} of ${badge.goal}',
                      style: HolyTypography.caption.copyWith(color: t.muted)),
                ]))));
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final state = ref.watch(repositoryProvider);
    final now = DateTime.now();
    final zone = state.profile.timeZone;
    final streak = streakFor(state.completed, now, zone);
    final badges = badgesFor(
        completed: state.completed,
        saved: state.saved,
        streak: streak,
        promiseStartedAt: state.profile.promiseStartedAt,
        timeZone: zone);
    final earned = badges.where((b) => b.earned).length;
    final local = localNow(now, zone);
    final month = DateTime(local.year, local.month + monthOffset);
    final media = MediaQuery.of(context);
    final compact = media.size.height < 740;
    return ColoredBox(
        color: t.paper,
        child: Padding(
            padding: EdgeInsets.only(top: media.padding.top),
            child: FitColumn(
                padding: EdgeInsets.fromLTRB(HolySpace.gutter, 16,
                    HolySpace.gutter, media.padding.bottom),
                children: [
                  Eyebrow('${state.completed.length} of 365 days'),
                  const SizedBox(height: 4),
                  Semantics(
                      header: true,
                      child: Text('Growth',
                          style: HolyTypography.title.copyWith(color: t.ink))),
                  SizedBox(height: compact ? 12 : 18),
                  Row(children: [
                    _Stat(
                        value: streak.current,
                        label: 'day walk',
                        icon: CupertinoIcons.sun_max_fill,
                        color: t.gold),
                    const SizedBox(width: 10),
                    _Stat(
                        value: streak.longest,
                        label: 'longest',
                        icon: CupertinoIcons.flag_fill,
                        color: t.accent),
                    const SizedBox(width: 10),
                    _Stat(
                        value: streak.graceDays,
                        label: 'grace days',
                        icon: CupertinoIcons.leaf_arrow_circlepath,
                        color: t.olive),
                  ]),
                  SizedBox(height: compact ? 12 : 16),
                  FitFlex(
                      min: compact ? 220 : 300,
                      child: Paper(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                          child: _Month(
                              month: month,
                              today: local,
                              read: state.completed.values.toSet(),
                              grace: streak.graceDates,
                              onPrevious: () =>
                                  setState(() => monthOffset--),
                              onNext: monthOffset >= 0
                                  ? null
                                  : () => setState(() => monthOffset++)))),
                  SizedBox(height: compact ? 12 : 18),
                  Row(children: [
                    Expanded(
                        child: Text('Medallions',
                            style: HolyTypography.headline
                                .copyWith(color: t.ink, fontSize: 24))),
                    Text('$earned of ${badges.length}',
                        style: HolyTypography.label.copyWith(color: t.muted)),
                  ]),
                  const SizedBox(height: 8),
                  SizedBox(
                      height: compact ? 84 : 98,
                      child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          itemCount: badges.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, i) {
                            final b = badges[i];
                            return Badge3D(
                                label: b.title,
                                badgeId: b.id,
                                earned: b.earned,
                                size: compact ? 72 : 86,
                                showLabel: false,
                                onPressed: () => _badge(b));
                          })),
                  SizedBox(height: compact ? 4 : 10),
                ])));
  }
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final Color color;
  const _Stat(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Expanded(
        child: Semantics(
            label: '$value $label',
            excludeSemantics: true,
            child: Paper(
                radius: 22,
                lift: .6,
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(height: 6),
                      RollingNumber(
                          value: value,
                          style: HolyTypography.numeral
                              .copyWith(color: t.ink, fontSize: 30)),
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HolyTypography.caption
                              .copyWith(color: t.muted)),
                    ]))));
  }
}

class _Month extends StatelessWidget {
  final DateTime month, today;
  final Set<String> read, grace;
  final VoidCallback? onPrevious, onNext;
  const _Month(
      {required this.month,
      required this.today,
      required this.read,
      required this.grace,
      required this.onPrevious,
      required this.onNext});
  static const names = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December'
  ];
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final first = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1; // Monday first.
    final cells = lead + days;
    final rows = (cells / 7).ceil();
    final readThisMonth = [
      for (var d = 1; d <= days; d++)
        if (read.contains(dateKey(DateTime(month.year, month.month, d)))) d
    ].length;
    return Column(children: [
      Row(children: [
        Expanded(
            child: Text('${names[month.month - 1]} ${month.year}',
                style: HolyTypography.label.copyWith(color: t.ink))),
        Text('$readThisMonth read',
            style: HolyTypography.caption.copyWith(color: t.muted)),
        const SizedBox(width: 6),
        _Nav(
            icon: CupertinoIcons.chevron_left,
            label: 'Previous month',
            onPressed: onPrevious),
        _Nav(
            icon: CupertinoIcons.chevron_right,
            label: 'Next month',
            onPressed: onNext),
      ]),
      const SizedBox(height: 4),
      Row(children: [
        for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
          Expanded(
              child: Center(
                  child: Text(d,
                      style: HolyTypography.caption.copyWith(
                          color: t.muted, fontWeight: FontWeight.w700)))),
      ]),
      const SizedBox(height: 4),
      Expanded(
          child: Column(children: [
        for (var r = 0; r < rows; r++)
          Expanded(
              child: Row(children: [
            for (var c = 0; c < 7; c++)
              Expanded(child: Builder(builder: (context) {
                final n = r * 7 + c - lead + 1;
                if (n < 1 || n > days) return const SizedBox();
                final date = DateTime(month.year, month.month, n);
                final key = dateKey(date);
                final isRead = read.contains(key);
                final kept = grace.contains(key);
                final isToday = date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
                return Center(
                    child: AspectRatio(
                        aspectRatio: 1,
                        child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isRead
                                        ? t.olive
                                        : kept
                                            ? t.olive.withValues(alpha: .14)
                                            : null,
                                    border: isToday && !isRead
                                        ? Border.all(color: t.accent, width: 1.5)
                                        : null),
                                child: Center(
                                    child: Text('$n',
                                        style: HolyTypography.caption.copyWith(
                                            fontSize: 12,
                                            fontWeight: isRead || isToday
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isRead
                                                ? t.surface
                                                : date.isAfter(today)
                                                    ? t.muted
                                                        .withValues(alpha: .5)
                                                    : t.ink)))))));
              })),
          ])),
      ])),
    ]);
  }
}

class _Nav extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _Nav({required this.icon, required this.label, this.onPressed});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Semantics(
        button: true,
        label: label,
        enabled: onPressed != null,
        excludeSemantics: true,
        child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(icon,
                    size: 16,
                    color: onPressed == null ? t.hairline : t.ink))));
  }
}
