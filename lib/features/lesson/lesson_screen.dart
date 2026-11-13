import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/lessons.g.dart';
import '../../design/art_catalog.dart';
import '../../domain/lesson.dart';
import '../../domain/lesson_position.dart';
import '../../design/design.dart';
import '../../services/auth_service.dart';
import '../../services/repository.dart';
import '../../services/share_card.dart';
import '../common.dart';
import '../celebration/celebration_screen.dart';

/// A lesson: four paper cards over the chapter photograph. Swipe or tap the
/// edges to move; hold "Amen" on the last card and light fills the room.
class LessonScreen extends ConsumerStatefulWidget {
  final int day;
  final bool continuation;
  const LessonScreen({super.key, required this.day, this.continuation = false});

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int card = 0;
  final deck = LessonDeckController();
  final scrolls = List.generate(4, (_) => ScrollController());
  final holdGlow = ValueNotifier<double>(0);
  final amenKey = GlobalKey();
  late final bloom = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  Offset bloomCenter = Offset.zero;
  bool finishing = false;
  String? _accountId;
  bool _completed = false;

  Lesson get lesson => lessonForDay(widget.day)!;

  @override
  void initState() {
    super.initState();
    _accountId = ref.read(authProvider).user?.uid;
    _completed = ref.read(repositoryProvider).completed.containsKey(widget.day);
    WidgetsBinding.instance.addObserver(this);
    HolySounds.warmUp();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
  }

  Future<void> _restorePosition() async {
    final uid = _accountId;
    if (uid == null || _completed) return;
    final position = await LessonPositionStore.read(uid, lesson);
    if (!mounted ||
        position == null ||
        ref.read(authProvider).user?.uid != uid) {
      return;
    }
    setState(() => card = position.stage.index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = scrolls[card];
      if (controller.hasClients) {
        controller
            .jumpTo(controller.position.maxScrollExtent * position.scrollFraction);
      }
    });
  }

  Future<void> _savePosition([int? stage]) async {
    final uid = _accountId;
    if (uid == null || finishing || _completed) return;
    final index = stage ?? card;
    final controller = scrolls[index];
    final max = controller.hasClients ? controller.position.maxScrollExtent : 0.0;
    final fraction = max > 0 ? (controller.offset / max).clamp(0.0, 1.0) : 0.0;
    try {
      await LessonPositionStore.write(
          uid,
          LessonPosition(widget.day, LessonStage.values[index], fraction,
              LessonPosition.revision(lesson), DateTime.now()));
    } catch (_) {/* The next stage or exit retries. */}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _savePosition();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _savePosition();
    for (final controller in scrolls) {
      controller.dispose();
    }
    holdGlow.dispose();
    bloom.dispose();
    super.dispose();
  }

  void move(int delta) {
    if (finishing) return;
    if (delta > 0 && card < 3) {
      deck.advance();
    } else if (delta < 0 && card > 0) {
      deck.retreat();
    }
  }

  void _close() {
    _savePosition();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _textSize() {
    final profile = ref.read(repositoryProvider).profile;
    const steps = [1.0, 1.15, 1.3];
    final i = steps.indexWhere((s) => (s - profile.readingScale).abs() < .05);
    final next = steps[(i + 1) % steps.length];
    HolyHaptics.chipSelect();
    ref
        .read(repositoryProvider.notifier)
        .updateProfile(profile.copyWith(readingScale: next));
  }

  Future<void> amen() async {
    if (finishing) return;
    setState(() => finishing = true);
    final box = amenKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      bloomCenter = box.localToGlobal(box.size.center(Offset.zero));
    }
    HolyHaptics.success();
    final reduced = MediaQuery.disableAnimationsOf(context);
    final before = ref.read(repositoryProvider);
    final now = DateTime.now();
    final light = reduced ? Future<void>.value() : bloom.forward();
    bool completed;
    try {
      completed = await ref
          .read(repositoryProvider.notifier)
          .completeDurably(widget.day, now: now);
    } catch (_) {
      if (mounted) {
        bloom.reverse();
        setState(() => finishing = false);
        toast(context, 'Your reading could not be saved. Please try again.');
      }
      return;
    }
    await light;
    if (!mounted) return;
    _completed = true;
    final uid = _accountId;
    if (uid != null) {
      unawaited(LessonPositionStore.clear(uid).catchError((Object _) {}));
    }
    ref.read(completionMomentProvider.notifier).state = completed
        ? completionMomentBetween(
            day: widget.day,
            before: before,
            after: ref.read(repositoryProvider),
            now: now)
        : null;
    context.pushReplacement('/celebration/${widget.day}');
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final state = ref.watch(repositoryProvider);
    final scale = state.profile.readingScale;
    final saved = state.saved.containsKey(widget.day);
    final media = MediaQuery.of(context);
    final compact = media.size.height < 740;
    final reduced = MediaQuery.disableAnimationsOf(context);
    const titles = Lesson.cardTitles;
    final text = [lesson.verse, lesson.meaning, lesson.heart, lesson.prayer];

    final header = Padding(
        padding: EdgeInsets.fromLTRB(HolySpace.gutter - 6, media.padding.top + 6,
            HolySpace.gutter - 6, 0),
        child: Row(children: [
          IconControl(
              icon: CupertinoIcons.xmark,
              label: 'Close lesson',
              onPhoto: true,
              onPressed: _close),
          const SizedBox(width: 12),
          Expanded(
              child: StepBar(
                  steps: 4, current: card, color: HolyTheme.photoInk)),
          const SizedBox(width: 12),
          IconControl(
              icon: CupertinoIcons.textformat_size,
              label: 'Text size',
              onPhoto: true,
              onPressed: _textSize),
          const SizedBox(width: 8),
          IconControl(
              icon: saved ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
              label: saved ? 'Remove from Saved' : 'Save this verse',
              onPhoto: true,
              color: saved ? const Color(0xFFFFB9C8) : null,
              onPressed: () {
                ref.read(repositoryProvider.notifier).toggleSaved(widget.day);
                HolyHaptics.chipSelect();
                toast(context,
                    saved ? 'Removed from Saved.' : 'Kept in Saved for another day.');
              }),
          const SizedBox(width: 8),
          IconControl(
              icon: CupertinoIcons.square_arrow_up,
              label: 'Share this verse',
              onPhoto: true,
              onPressed: () => shareVerseCard(context, lesson)),
        ]));

    final title = Padding(
        padding: EdgeInsets.fromLTRB(HolySpace.gutter, compact ? 14 : 22,
            HolySpace.gutter, compact ? 12 : 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Eyebrow('Day ${widget.day} · ${lesson.theme}',
              color: const Color(0xFFF6DDB0)),
          const SizedBox(height: 4),
          Text(lesson.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: HolyTypography.title.copyWith(
                  color: HolyTheme.photoInk,
                  fontSize: compact ? 28 : 32,
                  shadows: const [
                    Shadow(color: Color(0x80000000), blurRadius: 16)
                  ])),
        ]));

    Widget cardBody(int index) {
      final reading = index == 0
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              WordReveal(
                  text: '“${lesson.verse}”',
                  style: HolyTypography.verse.copyWith(
                      color: t.ink,
                      fontSize: (lesson.verse.length > 260 ? 25 : 29) * scale,
                      height: 1.26)),
              const SizedBox(height: 16),
              Row(children: [
                Flourish(color: t.gold, width: 28),
                const SizedBox(width: 10),
                Flexible(
                    child: Text('${lesson.reference} · WEB',
                        style:
                            HolyTypography.label.copyWith(color: t.accent))),
              ]),
              if (widget.continuation) ...[
                const SizedBox(height: 12),
                Text('The whole verse, right where you left it.',
                    style: HolyTypography.caption.copyWith(color: t.muted)),
              ],
            ])
          : Text(text[index],
              style: (index == 3
                      ? HolyTypography.readingItalic
                      : HolyTypography.reading)
                  .copyWith(
                      color: t.ink,
                      fontSize: (compact ? 19 : 20.5) * scale,
                      height: 1.58));
      return Paper(
          padding: EdgeInsets.fromLTRB(24, compact ? 20 : 26, 24, 18),
          lift: 1.6,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Text('${index + 1}',
                  style: HolyTypography.numeral
                      .copyWith(color: t.gold, fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(child: Eyebrow(titles[index])),
              Text('${index + 1} of 4',
                  style: HolyTypography.caption.copyWith(color: t.muted)),
            ]),
            SizedBox(height: compact ? 14 : 20),
            Expanded(
                child: NotificationListener<ScrollEndNotification>(
                    onNotification: (_) {
                      if (index == card) _savePosition(index);
                      return false;
                    },
                    child: LayoutBuilder(
                        builder: (context, box) => SingleChildScrollView(
                            controller: scrolls[index],
                            child: ConstrainedBox(
                                constraints:
                                    BoxConstraints(minHeight: box.maxHeight),
                                child: Align(
                                    alignment: index == 0
                                        ? Alignment.centerLeft
                                        : Alignment.topLeft,
                                    child: reading)))))),
            if (index == 3 && lesson.holdOn.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Hairline(),
              const SizedBox(height: 10),
              Text('Carry this today: ${lesson.holdOn}',
                  style: HolyTypography.caption
                      .copyWith(color: t.muted, fontStyle: FontStyle.italic)),
            ],
          ]));
    }

    return Scaffold(
        backgroundColor: HolyTheme.photoShade,
        body: Focus(
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  move(1);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  move(-1);
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: Stack(fit: StackFit.expand, children: [
              Hero(
                  tag: 'art-${widget.day}',
                  child: PhotoStage(
                      images: [HolyArtCatalog.assetForDay(widget.day)],
                      alignment: const Alignment(0, -.35),
                      topVeil: .55,
                      bottomVeil: .65)),
              Column(children: [
                header,
                title,
                Expanded(
                    child: LayoutBuilder(builder: (context, bounds) {
                  final width = math.min(bounds.maxWidth - 32, 620.0);
                  return LessonDeck(
                      controller: deck,
                      itemCount: 4,
                      index: card,
                      cardSize: Size(width, bounds.maxHeight - 8),
                      canMove: (from, to) => to >= 0 && to < 4,
                      locked: finishing,
                      onIndexChanged: (value) {
                        setState(() => card = value);
                        _savePosition(value);
                        HolySounds.lessonLand();
                      },
                      onCommit: (direction, intensity) => HolySounds.lessonSwipe(
                          forward: direction < 0, intensity: intensity),
                      itemBuilder: (context, index, lift) => GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapUp: (details) {
                            if (index != card) return;
                            final x = details.localPosition.dx / width;
                            if (x > .66) move(1);
                            if (x < .33) move(-1);
                          },
                          child: SizedBox.expand(child: cardBody(index))));
                })),
                Padding(
                    padding: EdgeInsets.fromLTRB(HolySpace.gutter, 14,
                        HolySpace.gutter, media.padding.bottom + 12),
                    child: SizedBox(
                        height: 60,
                        child: AnimatedSwitcher(
                            duration: Duration(milliseconds: reduced ? 0 : 280),
                            child: card == 3
                                ? HoldButton(
                                    key: amenKey,
                                    label: finishing
                                        ? 'Amen'
                                        : 'Hold to say Amen',
                                    enabled: !finishing,
                                    hapticOnComplete: false,
                                    onProgress: (v) => holdGlow.value = v,
                                    onComplete: amen)
                                : _CardHint(card: card, onNext: () => move(1))))),
              ]),
              // Light gathering while she holds, then the bloom.
              IgnorePointer(
                  child: AnimatedBuilder(
                      animation: Listenable.merge([holdGlow, bloom]),
                      builder: (context, _) {
                        final b = Curves.easeInCubic.transform(bloom.value);
                        final g = holdGlow.value * .35;
                        if (b == 0 && g == 0) return const SizedBox.shrink();
                        final size = media.size;
                        final center = bloomCenter == Offset.zero
                            ? Offset(size.width / 2, size.height - 80)
                            : bloomCenter;
                        return CustomPaint(
                            size: size,
                            painter: AmenBloomPainter(
                                center: center,
                                progress: math.max(b, g * .4),
                                gold: t.gold));
                      })),
            ])));
  }
}

class _CardHint extends StatelessWidget {
  final int card;
  final VoidCallback onNext;
  const _CardHint({required this.card, required this.onNext});
  @override
  Widget build(BuildContext context) => Center(
      child: Pressable(
          onPressed: onNext,
          semanticLabel: 'Next card',
          child: Tooltip(
              message: 'Next card',
              excludeFromSemantics: true,
              child: FrostedGlass(
                  onPhoto: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                        child: Text(
                            card == 0 ? 'Swipe or tap to continue' : 'Continue',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HolyTypography.label
                                .copyWith(color: HolyTheme.photoInk))),
                    const SizedBox(width: 8),
                    const Icon(CupertinoIcons.arrow_right,
                        size: 16, color: HolyTheme.photoInk),
                  ])))));
}

/// Light that blooms from the Amen button until it fills the screen.
class AmenBloomPainter extends CustomPainter {
  final Offset center;
  final double progress;
  final Color gold;
  AmenBloomPainter(
      {required this.center, required this.progress, required this.gold});
  @override
  void paint(Canvas canvas, Size size) {
    final reach = size.longestSide * 1.4 * progress + 40;
    final rect = Rect.fromCircle(center: center, radius: reach);
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFFBF2).withValues(alpha: math.min(1, progress * 1.6)),
            Color.lerp(const Color(0xFFFFF0D6), gold, .25)!
                .withValues(alpha: math.min(1, progress * 1.3)),
            const Color(0xFFFFE6C4).withValues(alpha: 0),
          ], stops: const [0, .55, 1])
              .createShader(rect));
    if (progress > .7) {
      canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..color = const Color(0xFFFFFBF2)
                .withValues(alpha: ((progress - .7) / .3).clamp(0, 1)));
    }
  }

  @override
  bool shouldRepaint(AmenBloomPainter old) =>
      old.progress != progress || old.center != center;
}
