import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/lessons.g.dart';
import '../../design/art_catalog.dart';
import '../../design/chapter_catalog.g.dart';
import '../../design/design.dart';
import '../../domain/access.dart';
import '../../domain/calendar.dart';
import '../../domain/daily_verse.dart';
import '../../domain/lesson_position.dart';
import '../../domain/pacing.dart';
import '../../domain/streak.dart';
import '../../services/auth_service.dart';
import '../../services/billing.dart';
import '../../services/repository.dart';

/// Today: a greeting, the week, one lesson, the verse of the day and the
/// way into the journey. One viewport, no scrolling.
class TodayScreen extends ConsumerStatefulWidget {
  final DateTime? now;
  const TodayScreen({super.key, this.now});
  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  Timer? clock;
  @override
  void initState() {
    super.initState();
    // Midnight changes the lesson; check once a minute.
    clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final state = ref.watch(repositoryProvider);
    final owned = ref.watch(lifetimeProvider.select((a) => a.active));
    final now = widget.now ?? DateTime.now();
    final zone = state.profile.timeZone;
    final local = localNow(now, zone);
    final pacing = pacingFor(state.completed, now, zone);
    final streak = streakFor(state.completed, now, zone);
    final name = state.profile.name.trim().split(RegExp(r'\s+')).first;
    final media = MediaQuery.of(context);
    final compact = media.size.height < 740;
    final greeting = local.hour < 12
        ? 'Good morning'
        : local.hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final verse = dailyVerse(lessons, now, zone);

    return ColoredBox(
        color: t.paper,
        child: Padding(
            padding: EdgeInsets.only(top: media.padding.top),
            child: FitColumn(
                padding: EdgeInsets.fromLTRB(HolySpace.gutter, compact ? 8 : 16,
                    HolySpace.gutter, media.padding.bottom),
                children: [
                  Rise(
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Eyebrow(_date(local), color: t.muted),
                              const SizedBox(height: 4),
                              Semantics(
                                  header: true,
                                  child: Text(
                                      name.isEmpty
                                          ? greeting
                                          : '$greeting, $name',
                                      maxLines: 2,
                                      style: HolyTypography.title.copyWith(
                                          color: t.ink,
                                          fontSize: compact ? 26 : 30))),
                            ])),
                        const SizedBox(width: 12),
                        _StreakBadge(days: streak.current),
                      ])),
                  SizedBox(height: compact ? 12 : 18),
                  Rise(
                      index: 1,
                      child: WeekRow(
                          completed: state.completed.values.toSet(),
                          grace: streak.graceDates,
                          today: local)),
                  SizedBox(height: compact ? 12 : 18),
                  FitFlex(
                      // The text block grows with the reader's text size;
                      // the photograph above it gives way first.
                      min: 250 * MediaQuery.textScalerOf(context).scale(16) / 16 +
                          (MediaQuery.textScalerOf(context).scale(16) > 17 ? 60 : 0),
                      child: Rise(
                          index: 2,
                          child: _LessonCard(
                              pacing: pacing,
                              owned: owned,
                              completed: state.completed))),
                  SizedBox(height: compact ? 10 : 14),
                  Rise(
                      index: 3,
                      child: _VerseRow(
                          compact: compact,
                          day: verse.day,
                          verse: verse.verse,
                          reference: verse.reference)),
                  const SizedBox(height: 10),
                  Rise(
                      index: 4,
                      child: _JourneyRow(
                          day: pacing.displayDay,
                          done: state.completed.length)),
                  SizedBox(height: compact ? 6 : 12),
                ])));
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

class _StreakBadge extends StatelessWidget {
  final int days;
  const _StreakBadge({required this.days});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Semantics(
        label: days == 1 ? '1 day walk' : '$days day walk',
        excludeSemantics: true,
        child: Paper(
            radius: 22,
            lift: .5,
            padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(CupertinoIcons.sun_max_fill,
                  size: 18, color: days > 0 ? t.gold : t.hairline),
              const SizedBox(width: 6),
              RollingNumber(
                  value: days,
                  style: HolyTypography.numeral
                      .copyWith(color: t.ink, fontSize: 26)),
            ])));
  }
}

/// The last seven days ending today: read days filled, grace days dotted.
class WeekRow extends StatelessWidget {
  final Set<String> completed, grace;
  final DateTime today;
  const WeekRow(
      {super.key,
      required this.completed,
      required this.grace,
      required this.today});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
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
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                        width: MediaQuery.sizeOf(context).height < 740 ? 32 : 36,
                        height: MediaQuery.sizeOf(context).height < 740 ? 32 : 36,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: read ? t.olive : t.surface,
                            border: Border.all(
                                color: read
                                    ? t.olive
                                    : isToday
                                        ? t.accent
                                        : t.hairline,
                                width: isToday && !read ? 1.6 : 1)),
                        child: Center(
                            child: read
                                ? Icon(CupertinoIcons.checkmark_alt,
                                    size: 18, color: t.surface)
                                : kept
                                    ? Icon(CupertinoIcons.leaf_arrow_circlepath,
                                        size: 15, color: t.olive)
                                    : Text('${d.day}',
                                        style: HolyTypography.caption.copyWith(
                                            color: isToday ? t.ink : t.muted,
                                            fontWeight: FontWeight.w700)))),
                  ]));
            }(),
        ]);
  }
}

enum _CardState { begin, resume, done, locked, finished }

class _LessonCard extends ConsumerWidget {
  final Pacing pacing;
  final bool owned;
  final Map<int, String> completed;
  const _LessonCard(
      {required this.pacing, required this.owned, required this.completed});

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
    final chapter = ChapterCatalog.forDay(day);
    final compact = MediaQuery.sizeOf(context).height < 740;

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
            _CardState.done => 'Day $day · Complete',
            _CardState.finished => 'All 365 days · Complete',
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
            _CardState.locked => 'Unlock all 365 days',
            _CardState.finished => 'Start again at Day 1',
          };

          return Semantics(
              container: true,
              child: GestureDetector(
                  onTap: open,
                  child: Paper(
                      padding: EdgeInsets.zero,
                      lift: 1.2,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                                child: Stack(fit: StackFit.expand, children: [
                              Hero(
                                  tag: 'art-$day',
                                  child: Image.asset(
                                      HolyArtCatalog.assetForDay(day),
                                      fit: BoxFit.cover,
                                      alignment: const Alignment(0, .1),
                                      excludeFromSemantics: true,
                                      errorBuilder: (c, e, s) =>
                                          ColoredBox(color: t.sunk))),
                              const DecoratedBox(
                                  decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          stops: [0, .5, 1],
                                          colors: [
                                    Color(0x33000000),
                                    Color(0x00000000),
                                    Color(0x55000000),
                                  ]))),
                              Positioned(
                                  left: 18,
                                  right: 18,
                                  bottom: 14,
                                  child: Row(children: [
                                    if (state == _CardState.done ||
                                        state == _CardState.finished) ...[
                                      const HolyCheck(
                                          checked: true,
                                          size: 20,
                                          color: Color(0xFF6E7B4C),
                                          ink: Colors.white),
                                      const SizedBox(width: 8),
                                    ],
                                    if (state == _CardState.locked) ...[
                                      const Icon(CupertinoIcons.lock_fill,
                                          size: 15, color: HolyTheme.photoInk),
                                      const SizedBox(width: 6),
                                    ],
                                    Expanded(
                                        child: Text(eyebrow.toUpperCase(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: HolyTypography.eyebrow
                                                .copyWith(
                                                    color: HolyTheme.photoInk,
                                                    shadows: const [
                                                  Shadow(
                                                      color: Color(0x66000000),
                                                      blurRadius: 8)
                                                ]))),
                                    if (chapter != null &&
                                        state != _CardState.locked)
                                      Text('5 min',
                                          style: HolyTypography.caption
                                              .copyWith(
                                                  color: HolyTheme.photoInk,
                                                  fontWeight:
                                                      FontWeight.w700)),
                                  ])),
                            ])),
                            Padding(
                                padding: EdgeInsets.fromLTRB(
                                    20, compact ? 14 : 18, 20, compact ? 16 : 20),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(lesson.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: HolyTypography.headline
                                              .copyWith(
                                                  color: t.ink,
                                                  fontSize:
                                                      compact ? 24 : 27)),
                                      const SizedBox(height: 6),
                                      Text(
                                          switch (state) {
                                            _CardState.done => next == null
                                                ? lesson.holdOn
                                                : 'Tomorrow: ${next.title}. ${next.teaser}',
                                            _CardState.locked =>
                                              'Your free week is done. One payment opens every day that follows.',
                                            _CardState.finished =>
                                              'You walked the whole year. Every lesson is still here.',
                                            _ => lesson.teaser,
                                          },
                                          maxLines: compact ? 2 : 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: HolyTypography.readingItalic
                                              .copyWith(
                                                  color: t.muted,
                                                  fontSize: compact ? 15.5 : 16.5,
                                                  height: 1.45)),
                                      SizedBox(height: compact ? 12 : 16),
                                      state == _CardState.done
                                          ? HolyButton.secondary(action,
                                              height: compact ? 50 : 54,
                                              onPressed: open)
                                          : HolyButton(action,
                                              height: compact ? 50 : 54,
                                              onPressed: open),
                                    ])),
                          ]))));
        });
  }
}

class _VerseRow extends StatelessWidget {
  final int day;
  final String verse, reference;
  final bool compact;
  const _VerseRow(
      {required this.day,
      required this.verse,
      required this.reference,
      this.compact = false});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Pressable(
        onPressed: () => context.push('/verse/$day'),
        pressedScale: .98,
        semanticLabel: 'Verse of the day. $verse $reference',
        child: Paper(
            radius: 22,
            lift: .5,
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(children: [
              Container(
                  width: 3,
                  height: 40,
                  decoration: BoxDecoration(
                      color: t.gold, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Eyebrow('Verse of the day · $reference', color: t.muted),
                    const SizedBox(height: 3),
                    Text('“$verse”',
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: HolyTypography.verse.copyWith(
                            color: t.ink, fontSize: 19, height: 1.2)),
                  ])),
              Icon(CupertinoIcons.chevron_right, size: 15, color: t.muted),
            ])));
  }
}

class _JourneyRow extends StatelessWidget {
  final int day, done;
  const _JourneyRow({required this.day, required this.done});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final chapter = ChapterCatalog.forDay(day);
    final index = chapter == null
        ? 1
        : ChapterCatalog.chapters.indexOf(chapter) + 1;
    return Pressable(
        onPressed: () => context.push('/journey'),
        pressedScale: .98,
        semanticLabel:
            'Your journey. Chapter $index of 73, ${chapter?.title ?? ''}. $done of 365 days read.',
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Chapter $index · ${chapter?.title ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HolyTypography.label.copyWith(color: t.ink)),
                    const SizedBox(height: 7),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                            value: done / 365,
                            minHeight: 3,
                            color: t.accent,
                            backgroundColor: t.hairline)),
                  ])),
              const SizedBox(width: 14),
              Text('Your journey',
                  style: HolyTypography.label.copyWith(color: t.accent)),
              const SizedBox(width: 4),
              Icon(CupertinoIcons.chevron_right, size: 14, color: t.accent),
            ])));
  }
}
