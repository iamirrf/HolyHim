import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design/chapter_catalog.g.dart';
import '../../design/widgets/coin_3d.dart';
import '../../design/widgets/glass.dart';
import '../../domain/milestones.dart';
import '../../design/design.dart';
import '../../design/widgets/glass_header.dart';
import '../../domain/badges.dart';
import '../../domain/calendar.dart';
import '../../domain/streak.dart';
import '../../services/repository.dart';

/// Growth: the walk so far, this month, and the medallion cabinet. Scrolls.
class GrowthScreen extends ConsumerStatefulWidget {
  const GrowthScreen({super.key});
  @override
  ConsumerState<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends ConsumerState<GrowthScreen> {
  int monthOffset = 0;

  void _medallion(WalkBadge badge) {
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: .35),
        builder: (context) {
          final t = HolyThemeScope.of(context);
          return Padding(
              padding: EdgeInsets.fromLTRB(
                  12, 0, 12, MediaQuery.paddingOf(context).bottom + 12),
              child: ClipRSuperellipse(
                  borderRadius: BorderRadius.circular(HolyRadius.sheet),
                  child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: ColoredBox(
                          color: t.surface.withValues(alpha: .88),
                          child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(28, 30, 28, 26),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Coin3D(
                                        badgeId: badge.id,
                                        earned: badge.earned,
                                        size: 190,
                                        interactive: true),
                                    const SizedBox(height: 26),
                                    Text(badge.title,
                                        textAlign: TextAlign.center,
                                        style: HolyTypography.title.copyWith(
                                            color: t.ink, fontSize: 30)),
                                    const SizedBox(height: 6),
                                    Text(badge.description,
                                        textAlign: TextAlign.center,
                                        style: HolyTypography.body
                                            .copyWith(color: t.muted)),
                                    const SizedBox(height: 18),
                                    ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                            value: badge.fraction,
                                            minHeight: 6,
                                            color: badge.earned
                                                ? t.gold
                                                : t.accent,
                                            backgroundColor: t.hairline)),
                                    const SizedBox(height: 8),
                                    Text(
                                        badge.earned
                                            ? 'Earned · spin it'
                                            : '${badge.progress} of ${badge.goal}',
                                        style: HolyTypography.caption
                                            .copyWith(color: t.muted)),
                                  ]))))));
        });
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
    final chapters = ChapterCatalog.chapters
        .where((c) => [for (var d = c.firstDay; d <= c.lastDay; d++) d]
            .every(state.completed.containsKey))
        .length;
    final goal = nextMilestone(state.completed.length);
    return GlassHeaderScaffold(
        title: 'Growth',
        background: backdropPaper(context, t),
        body:
            CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
          SliverPadding(
              padding: EdgeInsets.fromLTRB(HolySpace.gutter,
                  media.padding.top + 14, HolySpace.gutter, 0),
              sliver: SliverList.list(children: [
                Eyebrow('Your whole walk', color: t.accent),
                const SizedBox(height: 4),
                Semantics(
                    header: true,
                    child: Text('Growth',
                        style: HolyTypography.display
                            .copyWith(color: t.ink, fontSize: 40, height: 1))),
                const SizedBox(height: 18),
                _WalkHero(
                    walk: streak.current,
                    longest: streak.longest,
                    grace: streak.graceDays,
                    goal: goal),
                const SizedBox(height: 14),
                Row(children: [
                  _Stat(
                      value: state.completed.length,
                      label: 'lessons read',
                      icon: CupertinoIcons.book_fill,
                      color: t.accent),
                  const SizedBox(width: 10),
                  _Stat(
                      value: chapters,
                      label: 'chapters',
                      icon: CupertinoIcons.map_fill,
                      color: t.olive),
                  const SizedBox(width: 10),
                  _Stat(
                      value: state.saved.length,
                      label: 'verses kept',
                      icon: CupertinoIcons.heart_fill,
                      color: t.gold),
                ]),
                const SizedBox(height: 14),
                Paper(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: SizedBox(
                        height: 300,
                        child: _Month(
                            month: month,
                            today: local,
                            read: state.completed.values.toSet(),
                            grace: streak.graceDates,
                            onPrevious: () => setState(() => monthOffset--),
                            onNext: monthOffset >= 0
                                ? null
                                : () => setState(() => monthOffset++)))),
                const SizedBox(height: 30),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Eyebrow('Your collection', color: t.accent),
                        const SizedBox(height: 2),
                        Text('Medallions',
                            style: HolyTypography.display.copyWith(
                                color: t.ink, fontSize: 34, height: 1)),
                      ])),
                  Glass(
                      radius: 40,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      child: Text('$earned of ${badges.length}',
                          style: HolyTypography.label.copyWith(
                              color: t.ink, fontWeight: FontWeight.w800))),
                ]),
                const SizedBox(height: 16),
                _Spotlight(
                    badge: badges.lastWhere((b) => b.earned,
                        orElse: () => badges.first),
                    onTap: _medallion),
                const SizedBox(height: 16),
              ])),
          SliverPadding(
              padding: EdgeInsets.fromLTRB(HolySpace.gutter, 0,
                  HolySpace.gutter, media.padding.bottom + 24),
              sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: .74),
                  itemCount: badges.length,
                  itemBuilder: (context, i) {
                    final b = badges[i];
                    return Semantics(
                        button: true,
                        label:
                            '${b.title}${b.earned ? ', earned' : ', locked'}',
                        excludeSemantics: true,
                        child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _medallion(b),
                            child: _Tile3D(badge: b)));
                  })),
        ]));
  }
}

/// The walk, large: the day count on rose light, the record and the grace
/// days, and how close the next medallion is.
class _WalkHero extends StatelessWidget {
  final int walk, longest, grace;
  final Milestone? goal;
  const _WalkHero(
      {required this.walk,
      required this.longest,
      required this.grace,
      required this.goal});
  @override
  Widget build(BuildContext context) {
    const ink = HolyTheme.photoInk;
    // Each theme's own hero: plum to peach in First Light, violet in
    // Lavender, deep olive in Olive Grove.
    final t = HolyThemeScope.of(context);
    return DecoratedBox(
        decoration: ShapeDecoration(
            shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(HolyRadius.card)),
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: t.hero),
            shadows: [
              BoxShadow(
                  color: t.hero[1].withValues(alpha: .38),
                  blurRadius: 30,
                  offset: const Offset(0, 16))
            ]),
        child: Stack(children: [
          Positioned(
              right: -30,
              top: -40,
              child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        t.glow.withValues(alpha: .55),
                        t.glow.withValues(alpha: 0),
                      ])))),
          Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      RollingNumber(
                          value: walk,
                          style: HolyTypography.numeral
                              .copyWith(color: ink, fontSize: 64, height: .9)),
                      const SizedBox(width: 10),
                      Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('day walk',
                              style: HolyTypography.headline
                                  .copyWith(color: ink, fontSize: 22))),
                      const Spacer(),
                      Icon(CupertinoIcons.sun_max_fill,
                          color: t.glow, size: 40),
                    ]),
                    const SizedBox(height: 10),
                    Text(
                        'Longest $longest · $grace grace ${grace == 1 ? 'day' : 'days'} ready',
                        style: HolyTypography.label
                            .copyWith(color: ink.withValues(alpha: .85))),
                    if (goal != null) ...[
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                            child: Text(goal!.distance,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HolyTypography.label.copyWith(
                                    color: ink, fontWeight: FontWeight.w700))),
                      ]),
                      const SizedBox(height: 8),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                              value: goal!.progress,
                              minHeight: 7,
                              color: t.glow,
                              backgroundColor: ink.withValues(alpha: .22))),
                    ],
                  ])),
        ]));
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
                          style:
                              HolyTypography.caption.copyWith(color: t.muted)),
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
                                        ? Border.all(
                                            color: t.accent, width: 1.5)
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
                    size: 16, color: onPressed == null ? t.hairline : t.ink))));
  }
}

/// The latest medallion, large and turning, on glass.
class _Spotlight extends StatelessWidget {
  final WalkBadge badge;
  final ValueChanged<WalkBadge> onTap;
  const _Spotlight({required this.badge, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Pressable(
        semanticLabel:
            '${badge.title}, ${badge.earned ? 'earned' : 'first to earn'}',
        onPressed: () => onTap(badge),
        child: Glass(
            radius: HolyRadius.card,
            elevation: 3,
            padding: const EdgeInsets.fromLTRB(14, 16, 18, 16),
            child: Row(children: [
              Coin3D(badgeId: badge.id, earned: badge.earned, size: 132),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Eyebrow(
                        badge.earned
                            ? 'Latest medallion'
                            : 'Your first medallion',
                        color: t.gold),
                    const SizedBox(height: 4),
                    Text(badge.title,
                        style: HolyTypography.headline
                            .copyWith(color: t.ink, fontSize: 24, height: 1.1)),
                    const SizedBox(height: 6),
                    Text(badge.description,
                        style: HolyTypography.caption.copyWith(color: t.muted)),
                    const SizedBox(height: 10),
                    Text(
                        badge.earned
                            ? 'Tap to spin it'
                            : 'Earn it on your first morning',
                        style: HolyTypography.label.copyWith(
                            color: t.accent, fontWeight: FontWeight.w700)),
                  ])),
            ])));
  }
}

/// One medallion in the cabinet: big, turning, and how close it is.
class _Tile3D extends StatelessWidget {
  final WalkBadge badge;
  const _Tile3D({required this.badge});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Glass(
        radius: 26,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(children: [
          Expanded(
              child: Center(
                  child: Coin3D(
                      badgeId: badge.id, earned: badge.earned, size: 112))),
          const SizedBox(height: 8),
          Text(badge.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: HolyTypography.label.copyWith(
                  color: badge.earned ? t.ink : t.muted,
                  fontWeight: FontWeight.w800,
                  height: 1.2)),
          const SizedBox(height: 6),
          if (badge.earned)
            Text('Earned',
                style: HolyTypography.caption
                    .copyWith(color: t.gold, fontWeight: FontWeight.w800))
          else
            Row(children: [
              Expanded(
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                          value: badge.fraction,
                          minHeight: 5,
                          color: t.accent,
                          backgroundColor: t.hairline))),
              const SizedBox(width: 8),
              Text('${badge.progress}/${badge.goal}',
                  style: HolyTypography.caption.copyWith(color: t.muted)),
            ]),
        ]));
  }
}
