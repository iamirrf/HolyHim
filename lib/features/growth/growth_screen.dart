import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/chapters.g.dart';
import '../../design/design.dart';
import '../../design/widgets/coin.dart';
import '../../design/widgets/glass.dart';
import '../../design/widgets/holy_header.dart';
import '../../domain/badges.dart';
import '../../domain/calendar.dart';
import '../../domain/streak.dart';
import '../../services/badge_share.dart';
import '../../services/repository.dart';

/// Growth: the streak, the next medallion, the month, every medallion as a
/// coin you can spin, and the road so far.
class GrowthScreen extends ConsumerStatefulWidget {
  final DateTime? now;
  const GrowthScreen({super.key, this.now});
  @override
  ConsumerState<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends ConsumerState<GrowthScreen> {
  int monthOffset = 0;

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final state = ref.watch(repositoryProvider);
    final now = widget.now ?? DateTime.now();
    final zone = state.profile.timeZone;
    final streak = streakFor(state.completed, now, zone);
    final badges = badgesFor(
        completed: state.completed,
        saved: state.saved,
        streak: streak,
        promiseStartedAt: state.profile.promiseStartedAt,
        timeZone: zone);
    final earned = badges.where((b) => b.earned).length;
    final next = badges.where((b) => !b.earned).fold<WalkBadge?>(
        null, (best, b) => best == null || b.fraction > best.fraction ? b : best);
    final local = localNow(now, zone);
    final month = DateTime(local.year, local.month + monthOffset);
    final media = MediaQuery.of(context);

    return Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: HolyHeader(streak: streak.current),
        body: CustomScrollView(
            key: const PageStorageKey('growth'),
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: HolyHeader.inset(context))),
              SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, media.padding.bottom + 24),
                  sliver: SliverList.list(children: [
                    Rise(
                        child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Semantics(
                                header: true,
                                child: Text('Growth',
                                    style: HolyTypography.title
                                        .copyWith(color: t.ink, fontSize: 31))))),
                    const SizedBox(height: 14),
                    Rise(index: 1, child: _StreakHero(streak: streak, days: state.completed.length)),
                    if (next != null) ...[
                      const SizedBox(height: 12),
                      Rise(index: 2, child: _NextMedal(badge: next, onPressed: () => _medal(next))),
                    ],
                    const SizedBox(height: 12),
                    Rise(
                        index: 3,
                        child: Glass(
                            radius: 24,
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                            child: _Month(
                                month: month,
                                today: local,
                                read: state.completed.values.toSet(),
                                grace: streak.graceDates,
                                onPrevious: () => setState(() => monthOffset--),
                                onNext: monthOffset >= 0
                                    ? null
                                    : () => setState(() => monthOffset++)))),
                    const SizedBox(height: 26),
                    _Heading(title: 'Medallions', trailing: '$earned of ${badges.length}'),
                    const SizedBox(height: 12),
                    GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 10,
                            childAspectRatio: .74),
                        itemCount: badges.length,
                        itemBuilder: (context, i) => _MedalTile(
                            badge: badges[i], onPressed: () => _medal(badges[i]))),
                    const SizedBox(height: 26),
                    _Heading(
                        title: 'The road so far',
                        trailing:
                            '${chapters.where((c) => [for (var d = c.firstDay; d <= c.lastDay; d++) d].every(state.completed.containsKey)).length} of ${chapters.length} chapters'),
                    const SizedBox(height: 12),
                    _RoadGrid(completed: state.completed),
                  ])),
            ]));
  }

  void _medal(WalkBadge badge) {
    HolyHaptics.tap();
    HolyDialogs.sheet<void>(context, scrollControlled: false, builder: (context) {
      final t = HolyThemeScope.of(context);
      return SafeArea(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CoinBadge(
                    size: 168,
                    image: HolyArtAssets.badgePath(badge.id),
                    muted: !badge.earned,
                    spinOnAppear: badge.earned,
                    glow: badge.earned ? .7 : .1,
                    face: const Icon(CupertinoIcons.star_fill),
                    semanticLabel: badge.title),
                const SizedBox(height: 10),
                Text(badge.earned ? 'Drag it. Spin it. You earned it.' : 'Drag to turn it.',
                    style: HolyTypography.caption.copyWith(color: t.muted)),
                const SizedBox(height: 14),
                Text(badge.title,
                    textAlign: TextAlign.center,
                    style: HolyTypography.title.copyWith(color: t.ink, fontSize: 30)),
                const SizedBox(height: 6),
                Text(badge.description,
                    textAlign: TextAlign.center,
                    style: HolyTypography.body.copyWith(color: t.muted)),
                const SizedBox(height: 16),
                _Bar(value: badge.fraction, done: badge.earned),
                const SizedBox(height: 8),
                Text(badge.earned ? 'Earned' : '${badge.progress} of ${badge.goal}',
                    style: HolyTypography.caption.copyWith(color: t.muted)),
                if (badge.earned) ...[
                  const SizedBox(height: 16),
                  HolyButton.secondary('Share',
                      leading: Icon(CupertinoIcons.square_arrow_up, size: 17, color: t.ink),
                      onPressed: () => shareBadgeImage(context, badge)),
                ],
              ])));
    });
  }
}

class _Heading extends StatelessWidget {
  final String title, trailing;
  const _Heading({required this.title, required this.trailing});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
              child: Text(title,
                  style: HolyTypography.headline.copyWith(color: t.ink, fontSize: 24))),
          Text(trailing, style: HolyTypography.label.copyWith(color: t.muted)),
        ]));
  }
}

class _Bar extends StatelessWidget {
  final double value;
  final bool done;
  const _Bar({required this.value, this.done = false});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Container(
        height: 7,
        decoration: BoxDecoration(
            color: t.ink.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(4)),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
            widthFactor: value.clamp(0.02, 1.0),
            child: Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(colors: done
                        ? [Color.lerp(t.olive, Colors.white, .25)!, t.olive]
                        : [Color.lerp(t.accent, Colors.white, .3)!, t.accent]),
                    boxShadow: [
                      BoxShadow(
                          color: (done ? t.olive : t.accent).withValues(alpha: .45),
                          blurRadius: 8),
                    ]))));
  }
}

/// The streak as a ring of fire around its number, with the other numbers
/// beside it.
class _StreakHero extends StatelessWidget {
  final Streak streak;
  final int days;
  const _StreakHero({required this.streak, required this.days});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    const goals = [3, 7, 14, 30, 50, 100, 200, 365, 500, 1000];
    final goal = goals.firstWhere((g) => g > streak.current, orElse: () => streak.current + 1);
    Widget row(IconData icon, Color color, int value, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: color.withValues(alpha: .15)),
              child: Icon(icon, size: 15, color: color)),
          const SizedBox(width: 10),
          RollingNumber(
              value: value,
              style: HolyTypography.numeral.copyWith(color: t.ink, fontSize: 22)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HolyTypography.caption.copyWith(color: t.muted))),
        ]));
    return Glass(
        radius: 26,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(children: [
          SizedBox.square(
              dimension: 132,
              child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: streak.current / goal),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => CustomPaint(
                      painter: _FireRing(v, t.accent, t.ink.withValues(alpha: .08)),
                      child: Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                        ShaderMask(
                            shaderCallback: (r) => const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Color(0xFFE0782F), Color(0xFFD8A657), Color(0xFFFFE2A0)])
                                .createShader(r),
                            child: const Icon(CupertinoIcons.flame_fill,
                                size: 24, color: Colors.white)),
                        RollingNumber(
                            value: streak.current,
                            style: HolyTypography.numeral
                                .copyWith(color: t.ink, fontSize: 40, height: 1)),
                        Text(streak.current == 1 ? 'day streak' : 'day streak',
                            style: HolyTypography.caption.copyWith(color: t.muted)),
                      ]))))),
          const SizedBox(width: 16),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            row(CupertinoIcons.flag_fill, t.accent, streak.longest, 'longest'),
            row(CupertinoIcons.book_fill, const Color(0xFF8FA9D6), days, 'days read'),
            row(CupertinoIcons.leaf_arrow_circlepath, t.olive, streak.graceDays, 'grace days'),
            const SizedBox(height: 4),
            Text('Next: $goal days',
                style: HolyTypography.caption
                    .copyWith(color: t.accent, fontWeight: FontWeight.w800)),
          ])),
        ]));
  }
}

class _FireRing extends CustomPainter {
  final double value;
  final Color color, track;
  const _FireRing(this.value, this.color, this.track);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(8);
    canvas.drawArc(rect, 0, math.pi * 2, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = track);
    if (value <= 0) return;
    final sweep = math.pi * 2 * value.clamp(0.0, 1.0);
    canvas.drawArc(rect, -math.pi / 2, sweep, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: .25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    canvas.drawArc(rect, -math.pi / 2, sweep, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..shader = const SweepGradient(
                  startAngle: -math.pi / 2,
                  endAngle: math.pi * 1.5,
                  colors: [Color(0xFFE0782F), Color(0xFFD8A657), Color(0xFFFFE2A0)],
                  transform: GradientRotation(-math.pi / 2))
              .createShader(rect));
  }

  @override
  bool shouldRepaint(_FireRing old) => old.value != value || old.color != color;
}

class _NextMedal extends StatelessWidget {
  final WalkBadge badge;
  final VoidCallback onPressed;
  const _NextMedal({required this.badge, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Pressable(
        onPressed: onPressed,
        pressedScale: .985,
        semanticLabel: 'Next medallion, ${badge.title}. ${badge.progress} of ${badge.goal}.',
        child: Glass(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
            child: Row(children: [
              CoinBadge(
                  size: 78,
                  image: HolyArtAssets.badgePath(badge.id),
                  muted: true,
                  idle: true,
                  face: const Icon(CupertinoIcons.star_fill)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Eyebrow('Next medallion', color: t.accent),
                const SizedBox(height: 3),
                Text(badge.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HolyTypography.headline.copyWith(color: t.ink, fontSize: 20)),
                const SizedBox(height: 8),
                _Bar(value: badge.fraction),
                const SizedBox(height: 6),
                Text('${badge.progress} of ${badge.goal}',
                    style: HolyTypography.caption.copyWith(color: t.muted)),
              ])),
            ])));
  }
}

class _MedalTile extends StatelessWidget {
  final WalkBadge badge;
  final VoidCallback onPressed;
  const _MedalTile({required this.badge, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Semantics(
        button: true,
        label: '${badge.title}. ${badge.earned ? 'Earned' : '${badge.progress} of ${badge.goal}'}',
        excludeSemantics: true,
        child: GestureDetector(
            onTap: onPressed,
            behavior: HitTestBehavior.opaque,
            child: Column(children: [
              HolyCoin(
                  size: 84,
                  turn: -.28,
                  tilt: .06,
                  image: HolyArtAssets.badgePath(badge.id),
                  muted: !badge.earned,
                  glow: badge.earned ? .3 : 0,
                  face: const Icon(CupertinoIcons.star_fill)),
              const SizedBox(height: 10),
              Text(badge.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: HolyTypography.caption.copyWith(
                      color: badge.earned ? t.ink : t.muted,
                      fontWeight: FontWeight.w800,
                      height: 1.2)),
              if (!badge.earned) ...[
                const SizedBox(height: 3),
                Text('${badge.progress}/${badge.goal}',
                    style: HolyTypography.caption.copyWith(color: t.muted, fontSize: 11)),
              ],
            ])));
  }
}

/// Every chapter as a small coin: struck once all five days are read.
class _RoadGrid extends StatelessWidget {
  final Map<int, String> completed;
  const _RoadGrid({required this.completed});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Glass(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
        child: Wrap(spacing: 8, runSpacing: 10, alignment: WrapAlignment.center, children: [
          for (final c in chapters)
            () {
              final read = [
                for (var d = c.firstDay; d <= c.lastDay; d++)
                  if (completed.containsKey(d)) d
              ].length;
              return Semantics(
                  label: 'Chapter ${c.number}, ${c.title}, $read of 5',
                  excludeSemantics: true,
                  child: Stack(alignment: Alignment.center, children: [
                    HolyCoin(
                        size: 34,
                        thickness: .07,
                        metal: read == 5 ? CoinMetal.brass : CoinMetal.steel,
                        face: Text('${c.number}',
                            style: TextStyle(
                                fontSize: c.number > 9 ? 11 : 13,
                                color: read == 5 ? null : const Color(0xFFAEB7C2)))),
                    if (read > 0 && read < 5)
                      SizedBox.square(
                          dimension: 38,
                          child: CircularProgressIndicator(
                              value: read / 5,
                              strokeWidth: 2.2,
                              color: t.accent,
                              backgroundColor: Colors.transparent)),
                  ]));
            }(),
        ]));
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
    final rows = ((lead + days) / 7).ceil();
    final readThisMonth = [
      for (var d = 1; d <= days; d++)
        if (read.contains(dateKey(DateTime(month.year, month.month, d)))) d
    ].length;
    return Column(children: [
      Row(children: [
        Expanded(
            child: Text('${names[month.month - 1]} ${month.year}',
                style: HolyTypography.ui.copyWith(color: t.ink, fontWeight: FontWeight.w800))),
        Text('$readThisMonth read', style: HolyTypography.caption.copyWith(color: t.muted)),
        const SizedBox(width: 6),
        _Nav(icon: CupertinoIcons.chevron_left, label: 'Previous month', onPressed: onPrevious),
        _Nav(icon: CupertinoIcons.chevron_right, label: 'Next month', onPressed: onNext),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
          Expanded(
              child: Center(
                  child: Text(d,
                      style: HolyTypography.caption
                          .copyWith(color: t.muted, fontWeight: FontWeight.w800)))),
      ]),
      const SizedBox(height: 6),
      for (var r = 0; r < rows; r++)
        Row(children: [
          for (var c = 0; c < 7; c++)
            Expanded(child: Builder(builder: (context) {
              final n = r * 7 + c - lead + 1;
              if (n < 1 || n > days) return const SizedBox(height: 42);
              final date = DateTime(month.year, month.month, n);
              final key = dateKey(date);
              final isRead = read.contains(key);
              final kept = grace.contains(key);
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              return SizedBox(
                  height: 42,
                  child: Center(
                      child: isRead || kept
                          ? HolyCoin(
                              size: 32,
                              thickness: .07,
                              metal: isRead ? CoinMetal.brass : CoinMetal.pine,
                              face: Text('$n', style: const TextStyle(fontSize: 12)))
                          : Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: isToday
                                      ? Border.all(color: t.accent, width: 1.6)
                                      : null),
                              alignment: Alignment.center,
                              child: Text('$n',
                                  style: HolyTypography.caption.copyWith(
                                      fontSize: 12.5,
                                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                                      color: date.isAfter(today)
                                          ? t.muted.withValues(alpha: .45)
                                          : t.muted)))));
            })),
        ]),
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
                child: Icon(icon, size: 16, color: onPressed == null ? t.hairline : t.ink))));
  }
}
