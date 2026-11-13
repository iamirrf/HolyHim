import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/lessons.g.dart';
import '../../domain/pacing.dart';
import '../../domain/streak.dart';
import '../../design/design.dart';
import '../../design/art_catalog.dart';
import '../../design/chapter_catalog.g.dart';
import '../../services/repository.dart';
import '../../services/art_cache.dart';
import '../common.dart';

class WalkScreen extends ConsumerStatefulWidget {
  const WalkScreen({super.key});

  @override
  ConsumerState<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends ConsumerState<WalkScreen> {
  final scroll = ScrollController();
  final currentChapterKey = GlobalKey();
  double offset = 0;
  Timer? clock;

  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      if (mounted) setState(() => offset = scroll.offset);
    });
    clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    clock?.cancel();
    super.dispose();
  }

  void _openLesson(int day) {
    HolyHaptics.buttonPress();
    final state = ref.read(repositoryProvider);
    final pacing = pacingFor(state.completed, DateTime.now(), state.profile.timeZone);
    final allowed = pacing.canRead(day, state.completed);
    if (!allowed) {
      toast(context, 'Every day, a new lesson. There is no need to hurry.');
      return;
    }
    context.push('/lesson/$day');
  }

  void _previewLesson(int day) {
    HolyHaptics.tap();
    final state = ref.read(repositoryProvider);
    final lesson = lessons[day - 1];
    final pacing = pacingFor(state.completed, DateTime.now(), state.profile.timeZone);
    final allowed = pacing.canRead(day, state.completed);

    glassSheet(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: ArtImage(
                day: day,
                asset: HolyArtCatalog.landscapeForDay(day),
                animate: false,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Eyebrow('${ChapterCatalog.forDay(day)!.title} · Day $day'),
          const SizedBox(height: 12),
          Text(lesson.title, style: HolyTypography.title.copyWith(fontSize: 22)),
          const SizedBox(height: 14),
          Text(lesson.verse, style: HolyTypography.reading.copyWith(fontSize: 16)),
          const SizedBox(height: 10),
          Text('${lesson.reference} · WEB', style: muted(context)),
          const SizedBox(height: 24),
          ActionButton(
            allowed
                ? (state.completed.containsKey(day)
                    ? 'Read again'
                    : 'Begin this lesson')
                : 'A little further along your walk',
            onPressed: allowed
                ? () {
                    Navigator.pop(context);
                    context.push('/lesson/$day');
                  }
                : null,
          ),
          if (!allowed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Every day, a new lesson. There is no need to hurry.',
                style: muted(context),
              ),
            ),
        ],
      ),
    );
  }

  /// Combined Hero "Verse of the Day" Picture Card
  /// Uses rotating saved artwork from HolyArtCatalog, dark/frosted gradient scrim
  /// so white verse text stands out with high contrast, and removes "Begin your moment".
  Widget _heroVerseOfTheDayCard(WalkState state, Pacing pacing) {
    final day = pacing.displayDay;
    final lesson = lessons[day - 1];
    final theme = HolyThemeScope.of(context);
    final artAsset = HolyArtCatalog.assetForDay(day);
    final isCompleted = state.completed.containsKey(day);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: theme.accent.withValues(alpha: 0.38),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: theme.accent.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(29),
        child: Stack(
          children: [
            // Rotating artwork background with Hero animation
            Positioned.fill(
              child: Hero(
                tag: 'art-$day',
                child: ArtImage(
                  day: day,
                  asset: artAsset,
                  parallax: offset,
                ),
              ),
            ),

            // Deep dark warm gradient scrim ensuring 100% text legibility
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.62),
                      Colors.black.withValues(alpha: 0.88),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

            // Card content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Eyebrow row with sparkles badge & tap action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.sparkles,
                                  color: Color(0xFFE8C766),
                                  size: 13,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'VERSE OF THE DAY',
                                  style: HolyTypography.eyebrow.copyWith(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          HolyHaptics.tap();
                          context.push('/verse/$day');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.0,
                            ),
                          ),
                          child: const Icon(
                            CupertinoIcons.square_arrow_up,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Scripture verse text with deep drop shadow for extreme contrast
                  Text(
                    '“${lesson.verse}”',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: HolyTypography.verse.copyWith(
                      fontSize: 21,
                      height: 1.45,
                      color: Colors.white,
                      shadows: [
                        const Shadow(
                          color: Colors.black,
                          blurRadius: 16,
                          offset: Offset(0, 2),
                        ),
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.8),
                          blurRadius: 28,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Reference & translation
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${lesson.reference} · WEB',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HolyTypography.eyebrow.copyWith(
                            color: const Color(0xFFE8C766),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 10),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          HolyHaptics.tap();
                          context.push('/lesson/$day');
                        },
                        child: Row(
                          children: [
                            Text(
                              isCompleted ? 'Read again' : 'Read today',
                              style: HolyTypography.ui.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              CupertinoIcons.chevron_right,
                              color: Colors.white,
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(WalkState state, Pacing pacing, Streak streak) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    final displayName = state.profile.name.trim().isNotEmpty
        ? state.profile.name.trim()
        : (state.profile.username.trim().isNotEmpty
            ? state.profile.username.trim()
            : 'Beloved');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            MediaQuery.paddingOf(context).top + 80,
            22,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting + Username on ONE line (Scaling down gracefully if long)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$greeting, $displayName',
                        style: HolyTypography.display.copyWith(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  StreakPill(days: streak.current),
                ],
              ),

              const SizedBox(height: 22),

              // Calendar Dates inside a defined Cognein-style card with streak
              WeekStrip(
                completedDates: state.completed.values.toSet(),
                now: now,
                currentStreak: streak.current,
                longestStreak: streak.longest,
              ),

              const SizedBox(height: 22),

              // Combined "Verse of the Day" hero picture card
              _heroVerseOfTheDayCard(state, pacing),

              const SizedBox(height: 32),

              // Section Header: "Your walk with God" — Every day, a new lesson
              const Eyebrow('YOUR DAILY JOURNEY'),
              const SizedBox(height: 6),
              const Text(
                'Your walk with God',
                style: HolyTypography.title,
              ),
              const SizedBox(height: 4),
              Text(
                'Every day, a new lesson. Follow the path in your own gentle rhythm.',
                style: muted(context).copyWith(fontSize: 13),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  /// Cognein-sized Chapter Header Card with slightly blurred background artwork,
  /// thin border, and overlaid text. All chapters remain open (no collapsible header).
  Widget _chapterBanner(int unitIndex, ChapterArt chapter, int completedCount) {
    final theme = HolyThemeScope.of(context);
    final unitNumber = unitIndex + 1;
    final isComplete = completedCount >= 5;
    final artDay = chapter.firstDay;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isComplete
              ? const Color(0xFFE8C766).withValues(alpha: 0.65)
              : Colors.white.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.isDark ? 0.35 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: theme.accent.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Stack(
          children: [
            // Background Artwork (Slightly blurred per user request)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                child: ArtImage(
                  day: artDay,
                  asset: HolyArtCatalog.landscapeForDay(artDay),
                  animate: false,
                ),
              ),
            ),

            // Contrast Scrim
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.68),
                      Colors.black.withValues(alpha: 0.52),
                      Colors.black.withValues(alpha: 0.76),
                    ],
                  ),
                ),
              ),
            ),

            // Top specular hairline highlight
            Positioned(
              top: 0,
              left: 20,
              right: 20,
              child: Container(
                height: 1.2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.70),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Header Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Chapter Number Badge Container
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.28),
                          Colors.white.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 1.1,
                      ),
                    ),
                    child: Text(
                      '$unitNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Chapter Title & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chapter.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HolyTypography.title.copyWith(
                            fontSize: 17,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 10),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Every day, a new lesson · $completedCount of 5 complete',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.82),
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Completion status icon
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isComplete
                          ? const Color(0xFFC9A227)
                          : Colors.white.withValues(alpha: 0.18),
                      border: Border.all(
                        color: isComplete
                            ? const Color(0xFFE8C766)
                            : Colors.white.withValues(alpha: 0.4),
                        width: 1.0,
                      ),
                    ),
                    child: Icon(
                      isComplete
                          ? CupertinoIcons.check_mark
                          : CupertinoIcons.leaf_arrow_circlepath,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 3D Pedestal Medallion Node ported from Cognein
  Widget _lessonNode(
    int day,
    int indexInChapter,
    WalkState state,
    Pacing pacing,
  ) {
    final lesson = lessons[day - 1];
    final isCompleted = state.completed.containsKey(day);
    final isCurrent = day == pacing.currentDay;
    final theme = HolyThemeScope.of(context);

    // Node positioning along a gentle curving path
    final xAlign = math.sin(indexInChapter * 1.5) * 0.58;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Align(
        alignment: Alignment(xAlign, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _openLesson(day),
              onLongPress: () => _previewLesson(day),
              child: SizedBox(
                width: 82,
                height: 82,
                child: Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    // Outer Pulsing Aura Ring on Current Day
                    if (isCurrent)
                      Positioned(
                        left: -8,
                        top: -8,
                        width: 98,
                        height: 98,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.accent.withValues(alpha: 0.45),
                                width: 2.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.accent.withValues(alpha: 0.35),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // 3D Machined Pedestal Base
                    Positioned(
                      top: 7,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? const Color(0xFF2A2113)
                              : isCurrent
                                  ? Color.lerp(theme.accent, Colors.black, 0.45)
                                  : (theme.isDark
                                      ? const Color(0xFF262C36)
                                      : const Color(0xFF9EAAB5)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Primary Medallion Face
                    Positioned(
                      top: 0,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isCompleted
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFE8C766),
                                    Color(0xFFC9A227),
                                    Color(0xFF8C6D1F),
                                  ],
                                )
                              : isCurrent
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: theme.buttonGradient,
                                    )
                                  : LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: theme.isDark
                                          ? [
                                              const Color(0xFF4B5563),
                                              const Color(0xFF374151),
                                            ]
                                          : [
                                              Colors.white,
                                              const Color(0xFFE5E7EB),
                                            ],
                                    ),
                          border: Border.all(
                            color: isCompleted
                                ? const Color(0xFF2A2113)
                                : isCurrent
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.5),
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isCurrent ? theme.accent : Colors.black)
                                  .withValues(alpha: 0.20),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Top lens specular highlight
                            Positioned(
                              top: 2,
                              left: 14,
                              right: 14,
                              height: 18,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.65),
                                      Colors.white.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Center Icon / Day Number
                            if (isCompleted)
                              const Icon(
                                CupertinoIcons.check_mark,
                                color: Colors.white,
                                size: 28,
                              )
                            else if (isCurrent)
                              Text(
                                '$day',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              )
                            else
                              const Icon(
                                CupertinoIcons.lock_fill,
                                color: Color(0xFF9CA3AF),
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Status Badge Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFF2A2113).withValues(alpha: 0.85)
                    : isCurrent
                        ? theme.accent.withValues(alpha: 0.88)
                        : Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCompleted
                      ? const Color(0xFFC9A227).withValues(alpha: 0.5)
                      : isCurrent
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.2),
                  width: 1.0,
                ),
              ),
              child: Text(
                isCompleted
                    ? 'COMPLETED'
                    : isCurrent
                        ? 'START HERE'
                        : 'DAY $day',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Lesson Title Under Node
            SizedBox(
              width: 140,
              child: Text(
                lesson.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: HolyTypography.ui.copyWith(
                  fontSize: 12,
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                  color: isCurrent
                      ? theme.ink
                      : theme.ink.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// All chapters stay open like Cognein (no collapsible headers).
  Widget _chapterSection(int unitIndex, WalkState state, Pacing pacing) {
    final firstDay = unitIndex * 5 + 1;
    final chapter = ChapterCatalog.chapters[unitIndex];
    final isCurrentChapter = (pacing.currentDay - 1) ~/ 5 == unitIndex;
    final completedCount = List.generate(5, (i) => firstDay + i)
        .where(state.completed.containsKey)
        .length;

    final theme = HolyThemeScope.of(context);

    return Center(
      key: isCurrentChapter ? currentChapterKey : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Column(
            children: [
              // Chapter Banner Card (Cognein unit banner style)
              _chapterBanner(unitIndex, chapter, completedCount),

              const SizedBox(height: 14),

              // 5-Day Path with Cognein 3D Pedestal Nodes & Bezier Path
              CustomPaint(
                painter: _LessonPathPainter(
                  glowColor: theme.accent.withValues(alpha: 0.35),
                  coreColor: theme.accent.withValues(alpha: 0.65),
                ),
                child: Column(
                  children: List.generate(
                    5,
                    (i) => _lessonNode(firstDay + i, i, state, pacing),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(repositoryProvider);
    final now = DateTime.now();
    final pacing = pacingFor(state.completed, now, state.profile.timeZone);
    final streak = streakFor(state.completed, now, state.profile.timeZone,
        includeTodayAsActive: true);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassTopBar(
        title: const Brand(),
        centerTitle: false,
        automaticallyImplyLeading: false,
        scrollOffset: offset,
        maxOpacity: 0.88,
        maxBlurSigma: 12,
        trailing: StreakPill(days: streak.current),
      ),
      body: CustomScrollView(
        controller: scroll,
        slivers: [
          // Header: Single-line greeting, boxed calendar card, hero verse card
          SliverToBoxAdapter(
            child: _header(state, pacing, streak),
          ),

          // All Chapters Open (Cognein roadmap structure)
          SliverToBoxAdapter(
            child: Column(
              children: [
                for (var i = 0; i < ChapterCatalog.chapters.length; i++)
                  _chapterSection(i, state, pacing),
              ],
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 140)),
        ],
      ),
      floatingActionButton: offset > 800
          ? Padding(
              padding: const EdgeInsets.only(bottom: 95),
              child: Pressable(
                onPressed: () {
                  HolyHaptics.buttonPress();
                  final chapterContext = currentChapterKey.currentContext;
                  if (chapterContext != null) {
                    Scrollable.ensureVisible(
                      chapterContext,
                      alignment: 0.15,
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                    );
                  } else {
                    scroll.animateTo(
                      0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
                child: Glass(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  radius: 30,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.arrow_up, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Back to today',
                        style: ui(context).copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = ref.read(repositoryProvider);
    prefetchLessonArt(
      context,
      pacingFor(state.completed, DateTime.now(), state.profile.timeZone).currentDay,
    );
  }
}

/// 3-Pass Glowing Bezier Path Painter ported from Cognein
class _LessonPathPainter extends CustomPainter {
  final Color glowColor;
  final Color coreColor;

  _LessonPathPainter({
    required this.glowColor,
    required this.coreColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0 || size.width <= 0) return;

    final path = Path();
    const nodeHeight = 120.0;
    final totalNodes = 5;

    // Start at top node center
    final startX = size.width / 2 + math.sin(0 * 1.5) * (size.width * 0.28);
    path.moveTo(startX, 42);

    for (var i = 1; i < totalNodes; i++) {
      final prevX = size.width / 2 + math.sin((i - 1) * 1.5) * (size.width * 0.28);
      final prevY = (i - 1) * nodeHeight + 42;

      final nextX = size.width / 2 + math.sin(i * 1.5) * (size.width * 0.28);
      final nextY = i * nodeHeight + 42;

      final controlY1 = prevY + (nextY - prevY) * 0.5;
      final controlY2 = prevY + (nextY - prevY) * 0.5;

      path.cubicTo(prevX, controlY1, nextX, controlY2, nextX, nextY);
    }

    // Pass 1: Outer soft glow
    final glowPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, glowPaint);

    // Pass 2: Active Core line
    final corePaint = Paint()
      ..color = coreColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, corePaint);
  }

  @override
  bool shouldRepaint(_LessonPathPainter oldDelegate) =>
      oldDelegate.glowColor != glowColor || oldDelegate.coreColor != coreColor;
}
