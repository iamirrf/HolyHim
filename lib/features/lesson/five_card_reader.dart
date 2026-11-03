import 'package:holyher/core/widgets/keepsake_medallion.dart';
import 'package:holyher/services/lesson_audio.dart';
import 'package:holyher/services/reading_streak.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/core/widgets/lesson_artwork.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/data/readings.dart';
import 'package:holyher/features/home/saved_tab.dart';
import 'package:holyher/features/lesson/lesson_deck.dart';
import 'package:holyher/services/profile_service.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/reading_service.dart';
import 'package:holyher/services/feedback_service.dart';

class FiveCardReader extends ConsumerStatefulWidget {
  final DailyLesson lesson;
  final bool openScripture;
  final VoidCallback? onClose;
  const FiveCardReader(
      {super.key,
      required this.lesson,
      this.openScripture = false,
      this.onClose});
  @override
  ConsumerState<FiveCardReader> createState() => _FiveCardReaderState();
}

class _FiveCardReaderState extends ConsumerState<FiveCardReader>
    with WidgetsBindingObserver {
  final _deck = LessonDeckController();
  late final _audio =
      LessonAudio(() => mounted && ref.read(profileProvider).sounds);
  Map<String, dynamic>? _checkpoint;
  int _index = 0;
  bool _busy = false, _completed = false;
  String? _error;
  Set<int> _newBadges = {};
  DailyReading get _reading => readings[widget.lesson.day - 1];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(progressProvider).isUnlocked(widget.lesson.day)) {
      Future.microtask(_load);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _audio.stop();
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(readingSyncProvider.notifier).sync());
    }
  }

  Future<void> _load() async {
    try {
      final checkpoint = await ref
          .read(readingSyncProvider.notifier)
          .open(widget.lesson.day, scripture: widget.openScripture);
      if (mounted) {
        setState(() {
          _checkpoint = checkpoint;
          _index = checkpoint['cardIndex'] as int;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Your reading place could not be loaded. Retry to continue.');
      }
    }
  }

  Future<void> _visit(int index) async {
    final next = {
      ..._checkpoint!,
      'cardIndex': index,
      'visited':
          {...List<int>.from(_checkpoint!['visited'] as List), index}.toList()
            ..sort()
    };
    setState(() => _index = index);
    try {
      await ref.read(readingSyncProvider.notifier).checkpoint(next);
      if (mounted) {
        setState(() {
          _checkpoint = next;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Your place could not be saved. Retry before finishing.');
      }
    }
  }

  Future<void> _finish() async {
    if (_busy || _checkpoint == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final before = ref.read(progressProvider).earnedBadges;
    try {
      final current = {
        ..._checkpoint!,
        'cardIndex': _index,
        'visited': {...List<int>.from(_checkpoint!['visited'] as List), _index}
            .toList()
      };
      await ref.read(readingSyncProvider.notifier).checkpoint(current);
      _checkpoint = current;
      await ref.read(readingSyncProvider.notifier).complete(current);
      if (!mounted) return;
      ref.read(feedbackProvider).selection();
      unawaited(_audio.play('lesson_land', .15));
      setState(() {
        _completed = true;
        _newBadges = ref.read(progressProvider).earnedBadges.difference(before);
      });
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Your reading could not be saved. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    if (_busy) return;
    if (_checkpoint != null && !_completed) {
      try {
        await ref.read(readingSyncProvider.notifier).checkpoint(_checkpoint!);
      } catch (_) {
        if (mounted) {
          setState(
              () => _error = 'Your place could not be saved. Please retry.');
        }
        return;
      }
    }
    if (mounted) {
      if (widget.onClose != null) {
        widget.onClose!();
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final profile = ref.watch(profileProvider),
        sync = ref.watch(readingSyncProvider),
        progress = ref.watch(progressProvider);
    final pending = sync.pending.any((o) => o['day'] == widget.lesson.day);
    if (_checkpoint == null && progress.isUnlocked(widget.lesson.day)) {
      return HolyScaffold(
          title: 'Day ${widget.lesson.day}',
          actions: [
            IconButton(
                tooltip: 'Close reading',
                onPressed: _close,
                icon: const Icon(Icons.close))
          ],
          body: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          HolyButton(label: 'Retry', onPressed: _load)
                        ]))));
    }
    if (_completed) {
      return HolyScaffold(
          body: ReadingWidth(
              maxWidth: 560,
              child: Center(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const HolyMark(size: 72),
                        const SizedBox(height: 24),
                        const Eyebrow('A moment well spent'),
                        const SizedBox(height: 16),
                        Text('Walk a little lighter.',
                            textAlign: TextAlign.center,
                            style: HolyTypography.display
                                .copyWith(color: AppColors.textPrimary)),
                        const SizedBox(height: 16),
                        Text(
                            'Day ${widget.lesson.day} accepted · ${progress.completedCount} of 365 readings',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        Text(
                            '${ref.watch(readingStreakProvider).current} day reading streak',
                            textAlign: TextAlign.center,
                            style: HolyTypography.supporting),
                        const SizedBox(height: 12),
                        Text(
                            pending
                                ? 'Saved on this device. Synchronization is pending.'
                                : 'Your reading is synced.',
                            textAlign: TextAlign.center,
                            style: HolyTypography.supporting),
                        if (_newBadges.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          KeepsakeMedallion(
                              milestone: _newBadges.last,
                              reveal: true,
                              size: 112),
                          Text(
                              '${_newBadges.last} ${_newBadges.last == 1 ? 'reading' : 'readings'} · A new keepsake',
                              textAlign: TextAlign.center,
                              style: HolyTypography.section)
                        ],
                        const SizedBox(height: 32),
                        HolyButton(
                            label: 'Return to my walk',
                            onPressed: _close,
                            icon: Icons.arrow_forward_rounded),
                      ])))));
    }
    if (!progress.isUnlocked(widget.lesson.day)) {
      return HolyScaffold(
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.lock_outline, size: 40),
                    const SizedBox(height: 18),
                    Text('Day ${widget.lesson.day} is still ahead.',
                        style: HolyTypography.heading),
                    const SizedBox(height: 16),
                    const Text('One new reading opens each journey day.'),
                    TextButton(
                        onPressed: _close,
                        child: const Text('Return to my walk'))
                  ]))));
    }
    return PopScope(
        canPop: _checkpoint == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_close());
        },
        child: HolyScaffold(
            body: Shortcuts(
                shortcuts: const {
              SingleActivator(LogicalKeyboardKey.arrowRight): _NextCard(),
              SingleActivator(LogicalKeyboardKey.arrowLeft): _PreviousCard()
            },
                child: Actions(
                    actions: {
                      _NextCard: CallbackAction<_NextCard>(onInvoke: (_) {
                        if (_index < 4) _deck.advance(1);
                        return null;
                      }),
                      _PreviousCard:
                          CallbackAction<_PreviousCard>(onInvoke: (_) {
                        if (_index > 0) _deck.advance(-1);
                        return null;
                      })
                    },
                    child: Focus(
                        autofocus: true,
                        child: Column(children: [
                          Padding(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                              child: Column(children: [
                                Row(children: [
                                  IconButton(
                                      tooltip: 'Close reading',
                                      onPressed: _busy ? null : _close,
                                      icon: const Icon(Icons.close)),
                                  Expanded(
                                      child: Text(
                                          'Day ${widget.lesson.day} / 365',
                                          textAlign: TextAlign.center,
                                          style: HolyTypography.label)),
                                  SaveLessonButton(day: widget.lesson.day),
                                  IconButton(
                                      tooltip: 'Share Scripture',
                                      onPressed: () =>
                                          shareVerse(context, widget.lesson),
                                      icon:
                                          const Icon(Icons.ios_share_outlined))
                                ]),
                                Semantics(
                                    label: 'Reading progress',
                                    value: '${_index + 1} of 5 cards',
                                    child: Row(
                                        children: List.generate(
                                            5,
                                            (i) => Expanded(
                                                child: Container(
                                                    height: 3,
                                                    margin: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 3),
                                                    decoration: BoxDecoration(
                                                        color: i <= _index
                                                            ? AppColors.accent
                                                            : AppColors.divider,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                                    4))))))),
                              ])),
                          if (_checkpoint == null)
                            Expanded(
                                child: Center(
                                    child: _error == null
                                        ? const CircularProgressIndicator()
                                        : Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            24),
                                                    child: Text(_error!,
                                                        textAlign:
                                                            TextAlign.center)),
                                                TextButton(
                                                    onPressed: _load,
                                                    child: const Text('Retry'))
                                              ])))
                          else
                            Expanded(
                                child: ReadingWidth(
                                    maxWidth: 620,
                                    child: LayoutBuilder(
                                        builder: (context, box) => LessonDeck(
                                            itemCount: 5,
                                            index: _index,
                                            cardSize: Size(box.maxWidth - 28,
                                                box.maxHeight - 12),
                                            controller: _deck,
                                            canMove: (from, to) =>
                                                !_busy && to >= 0 && to < 5,
                                            onIndexChanged: (i) =>
                                                unawaited(_visit(i)),
                                            locked: _busy,
                                            onCommit: (direction, intensity) =>
                                                unawaited(_audio.play(
                                                    direction > 0
                                                        ? 'lesson_swipe_back'
                                                        : 'lesson_swipe_1',
                                                    .12 * intensity)),
                                            itemBuilder:
                                                (context, index, lift) {
                                              final card =
                                                  _reading.cards[index];
                                              return ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                  child: DecoratedBox(
                                                      decoration: BoxDecoration(
                                                          border: Border.all(
                                                              color: AppColors
                                                                  .pearl,
                                                              width: 1.5),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  30)),
                                                      child: LessonArtwork(
                                                          day:
                                                              widget.lesson.day,
                                                          quiet: true,
                                                          child:
                                                              SingleChildScrollView(
                                                                  key: PageStorageKey(
                                                                      'reading-${widget.lesson.day}-$index'),
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .fromLTRB(
                                                                          28,
                                                                          32,
                                                                          28,
                                                                          48),
                                                                  child: Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Eyebrow(
                                                                            '${const [
                                                                          'Scripture',
                                                                          'Meaning',
                                                                          'Encouragement',
                                                                          'Hope',
                                                                          'Prayer'
                                                                        ][index]} · ${index + 1} of 5'),
                                                                        const SizedBox(
                                                                            height:
                                                                                22),
                                                                        Text(
                                                                            index == 0
                                                                                ? widget.lesson.title
                                                                                : const [
                                                                                    '',
                                                                                    'God in the story',
                                                                                    'For your everyday',
                                                                                    'A truth to carry',
                                                                                    'A moment of prayer'
                                                                                  ][index],
                                                                            style: HolyTypography.heading.copyWith(color: AppColors.textPrimary)),
                                                                        const SizedBox(
                                                                            height:
                                                                                24),
                                                                        SelectableText(
                                                                            card
                                                                                .text,
                                                                            style: (index == 0 ? HolyTypography.scripture : HolyTypography.reading).copyWith(
                                                                                color: AppColors.textPrimary,
                                                                                fontSize: (index == 0 ? 22 : 20) * profile.readingScale,
                                                                                height: 1.6)),
                                                                        if (index ==
                                                                            0) ...[
                                                                          const SizedBox(
                                                                              height: 22),
                                                                          Text(
                                                                              '${_reading.reference} · World English Bible',
                                                                              style: HolyTypography.supporting.copyWith(color: AppColors.textSecondary))
                                                                        ],
                                                                      ])))));
                                            })))),
                          if (sync.error?.contains('another device') == true)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: Column(children: [
                                  Text(sync.error!,
                                      style: HolyTypography.supporting),
                                  Wrap(children: [
                                    TextButton(
                                        onPressed: () async {
                                          await ref
                                              .read(
                                                  readingSyncProvider.notifier)
                                              .resolveCheckpoint(
                                                  widget.lesson.day,
                                                  useCloud: true);
                                          await _load();
                                        },
                                        child: const Text('Use synced place')),
                                    TextButton(
                                        onPressed: () async {
                                          await ref
                                              .read(
                                                  readingSyncProvider.notifier)
                                              .resolveCheckpoint(
                                                  widget.lesson.day,
                                                  useCloud: false);
                                          await _load();
                                        },
                                        child: const Text('Keep this place'))
                                  ])
                                ])),
                          if (_error != null)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: Semantics(
                                    liveRegion: true,
                                    child: Text(_error!,
                                        style: HolyTypography.supporting
                                            .copyWith(
                                                color: AppColors.error)))),
                          Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 12, 18, 12),
                              child: ReadingWidth(
                                  maxWidth: 620,
                                  child: Row(children: [
                                    IconButton(
                                        tooltip: 'Previous card',
                                        onPressed: _index > 0 && !_busy
                                            ? () => _deck.advance(-1)
                                            : null,
                                        icon: const Icon(
                                            Icons.arrow_back_rounded)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: HolyButton(
                                            label: _busy
                                                ? 'Saving…'
                                                : _index == 4
                                                    ? (MediaQuery.textScalerOf(
                                                                    context)
                                                                .scale(16) >
                                                            24
                                                        ? 'Done'
                                                        : 'Finish my reading')
                                                    : (MediaQuery.textScalerOf(
                                                                    context)
                                                                .scale(16) >
                                                            24
                                                        ? 'Next'
                                                        : 'Continue'),
                                            onPressed: _checkpoint == null ||
                                                    _busy
                                                ? null
                                                : _index == 4
                                                    ? _finish
                                                    : () => _deck.advance(1),
                                            icon: Icons.arrow_forward_rounded))
                                  ]))),
                        ]))))));
  }
}

class _NextCard extends Intent {
  const _NextCard();
}

class _PreviousCard extends Intent {
  const _PreviousCard();
}
