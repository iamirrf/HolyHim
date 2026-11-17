import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/lessons.g.dart';
import '../../design/chapter_catalog.g.dart';
import '../../design/design.dart';
import '../../design/art_catalog.dart';
import '../../domain/access.dart';
import '../../domain/pacing.dart';
import '../../services/billing.dart';
import '../../services/repository.dart';
import '../common.dart';

/// The year as 73 chapters, one per page, each with its five days.
class JourneyScreen extends ConsumerStatefulWidget {
  const JourneyScreen({super.key});
  @override
  ConsumerState<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends ConsumerState<JourneyScreen> {
  late final PageController pages;
  late int page;

  @override
  void initState() {
    super.initState();
    final state = ref.read(repositoryProvider);
    final pacing =
        pacingFor(state.completed, DateTime.now(), state.profile.timeZone);
    final chapter = ChapterCatalog.forDay(pacing.displayDay);
    page = chapter == null ? 0 : ChapterCatalog.chapters.indexOf(chapter);
    pages = PageController(initialPage: page, viewportFraction: 1);
  }

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  void _turn(int delta) {
    final target = (page + delta).clamp(0, ChapterCatalog.chapters.length - 1);
    if (MediaQuery.disableAnimationsOf(context)) {
      pages.jumpToPage(target);
    } else {
      pages.animateToPage(target,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final state = ref.watch(repositoryProvider);
    final owned = ref.watch(accessProvider.select((a) => a.active));
    final pacing =
        pacingFor(state.completed, DateTime.now(), state.profile.timeZone);
    final media = MediaQuery.of(context);
    return Scaffold(
        backgroundColor: t.paper,
        body: Stack(children: [
          PageView.builder(
              controller: pages,
              itemCount: ChapterCatalog.chapters.length,
              onPageChanged: (i) {
                HolyHaptics.detent();
                setState(() => page = i);
              },
              itemBuilder: (context, i) => _ChapterPage(
                  index: i,
                  pageController: pages,
                  pacing: pacing,
                  owned: owned,
                  completed: state.completed)),
          Positioned(
              top: media.padding.top + 6,
              left: HolySpace.gutter - 6,
              right: HolySpace.gutter - 6,
              child: Row(children: [
                IconControl(
                    icon: CupertinoIcons.xmark,
                    label: 'Close',
                    onPhoto: true,
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/')),
                const Spacer(),
                _PagePill(
                    page: page,
                    total: ChapterCatalog.chapters.length,
                    completed: state.completed,
                    pacing: pacing),
              ])),
          Positioned(
              bottom: media.padding.bottom + 10,
              left: HolySpace.gutter,
              right: HolySpace.gutter,
              child: Row(children: [
                IconControl(
                    icon: CupertinoIcons.chevron_left,
                    label: 'Previous chapter',
                    onPressed: page == 0 ? null : () => _turn(-1)),
                const Spacer(),
                IconControl(
                    icon: CupertinoIcons.chevron_right,
                    label: 'Next chapter',
                    onPressed: page == ChapterCatalog.chapters.length - 1
                        ? null
                        : () => _turn(1)),
              ])),
        ]));
  }
}

class _PagePill extends StatelessWidget {
  final int page, total;
  final Map<int, String> completed;
  final Pacing pacing;
  const _PagePill(
      {required this.page,
      required this.total,
      required this.completed,
      required this.pacing});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final chapter = ChapterCatalog.chapters[page];
    final done = [
      for (var d = chapter.firstDay; d <= chapter.lastDay; d++)
        if (completed.containsKey(d)) d
    ].length;
    final chapterComplete = done == 5;
    final currentChapter =
        ChapterCatalog.forDay(pacing.displayDay) == chapter;
    final label = '${page + 1} of $total';

    if (currentChapter) {
      // Accent pill for current chapter.
      return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
              color: t.accent,
              borderRadius: BorderRadius.circular(100)),
          child: Text(label,
              style: HolyTypography.label.copyWith(color: Colors.white)));
    }

    return FrostedGlass(
        onPhoto: true,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (chapterComplete) ...[
            const Icon(CupertinoIcons.checkmark_alt,
                size: 14, color: HolyTheme.photoInk),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: HolyTypography.label.copyWith(color: HolyTheme.photoInk)),
        ]));
  }
}

class _ChapterPage extends StatelessWidget {
  final int index;
  final PageController pageController;
  final Pacing pacing;
  final bool owned;
  final Map<int, String> completed;
  const _ChapterPage(
      {required this.index,
      required this.pageController,
      required this.pacing,
      required this.owned,
      required this.completed});

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final chapter = ChapterCatalog.chapters[index];
    final media = MediaQuery.of(context);
    final compact = media.size.height < 740;
    final photo = media.size.height * (compact ? .30 : .36);
    final summary = index < unitSummaries.length ? unitSummaries[index] : '';
    final done = [
      for (var d = chapter.firstDay; d <= chapter.lastDay; d++)
        if (completed.containsKey(d)) d
    ].length;
    return Stack(children: [
      SizedBox(
          height: photo + HolyRadius.sheet,
          width: double.infinity,
          child: AnimatedBuilder(
              animation: pageController,
              builder: (context, child) {
                // Parallax: the photograph moves slower than the page.
                final p = pageController.hasClients &&
                        pageController.position.haveDimensions
                    ? (pageController.page ?? index.toDouble()) - index
                    : 0.0;
                return ClipRect(
                    child: Transform.translate(
                        offset: Offset(p * media.size.width * .45, 0),
                        child: child));
              },
              child: Stack(fit: StackFit.expand, children: [
                Image.asset(
                    // The chapter's own photograph when it has one, otherwise
                    // the library photograph for its first day.
                    HolyArtCatalog.assetForDay(chapter.firstDay),
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -.3),
                    excludeFromSemantics: true,
                    errorBuilder: (c, e, s) => ColoredBox(color: t.sunk)),
                const DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x55000000), Color(0x00000000)],
                            stops: [0, .4]))),
              ]))),
      Positioned.fill(
          top: photo,
          child: DecoratedBox(
              decoration: ShapeDecoration(
                  color: t.paper,
                  shape: const RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(HolyRadius.sheet)))),
              child: FitColumn(
                  padding: EdgeInsets.fromLTRB(HolySpace.gutter,
                      compact ? 20 : 26, HolySpace.gutter, media.padding.bottom + 70),
                  children: [
                    Eyebrow('Chapter ${index + 1} · Days ${chapter.firstDay} to ${chapter.lastDay}'),
                    const SizedBox(height: 6),
                    Semantics(
                        header: true,
                        child: Text(chapter.title,
                            style: HolyTypography.title.copyWith(
                                color: t.ink, fontSize: compact ? 28 : 32))),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: HolyTypography.readingItalic.copyWith(
                              color: t.muted, fontSize: 16, height: 1.4)),
                    ],
                    SizedBox(height: compact ? 12 : 18),
                    for (var d = chapter.firstDay; d <= chapter.lastDay; d++)
                      _DayRow(
                          day: d,
                          pacing: pacing,
                          owned: owned,
                          completed: completed,
                          last: d == chapter.lastDay),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var d = chapter.firstDay; d <= chapter.lastDay; d++) ...[
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: completed.containsKey(d) ? t.olive : Colors.transparent,
                              border: Border.all(
                                color: completed.containsKey(d) ? t.olive : t.hairline,
                                width: 1.5,
                              ),
                            ),
                          ),
                          if (d < chapter.lastDay) const SizedBox(width: 6),
                        ],
                        const SizedBox(width: 10),
                        Text(done == 5 ? 'Complete' : '$done of 5',
                          style: HolyTypography.caption.copyWith(color: t.muted)),
                      ],
                    ),
                  ]))),
    ]);
  }
}

class _DayRow extends StatelessWidget {
  final int day;
  final Pacing pacing;
  final bool owned, last;
  final Map<int, String> completed;
  const _DayRow(
      {required this.day,
      required this.pacing,
      required this.owned,
      required this.completed,
      required this.last});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final lesson = lessons[day - 1];
    final read = completed.containsKey(day);
    final current = !read && day == pacing.currentDay;
    final locked = !canOpenLesson(day, owned: owned, completed: completed);
    final open = pacing.canRead(day, completed) && !locked;
    void tap() {
      if (open) {
        context.push('/lesson/$day');
      } else if (locked && current) {
        context.push('/offer?day=$day');
      } else if (locked) {
        toast(context, 'Day $day opens with membership.');
      } else {
        toast(context, 'One lesson a day. Day $day is still ahead.');
      }
    }

    final status = read
        ? 'Read'
        : current
            ? (pacing.canBegin ? (locked ? 'Unlock' : 'Today') : 'Tomorrow')
            : locked
                ? null
                : null;
    return Pressable(
        onPressed: tap,
        pressedScale: .985,
        semanticLabel:
            'Day $day, ${lesson.title}${read ? ', read' : current ? ', up next' : locked ? ', locked' : ''}',
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                border: last
                    ? null
                    : Border(bottom: BorderSide(color: t.hairline, width: .8))),
            child: Row(children: [
              if (current) ...[
                Container(width: 3, height: 24,
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
              ],
              SizedBox(
                  width: 34,
                  child: Text('$day',
                      style: HolyTypography.numeral.copyWith(
                          fontSize: 22,
                          color: read || current ? t.ink : t.muted))),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(lesson.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HolyTypography.ui.copyWith(
                          color: read || current ? t.ink : t.muted,
                          fontWeight:
                              current ? FontWeight.w700 : FontWeight.w500))),
              const SizedBox(width: 8),
              if (read)
                HolyCheck(checked: true, size: 22, color: t.olive)
              else if (locked)
                Icon(CupertinoIcons.lock, size: 16, color: t.muted)
              else if (status != null)
                Text(status,
                    style: HolyTypography.label.copyWith(color: t.accent)),
            ])));
  }
}
