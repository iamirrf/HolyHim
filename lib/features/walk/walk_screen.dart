import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/lessons.g.dart';
import '../../design/art_catalog.dart';
import '../../design/chapter_catalog.g.dart';
import '../../design/design.dart';
import '../../design/widgets/coin_3d.dart';
import '../../design/widgets/glass_header.dart';
import '../../domain/access.dart';
import '../../domain/badges.dart';
import '../../domain/pacing.dart';
import '../../domain/streak.dart';
import '../../services/billing.dart';
import '../../services/repository.dart';

/// The walk: every chapter as a winding path of stones, from the first
/// morning onward, all year. Finished days shine in the theme's metal with a
/// light passing over them, today's stone floats and breathes, light travels
/// along the path toward it, and medallions turn beside the days that earn
/// them.
class WalkScreen extends ConsumerStatefulWidget {
  const WalkScreen({super.key});
  @override
  ConsumerState<WalkScreen> createState() => _WalkScreenState();
}

const _row = 108.0, _header = 172.0, _gap = 28.0;
double _sectionHeight(ChapterArt c) =>
    _header + (c.lastDay - c.firstDay + 1) * _row + _gap;

class _WalkScreenState extends ConsumerState<WalkScreen>
    with SingleTickerProviderStateMixin {
  ScrollController? _scroll;

  /// One slow light for the whole screen: the sheen on the stones and the
  /// motes on the path both follow it.
  late final AnimationController _light =
      AnimationController(vsync: this, duration: const Duration(seconds: 7));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _light
        ..stop()
        ..value = .3;
    } else if (!_light.isAnimating) {
      _light.repeat();
    }
  }

  ScrollController _controllerFor(int currentDay) {
    if (_scroll != null) return _scroll!;
    // Open at her place: the chapter she is in, just below the hero.
    var offset = 0.0;
    for (final c in ChapterCatalog.chapters) {
      if (currentDay <= c.lastDay) break;
      offset += _sectionHeight(c);
    }
    return _scroll =
        ScrollController(initialScrollOffset: offset == 0 ? 0 : offset + 300);
  }

  @override
  void dispose() {
    _light.dispose();
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final state = ref.watch(repositoryProvider);
    final owned = ref.watch(accessProvider.select((a) => a.active));
    final now = DateTime.now();
    final pacing = pacingFor(state.completed, now, state.profile.timeZone);
    final streak = streakFor(state.completed, now, state.profile.timeZone);
    final media = MediaQuery.of(context);
    final chapters = ChapterCatalog.chapters;
    return GlassHeaderScaffold(
        title: 'Your walk',
        background: backdropPaper(context, t),
        body: _WalkLight(
            animation: _light,
            child: CustomScrollView(
                controller: _controllerFor(pacing.currentDay),
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: EdgeInsets.fromLTRB(HolySpace.gutter,
                              media.padding.top + 14, HolySpace.gutter, 18),
                          child: _Header(
                              walk: streak.current,
                              read: state.completed.length))),
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: HolySpace.gutter),
                          child: _ContinueCard(
                              pacing: pacing,
                              owned: owned,
                              completed: state.completed))),
                  const SliverToBoxAdapter(child: SizedBox(height: 30)),
                  SliverList.builder(
                      itemCount: chapters.length,
                      itemBuilder: (context, i) => _ChapterSection(
                          number: i + 1,
                          chapter: chapters[i],
                          summary:
                              i < unitSummaries.length ? unitSummaries[i] : '',
                          pacing: pacing,
                          owned: owned,
                          completed: state.completed)),
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              32, 12, 32, media.padding.bottom + 28),
                          child: Column(children: [
                            Flourish(color: t.gold, width: 40),
                            const SizedBox(height: 12),
                            Text('Every step you take stays yours.',
                                textAlign: TextAlign.center,
                                style: HolyTypography.ui
                                    .copyWith(color: t.muted, fontSize: 15)),
                          ]))),
                ])));
  }
}

/// The screen's one light, shared with every stone and path below it.
class _WalkLight extends InheritedWidget {
  final Animation<double> animation;
  const _WalkLight({required this.animation, required super.child});
  static Animation<double> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_WalkLight>()?.animation ??
      const AlwaysStoppedAnimation(.3);
  @override
  bool updateShouldNotify(_WalkLight old) => old.animation != animation;
}

class _Header extends StatelessWidget {
  final int walk, read;
  const _Header({required this.walk, required this.read});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Eyebrow('365 mornings', color: t.accent),
        const SizedBox(height: 4),
        Semantics(
            header: true,
            child: Text('Your walk',
                style: HolyTypography.display
                    .copyWith(color: t.ink, fontSize: 40, height: 1))),
      ])),
      _Chip(icon: CupertinoIcons.sun_max_fill, value: '$walk', color: t.gold),
      const SizedBox(width: 8),
      _Chip(icon: CupertinoIcons.book_fill, value: '$read', color: t.accent),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _Chip({required this.icon, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return DecoratedBox(
        decoration: ShapeDecoration(
            shape: const StadiumBorder(), shadows: HolyDepth.paper(t)),
        child: FrostedGlass(
            radius: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(value,
                  style: HolyTypography.numeral
                      .copyWith(color: t.ink, fontSize: 20, height: 1)),
            ])));
  }
}

/// Her place on the path: the chapter's art and one clear next step.
class _ContinueCard extends StatelessWidget {
  final Pacing pacing;
  final bool owned;
  final Map<int, String> completed;
  const _ContinueCard(
      {required this.pacing, required this.owned, required this.completed});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final day = pacing.finished ? 1 : pacing.currentDay;
    final lesson = lessons[day - 1];
    final chapter = ChapterCatalog.forDay(day)!;
    final number = ChapterCatalog.chapters.indexOf(chapter) + 1;
    final inChapter = [
      for (var d = chapter.firstDay; d <= chapter.lastDay; d++) d
    ];
    final done = inChapter.where(completed.containsKey).length;
    final label = pacing.finished
        ? 'Walk it again'
        : !pacing.canBegin
            ? 'Day $day opens tomorrow'
            : 'Continue · Day $day';
    return ClipRSuperellipse(
        borderRadius: BorderRadius.circular(HolyRadius.card),
        child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 236),
            child: Stack(children: [
              Positioned.fill(
                  child: Image.asset(
                      HolyArtCatalog.landscapeForDay(day) ??
                          HolyArtCatalog.assetForDay(day),
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => ColoredBox(color: t.sunk))),
              const Positioned.fill(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                    Color(0x1A1E1216),
                    Color(0xD91E1216)
                  ])))),
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Eyebrow('Chapter $number', color: t.photoLabel),
                          const Spacer(),
                          _Ring(
                              value: done / inChapter.length,
                              label: '$done/${inChapter.length}'),
                        ]),
                        const SizedBox(height: 36),
                        Text(lesson.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: HolyTypography.title.copyWith(
                                color: HolyTheme.photoInk, fontSize: 28)),
                        const SizedBox(height: 4),
                        Text(chapter.title,
                            style: HolyTypography.ui.copyWith(
                                color:
                                    HolyTheme.photoInk.withValues(alpha: .84),
                                fontSize: 14.5)),
                        const SizedBox(height: 14),
                        HolyButton(label,
                            style: HolyButtonStyle.photoPrimary,
                            onPressed: () => openDay(context, day,
                                pacing: pacing,
                                owned: owned,
                                completed: completed)),
                      ])),
            ])));
  }
}

class _Ring extends StatelessWidget {
  final double value;
  final String label;
  const _Ring({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => SizedBox.square(
      dimension: 46,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(
            size: const Size.square(46),
            painter: _RingPainter(
                value,
                Color.lerp(HolyThemeScope.of(context).metal[0],
                    HolyThemeScope.of(context).metal[1], .55)!)),
        Text(label,
            style: HolyTypography.caption.copyWith(
                color: HolyTheme.photoInk, fontWeight: FontWeight.w800)),
      ]));
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  _RingPainter(this.value, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Colors.white.withValues(alpha: .22));
    canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * value.clamp(0, 1),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

/// What a tap on a day does: read, reread, unlock, or wait for its morning.
void openDay(BuildContext context, int day,
    {required Pacing pacing,
    required bool owned,
    required Map<int, String> completed}) {
  final read = completed.containsKey(day);
  final locked = !canOpenLesson(day, owned: owned, completed: completed);
  final open = pacing.canRead(day, completed) && !locked;
  HolyHaptics.tap();
  if (open) {
    context.push('/lesson/$day');
  } else if (locked && day == pacing.currentDay) {
    context.push('/offer?day=$day');
  } else {
    _preview(context, day, locked: locked && !read);
  }
}

/// A future day, seen through frosted glass: its title and what it holds.
void _preview(BuildContext context, int day, {required bool locked}) {
  final lesson = lessons[day - 1];
  showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .28),
      builder: (context) {
        final t = HolyThemeScope.of(context);
        return Padding(
            padding: EdgeInsets.fromLTRB(
                12, 0, 12, MediaQuery.paddingOf(context).bottom + 12),
            child: ClipRSuperellipse(
                borderRadius: BorderRadius.circular(HolyRadius.sheet),
                child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                    child: ColoredBox(
                        color: t.surface.withValues(alpha: .86),
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Eyebrow('Day $day · ${lesson.theme}',
                                      color: t.accent),
                                  const SizedBox(height: 6),
                                  Text(lesson.title,
                                      style: HolyTypography.title.copyWith(
                                          color: t.ink, fontSize: 28)),
                                  const SizedBox(height: 10),
                                  Text(lesson.teaser,
                                      style: HolyTypography.ui.copyWith(
                                          color: t.muted, fontSize: 16)),
                                  const SizedBox(height: 18),
                                  Row(children: [
                                    Icon(
                                        locked
                                            ? CupertinoIcons.lock_fill
                                            : CupertinoIcons.moon_stars_fill,
                                        size: 16,
                                        color: t.gold),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(
                                            locked
                                                ? 'Opens with membership'
                                                : 'Opens on its own morning',
                                            style: HolyTypography.label
                                                .copyWith(color: t.ink))),
                                  ]),
                                  if (locked) ...[
                                    const SizedBox(height: 16),
                                    HolyButton('See membership', onPressed: () {
                                      Navigator.of(context).pop();
                                      context.push('/offer?day=$day');
                                    }),
                                  ],
                                ]))))));
      });
}

class _ChapterSection extends StatelessWidget {
  final int number;
  final ChapterArt chapter;
  final String summary;
  final Pacing pacing;
  final bool owned;
  final Map<int, String> completed;
  const _ChapterSection(
      {required this.number,
      required this.chapter,
      required this.summary,
      required this.pacing,
      required this.owned,
      required this.completed});

  @override
  Widget build(BuildContext context) {
    final days = [for (var d = chapter.firstDay; d <= chapter.lastDay; d++) d];
    return SizedBox(
        height: _sectionHeight(chapter),
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: HolySpace.gutter),
              child: SizedBox(
                  height: _header - 22,
                  child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3,
                      child: _ChapterHeader(
                          number: number,
                          chapter: chapter,
                          summary: summary,
                          done: days.where(completed.containsKey).length,
                          total: days.length)))),
          const SizedBox(height: 22),
          SizedBox(
              height: days.length * _row,
              child: LayoutBuilder(builder: (context, box) {
                final points = [
                  for (var i = 0; i < days.length; i++)
                    Offset(
                        box.maxWidth / 2 +
                            math.sin(i * 1.15 + number * .9) *
                                box.maxWidth *
                                .26,
                        i * _row + _row / 2 - 10)
                ];
                final doneUpTo = days.lastIndexWhere(completed.containsKey);
                // Today's stone, if it is in this chapter: the motes on the
                // path travel toward it.
                final today = days.indexOf(pacing.currentDay);
                final toward = today > 0 &&
                        !pacing.finished &&
                        !completed.containsKey(pacing.currentDay)
                    ? today
                    : -1;
                return Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                      child: RepaintBoundary(
                          child: CustomPaint(
                              painter: _PathPainter(
                                  points, doneUpTo, HolyThemeScope.of(context),
                                  toward: toward,
                                  light: toward > 0
                                      ? _WalkLight.of(context)
                                      : null)))),
                  for (var i = 0; i < days.length; i++) ...[
                    if (dayBadgeTitles.containsKey(days[i]))
                      Positioned(
                          left: points[i].dx < box.maxWidth / 2
                              ? points[i].dx + 62
                              : points[i].dx - 62 - 62,
                          top: points[i].dy - 31,
                          child: _CoinMark(
                              day: days[i],
                              earned: completed.length >= days[i])),
                    Positioned(
                        left: points[i].dx - 44,
                        top: points[i].dy - 44,
                        child: _Stone(
                            day: days[i],
                            pacing: pacing,
                            owned: owned,
                            completed: completed)),
                  ],
                ]);
              })),
          const SizedBox(height: _gap),
        ]));
  }
}

class _ChapterHeader extends StatelessWidget {
  final int number, done, total;
  final ChapterArt chapter;
  final String summary;
  const _ChapterHeader(
      {required this.number,
      required this.chapter,
      required this.summary,
      required this.done,
      required this.total});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final complete = done == total;
    final art = HolyArtCatalog.landscapeForDay(chapter.firstDay) ??
        HolyArtCatalog.thumbnailForDay(chapter.firstDay);
    return DecoratedBox(
        decoration: ShapeDecoration(
            shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(HolyRadius.card - 4)),
            shadows: HolyDepth.paper(t, lift: 1.2)),
        child: ClipRSuperellipse(
            borderRadius: BorderRadius.circular(HolyRadius.card - 4),
            child: Stack(fit: StackFit.expand, children: [
              _Parallax(
                  child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 1.6, sigmaY: 1.6),
                      child: Image.asset(art,
                          fit: BoxFit.cover,
                          cacheWidth: 700,
                          errorBuilder: (c, e, s) =>
                              ColoredBox(color: t.sunk)))),
              const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                    Color(0xE61E1216),
                    Color(0x991E1216),
                    Color(0x331E1216),
                  ]))),
              // Light catching the top edge, as on a pane of glass.
              const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment(0, -.25),
                          colors: [Color(0x26FFFFFF), Color(0x00FFFFFF)]))),
              DecoratedBox(
                  decoration: ShapeDecoration(
                      shape: RoundedSuperellipseBorder(
                          borderRadius:
                              BorderRadius.circular(HolyRadius.card - 4),
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: .16))))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                  child: Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          Eyebrow('Chapter $number', color: t.photoLabel),
                          const SizedBox(height: 4),
                          Text(chapter.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HolyTypography.title.copyWith(
                                  color: HolyTheme.photoInk, fontSize: 24)),
                          const SizedBox(height: 4),
                          Text(summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: HolyTypography.ui.copyWith(
                                  color:
                                      HolyTheme.photoInk.withValues(alpha: .84),
                                  fontSize: 13,
                                  height: 1.35)),
                        ])),
                    const SizedBox(width: 12),
                    complete
                        ? Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [t.metal[0], t.metal[2]])),
                            child: Icon(CupertinoIcons.checkmark_alt,
                                color: t.metalInk, size: 24))
                        : _Ring(value: done / total, label: '$done/$total'),
                  ])),
            ])));
  }
}

/// The path between stones: a soft glow, a body and a bright core; gold
/// where she has walked, a dotted line where she has not yet.
class _PathPainter extends CustomPainter {
  final List<Offset> points;
  final int doneUpTo;
  final HolyTheme t;

  /// The stone the motes travel toward, or -1 for none.
  final int toward;
  final Animation<double>? light;
  _PathPainter(this.points, this.doneUpTo, this.t,
      {this.toward = -1, this.light})
      : super(repaint: light);

  Path _through(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      final mid = (a.dy + b.dy) / 2;
      p.cubicTo(a.dx, mid, b.dx, mid, b.dx, b.dy);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final all = _through(points);
    // The road ahead: a soft dotted line.
    for (final metric in all.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 14) {
        final tan = metric.getTangentForOffset(d)!;
        canvas.drawCircle(tan.position, 2.4,
            Paint()..color = t.muted.withValues(alpha: t.isDark ? .45 : .32));
      }
    }
    _motes(canvas);
    if (doneUpTo < 1) return;
    final walked = _through(points.sublist(0, doneUpTo + 1));
    final gold = t.metal[1];
    canvas.drawPath(
        walked,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22
          ..strokeCap = StrokeCap.round
          ..color = gold.withValues(alpha: .18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawPath(
        walked,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..color = gold.withValues(alpha: .65));
    canvas.drawPath(
        walked,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(t.glow, Colors.white, .55)!);
    _motes(canvas);
  }

  /// Small lights drifting along the path to today's stone, each fading in
  /// as it sets out and out as it arrives.
  void _motes(Canvas canvas) {
    final light = this.light;
    if (light == null || toward < 1) return;
    final metric =
        _through(points.sublist(0, toward + 1)).computeMetrics().first;
    const count = 5;
    for (var k = 0; k < count; k++) {
      final p = (light.value + k / count) % 1.0;
      final tan = metric.getTangentForOffset(p * metric.length)!;
      final fade = math.sin(p * math.pi);
      canvas.drawCircle(
          tan.position,
          7,
          Paint()
            ..color = t.glow.withValues(alpha: .45 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawCircle(tan.position, 2.2,
          Paint()..color = Colors.white.withValues(alpha: .9 * fade));
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.doneUpTo != doneUpTo ||
      old.points != points ||
      old.t != t ||
      old.toward != toward ||
      old.light != light;
}

/// A medallion waiting beside the day that earns it.
class _CoinMark extends StatelessWidget {
  final int day;
  final bool earned;
  const _CoinMark({required this.day, required this.earned});
  @override
  Widget build(BuildContext context) => Semantics(
      label: '${dayBadgeTitles[day]} medallion${earned ? ', earned' : ''}',
      excludeSemantics: true,
      child: Coin3D(badgeId: 'days-$day', earned: earned, size: 62));
}

/// A stone on the path: a pedestal under a domed medallion face.
class _Stone extends StatefulWidget {
  final int day;
  final Pacing pacing;
  final bool owned;
  final Map<int, String> completed;
  const _Stone(
      {required this.day,
      required this.pacing,
      required this.owned,
      required this.completed});
  @override
  State<_Stone> createState() => _StoneState();
}

class _StoneState extends State<_Stone> with SingleTickerProviderStateMixin {
  AnimationController? _breath;

  bool get _current =>
      !widget.completed.containsKey(widget.day) &&
      widget.day == widget.pacing.currentDay &&
      !widget.pacing.finished;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Stone old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_current && _breath == null) {
      _breath = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 1800))
        ..repeat(reverse: true);
    } else if (!_current && _breath != null) {
      _breath!.dispose();
      _breath = null;
    }
  }

  @override
  void dispose() {
    _breath?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final day = widget.day;
    final done = widget.completed.containsKey(day);
    final current = _current;
    final locked = !done &&
        !canOpenLesson(day, owned: widget.owned, completed: widget.completed);
    final faces = done
        ? t.metal
        : current
            ? [Color.lerp(t.accent, Colors.white, .25)!, t.accent, t.primary]
            // Stones ahead are the theme's own paper, lit from above.
            : t.isDark
                ? [
                    Color.lerp(t.surface, t.ink, .16)!,
                    Color.lerp(t.surface, t.ink, .07)!,
                    t.surface
                  ]
                : [
                    Color.lerp(t.surface, Colors.white, .7)!,
                    t.sunk,
                    Color.lerp(t.sunk, t.hairline, .8)!
                  ];
    final base = done
        ? Color.lerp(t.metal[2], Colors.black, .28)!
        : current
            ? Color.lerp(t.primary, Colors.black, .35)!
            : (t.isDark
                ? Color.lerp(t.sunk, Colors.black, .3)!
                : Color.lerp(t.hairline, t.muted, .3)!);
    final ink = done
        ? t.metalInk
        : current
            ? (t.isDark ? t.onPrimary : const Color(0xFFFFF8EC))
            : t.muted;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final stone = SizedBox(
        width: 88,
        height: 96,
        child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              if (current && _breath != null)
                Positioned(
                    top: -6,
                    child: AnimatedBuilder(
                        animation: _breath!,
                        builder: (context, _) {
                          final b = reduced ? .5 : _breath!.value;
                          return Container(
                              width: 88 + b * 10,
                              height: 88 + b * 10,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: t.accent
                                          .withValues(alpha: .35 + b * .25),
                                      width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                        color: t.accent
                                            .withValues(alpha: .18 + b * .2),
                                        blurRadius: 22 + b * 10)
                                  ]));
                        })),
              // The pedestal, seen below the face.
              Positioned(
                  top: 10,
                  child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: base,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: .26),
                                blurRadius: 12,
                                offset: const Offset(0, 7))
                          ]))),
              // The face: domed, rimmed, catching the light.
              Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: faces),
                      border: Border.all(
                          color: Colors.white
                              .withValues(alpha: done || current ? .7 : .55),
                          width: 1.8)),
                  child: Stack(alignment: Alignment.center, children: [
                    Positioned(
                        top: 6,
                        left: 14,
                        right: 14,
                        height: 22,
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withValues(alpha: .55),
                                      Colors.white.withValues(alpha: 0),
                                    ])))),
                    if (done || current)
                      Positioned.fill(
                          child: ClipOval(
                              child: CustomPaint(
                                  painter: _SheenPainter(_WalkLight.of(context),
                                      offset: (day * .137) % 1)))),
                    if (locked)
                      // Frosted: the day is there, not yet open.
                      Positioned.fill(
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withValues(
                                            alpha: t.isDark ? .18 : .55),
                                        Colors.white.withValues(
                                            alpha: t.isDark ? .04 : .14),
                                      ]),
                                  border: Border.all(
                                      color: Colors.white.withValues(
                                          alpha: t.isDark ? .22 : .8),
                                      width: 1.2)))),
                    if (done)
                      _Engraved(CupertinoIcons.checkmark_alt,
                          size: 34, color: ink)
                    else if (locked)
                      Icon(CupertinoIcons.lock_fill,
                          size: 22, color: ink.withValues(alpha: .8))
                    else
                      Text('$day',
                          style: HolyTypography.numeral.copyWith(
                              color: ink,
                              fontSize: day > 99 ? 24 : 30,
                              height: 1)),
                  ])),
              if (current)
                Positioned(
                    top: -40,
                    child: _Bubble(
                        text: locked
                            ? 'Unlock'
                            : widget.pacing.canBegin
                                ? 'Start'
                                : 'Tomorrow')),
            ]));
    return Semantics(
        button: true,
        label: 'Day $day, ${lessons[day - 1].title}'
            '${done ? ', read' : current ? ', today' : locked ? ', locked' : ''}',
        excludeSemantics: true,
        child: Pressable(
            onPressed: () => openDay(context, day,
                pacing: widget.pacing,
                owned: widget.owned,
                completed: widget.completed),
            child: !current
                ? stone
                : _breath == null || reduced
                    ? Transform.scale(scale: 1.08, child: stone)
                    : AnimatedBuilder(
                        animation: _breath!,
                        builder: (context, child) => Transform.translate(
                            offset: Offset(
                                0,
                                -4 *
                                    Curves.easeInOut.transform(_breath!.value)),
                            child: child),
                        child: Transform.scale(scale: 1.08, child: stone))));
  }
}

/// A mark pressed into metal: a faint light edge below a darker cut.
class _Engraved extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  const _Engraved(this.icon, {required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Stack(children: [
        Transform.translate(
            offset: const Offset(0, 1.3),
            child: Icon(icon,
                size: size, color: Colors.white.withValues(alpha: .55))),
        Icon(icon, size: size, color: color.withValues(alpha: .88)),
      ]);
}

/// A band of light that passes over a metal stone now and then. Each stone
/// is a little out of step with the next, so the light seems to travel
/// down the path.
class _SheenPainter extends CustomPainter {
  final Animation<double> light;
  final double offset;
  _SheenPainter(this.light, {required this.offset}) : super(repaint: light);

  @override
  void paint(Canvas canvas, Size size) {
    // The band crosses the face in part of each turn and rests off it for
    // the rest, so the stones glint rather than flicker.
    final p = (light.value + offset) % 1.0;
    final centre = -.5 + p * 3.0;
    if (centre < -.4 || centre > 1.4) return;
    final rect = Offset.zero & size;
    final a = -1 + 2 * (centre - .28), b = -1 + 2 * (centre + .28);
    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment(a, -1),
              end: Alignment(b, 1),
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: .4),
                Colors.white.withValues(alpha: 0),
              ]).createShader(rect));
  }

  @override
  bool shouldRepaint(_SheenPainter old) =>
      old.light != light || old.offset != offset;
}

/// The little sign over today's stone.
class _Bubble extends StatelessWidget {
  final String text;
  const _Bubble({required this.text});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      DecoratedBox(
          decoration: ShapeDecoration(
              color: t.surface,
              shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: t.hairline)),
              shadows: HolyDepth.paper(t)),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Text(text.toUpperCase(),
                  style: HolyTypography.eyebrow
                      .copyWith(color: t.accent, letterSpacing: 1.4)))),
      CustomPaint(size: const Size(14, 7), painter: _Tail(t.surface)),
    ]);
  }
}

class _Tail extends CustomPainter {
  final Color color;
  _Tail(this.color);
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color);
  @override
  bool shouldRepaint(_Tail old) => old.color != color;
}

/// A photo that drifts more slowly than the page as she scrolls, so the
/// chapter header reads as a window with depth behind it.
class _Parallax extends StatelessWidget {
  final Widget child;
  const _Parallax({required this.child});
  @override
  Widget build(BuildContext context) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null || MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return Flow(
        delegate: _ParallaxDelegate(scrollable: scrollable, item: context),
        children: [child]);
  }
}

class _ParallaxDelegate extends FlowDelegate {
  final ScrollableState scrollable;
  final BuildContext item;
  _ParallaxDelegate({required this.scrollable, required this.item})
      : super(repaint: scrollable.position);

  /// How much taller the photo is than its window.
  static const overscan = 1.28;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tightFor(
          width: constraints.maxWidth,
          height: constraints.maxHeight * overscan);

  @override
  void paintChildren(FlowPaintingContext context) {
    final viewport = scrollable.context.findRenderObject();
    final box = item.findRenderObject();
    if (viewport is! RenderBox || box is! RenderBox || !box.attached) {
      context.paintChild(0);
      return;
    }
    final centre =
        box.localToGlobal(box.size.center(Offset.zero), ancestor: viewport);
    final fraction = (centre.dy / viewport.size.height).clamp(0.0, 1.0);
    final extra = context.getChildSize(0)!.height - context.size.height;
    context.paintChild(0,
        transform: Matrix4.translationValues(0, -extra * fraction, 0));
  }

  @override
  bool shouldRepaint(_ParallaxDelegate old) =>
      scrollable != old.scrollable || item != old.item;
}
