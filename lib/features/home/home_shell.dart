import 'package:holyher/core/widgets/lesson_artwork.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:holyher/features/settings/theme_screen.dart';
import 'package:holyher/features/home/badges_screen.dart';
import 'package:holyher/services/reading_service.dart';
import 'package:holyher/services/reading_streak.dart';
import 'dart:math' as math;
import 'package:holyher/features/home/lesson_presentation.dart';
import 'package:holyher/features/home/roadmap_layout.dart';
import 'package:holyher/core/widgets/holy_navigation.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/core/widgets/holy_header.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/data/units.dart';
import 'package:holyher/features/home/saved_tab.dart';
import 'package:holyher/features/home/progress_calendar.dart';
import 'package:holyher/features/lesson/lesson_screen.dart';
import 'package:holyher/features/settings/settings_screen.dart';
import 'package:holyher/features/settings/profile_editors.dart';
import 'package:holyher/features/support/support_screens.dart';
import 'package:holyher/services/accessibility_service.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/profile_service.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/learning_service.dart';
import 'package:holyher/services/saved_service.dart';

class HomeShell extends ConsumerStatefulWidget {
  final int initialTab;
  const HomeShell({super.key, this.initialTab = 0})
      : assert(initialTab >= 0 && initialTab < 3);
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late final _pager = PageController(initialPage: widget.initialTab);
  final _scrolls = List.generate(3, (_) => ScrollController());
  late int _index = widget.initialTab;
  bool _compact = false;
  double _down = 0;
  @override
  void dispose() {
    _pager.dispose();
    for (final s in _scrolls) {
      s.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab && _pager.hasClients) {
      _select(widget.initialTab);
    }
  }

  void _select(int i) {
    final router = GoRouter.maybeOf(context);
    if (router != null &&
        !router.routeInformationProvider.value.uri.path
            .startsWith('/reading/')) {
      final path = i == 1
          ? '/saved'
          : i == 2
              ? '/profile'
              : '/';
      if (router.routeInformationProvider.value.uri.path != path) {
        router.go(path);
      }
    }
    if (i == _index && _scrolls[i].hasClients) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _scrolls[i].jumpTo(0);
      } else {
        _scrolls[i].animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic);
      }
    }
    setState(() {
      _compact = false;
      _down = 0;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _pager.jumpToPage(i);
    } else {
      _pager.animateToPage(i,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic);
    }
  }

  bool _scroll(ScrollNotification n) {
    if (n.depth != 1 || n.metrics.axis != Axis.vertical) return false;
    if (n is ScrollUpdateNotification &&
        n.dragDetails != null &&
        !n.metrics.outOfRange) {
      final d = n.scrollDelta ?? 0;
      if (d < 0 || n.metrics.pixels < 24) {
        _down = 0;
        if (_compact) setState(() => _compact = false);
      } else {
        _down += d;
        if (_down >= 24 && !_compact) setState(() => _compact = true);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final accessible = MediaQuery.accessibleNavigationOf(context) ||
        MediaQuery.textScalerOf(context).scale(12) > 17;
    return HolyScaffold(
        body: Stack(children: [
      Column(children: [
        HolyHeader(
            onProgress: () => openScreen(context, const ProgressCalendar())),
        Expanded(
            child: NotificationListener<ScrollNotification>(
                onNotification: _scroll,
                child: PageView(
                    controller: _pager,
                    onPageChanged: (i) => setState(() {
                          _index = i;
                          _compact = false;
                          _down = 0;
                        }),
                    children: [
                      PrimaryScrollController(
                          controller: _scrolls[0],
                          child: LearnTab(onSaved: () => _select(1))),
                      PrimaryScrollController(
                          controller: _scrolls[1],
                          child: SavedTab(onLearn: () => _select(0))),
                      PrimaryScrollController(
                          controller: _scrolls[2], child: const ProfileTab()),
                    ])))
      ]),
      Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: ReadingWidth(
              maxWidth: 520,
              child: AnimatedBuilder(
                  animation: _pager,
                  builder: (context, _) => _navigation(accessible)))),
    ]));
  }

  Widget _navigation(bool accessible) {
    final compact = _compact && !accessible;
    final opaque = ref.watch(reduceTransparencyProvider);
    final nativeGlass = defaultTargetPlatform == TargetPlatform.iOS;
    final fraction = _pager.hasClients && _pager.position.hasContentDimensions
        ? _pager.page ?? _index.toDouble()
        : _index.toDouble();
    return ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
            enabled: !opaque && !nativeGlass,
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                height: compact ? 56 : holyNavigationHeight(context),
                decoration: BoxDecoration(
                    color: opaque
                        ? AppColors.pearl
                        : AppColors.pearl
                            .withValues(alpha: nativeGlass ? .25 : .78),
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(color: AppColors.pearl, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.accentDark.withValues(alpha: .10),
                          blurRadius: 24,
                          offset: const Offset(0, 8))
                    ]),
                child: LayoutBuilder(
                    builder: (context, box) => Stack(children: [
                          if (!opaque &&
                              !kIsWeb &&
                              defaultTargetPlatform == TargetPlatform.iOS)
                            Positioned.fill(
                                child: IgnorePointer(
                                    child: UiKitView(
                                        key: ValueKey(AppColors.palette.id),
                                        viewType: 'holyher/glass',
                                        creationParams: {
                                          'dark': AppColors.palette.isDark,
                                          'tint':
                                              AppColors.background.toARGB32()
                                        },
                                        creationParamsCodec:
                                            const StandardMessageCodec()))),
                          Positioned(
                              left: 6 + (box.maxWidth - 12) / 3 * fraction,
                              top: 6,
                              bottom: 6,
                              width: (box.maxWidth - 12) / 3,
                              child: DecoratedBox(
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(28),
                                      gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppColors.pearl,
                                            AppColors.surface
                                          ]),
                                      border: Border.all(
                                          color: AppColors.surfaceLight
                                              .withValues(alpha: .8))))),
                          Row(children: [
                            for (final t in [
                              (0, Icons.route_outlined, 'Walk'),
                              (1, Icons.bookmark_border_rounded, 'Saved'),
                              (2, Icons.person_outline_rounded, 'Profile')
                            ])
                              Expanded(
                                  child: HolyPressable(
                                      label: t.$3,
                                      selected: _index == t.$1,
                                      onPressed: () => _select(t.$1),
                                      child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(t.$2,
                                                size: 26,
                                                color: _index == t.$1
                                                    ? AppColors.accentDark
                                                    : AppColors.textSecondary),
                                            if (!compact) ...[
                                              const SizedBox(height: 3),
                                              Text(t.$3,
                                                  style: HolyTypography.label
                                                      .copyWith(
                                                          color: _index == t.$1
                                                              ? AppColors
                                                                  .accentDark
                                                              : AppColors
                                                                  .textSecondary))
                                            ]
                                          ])))
                          ]),
                        ])))));
  }
}

void openLesson(BuildContext context, DailyLesson lesson) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    openScreen(context, LessonScreen(lesson: lesson));
    return;
  }
  final from = router.routeInformationProvider.value.uri.path == '/saved'
      ? '?from=saved'
      : '';
  router.go('/reading/${lesson.day}$from');
}

String lessonAvailableDate(ProgressState progress, int day) {
  try {
    final start = DateTime.parse(progress.startDate!);
    final date = DateTime(start.year, start.month, start.day + day - 1);
    return '${const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ][date.month - 1]} ${date.day}, ${date.year}';
  } catch (_) {
    return 'on its journey day';
  }
}

class LearnTab extends ConsumerStatefulWidget {
  final VoidCallback? onSaved;
  const LearnTab({super.key, this.onSaved});
  @override
  ConsumerState<LearnTab> createState() => _LearnTabState();
}

class _LearnTabState extends ConsumerState<LearnTab>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  final _headerKey = GlobalKey();
  final _currentNodeKey = GlobalKey();
  final _unitLayouts = <int, RoadmapUnitLayout>{};
  double? _layoutWidth;
  TextScaler? _layoutScaler;
  bool _searching = false, _list = false, _revealed = false, _far = false;
  ScrollController? _scroll;
  @override
  bool get wantKeepAlive => true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = PrimaryScrollController.maybeOf(context);
    if (controller != _scroll) {
      _scroll?.removeListener(_position);
      _scroll = controller;
      _scroll?.addListener(_position);
    }
    if (!_revealed) {
      _revealed = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _today(initial: true));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll?.removeListener(_position);
    super.dispose();
  }

  RoadmapUnitLayout _geometry(int index) {
    final width = math.min(720.0, MediaQuery.sizeOf(context).width) - 32;
    final scaler = MediaQuery.textScalerOf(context);
    if (_layoutWidth != width || _layoutScaler != scaler) {
      _unitLayouts.clear();
      _layoutWidth = width;
      _layoutScaler = scaler;
    }
    return _unitLayouts.putIfAbsent(
        index,
        () => RoadmapUnitLayout.measure(
            index: index,
            title: unitTitles[index],
            width: width,
            scaler: scaler,
            direction: Directionality.of(context)));
  }

  double _todayOffset() {
    if (ref.read(progressProvider).nextLesson == null) return 0;
    final day = ref.read(progressProvider).nextLesson?.day ??
        ref.read(progressProvider).unlockedThrough;
    if (day <= 1) return 0;
    final header = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    var offset = (header?.hasSize == true ? header!.size.height : 244) + 28;
    final unit = (day - 1) ~/ 5;
    for (var i = 0; i < unit; i++) {
      offset += _geometry(i).extent;
    }
    offset += _geometry(unit).bannerHeight +
        ((day - 1) % 5) * _geometry(unit).rowHeight;
    return math.max(0, offset - 96);
  }

  void _position() {
    final far = !_list &&
        !_searching &&
        _search.text.isEmpty &&
        _scroll != null &&
        _scroll!.hasClients &&
        (_scroll!.offset - _todayOffset()).abs() > 700;
    if (far != _far && mounted) setState(() => _far = far);
  }

  void _today({bool initial = false}) {
    if (!mounted || _scroll?.hasClients != true || _searching || _list) return;
    final target = _todayOffset();
    if (initial || MediaQuery.disableAnimationsOf(context)) {
      if (!initial || target > 300) _scroll!.jumpTo(target);
    } else {
      _scroll!.animateTo(target,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic);
    }
  }

  void _preview(DailyLesson lesson) {
    final progress = ref.read(progressProvider),
        available = ref.read(progressProvider).isUnlocked(lesson.day);
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheet) => Consumer(builder: (sheet, sheetRef, _) {
              final presentation = sheetRef
                  .watch(lessonNodePresentationProvider(lesson.day))
                  .valueOrNull;
              final done = progress.completedDays.contains(lesson.day);
              return SafeArea(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ReadingWidth(
                          maxWidth: 520,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: LessonArtwork(
                                        day: lesson.day,
                                        child: SizedBox(
                                            height: 150,
                                            child: Center(
                                                child: LessonMedallion(
                                                    state: available
                                                        ? (done
                                                            ? LessonNodeState
                                                                .complete
                                                            : LessonNodeState
                                                                .current)
                                                        : LessonNodeState
                                                            .future))))),
                                const SizedBox(height: 20),
                                Eyebrow(
                                    'Day ${lesson.day} · 2–3 minutes · Five cards'),
                                const SizedBox(height: 12),
                                Text(lesson.title,
                                    style: HolyTypography.heading),
                                const SizedBox(height: 12),
                                Text(lesson.verseReference,
                                    style: HolyTypography.supporting),
                                const SizedBox(height: 18),
                                if (!available)
                                  Text(
                                      'Available ${lessonAvailableDate(progress, lesson.day)} in your journey’s time zone.'),
                                const SizedBox(height: 18),
                                HolyButton(
                                    label: available
                                        ? (done
                                            ? 'Read again'
                                            : presentation?.state ==
                                                    LessonNodeState.inProgress
                                                ? 'Resume reading'
                                                : 'Begin reading')
                                        : 'Return to today',
                                    onPressed: () {
                                      Navigator.pop(sheet);
                                      if (available) {
                                        openLesson(context, lesson);
                                      } else {
                                        _today();
                                      }
                                    },
                                    icon: available
                                        ? Icons.arrow_forward_rounded
                                        : Icons.route_outlined),
                              ]))));
            }));
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    super.build(context);
    final p = ref.watch(progressProvider),
        matches = lessons
            .where((l) => '${l.day} ${l.title} ${l.verseReference} ${l.theme}'
                .toLowerCase()
                .contains(_search.text.toLowerCase()))
            .toList();
    return ReadingWidth(
        child: Stack(children: [
      RefreshIndicator(
          onRefresh: () => ref.read(progressProvider.notifier).refresh(),
          child: CustomScrollView(
              primary: true,
              key: const PageStorageKey('learn'),
              slivers: [
                SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    sliver: SliverToBoxAdapter(
                        child: Column(
                            key: _headerKey,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          JourneyProgressObject(
                              progress: p,
                              onSaved: widget.onSaved,
                              onContinue: p.nextLesson != null
                                  ? () => openLesson(context, p.nextLesson!)
                                  : p.allComplete
                                      ? () => openLesson(context, lessons.first)
                                      : null),
                          if (p.syncError != null)
                            const InlineMessage(
                                'Your saved lessons are available. Reconnect to check new daily lessons.'),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(
                                child: _searching
                                    ? TextField(
                                        controller: _search,
                                        autofocus: true,
                                        onChanged: (_) => setState(() {}),
                                        style: HolyTypography.body,
                                        decoration: InputDecoration(
                                            hintText: 'Find a lesson',
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 12),
                                            prefixIcon: const Icon(Icons.search,
                                                size: 20),
                                            suffixIcon: IconButton(
                                                tooltip: 'Clear search',
                                                onPressed: () {
                                                  _search.clear();
                                                  setState(
                                                      () => _searching = false);
                                                },
                                                icon: const Icon(Icons.close,
                                                    size: 20))))
                                    : Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                            onPressed: () => setState(
                                                () => _searching = true),
                                            icon: const Icon(Icons.search,
                                                size: 20),
                                            label: const Text('Search',
                                                style: HolyTypography
                                                    .supporting)))),
                            const SizedBox(width: 8),
                            TextButton.icon(
                                onPressed: () => setState(() => _list = !_list),
                                icon: Icon(
                                    _list
                                        ? Icons.route_outlined
                                        : Icons.list_rounded,
                                    size: 20),
                                label: Text(_list ? 'Map' : 'List',
                                    style: HolyTypography.supporting))
                          ]),
                          if (matches.isEmpty)
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Text(
                                    'No lessons match your search. Try a day, title, or Scripture reference.')),
                        ]))),
                if (_list || _search.text.isNotEmpty)
                  SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList.builder(
                          itemCount: matches.length,
                          itemBuilder: (c, i) {
                            final l = matches[i];
                            return MenuRow(
                                title: l.title,
                                subtitle:
                                    'Day ${l.day} · ${l.verseReference}\n${p.completedDays.contains(l.day) ? 'Complete' : p.isUnlocked(l.day) ? 'Available' : 'Available ${lessonAvailableDate(p, l.day)}'}',
                                icon: p.completedDays.contains(l.day)
                                    ? Icons.check_circle_outline
                                    : p.isUnlocked(l.day)
                                        ? Icons.menu_book_outlined
                                        : Icons.lock_outline,
                                onTap: () => _preview(l));
                          }))
                else
                  SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverVariedExtentList.builder(
                          itemExtentBuilder: (index, dimensions) =>
                              index < 73 ? _geometry(index).extent : null,
                          itemCount: 73,
                          itemBuilder: (c, i) => _unitMap(i, p))),
                SliverToBoxAdapter(
                    child:
                        SizedBox(height: holyNavigationReservation(context))),
              ])),
      if (_far && !_searching && !_list && _search.text.isEmpty)
        Positioned(
            left: 24,
            right: 24,
            bottom: holyNavigationReservation(context) + 8,
            child: Align(
                alignment: Alignment.centerRight,
                child: HolyPressable(
                    label: 'Return to today',
                    onPressed: () => _today(),
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                            color: AppColors.pearl,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.divider),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.accentDark
                                      .withValues(alpha: .10),
                                  blurRadius: 20,
                                  offset: const Offset(0, 7))
                            ]),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.my_location_rounded,
                              size: 18, color: AppColors.accent),
                          const SizedBox(width: 10),
                          const Flexible(
                              child: Text('Return to today',
                                  style: HolyTypography.action))
                        ]))))),
    ]));
  }

  Widget _unitMap(int index, ProgressState p) {
    final count = List.generate(5, (i) => index * 5 + i + 1)
        .where(p.completedDays.contains)
        .length;
    final geometry = _geometry(index), rowHeight = _geometry(index).rowHeight;
    return Column(children: [
      SizedBox(
          height: geometry.bannerHeight,
          child: HolyPressable(
              label:
                  'Unit ${index + 1}, ${unitTitles[index]}, $count of 5 lessons complete',
              onPressed: () => _unit(index),
              child: QuietInset(
                  radius: 22,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(children: [
                    Row(children: [
                      Container(
                          width: geometry.numberSize,
                          height: geometry.numberSize,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [AppColors.pearl, AppColors.surface]),
                              border: Border.all(color: AppColors.pearl),
                              borderRadius: BorderRadius.circular(15)),
                          child: Text('${index + 1}'.padLeft(2, '0'),
                              style: HolyTypography.section
                                  .copyWith(color: AppColors.accent))),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('UNIT ${index + 1}',
                                style: HolyTypography.label.copyWith(
                                    color: AppColors.accent, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(unitTitles[index],
                                style: HolyTypography.action)
                          ])),
                      if (!geometry.stacked) ...[
                        const SizedBox(width: 12),
                        SizedBox.square(
                            dimension: geometry.progressSize,
                            child:
                                Stack(alignment: Alignment.center, children: [
                              SizedBox.expand(
                                  child: CircularProgressIndicator(
                                      value: count / 5,
                                      strokeWidth: 3,
                                      backgroundColor: AppColors.divider)),
                              Text('$count/5', style: HolyTypography.label)
                            ]))
                      ],
                    ]),
                    if (geometry.stacked) ...[
                      const SizedBox(height: 12),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: Text('$count of 5 lessons complete',
                              style: HolyTypography.supporting)),
                      const SizedBox(height: 8),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                              value: count / 5,
                              minHeight: 4,
                              backgroundColor: AppColors.divider))
                    ],
                  ])))),
      LayoutBuilder(builder: (context, box) {
        final points = [
          for (var n = 0; n < 5; n++)
            Offset([.5, .76, .5, .24, .5][n], 52 + n * rowHeight)
        ];
        return CustomPaint(
            painter: RoseRoutePainter(points: points, completedSegments: {
              for (var i = 0; i < 4; i++)
                if (p.completedDays.contains(index * 5 + i + 1) &&
                    p.completedDays.contains(index * 5 + i + 2))
                  i
            }),
            child: Column(children: [
              for (var n = 0; n < 5; n++)
                SizedBox(
                    height: rowHeight,
                    child: Align(
                        alignment: Alignment([0.0, .6, 0.0, -.6, 0.0][n], -1),
                        child: SizedBox(
                            width: math.min(230, box.maxWidth * .70),
                            child: _node(lessons[index * 5 + n], p))))
            ]));
      }),
    ]);
  }

  Widget _node(DailyLesson l, ProgressState p) {
    final done = p.completedDays.contains(l.day),
        current = p.nextLesson?.day == l.day;
    final fallback = done
        ? LessonNodeState.complete
        : !p.isUnlocked(l.day)
            ? LessonNodeState.future
            : current
                ? LessonNodeState.current
                : LessonNodeState.available;
    final presentation =
        ref.watch(lessonNodePresentationProvider(l.day)).valueOrNull ??
            LessonNodePresentation(fallback);
    final state = presentation.state;
    return HolyPressable(
        key: current ? _currentNodeKey : null,
        label: 'Day ${l.day}, ${l.title}, ${state.name}',
        onPressed: () => _preview(l),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          LessonMedallion(state: state, progress: presentation.fraction),
          const SizedBox(height: 4),
          Text('DAY ${l.day.toString().padLeft(2, '0')}',
              style: HolyTypography.label
                  .copyWith(color: AppColors.accent, letterSpacing: 1.1)),
          const SizedBox(height: 4),
          Text(l.title,
              textAlign: TextAlign.center, style: HolyTypography.supporting),
          if (!p.isUnlocked(l.day))
            Text(lessonAvailableDate(p, l.day),
                style: HolyTypography.label
                    .copyWith(color: AppColors.textSecondary)),
          if (current || state == LessonNodeState.inProgress)
            Text(presentation.action,
                style: HolyTypography.label.copyWith(color: AppColors.accent))
        ]));
  }

  void _unit(int index) => showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('UNIT ${index + 1}', style: HolyTypography.label),
                    const SizedBox(height: 12),
                    Text(unitTitles[index], style: HolyTypography.heading),
                    const SizedBox(height: 16),
                    for (final l in lessons.sublist(index * 5, index * 5 + 5))
                      MenuRow(
                          title: l.title,
                          subtitle: 'Day ${l.day} · ${l.verseReference}',
                          icon: ref
                                  .read(progressProvider)
                                  .completedDays
                                  .contains(l.day)
                              ? Icons.check_circle_outline
                              : ref.read(progressProvider).isUnlocked(l.day)
                                  ? Icons.menu_book_outlined
                                  : Icons.lock_outline,
                          onTap: () {
                            Navigator.pop(c);
                            _preview(l);
                          })
                  ]))));
}

class JourneyProgressObject extends StatelessWidget {
  final ProgressState progress;
  final VoidCallback? onContinue;
  final VoidCallback? onSaved;
  const JourneyProgressObject(
      {super.key, required this.progress, this.onContinue, this.onSaved});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => PearlSurface(
            radius: 26,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: LayoutBuilder(builder: (context, box) {
              final wide = box.maxWidth >= 580;
              final summary = Row(children: [
                _JourneyDial(
                    fraction: progress.fraction,
                    complete: progress.allComplete),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Eyebrow('Walk with God'),
                      const SizedBox(height: 6),
                      Text('${progress.completedCount} of 365 complete',
                          style: HolyTypography.supporting
                              .copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                          progress.nextLesson?.title ??
                              (progress.allComplete
                                  ? 'A year to return to.'
                                  : 'You’re here for today.'),
                          style: HolyTypography.section),
                    ])),
              ]);
              if (wide && onContinue != null && !progress.allComplete) {
                return Row(children: [
                  Expanded(child: summary),
                  const SizedBox(width: 24),
                  SizedBox(
                      width: 180,
                      child:
                          HolyButton(label: 'Continue', onPressed: onContinue))
                ]);
              }
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    summary,
                    const SizedBox(height: 14),
                    if (onContinue != null)
                      HolyButton(
                          label: progress.allComplete
                              ? 'Revisit Day 1'
                              : 'Continue',
                          onPressed: onContinue)
                    else
                      Text(
                          progress.allComplete
                              ? 'Revisit a lesson or keep a saved verse close.'
                              : 'Your next lesson opens ${lessonAvailableDate(progress, progress.unlockedThrough + 1)}.',
                          style: HolyTypography.supporting),
                    if (progress.allComplete && onSaved != null)
                      TextButton(
                          onPressed: onSaved, child: const Text('Open Saved')),
                  ]);
            }),
          ));
}

class _JourneyDial extends StatelessWidget {
  final double fraction;
  final bool complete;
  const _JourneyDial({required this.fraction, required this.complete});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => ExcludeSemantics(
          child: Container(
              width: 56,
              height: 56,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.pearl, const Color(0xFFF2DFE9)]),
                  border: Border.all(color: AppColors.pearl),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.accentDark.withValues(alpha: .07),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ]),
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(
                    child: CircularProgressIndicator(
                        value: fraction,
                        strokeWidth: 3,
                        backgroundColor: AppColors.divider)),
                complete
                    ? const Icon(Icons.check_rounded,
                        size: 24, color: AppColors.success)
                    : const BookGlyph(size: 23)
              ]))));
}

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Theme.of(context);
    final profile = ref.watch(profileProvider),
        user = ref.watch(authProvider).user,
        p = ref.watch(progressProvider),
        streak = ref.watch(readingStreakProvider);
    return ReadingWidth(
        child: ListView(
            primary: true,
            key: const PageStorageKey('profile'),
            padding: EdgeInsets.fromLTRB(
                24, 20, 24, holyNavigationReservation(context)),
            children: [
          HolyPressable(
              label:
                  'Edit preferred name, ${profile.name.isEmpty ? 'not added' : profile.name}, ${user?.email ?? 'HolyHer account'}',
              onPressed: () => openScreen(context, const NameEditorScreen()),
              child: _ProfileIdentity(name: profile.name, email: user?.email)),
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, box) {
            final stats = [
              ('Readings', p.completedCount, Icons.menu_book_outlined),
              ('Streak', streak.current, Icons.local_fire_department_outlined),
              ('Longest', streak.longest, Icons.timeline_rounded)
            ];
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final s in stats)
                Expanded(
                    child: HolyPressable(
                        onPressed: () =>
                            openScreen(context, const ProgressCalendar()),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 4),
                            child: Column(children: [
                              Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.surface),
                                  child: Icon(s.$3,
                                      color: AppColors.accent, size: 22)),
                              const SizedBox(height: 12),
                              Text('${s.$2}',
                                  style: HolyTypography.heading.copyWith(
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ])),
                              const SizedBox(height: 4),
                              Text(s.$1,
                                  style: HolyTypography.supporting,
                                  textAlign: TextAlign.center)
                            ]))))
            ]);
          }),
          const SizedBox(height: 24),
          MenuRow(
              title: 'Your theme',
              subtitle: HolyPalette.byId(profile.theme).name,
              icon: Icons.palette_outlined,
              onTap: () => openScreen(context, const ThemeScreen())),
          MenuRow(
              title: 'Your keepsakes',
              subtitle: '${p.earnedBadges.length} of 6 earned',
              icon: Icons.workspace_premium_outlined,
              onTap: () => openScreen(context, const BadgesScreen())),
          MenuRow(
              title: 'My rhythm',
              subtitle: 'A little room for your day',
              icon: Icons.wb_twilight_outlined,
              onTap: () => openScreen(context, const RhythmScreen())),
          MenuRow(
              title: 'Calendar & milestones',
              icon: Icons.calendar_month_outlined,
              onTap: () => openScreen(context, const ProgressCalendar())),
          MenuRow(
              title: 'Settings',
              icon: Icons.tune_rounded,
              onTap: () => openScreen(context, const SettingsScreen())),
          MenuRow(
              title: 'Help',
              icon: Icons.help_outline_rounded,
              onTap: () => openScreen(context, const HelpScreen())),
          MenuRow(
              title: 'About',
              icon: Icons.info_outline_rounded,
              onTap: () => openScreen(context, const AboutScreen())),
          if (p.pendingDays.isNotEmpty ||
              p.syncError != null ||
              ref.watch(attemptSyncProvider).pending.isNotEmpty ||
              ref.watch(readingSyncProvider).pending.isNotEmpty ||
              ref.watch(readingSyncProvider).pendingCheckpoints.isNotEmpty ||
              ref.watch(savedProvider).pending.isNotEmpty)
            const InlineMessage(
                'Your latest progress will sync when you’re online.'),
          const LegalFooter(),
        ]));
  }
}

class _ProfileIdentity extends StatelessWidget {
  final String name;
  final String? email;
  const _ProfileIdentity({required this.name, required this.email});
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final avatar = IdentityMedallion(
        size: 72,
        initial: name.isEmpty
            ? 'H'
            : String.fromCharCode(name.runes.first).toUpperCase());
    final title = Text(name.isEmpty ? 'Your quiet space' : name,
        style: HolyTypography.section);
    final address = Text(email ?? 'Your HolyHer account',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: HolyTypography.supporting);
    final edition = Text('HolyHer 365 edition',
        style: HolyTypography.label.copyWith(color: AppColors.accent));
    final edit =
        Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary);
    return PearlSurface(
        radius: 24,
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(builder: (context, box) {
          if (MediaQuery.textScalerOf(context).scale(17) > 24 ||
              box.maxWidth < 270) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    avatar,
                    const SizedBox(width: 16),
                    Expanded(child: title),
                    const SizedBox(width: 8),
                    edit
                  ]),
                  const SizedBox(height: 16),
                  address,
                  const SizedBox(height: 8),
                  edition
                ]);
          }
          return Row(children: [
            avatar,
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  title,
                  const SizedBox(height: 6),
                  address,
                  const SizedBox(height: 6),
                  edition
                ])),
            const SizedBox(width: 8),
            edit
          ]);
        }));
  }
}
