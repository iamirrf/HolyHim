import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/features/lesson/lesson_deck.dart';
import 'package:holyher/features/onboarding/personalization.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/profile_service.dart';

/// Five editorial cards, with a physics-driven deck on roomy viewports and a
/// natural-height reading view for large text and short landscape windows.
class LessonCards extends ConsumerStatefulWidget {
  final DailyLesson lesson;
  final bool done;
  final bool saving;
  final Future<void> Function() onComplete;
  const LessonCards(
      {super.key,
      required this.lesson,
      required this.done,
      required this.saving,
      required this.onComplete});
  @override
  ConsumerState<LessonCards> createState() => _LessonCardsState();
}

class _LessonCardsState extends ConsumerState<LessonCards> {
  final _deck = LessonDeckController();
  final _scroll = ScrollController();
  int _page = 0;
  bool _help = false;
  bool _loaded = false;
  String get _positionKey =>
      'card_position_${ref.read(authProvider).user?.uid ?? 'local'}_${widget.lesson.day}';
  @override
  void initState() {
    super.initState();
    _help = ref.read(profileProvider).familiarity != 'regular';
    _restore();
  }

  Future<void> _restore() async {
    final saved =
        widget.done ? 0 : await ref.read(localStoreProvider).read(_positionKey);
    if (mounted && !_loaded) {
      setState(() {
        _page = saved is int ? saved.clamp(0, 4) : 0;
        _loaded = true;
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _change(int page) {
    setState(() {
      _page = page;
      _loaded = true;
    });
    ref.read(localStoreProvider).write(_positionKey, page);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  static const _labels = ['Verse', 'Confidence', 'Reason', 'Hope', 'Carry'];
  static const _icons = [
    Icons.menu_book_outlined,
    Icons.wb_sunny_outlined,
    Icons.lightbulb_outline_rounded,
    Icons.auto_awesome_outlined,
    Icons.favorite_border_rounded
  ];
  static const _helpText = [
    'Begin with the passage itself. The reference identifies its book, chapter, verse, and translation.',
    'One grounded encouragement, drawn from the passage you just read.',
    'A plain-language explanation of why this confidence follows from the verse.',
    'A way to meet an ordinary moment with the passage in mind. The devotional reflection is original writing, separate from scripture.',
    'A small reflection to bring into the rest of your day. Your focus adds a personal application question.',
  ];
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    return LayoutBuilder(builder: (context, box) {
      final natural = box.maxHeight < 500 ||
          MediaQuery.textScalerOf(context).scale(16) > 25;
      final header = Padding(
          padding: const EdgeInsets.fromLTRB(26, 12, 26, 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Eyebrow(
                      'Day ${widget.lesson.day} · ${widget.lesson.theme}')),
              Text('${_page + 1} / 5',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary))
            ]),
            const SizedBox(height: 13),
            Semantics(
                label: 'Lesson progress',
                value: '${_page + 1} of 5 cards',
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                        tween: Tween(end: (_page + 1) / 5),
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 380),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => LinearProgressIndicator(
                            value: value,
                            minHeight: 5,
                            backgroundColor: AppColors.divider)))),
          ]));
      final footer = _footer(natural);
      if (natural) {
        return ReadingWidth(
            maxWidth: 700,
            child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.only(bottom: 18),
                children: [
                  header,
                  Padding(
                      padding: const EdgeInsets.all(22),
                      child: _card(_page, profile, natural: true)),
                  footer
                ]));
      }
      return ReadingWidth(
          maxWidth: 780,
          child: Column(children: [
            header,
            Expanded(child: LayoutBuilder(builder: (context, deckBox) {
              final width = math.min(620.0, deckBox.maxWidth - 48);
              return LessonDeck(
                  itemCount: 5,
                  index: _page,
                  cardSize: Size(width, deckBox.maxHeight - 24),
                  controller: _deck,
                  canMove: (from, to) => to >= 0 && to < 5,
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
    final lesson = widget.lesson;
    final title = switch (index) {
      0 => lesson.title,
      1 => 'A confidence\nto hold.',
      2 => 'Why it stands.',
      3 => 'Hope for\nthe everyday.',
      _ => 'Take this\nwith you.'
    };
    final body = switch (index) {
      0 => lesson.verseText,
      1 => lesson.confidence,
      2 => lesson.reason,
      3 => lesson.hope,
      _ => lesson.reflection
    };
    final content = Padding(
        padding: const EdgeInsets.all(27),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white)),
                    child:
                        Icon(_icons[index], color: AppColors.accent, size: 22)),
                const SizedBox(width: 13),
                Expanded(child: Eyebrow(_labels[index])),
                IconButton(
                    tooltip: _help ? 'Hide reading help' : 'Show reading help',
                    icon: const Icon(Icons.info_outline_rounded,
                        size: 19, color: AppColors.textSecondary),
                    onPressed: () => setState(() => _help = !_help))
              ]),
              if (_help) ...[
                const SizedBox(height: 15),
                Text(_helpText[index],
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.7))
              ],
              const SizedBox(height: 26),
              Text(title,
                  style: const TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w500,
                      height: 1.22,
                      letterSpacing: -.9)),
              const SizedBox(height: 25),
              if (index == 0) ...[
                const Icon(Icons.format_quote_rounded,
                    size: 34, color: AppColors.accent),
                const SizedBox(height: 10)
              ],
              Text(body,
                  style: TextStyle(
                      fontSize: index == 0 || index == 1 ? 20 : 17,
                      height: 1.75,
                      color: index == 0
                          ? AppColors.accentDark
                          : AppColors.textPrimary)),
              if (index == 0) ...[
                const SizedBox(height: 24),
                Text(lesson.verseReference,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.6))
              ],
              if (index == 3 && lesson.devotionalReflection.isNotEmpty) ...[
                const SizedBox(height: 26),
                const Divider(),
                const SizedBox(height: 16),
                const Eyebrow('Devotional reflection'),
                const SizedBox(height: 10),
                Text(lesson.devotionalReflection,
                    style: const TextStyle(
                        fontSize: 17,
                        height: 1.75,
                        color: AppColors.accentDark)),
                const SizedBox(height: 12),
                const Text(
                    'Original devotional writing · not a Bible quotation',
                    style: TextStyle(
                        fontSize: 10,
                        height: 1.6,
                        color: AppColors.textSecondary))
              ],
              if (index == 4) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Eyebrow('Your focus · ${focusLabel(profile.focus)}'),
                const SizedBox(height: 12),
                Text(focusQuestion(profile, lesson.day),
                    style: const TextStyle(
                        fontSize: 15, height: 1.8, color: AppColors.accentDark))
              ],
              const SizedBox(height: 14),
            ]));
    return AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration:
            BoxDecoration(borderRadius: BorderRadius.circular(30), boxShadow: [
          BoxShadow(
              color: AppColors.accentDark.withValues(alpha: .11 + lift * .07),
              blurRadius: 30 + lift * 20,
              offset: Offset(0, 12 + lift * 10))
        ]),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: DecoratedBox(
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFFEFF),
                          Color(0xFFF9ECF2),
                          Color(0xFFF1DCE8)
                        ]),
                    borderRadius: BorderRadius.all(Radius.circular(30))),
                child: natural
                    ? content
                    : SingleChildScrollView(
                        key: PageStorageKey('card-${lesson.day}-$index'),
                        child: content))));
  }

  Widget _footer(bool natural) {
    final large = MediaQuery.textScalerOf(context).scale(15) > 24;
    final previous = IconButton(
      tooltip: 'Previous card',
      onPressed: widget.saving ? null : () => _change(_page - 1),
      icon: const Icon(Icons.arrow_back_rounded),
    );
    final action = HolyButton(
      key: ValueKey('lesson-action-$_page'),
      label: _page == 4
          ? (widget.done
              ? (large ? 'Return' : 'Return to my day')
              : (large ? 'Complete' : 'Complete today’s message'))
          : 'Next card',
      busy: widget.saving,
      onPressed: widget.saving
          ? null
          : _page == 4
              ? () async {
                  await widget.onComplete();
                  if (mounted) {
                    ref.read(localStoreProvider).write(_positionKey, 0);
                  }
                }
              : () {
                  if (natural) {
                    _change(_page + 1);
                  } else {
                    _deck.advance();
                  }
                },
      icon: large
          ? null
          : (_page == 4 ? Icons.check_rounded : Icons.arrow_forward_rounded),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 10, 25, 18),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                5,
                (index) => Semantics(
                      label: '${_labels[index]}, card ${index + 1}',
                      selected: index == _page,
                      child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 5,
                          width: index == _page ? 24 : 6,
                          decoration: BoxDecoration(
                              color: index == _page
                                  ? AppColors.accent
                                  : AppColors.divider,
                              borderRadius: BorderRadius.circular(5))),
                    ))),
        const SizedBox(height: 15),
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
