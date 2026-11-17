import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/chapters.g.dart';
import '../../data/lessons.g.dart';
import '../../design/art_catalog.dart';
import '../../design/design.dart';
import '../../design/widgets/coin.dart';
import '../../design/widgets/glass.dart';
import '../../design/widgets/holy_header.dart';
import '../../domain/access.dart';
import '../../domain/badges.dart';
import '../../domain/calendar.dart';
import '../../domain/daily_verse.dart';
import '../../domain/lesson_position.dart';
import '../../domain/pacing.dart';
import '../../domain/streak.dart';
import '../../services/auth_service.dart';
import '../../services/billing.dart';
import '../../services/repository.dart';
import '../common.dart';

/// Where a lesson stands on the road.
enum Stop { done, current, tomorrow, ahead, locked }

const _bannerHeight = 132.0;
const _nodeGap = 112.0;
const _sectionHeight = _bannerHeight + 22 + 5 * _nodeGap + 34;

/// The walk: today's lesson at the top, then the whole road, chapter by
/// chapter, every lesson a coin on a winding brass path.
class WalkScreen extends ConsumerStatefulWidget {
  final DateTime? now;
  const WalkScreen({super.key, this.now});
  @override
  ConsumerState<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends ConsumerState<WalkScreen> {
  final _scroll = ScrollController();
  final _roadKey = GlobalKey();
  Timer? _clock;

  /// Where the current lesson sits relative to the screen: -1 above, 0 in
  /// view, 1 below.
  final _todayAway = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    // Midnight opens the next lesson; look once a minute.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _scroll.addListener(_measure);
  }

  @override
  void dispose() {
    _clock?.cancel();
    _scroll.dispose();
    _todayAway.dispose();
    super.dispose();
  }

  /// Where the road begins in the scroll content, kept once measured: the
  /// header scrolls out of the list as you walk down the road.
  double? _roadStart;

  /// Measured after layout only: inside a scroll listener the boxes still
  /// sit where the last frame put them, which would count the scroll twice.
  double? _measureRoad({bool fresh = false}) {
    if (!fresh && _roadStart != null) return _roadStart;
    final box = _roadKey.currentContext?.findRenderObject() as RenderBox?;
    final page = context.findRenderObject() as RenderBox?;
    if (box != null && page != null && box.attached && _scroll.hasClients) {
      _roadStart = box.localToGlobal(Offset.zero, ancestor: page).dy +
          box.size.height +
          _scroll.offset;
    }
    return _roadStart;
  }

  int get _todayDay {
    final state = ref.read(repositoryProvider);
    final pacing = pacingFor(state.completed, widget.now ?? DateTime.now(),
        state.profile.timeZone);
    return pacing.finished ? 365 : pacing.currentDay;
  }

  /// The centre of a day's stop, measured from the start of the road.
  static double _stopOffset(int day) {
    final i = day - 1;
    return (i ~/ 5) * _sectionHeight +
        _bannerHeight +
        22 +
        (i % 5) * _nodeGap +
        _nodeGap / 2;
  }

  void _measure({bool fresh = false}) {
    final road = _measureRoad(fresh: fresh);
    if (road == null || !_scroll.hasClients) {
      _todayAway.value = 0;
      return;
    }
    final view = _scroll.position.viewportDimension;
    // Up top, today's card is on screen: that is today.
    if (_scroll.offset < road - view * .55) {
      _todayAway.value = 0;
      return;
    }
    final y = road + _stopOffset(_todayDay) - _scroll.offset;
    final top = HolyHeader.inset(context);
    final bottom = view - MediaQuery.paddingOf(context).bottom;
    _todayAway.value = y < top ? -1 : y > bottom ? 1 : 0;
  }

  void _backToToday() {
    final road = _measureRoad();
    if (road == null || !_scroll.hasClients) return;
    HolyHaptics.tap();
    final view = _scroll.position.viewportDimension;
    final target = (road + _stopOffset(_todayDay) - view * .45)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    final distance = (target - _scroll.offset).abs();
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(target,
          duration: Duration(
              milliseconds: (420 + distance / 12).clamp(420, 1100).round()),
          curve: Curves.easeInOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final state = ref.watch(repositoryProvider);
    final owned = ref.watch(accessProvider.select((a) => a.active));
    final now = widget.now ?? DateTime.now();
    final zone = state.profile.timeZone;
    final local = localNow(now, zone);
    final pacing = pacingFor(state.completed, now, zone);
    final streak = streakFor(state.completed, now, zone);
    final name = state.profile.name.trim().split(RegExp(r'\s+')).first;
    final verse = dailyVerse(lessons, now, zone);
    final media = MediaQuery.of(context);
    Stop stopFor(int day) {
      if (state.completed.containsKey(day)) return Stop.done;
      if (day == pacing.currentDay && !pacing.finished) {
        if (!pacing.canBegin) return Stop.tomorrow;
        return canOpenLesson(day, owned: owned, completed: state.completed)
            ? Stop.current
            : Stop.locked;
      }
      if (!canOpenLesson(day, owned: owned, completed: state.completed)) {
        return Stop.locked;
      }
      return Stop.ahead;
    }

    void openStop(int day, Stop stop) {
      switch (stop) {
        case Stop.done:
        case Stop.current:
          HolyHaptics.buttonPress();
          context.push('/lesson/$day');
        case Stop.locked:
          HolyHaptics.buttonPress();
          context.push('/offer?day=$day');
        case Stop.tomorrow:
          HolyHaptics.tap();
          toast(context, 'Day $day opens tomorrow morning.');
        case Stop.ahead:
          HolyHaptics.tap();
          toast(context, 'One day at a time. Day $day comes after Day ${pacing.currentDay}.');
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure(fresh: true);
    });

    final greeting = local.hour < 12
        ? 'Good morning'
        : local.hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final earned = {
      for (final b in badgesFor(
          completed: state.completed,
          saved: state.saved,
          streak: streak,
          promiseStartedAt: state.profile.promiseStartedAt,
          timeZone: zone))
        b.id: b.earned
    };

    return Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: HolyHeader(
            streak: streak.current, onStreak: () => context.go('/growth')),
        body: Stack(children: [
          CustomScrollView(
              key: const PageStorageKey('walk'),
              controller: _scroll,
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                    child: SizedBox(height: HolyHeader.inset(context))),
                SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: HolySpace.gutter - 4),
                    sliver: SliverList.list(children: [
                      Rise(
                          child: _Greeting(
                              date: _date(local),
                              text: name.isEmpty ? greeting : '$greeting, $name')),
                      const SizedBox(height: 18),
                      Rise(
                          index: 1,
                          child: WeekCoins(
                              completed: state.completed.values.toSet(),
                              grace: streak.graceDates,
                              today: local)),
                      const SizedBox(height: 20),
                      Rise(
                          index: 2,
                          child: TodayCard(
                              pacing: pacing,
                              owned: owned,
                              completed: state.completed)),
                      const SizedBox(height: 14),
                      Rise(
                          index: 3,
                          child: _VerseCard(
                              day: verse.day,
                              verse: verse.verse,
                              reference: verse.reference)),
                      const SizedBox(height: 14),
                      Rise(
                          index: 4,
                          child: _RoadMeter(
                              day: pacing.currentDay,
                              finished: pacing.finished,
                              walked: state.completed.length,
                              onPressed: _backToToday)),
                      const SizedBox(height: 34),
                      const _RoadTitle(),
                      SizedBox(key: _roadKey, height: 18),
                    ])),
                SliverList.builder(
                    itemCount: chapters.length,
                    itemBuilder: (context, i) => _ChapterSection(
                        chapter: chapters[i],
                        stops: [
                          for (var d = chapters[i].firstDay;
                              d <= chapters[i].lastDay;
                              d++)
                            stopFor(d)
                        ],
                        earned: earned,
                        onStop: openStop)),
                SliverToBoxAdapter(
                    child: _RoadEnd(
                        finished: pacing.finished,
                        bottom: media.padding.bottom)),
              ]),
          Positioned(
              left: 0,
              right: 0,
              bottom: media.padding.bottom + 4,
              child: ValueListenableBuilder<int>(
                  valueListenable: _todayAway,
                  builder: (context, away, _) => IgnorePointer(
                      ignoring: away == 0,
                      child: AnimatedOpacity(
                          opacity: away == 0 ? 0 : 1,
                          duration: const Duration(milliseconds: 220),
                          child: AnimatedSlide(
                              offset: Offset(0, away == 0 ? .4 : 0),
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              child: Center(
                                  child: _BackToToday(
                                      up: away < 0,
                                      onPressed: _backToToday))))))),
          // A soft fade where the road meets the tab bar.
          Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: media.padding.bottom * .9,
              child: IgnorePointer(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                t.paper.withValues(alpha: 0),
                t.paper.withValues(alpha: .55),
              ]))))),
        ]));
  }

  static String _date(DateTime d) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
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
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }
}

class _Greeting extends StatelessWidget {
  final String date, text;
  const _Greeting({required this.date, required this.text});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Eyebrow(date, color: t.accent),
          const SizedBox(height: 6),
          Semantics(
              header: true,
              child: Text(text,
                  maxLines: 2,
                  style: HolyTypography.title
                      .copyWith(color: t.ink, fontSize: 31, height: 1.08))),
        ]));
  }
}

/// The last seven days ending today, each a small coin: brass where you read,
/// pine where a grace day held the streak, steel where the day is still open.
class WeekCoins extends StatelessWidget {
  final Set<String> completed, grace;
  final DateTime today;
  const WeekCoins(
      {super.key,
      required this.completed,
      required this.grace,
      required this.today});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Glass(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 6; i >= 0; i--)
                () {
                  final d = DateTime(today.year, today.month, today.day - i);
                  final key = dateKey(d);
                  final read = completed.contains(key);
                  final kept = grace.contains(key);
                  final isToday = i == 0;
                  return Semantics(
                      label:
                          '${letters[d.weekday - 1]} ${d.day}, ${read ? 'read' : kept ? 'grace day' : 'not read'}',
                      excludeSemantics: true,
                      child: Column(children: [
                        Text(letters[d.weekday - 1],
                            style: HolyTypography.caption.copyWith(
                                color: isToday ? t.accent : t.muted,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 7),
                        DecoratedBox(
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: isToday && !read
                                    ? Border.all(color: t.accent, width: 1.6)
                                    : null),
                            child: Padding(
                                padding: EdgeInsets.all(isToday && !read ? 2 : 0),
                                child: HolyCoin(
                                    size: isToday && !read ? 32 : 36,
                                    metal: read
                                        ? CoinMetal.brass
                                        : kept
                                            ? CoinMetal.pine
                                            : CoinMetal.steel,
                                    thickness: .07,
                                    face: read
                                        ? const Icon(CupertinoIcons.checkmark_alt)
                                        : kept
                                            ? const Icon(CupertinoIcons.leaf_arrow_circlepath)
                                            : Text('${d.day}',
                                                style: TextStyle(
                                                    fontSize: isToday ? 13 : 14,
                                                    color: isToday
                                                        ? const Color(0xFFE6EBF1)
                                                        : null))))),
                      ]));
                }(),
            ]));
  }
}

enum _CardState { begin, resume, done, locked, finished }

/// Today's lesson on its photograph: the one thing to do this morning.
class TodayCard extends ConsumerWidget {
  final Pacing pacing;
  final bool owned;
  final Map<int, String> completed;
  const TodayCard(
      {super.key,
      required this.pacing,
      required this.owned,
      required this.completed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = HolyThemeScope.of(context);
    final day = pacing.finished
        ? 365
        : pacing.nextUnlock != null
            ? pacing.displayDay
            : pacing.currentDay;
    final uid = ref.watch(authProvider.select((a) => a.user?.uid));
    final locked = pacing.canBegin &&
        !canOpenLesson(pacing.currentDay, owned: owned, completed: completed);
    final lesson = lessons[day - 1];
    final next = pacing.nextUnlock != null && pacing.currentDay <= 365
        ? lessons[pacing.currentDay - 1]
        : null;
    final chapter = Chapter.forDay(day);

    return FutureBuilder<LessonPosition?>(
        future: uid == null || !pacing.canBegin
            ? Future.value(null)
            : LessonPositionStore.read(uid, lessons[pacing.currentDay - 1]),
        builder: (context, snapshot) {
          final position = snapshot.data;
          final state = pacing.finished
              ? _CardState.finished
              : pacing.nextUnlock != null
                  ? _CardState.done
                  : locked
                      ? _CardState.locked
                      : position != null && position.stage.index > 0
                          ? _CardState.resume
                          : _CardState.begin;
          final eyebrow = switch (state) {
            _CardState.done => 'Day $day · Done for today',
            _CardState.finished => 'The whole road · Complete',
            _ => 'Day $day · ${lesson.theme}',
          };
          void open() {
            HolyHaptics.buttonPress();
            switch (state) {
              case _CardState.locked:
                context.push('/offer?day=$day');
              case _CardState.finished:
                context.push('/lesson/1');
              default:
                context.push('/lesson/$day');
            }
          }

          final action = switch (state) {
            _CardState.begin => 'Begin Day $day',
            _CardState.resume => 'Continue Day $day',
            _CardState.done => 'Read again',
            _CardState.locked => 'Unlock lifetime access',
            _CardState.finished => 'Start again at Day 1',
          };
          final line = switch (state) {
            _CardState.done => next == null
                ? lesson.holdOn
                : 'Tomorrow: ${next.title}. ${next.teaser}',
            _CardState.locked =>
              'Days 1 to 7 were free. One payment opens every lesson, for life.',
            _CardState.finished =>
              'You walked the whole road. Every lesson is still yours.',
            _ => lesson.teaser,
          };

          return Semantics(
              container: true,
              child: Pressable(
                  onPressed: open,
                  pressedScale: .985,
                  child: DecoratedBox(
                      decoration: ShapeDecoration(
                          shape: RoundedSuperellipseBorder(
                              borderRadius: BorderRadius.circular(28)),
                          shadows: [
                            BoxShadow(
                                color: t.accent
                                    .withValues(alpha: t.isDark ? .20 : .14),
                                blurRadius: 40,
                                spreadRadius: -8,
                                offset: const Offset(0, 18)),
                            BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: t.isDark ? .45 : .18),
                                blurRadius: 24,
                                offset: const Offset(0, 10)),
                          ]),
                      child: ClipRSuperellipse(
                          borderRadius: BorderRadius.circular(28),
                          child: Stack(children: [
                            Positioned.fill(
                                child: Hero(
                                    tag: 'art-$day',
                                    child: Image.asset(
                                        HolyArtCatalog.assetForDay(day),
                                        fit: BoxFit.cover,
                                        alignment: const Alignment(0, -.2),
                                        excludeFromSemantics: true,
                                        errorBuilder: (c, e, s) =>
                                            ColoredBox(color: t.sunk)))),
                            const Positioned.fill(
                                child: DecoratedBox(
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            stops: [0, .32, .62, 1],
                                            colors: [
                                  Color(0x660B0E13),
                                  Color(0x000B0E13),
                                  Color(0xB30B0E13),
                                  Color(0xF20B0E13),
                                ])))),
                            Positioned.fill(
                                child: DecoratedBox(
                                    decoration: ShapeDecoration(
                                        shape: RoundedSuperellipseBorder(
                                            borderRadius:
                                                BorderRadius.circular(28),
                                            side: BorderSide(
                                                color: HolyTheme.photoBrass
                                                    .withValues(alpha: .38),
                                                width: 1))))),
                            Padding(
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        _PhotoChip(
                                            icon: switch (state) {
                                              _CardState.locked =>
                                                CupertinoIcons.lock_fill,
                                              _CardState.done ||
                                              _CardState.finished =>
                                                CupertinoIcons.checkmark_seal_fill,
                                              _ => CupertinoIcons.book_fill,
                                            },
                                            text: 'Chapter ${chapter.number}'),
                                        const Spacer(),
                                        if (state != _CardState.locked)
                                          const _PhotoChip(
                                              icon: CupertinoIcons.timer,
                                              text: '5 min'),
                                      ]),
                                      const SizedBox(height: 108),
                                      Text(eyebrow.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: HolyTypography.eyebrow.copyWith(
                                              color: HolyTheme.photoBrass)),
                                      const SizedBox(height: 6),
                                      Text(lesson.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: HolyTypography.headline.copyWith(
                                              color: HolyTheme.photoInk,
                                              fontSize: 29,
                                              height: 1.08,
                                              shadows: const [
                                                Shadow(
                                                    color: Color(0x99000000),
                                                    blurRadius: 18)
                                              ])),
                                      const SizedBox(height: 8),
                                      Text(line,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: HolyTypography.reading.copyWith(
                                              color: HolyTheme.photoInk
                                                  .withValues(alpha: .84),
                                              fontSize: 16,
                                              height: 1.4)),
                                      const SizedBox(height: 16),
                                      state == _CardState.done
                                          ? HolyButton(action,
                                              style: HolyButtonStyle.onPhoto,
                                              height: 52,
                                              onPressed: open)
                                          : HolyButton(action,
                                              style: HolyButtonStyle.photoPrimary,
                                              height: 52,
                                              onPressed: open),
                                    ])),
                          ])))));
        });
  }
}

class _PhotoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PhotoChip({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          color: const Color(0x590B0E13),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x33FFFFFF), width: .8)),
      child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: HolyTheme.photoBrass),
            const SizedBox(width: 5),
            Text(text,
                style: HolyTypography.caption.copyWith(
                    color: HolyTheme.photoInk, fontWeight: FontWeight.w800)),
          ])));
}

class _VerseCard extends StatelessWidget {
  final int day;
  final String verse, reference;
  const _VerseCard(
      {required this.day, required this.verse, required this.reference});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Pressable(
        onPressed: () => context.push('/verse/$day'),
        pressedScale: .98,
        semanticLabel: 'Verse of the day. $verse $reference',
        child: Glass(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('“',
                  style: HolyTypography.display.copyWith(
                      color: t.accent, fontSize: 54, height: .9)),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Eyebrow('Verse of the day', color: t.accent),
                    const SizedBox(height: 6),
                    Text(verse,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: HolyTypography.verse.copyWith(
                            color: t.ink, fontSize: 19, height: 1.28)),
                    const SizedBox(height: 8),
                    Text(reference,
                        style: HolyTypography.label.copyWith(color: t.muted)),
                  ])),
              Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(CupertinoIcons.chevron_right,
                      size: 15, color: t.muted)),
            ])));
  }
}

/// Where you are on the road: the chapter, its five stops, and the days
/// walked so far. Tapping it takes you to your place on the path.
class _RoadMeter extends StatelessWidget {
  final int day, walked;
  final bool finished;
  final VoidCallback onPressed;
  const _RoadMeter(
      {required this.day,
      required this.walked,
      required this.finished,
      required this.onPressed});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final chapter = Chapter.forDay(day);
    final into = finished ? 5 : day - chapter.firstDay;
    return Pressable(
        onPressed: onPressed,
        pressedScale: .98,
        semanticLabel:
            'Chapter ${chapter.number}, ${chapter.title}. $walked days walked. Show my place on the road.',
        child: Glass(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(children: [
              Row(children: [
                HolyCoin(
                    size: 40,
                    thickness: .07,
                    face: Text('${chapter.number}',
                        style: const TextStyle(fontSize: 15))),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Eyebrow('Chapter ${chapter.number}', color: t.muted),
                      const SizedBox(height: 2),
                      Text(chapter.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HolyTypography.headline
                              .copyWith(color: t.ink, fontSize: 20)),
                    ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$walked',
                      style: HolyTypography.numeral
                          .copyWith(color: t.ink, fontSize: 24, height: 1)),
                  Text(walked == 1 ? 'day walked' : 'days walked',
                      style: HolyTypography.caption.copyWith(color: t.muted)),
                ]),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                for (var i = 0; i < 5; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                      child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: 6,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: i < into
                                  ? LinearGradient(colors: [
                                      Color.lerp(t.accent, Colors.white, .25)!,
                                      t.accent
                                    ])
                                  : null,
                              color: i < into
                                  ? null
                                  : i == into
                                      ? t.accent.withValues(alpha: .28)
                                      : t.hairline))),
                ],
              ]),
            ])));
  }
}

class _RoadTitle extends StatelessWidget {
  const _RoadTitle();
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    Widget rule(bool left) => Expanded(
        child: Container(
            height: 1,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: left
                        ? [t.accent.withValues(alpha: 0), t.accent.withValues(alpha: .5)]
                        : [t.accent.withValues(alpha: .5), t.accent.withValues(alpha: 0)]))));
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          rule(true),
          const SizedBox(width: 12),
          Text('THE ROAD',
              style: HolyTypography.eyebrow
                  .copyWith(color: t.accent, letterSpacing: 3)),
          const SizedBox(width: 12),
          rule(false),
        ]));
  }
}

/// One chapter: its banner, then five stops on the path.
class _ChapterSection extends StatelessWidget {
  final Chapter chapter;
  final List<Stop> stops;
  final Map<String, bool> earned;
  final void Function(int day, Stop stop) onStop;
  const _ChapterSection(
      {required this.chapter,
      required this.stops,
      required this.earned,
      required this.onStop});

  static double xFor(int day) => math.sin((day - 1) * 1.05) * .68;

  @override
  Widget build(BuildContext context) {
    final done = stops.where((s) => s == Stop.done).length;
    final live = stops.any((s) => s == Stop.current || s == Stop.tomorrow);
    final ahead = done == 0 && !live;
    return SizedBox(
        height: _sectionHeight,
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          final amp = math.min(w / 2 - 74, 150.0);
          Offset at(int i) => Offset(w / 2 + xFor(chapter.firstDay + i) * amp,
              _bannerHeight + 22 + i * _nodeGap + _nodeGap / 2);
          return Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
                child: CustomPaint(
                    painter: _PathPainter(
                        points: [for (var i = 0; i < 5; i++) at(i)],
                        start: Offset(w / 2, _bannerHeight + 4),
                        end: Offset(w / 2, _sectionHeight),
                        stops: stops,
                        color: HolyThemeScope.of(context).accent,
                        rest: HolyThemeScope.of(context).hairline))),
            Positioned(
                left: HolySpace.gutter - 4,
                right: HolySpace.gutter - 4,
                top: 0,
                height: _bannerHeight,
                child: _ChapterBanner(
                    chapter: chapter,
                    done: done,
                    live: live,
                    ahead: ahead)),
            for (var i = 0; i < 5; i++) ...[
              () {
                final day = chapter.firstDay + i;
                final title = dayBadgeTitles[day];
                if (title == null) return const SizedBox.shrink();
                final p = at(i);
                final side = xFor(day) >= -.05 ? -1 : 1;
                final x = w / 2 + side * amp * .98;
                final id = 'days-$day';
                return Positioned(
                    left: x - 56,
                    top: p.dy - 34,
                    width: 112,
                    child: _Milestone(
                        id: id, title: title, earned: earned[id] == true));
              }(),
              Positioned(
                  left: at(i).dx - 60,
                  top: at(i).dy - 60,
                  width: 120,
                  height: 120,
                  child: _StopNode(
                      day: chapter.firstDay + i,
                      stop: stops[i],
                      onPressed: () => onStop(chapter.firstDay + i, stops[i]))),
            ],
          ]);
        }));
  }
}

class _ChapterBanner extends StatelessWidget {
  final Chapter chapter;
  final int done;
  final bool live, ahead;
  const _ChapterBanner(
      {required this.chapter,
      required this.done,
      required this.live,
      required this.ahead});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final complete = done == 5;
    final radius = BorderRadius.circular(26);
    return Semantics(
        header: true,
        label:
            'Chapter ${chapter.number}, ${chapter.title}. ${chapter.summary} $done of 5 read.',
        excludeSemantics: true,
        child: DecoratedBox(
            decoration: ShapeDecoration(
                shape: RoundedSuperellipseBorder(borderRadius: radius),
                shadows: [
                  if (live)
                    BoxShadow(
                        color: t.accent.withValues(alpha: .34),
                        blurRadius: 30,
                        spreadRadius: -6),
                  BoxShadow(
                      color: Colors.black.withValues(alpha: t.isDark ? .4 : .16),
                      blurRadius: 18,
                      offset: const Offset(0, 8)),
                ]),
            child: ClipRSuperellipse(
                borderRadius: radius,
                child: Stack(fit: StackFit.expand, children: [
                  ColorFiltered(
                      colorFilter: ahead
                          ? const ColorFilter.matrix([
                              .25, .5, .08, 0, 0, //
                              .25, .5, .08, 0, 0,
                              .27, .52, .1, 0, 4,
                              0, 0, 0, 1, 0,
                            ])
                          : const ColorFilter.mode(
                              Colors.transparent, BlendMode.dst),
                      child: Image.asset(
                          HolyArtCatalog.assetForDay(chapter.firstDay),
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -.1),
                          excludeFromSemantics: true,
                          errorBuilder: (c, e, s) => ColoredBox(color: t.sunk))),
                  DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                    HolyTheme.photoShade.withValues(alpha: .94),
                    HolyTheme.photoShade.withValues(alpha: .70),
                    HolyTheme.photoShade.withValues(alpha: ahead ? .62 : .22),
                  ], stops: const [0, .55, 1]))),
                  DecoratedBox(
                      decoration: ShapeDecoration(
                          shape: RoundedSuperellipseBorder(
                              borderRadius: radius,
                              side: BorderSide(
                                  color: live
                                      ? HolyTheme.photoBrass.withValues(alpha: .75)
                                      : Colors.white.withValues(alpha: .10),
                                  width: live ? 1.4 : 1)))),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(children: [
                        HolyCoin(
                            size: 58,
                            metal: ahead ? CoinMetal.steel : CoinMetal.brass,
                            glow: live ? .55 : 0,
                            face: Text('${chapter.number}',
                                style: TextStyle(
                                    fontSize: chapter.number > 9 ? 20 : 23))),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('CHAPTER ${chapter.number}',
                                  style: HolyTypography.eyebrow.copyWith(
                                      color: ahead
                                          ? HolyTheme.photoInk.withValues(alpha: .6)
                                          : HolyTheme.photoBrass,
                                      fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(chapter.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: HolyTypography.headline.copyWith(
                                      color: HolyTheme.photoInk,
                                      fontSize: 21,
                                      height: 1.1)),
                              const SizedBox(height: 4),
                              Text(chapter.summary,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: HolyTypography.caption.copyWith(
                                      color:
                                          HolyTheme.photoInk.withValues(alpha: .74),
                                      height: 1.3)),
                            ])),
                        const SizedBox(width: 12),
                        _MiniRing(done: done, complete: complete),
                      ])),
                ]))));
  }
}

class _MiniRing extends StatelessWidget {
  final int done;
  final bool complete;
  const _MiniRing({required this.done, required this.complete});
  @override
  Widget build(BuildContext context) => SizedBox.square(
      dimension: 42,
      child: CustomPaint(
          painter: _RingPainter(done / 5),
          child: Center(
              child: complete
                  ? const Icon(CupertinoIcons.checkmark_alt,
                      size: 18, color: HolyTheme.photoBrass)
                  : Text('$done/5',
                      style: HolyTypography.caption.copyWith(
                          color: HolyTheme.photoInk,
                          fontWeight: FontWeight.w800,
                          fontSize: 11)))));
}

class _RingPainter extends CustomPainter {
  final double value;
  const _RingPainter(this.value);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2.5);
    canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..color = Colors.white.withValues(alpha: .16));
    if (value <= 0) return;
    canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..shader = const SweepGradient(
                  colors: [Color(0xFFB5813A), HolyTheme.photoBrass, Color(0xFFF7DFA4)])
              .createShader(rect));
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

/// The road between stops: brass where you have walked, a dotted trail where
/// you have not.
class _PathPainter extends CustomPainter {
  final List<Offset> points;
  final Offset start, end;
  final List<Stop> stops;
  final Color color, rest;
  const _PathPainter(
      {required this.points,
      required this.start,
      required this.end,
      required this.stops,
      required this.color,
      required this.rest});

  Path _curve(Offset a, Offset b) {
    final dy = (b.dy - a.dy) / 2;
    return Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(a.dx, a.dy + dy, b.dx, b.dy - dy, b.dx, b.dy);
  }

  bool _reached(int i) =>
      i < stops.length &&
      (stops[i] == Stop.done || stops[i] == Stop.current || stops[i] == Stop.tomorrow);

  @override
  void paint(Canvas canvas, Size size) {
    final chain = [start, ...points, end];
    for (var i = 0; i < chain.length - 1; i++) {
      final path = _curve(chain[i], chain[i + 1]);
      // Segment i leads into stop i; the last leads out of the chapter.
      final walked = i < stops.length ? _reached(i) : stops.last == Stop.done;
      if (walked) {
        canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 12
              ..strokeCap = StrokeCap.round
              ..color = color.withValues(alpha: .22)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..strokeCap = StrokeCap.round
              ..shader = LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color.lerp(color, Colors.white, .3)!, color])
                  .createShader(path.getBounds().inflate(4)));
      } else {
        final dots = Paint()..color = rest.withValues(alpha: .9);
        for (final metric in path.computeMetrics()) {
          for (var d = 6.0; d < metric.length; d += 14) {
            final p = metric.getTangentForOffset(d)!.position;
            canvas.drawCircle(p, 2.6, dots);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.color != color ||
      old.rest != rest ||
      old.start != start ||
      old.stops.join() != stops.join() ||
      old.points.join() != points.join();
}

/// One lesson on the road: a coin you can tap.
class _StopNode extends StatefulWidget {
  final int day;
  final Stop stop;
  final VoidCallback onPressed;
  const _StopNode(
      {required this.day, required this.stop, required this.onPressed});
  @override
  State<_StopNode> createState() => _StopNodeState();
}

class _StopNodeState extends State<_StopNode>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_StopNode old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final live = widget.stop == Stop.current &&
        !MediaQuery.disableAnimationsOf(context);
    if (live && _pulse == null) {
      _pulse = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 2200))
        ..repeat();
    } else if (!live && _pulse != null) {
      _pulse!.dispose();
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final stop = widget.stop;
    final current = stop == Stop.current;
    final size = current ? 80.0 : stop == Stop.done ? 62.0 : 56.0;
    final lesson = lessons[widget.day - 1];
    final label = switch (stop) {
      Stop.done => 'Day ${widget.day}, ${lesson.title}. Read. Tap to read again.',
      Stop.current => 'Day ${widget.day}, ${lesson.title}. Today. Tap to begin.',
      Stop.tomorrow => 'Day ${widget.day}. Opens tomorrow.',
      Stop.ahead => 'Day ${widget.day}. Still ahead.',
      Stop.locked => 'Day ${widget.day}. Unlock lifetime access to read it.',
    };
    final coin = HolyCoin(
        size: size,
        metal: stop == Stop.done || current ? CoinMetal.brass : CoinMetal.steel,
        glow: current ? .9 : stop == Stop.done ? .18 : 0,
        face: switch (stop) {
          Stop.done => const Icon(CupertinoIcons.checkmark_alt),
          Stop.current => Text('${widget.day}',
              style: TextStyle(fontSize: widget.day > 99 ? 24 : 28)),
          Stop.tomorrow => Icon(CupertinoIcons.moon_stars_fill,
              color: const Color(0xFFB8C2CF).withValues(alpha: .9)),
          Stop.locked => Icon(CupertinoIcons.lock_fill,
              color: const Color(0xFFB8C2CF).withValues(alpha: .85)),
          Stop.ahead => Text('${widget.day}',
              style: TextStyle(
                  fontSize: widget.day > 99 ? 17 : 19,
                  color: const Color(0xFFC9D1DB).withValues(alpha: .85))),
        });
    return Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          if (_pulse != null)
            AnimatedBuilder(
                animation: _pulse!,
                builder: (context, _) => CustomPaint(
                    size: const Size.square(120),
                    painter: _PulsePainter(_pulse!.value, t.accent))),
          Pressable(
              onPressed: widget.onPressed,
              pressedScale: .92,
              borderRadius: BorderRadius.circular(size),
              child: coin),
          if (current || stop == Stop.tomorrow)
            Positioned(
                top: current ? -12 : 2,
                child: _Bubble(
                    text: current ? 'START' : 'TOMORROW', strong: current)),
          if (current)
            Positioned(
                top: 104,
                width: 220,
                child: Text(lesson.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HolyTypography.headline.copyWith(
                        color: t.ink,
                        fontSize: 16,
                        shadows: [
                          Shadow(color: t.paper, blurRadius: 10),
                        ]))),
        ]));
  }
}

class _PulsePainter extends CustomPainter {
  final double t;
  final Color color;
  const _PulsePainter(this.t, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (final phase in [0.0, .5]) {
      final p = (t + phase) % 1;
      canvas.drawCircle(
          c,
          40 + p * 22,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2 * (1 - p) + .4
            ..color = color.withValues(alpha: (1 - p) * .55));
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t || old.color != color;
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool strong;
  const _Bubble({required this.text, required this.strong});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return IgnorePointer(
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
                gradient: strong
                    ? LinearGradient(colors: [
                        Color.lerp(t.accent, Colors.white, .22)!,
                        t.accent,
                      ])
                    : null,
                color: strong ? null : t.surface.withValues(alpha: .92),
                borderRadius: BorderRadius.circular(12),
                border: strong
                    ? null
                    : Border.all(color: t.hairline, width: 1),
                boxShadow: [
                  BoxShadow(
                      color: (strong ? t.accent : Colors.black)
                          .withValues(alpha: .35),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ]),
            child: Text(text,
                style: HolyTypography.caption.copyWith(
                    color: strong ? t.onPrimary : t.muted,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    fontSize: 11))));
  }
}

/// A milestone beside the road: its medallion, struck once you reach it.
class _Milestone extends StatelessWidget {
  final String id, title;
  final bool earned;
  const _Milestone(
      {required this.id, required this.title, required this.earned});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Semantics(
        label: '$title. ${earned ? 'Earned' : 'Not earned yet'}.',
        excludeSemantics: true,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          HolyCoin(
              size: 44,
              turn: -.35,
              tilt: .08,
              thickness: .1,
              image: HolyArtAssets.badgePath(id),
              muted: !earned,
              glow: earned ? .35 : 0),
          const SizedBox(height: 6),
          Text(title,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: HolyTypography.caption.copyWith(
                  color: earned ? t.accent : t.muted,
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                  height: 1.2)),
        ]));
  }
}

class _RoadEnd extends StatelessWidget {
  final bool finished;
  final double bottom;
  const _RoadEnd({required this.finished, required this.bottom});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Padding(
        padding: EdgeInsets.fromLTRB(32, 8, 32, bottom + 36),
        child: Column(children: [
          CoinBadge(
              size: 96,
              image: HolyArtAssets.badgePath('days-365'),
              muted: !finished,
              idle: true,
              glow: finished ? .6 : .15,
              semanticLabel: 'The end of the road'),
          const SizedBox(height: 16),
          Text('The end of the road',
              textAlign: TextAlign.center,
              style: HolyTypography.headline.copyWith(color: t.ink, fontSize: 22)),
          const SizedBox(height: 6),
          Text('Every lesson stays yours for life.',
              textAlign: TextAlign.center,
              style: HolyTypography.body.copyWith(color: t.muted)),
        ]));
  }
}

class _BackToToday extends StatelessWidget {
  final bool up;
  final VoidCallback onPressed;
  const _BackToToday({required this.up, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Pressable(
        onPressed: onPressed,
        semanticLabel: 'Back to today',
        child: Glass(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Back to today',
                  style: HolyTypography.label
                      .copyWith(color: t.ink, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              Icon(up ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
                  size: 15, color: t.accent),
            ])));
  }
}
