import 'dart:math' as math;
import 'package:holyher/features/home/lesson_presentation.dart';
import 'dart:convert';
import 'package:holyher/core/widgets/holy_loader.dart';
import 'package:holyher/services/durable_store.dart';
import 'package:holyher/features/lesson/reading_parts.dart';
import 'package:holyher/features/lesson/lesson_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/features/lesson/lesson_deck.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/profile_service.dart';

/// Five editorial cards, with a physics-driven deck on roomy viewports and a
/// natural-height reading view for large text and short landscape windows.
class LessonCardsController {
  Future<void> Function()? _save;
  Future<void> save() async {
    await _save?.call();
  }
}

class LessonCards extends ConsumerStatefulWidget {
  final DailyLesson lesson;
  final LessonCardsController? controller;
  final bool done;
  final bool saving;
  final Future<bool> Function() onComplete;
  final VoidCallback onClose;
  final String? error;
  const LessonCards(
      {super.key,
      required this.lesson,
      this.controller,
      required this.done,
      required this.saving,
      required this.onComplete,
      required this.onClose,
      this.error});
  @override
  ConsumerState<LessonCards> createState() => _LessonCardsState();
}

class _LessonCardsState extends ConsumerState<LessonCards> {
  final _deck = LessonDeckController();
  final _scroll = ScrollController();
  int _page = 0, _offset = 0;
  List<ReadingPart> _parts = const [ReadingPart('', 0, 0)];
  int get _part => ReadingLayout.indexAt(_parts, _offset);
  String? _positionError;
  bool _help = false;
  bool _loaded = false;
  String get _positionKey =>
      'card_position_${ref.read(authProvider).user?.uid ?? 'local'}_${widget.lesson.day}';
  @override
  void initState() {
    super.initState();
    _help = ref.read(profileProvider).tips &&
        ref.read(profileProvider).familiarity != 'regular';
    widget.controller?._save = _savePosition;
    _restore();
  }

  Future<void> _restore() async {
    try {
      final store = ref.read(localStoreProvider),
          raw = await ref
              .read(localStoreProvider)
              .read('${_positionKey}_semantic');
      final legacy = widget.done ? 0 : await store.read(_positionKey);
      int page = legacy is int ? legacy.clamp(0, 4) : 0, offset = 0;
      if (!widget.done && raw != null && raw != '') {
        if (raw is! String) throw const FormatException();
        final saved = jsonDecode(raw) as Map;
        page = _labels
            .map((s) => s.toLowerCase())
            .toList()
            .indexOf(saved['stepId']);
        if (page < 0 ||
            saved['readingOffset'] is! int ||
            saved['readingOffset'] < 0) {
          throw const FormatException();
        }
        offset = saved['readingOffset'];
      }
      if (mounted && !_loaded) {
        setState(() {
          _page = page;
          _offset = offset;
          _loaded = true;
          _positionError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _positionError =
            'Your saved place could not be read. Retry before continuing.');
      }
    }
  }

  @override
  void dispose() {
    widget.controller?._save = null;
    _scroll.dispose();
    super.dispose();
  }

  void _change(int page) {
    setState(() {
      _page = page;
      _offset = 0;
      _loaded = true;
    });
    _savePosition().catchError((Object _) {
      if (mounted) {
        setState(() =>
            _positionError = 'Your place could not be saved. Please retry.');
      }
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _savePosition() async {
    if (!_loaded) return;
    final store = ref.read(localStoreProvider);
    if (!await writeLocalBatch(store, {
      '${_positionKey}_semantic': jsonEncode(
          {'stepId': _labels[_page].toLowerCase(), 'readingOffset': _offset}),
      _positionKey: _page
    })) {
      throw StateError('Your place could not be saved.');
    }
    ref.read(readingPositionRevisionProvider.notifier).state++;
  }

  String _body(int i) => switch (i) {
        0 => widget.lesson.verseText,
        1 => widget.lesson.confidence,
        2 => widget.lesson.reason,
        3 => widget.lesson.hope,
        _ => widget.lesson.reflection
      };
  static const _labels = ['Verse', 'Confidence', 'Reason', 'Hope', 'Carry'];
  static const _helpText = [
    'Start with the passage. Its reference is below.',
    'An encouragement drawn from this passage.',
    'How this thought connects to the passage.',
    'A practical reflection for an ordinary day.',
    'One small thought to carry into your day.',
  ];
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final profile = ref.watch(profileProvider);
    if (!_loaded) {
      return LessonRecoveryFrame(
          child: _positionError == null
              ? const PulsingDotsLoader(semanticsLabel: 'Restoring your place')
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  InlineMessage(_positionError!, error: true),
                  TextButton(onPressed: _restore, child: const Text('Retry'))
                ]));
    }
    return LayoutBuilder(builder: (context, box) {
      final natural = box.maxHeight < 650 ||
          MediaQuery.textScalerOf(context).scale(16) > 25;
      final body = _body(_page);
      _parts = natural
          ? [ReadingPart(body, 0, body.length)]
          : ReadingLayout.split(body,
              style: _page == 0 || _page == 1
                  ? HolyTypography.scripture
                  : HolyTypography.reading,
              width: natural
                  ? math.min(700, box.maxWidth - 44) - 64
                  : lessonPageSize(Size(box.maxWidth, box.maxHeight - 190),
                              gutter: 48, inset: 24)
                          .width -
                      64,
              height: math.max(180, box.maxHeight - 360),
              scaler: MediaQuery.textScalerOf(context),
              direction: Directionality.of(context));
      final header = Column(children: [
        LessonHeader(
            day: widget.lesson.day,
            index: _page,
            count: 5,
            onClose: widget.saving ? null : widget.onClose),
        if (widget.error != null)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: InlineMessage(widget.error!, error: true))
      ]);
      final footer = _footer(natural);
      if (natural) {
        if (MediaQuery.textScalerOf(context).scale(17) > 42) {
          return ReadingWidth(
              maxWidth: 700,
              child: ListView(controller: _scroll, children: [
                header,
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: _card(_page, profile, natural: true)),
                footer
              ]));
        }
        return ReadingWidth(
            maxWidth: 700,
            child: Column(children: [
              header,
              Expanded(
                  child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      children: [_card(_page, profile, natural: true)])),
              footer,
            ]));
      }

      return ReadingWidth(
          maxWidth: 780,
          child: Column(children: [
            header,
            Expanded(child: LayoutBuilder(builder: (context, deckBox) {
              return LessonDeck(
                  itemCount: 5,
                  index: _page,
                  cardSize:
                      lessonPageSize(deckBox.biggest, gutter: 48, inset: 24),
                  controller: _deck,
                  canMove: (from, to) =>
                      to >= 0 &&
                      to < 5 &&
                      (to < from || _part == _parts.length - 1),
                  onIndexChanged: _change,
                  locked: widget.saving,
                  itemBuilder: (context, index, lift) =>
                      _card(index, profile, lift: lift));
            })),
            footer
          ]));
    });
  }

  Widget _card(int index, UserProfile profile,
      {bool natural = false, double lift = 0}) {
    final l = widget.lesson;
    final titles = [
      l.title,
      'A confidence to hold.',
      'Why it stands.',
      'Hope for the everyday.',
      'Take this with you.'
    ];
    final content = Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(child: Eyebrow('Day ${l.day} · ${_labels[index]}')),
                IconButton(
                    tooltip: _help ? 'Hide reading help' : 'Show reading help',
                    onPressed: () => setState(() => _help = !_help),
                    icon: const Icon(Icons.info_outline, size: 20))
              ]),
              if (_help) ...[
                const SizedBox(height: 12),
                Text(_helpText[index],
                    style: HolyTypography.supporting
                        .copyWith(color: AppColors.textSecondary))
              ],
              const SizedBox(height: 24),
              if (index == 2 || index == 4) ...[
                Text(titles[index], style: HolyTypography.section),
                const SizedBox(height: 24)
              ],
              if (index == _page && _parts.length > 1) ...[
                Text('Part ${_part + 1} of ${_parts.length}',
                    style: HolyTypography.supporting),
                const SizedBox(height: 16)
              ],
              Text(index == _page ? _parts[_part].text : _body(index),
                  style: index == 0 || index == 1 || index == 4
                      ? HolyTypography.scripture
                      : HolyTypography.reading),
              if (index == 0) ...[
                const SizedBox(height: 28),
                Container(height: 1, width: 32, color: AppColors.accent),
                const SizedBox(height: 16),
                Text(l.verseReference,
                    style: HolyTypography.supporting
                        .copyWith(color: AppColors.accentDark)),
                const SizedBox(height: 4),
                const Text('World English Bible',
                    style: HolyTypography.supporting)
              ],
              if (index == 3 && l.devotionalReflection.isNotEmpty) ...[
                const Divider(height: 40),
                const Text('HolyHer reflection',
                    style: HolyTypography.supporting),
                const SizedBox(height: 16),
                Text(l.devotionalReflection, style: HolyTypography.reading),
                const SizedBox(height: 16),
                const Text('Original devotional writing',
                    style: HolyTypography.supporting)
              ],
              if (_positionError != null) ...[
                InlineMessage(_positionError!, error: true),
                TextButton(
                    onPressed: () async {
                      try {
                        await _savePosition();
                        if (mounted) setState(() => _positionError = null);
                      } catch (_) {}
                    },
                    child: const Text('Retry'))
              ],
            ]));
    return PearlSurface(
        radius: 24,
        lift: lift,
        ribbon: index == 4,
        child: natural
            ? content
            : SingleChildScrollView(
                key: ValueKey(
                    'existing-${l.day}-$index-${index == _page ? _offset : 0}'),
                child: content));
  }

  Widget _footer(bool natural) {
    final large = MediaQuery.textScalerOf(context).scale(15) > 24;
    final previous = IconButton(
      tooltip: 'Previous card',
      onPressed: widget.saving
          ? null
          : () {
              if (_part > 0) {
                setState(() => _offset = _parts[_part - 1].start);
              } else {
                _change(_page - 1);
              }
            },
      icon: const Icon(Icons.arrow_back_rounded),
    );
    final action = HolyButton(
      key: ValueKey('lesson-action-$_page'),
      label: _part < _parts.length - 1
          ? 'Next part'
          : _page == 4
              ? (widget.done ? 'Continue' : 'Complete lesson')
              : 'Next',
      busy: widget.saving,
      onPressed: widget.saving
          ? null
          : _part < _parts.length - 1
              ? () async {
                  setState(() => _offset = _parts[_part + 1].start);
                  try {
                    await _savePosition();
                  } catch (_) {
                    if (mounted) {
                      setState(() => _positionError =
                          'Your place could not be saved. Please retry.');
                    }
                  }
                }
              : _page == 4
                  ? () async {
                      final accepted = await widget.onComplete();
                      if (accepted && mounted) {
                        final store = ref.read(localStoreProvider);
                        await writeLocalBatch(store, {
                          _positionKey: 0,
                          '${_positionKey}_semantic': jsonEncode(
                              {'stepId': 'verse', 'readingOffset': 0})
                        });
                      }
                    }
                  : () {
                      if (natural) {
                        _change(_page + 1);
                      } else {
                        _deck.advance();
                      }
                    },
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (large) ...[
          if (_page > 0)
            Align(alignment: Alignment.centerLeft, child: previous),
          action,
        ] else
          Row(children: [
            if (_page > 0) ...[previous, const SizedBox(width: 8)],
            Expanded(child: action)
          ]),
      ]),
    );
  }
}
