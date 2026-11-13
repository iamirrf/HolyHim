import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/lessons.g.dart';
import '../../design/art_catalog.dart';
import '../../domain/lesson_position.dart';
import '../../design/design.dart';
import '../../services/auth_service.dart';
import '../../services/repository.dart';
import '../../services/share_card.dart';
import '../common.dart';
import '../celebration/celebration_screen.dart';

class LessonScreen extends ConsumerStatefulWidget {
  final int day;
  final bool continuation;
  const LessonScreen({super.key, required this.day, this.continuation = false});

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen>
    with WidgetsBindingObserver {
  int card = 0;
  final deck = LessonDeckController();
  final scrolls = List.generate(4, (_) => ScrollController());
  bool finishing = false;
  String? _accountId;
  bool _completed = false;
  bool _hasSwipedInSession = false;

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
    if (uid == null || _completed) {
      return;
    }
    final position =
        await LessonPositionStore.read(uid, lessons[widget.day - 1]);
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
        controller.jumpTo(
            controller.position.maxScrollExtent * position.scrollFraction);
      }
    });
  }

  Future<void> _savePosition([int? stage]) async {
    final uid = _accountId;
    if (uid == null || finishing || _completed) {
      return;
    }
    final index = stage ?? card;
    final controller = scrolls[index];
    final max =
        controller.hasClients ? controller.position.maxScrollExtent : 0.0;
    final fraction = max > 0 ? (controller.offset / max).clamp(0.0, 1.0) : 0.0;
    try {
      await LessonPositionStore.write(
          uid,
          LessonPosition(
              widget.day,
              LessonStage.values[index],
              fraction,
              LessonPosition.revision(lessons[widget.day - 1]),
              DateTime.now()));
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
    super.dispose();
  }

  void move(int delta) {
    _hasSwipedInSession = true;
    if (delta > 0) {
      deck.advance();
    } else {
      deck.retreat();
    }
  }

  Future<void> amen() async {
    if (finishing) return;
    setState(() => finishing = true);
    final before = ref.read(repositoryProvider);
    final now = DateTime.now();
    bool completed;
    try {
      completed = await ref
          .read(repositoryProvider.notifier)
          .completeDurably(widget.day, now: now);
    } catch (_) {
      if (mounted) {
        setState(() => finishing = false);
        toast(context, 'Your reading could not be saved. Please try again.');
      }
      return;
    }
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
    final lesson = lessonForDay(widget.day)!;
    final state = ref.watch(repositoryProvider);
    final scale = state.profile.readingScale;
    final theme = HolyThemeScope.of(context);

    // Show swipe tour for first 3 lessons
    final shouldShowSwipeTour =
        (widget.day <= 3 || state.completed.length < 3) &&
            card == 0 &&
            !_hasSwipedInSession;

    final titles = [
      "Today's Word",
      'What it means',
      'For your heart',
      'Prayer'
    ];
    final text = [lesson.verse, lesson.meaning, lesson.heart, lesson.prayer];

    return Scaffold(
      body: Stack(
        children: [
          // Background ambient art
          Positioned.fill(
            child: Hero(
              tag: 'art-${widget.day}',
              child: ArtImage(day: widget.day),
            ),
          ),

          SafeArea(
            child: Focus(
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
              child: Column(
                children: [
                  // Top Bar: Close (X), 4-Segment Progress Indicator, Like/Save, Share
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    child: Row(
                      children: [
                        CircleControl(
                          icon: CupertinoIcons.xmark,
                          onPressed: () {
                            _savePosition();
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/');
                            }
                          },
                          label: 'Close lesson',
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Row(
                            children: List.generate(
                              4,
                              (i) => Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  height: 3.5,
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  decoration: BoxDecoration(
                                    color: i <= card
                                        ? theme.accent
                                        : theme.accent.withValues(alpha: 0.20),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        CircleControl(
                          icon: state.saved.containsKey(widget.day)
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          onPressed: () {
                            ref
                                .read(repositoryProvider.notifier)
                                .toggleSaved(widget.day);
                            toast(
                              context,
                              state.saved.containsKey(widget.day)
                                  ? 'Verse removed from Saved.'
                                  : 'A word kept for another day.',
                            );
                          },
                          label: 'Save verse',
                        ),
                        const SizedBox(width: 8),
                        CircleControl(
                          icon: CupertinoIcons.square_arrow_up,
                          onPressed: () => shareVerseCard(context, lesson),
                          label: 'Share verse',
                        ),
                      ],
                    ),
                  ),

                  Eyebrow('Day ${widget.day} · ${lesson.theme}'),
                  const SizedBox(height: 10),

                  // FULL-HEIGHT LEARNING CARD DECK
                  // White/blur glass fills the full card height on every screen!
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, bounds) {
                        final cardWidth =
                            (bounds.maxWidth - 36).clamp(280.0, 620.0);
                        final cardHeight = bounds.maxHeight - 16;

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            LessonDeck(
                              controller: deck,
                              itemCount: 4,
                              index: card,
                              cardSize: Size(cardWidth, cardHeight),
                              canMove: (from, to) => to >= 0 && to < 4,
                              locked: finishing,
                              onIndexChanged: (value) {
                                setState(() {
                                  card = value;
                                  _hasSwipedInSession = true;
                                });
                                _savePosition(value);
                                HolySounds.lessonLand();
                              },
                              onCommit: (direction, intensity) =>
                                  HolySounds.lessonSwipe(
                                forward: direction < 0,
                                intensity: intensity,
                              ),
                              itemBuilder: (context, index, lift) => EdgeGlow(
                                radius: 28,
                                child: SizedBox.expand(
                                  child: Glass(
                                    radius: 28,
                                    borderWidth: 1.2,
                                    padding: const EdgeInsets.fromLTRB(
                                        26, 28, 26, 24),
                                    elevation: 3,
                                    child: NotificationListener<
                                        ScrollEndNotification>(
                                      onNotification: (notification) {
                                        if (index == card) {
                                          _savePosition(index);
                                        }
                                        return false;
                                      },
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          // Top Card Indicator Row
                                          Row(
                                            children: [
                                              Text(
                                                '0${index + 1}',
                                                style: HolyTypography.eyebrow
                                                    .copyWith(
                                                  color: theme.accent,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  titles[index],
                                                  style: HolyTypography.eyebrow
                                                      .copyWith(
                                                    color: theme.accent,
                                                    letterSpacing: 1.2,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '${index + 1}/4',
                                                style: HolyTypography.eyebrow
                                                    .copyWith(
                                                  color: theme.muted,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 18),

                                          // Artwork thumbnail on Card 2 (What it means)
                                          if (index == 1 &&
                                              HolyArtCatalog.landscapeForDay(
                                                      widget.day) !=
                                                  null) ...[
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              child: Image.asset(
                                                HolyArtCatalog.landscapeForDay(
                                                    widget.day)!,
                                                height: 140,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            const SizedBox(height: 18),
                                          ],

                                          // Scrollable Reading Text (Vertically Centered in Card)
                                          Expanded(
                                            child: Center(
                                              child: SingleChildScrollView(
                                                controller: scrolls[index],
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    if (index == 0) ...[
                                                      WordReveal(
                                                        text: lesson.verse,
                                                        style: HolyTypography
                                                            .verse
                                                            .copyWith(
                                                          fontSize: 26 * scale,
                                                          height: 1.48,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 22),
                                                      Text(
                                                        '${lesson.reference} · WEB',
                                                        style: HolyTypography.ui
                                                            .copyWith(
                                                          color: theme.accent,
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                      if (widget
                                                          .continuation) ...[
                                                        const SizedBox(
                                                            height: 14),
                                                        Text(
                                                          'The whole word, just for this moment.',
                                                          style: muted(context),
                                                        ),
                                                      ],
                                                    ] else ...[
                                                      // Cards 2, 3, 4: Generous 24pt reading typography
                                                      Text(
                                                        text[index],
                                                        style: HolyTypography
                                                            .reading
                                                            .copyWith(
                                                          fontSize: 24 * scale,
                                                          height: 1.55,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Animated Swipe Tour Hint on First 3 Lessons
                            if (shouldShowSwipeTour)
                              Positioned(
                                bottom: 20,
                                child: _SwipeTourHint(
                                  onDismiss: () => setState(
                                      () => _hasSwipedInSession = true),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),

                  // Bottom Controls (Arrows REMOVED per user request)
                  // On final card: "Hold to say Amen" button.
                  // On cards 1-3: Clean dot page indicator.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                    child: card == 3
                        ? HoldButton(
                            key: ValueKey('amen-$finishing'),
                            label: finishing ? 'Saving…' : 'Hold to say Amen',
                            enabled: !finishing,
                            hapticOnComplete: false,
                            onComplete: amen,
                          )
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              Center(
                                child: Semantics(
                                  label: 'Card ${card + 1} of 4',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(
                                      4,
                                      (i) => AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 250),
                                        width: i == card ? 22 : 6,
                                        height: 6,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        decoration: BoxDecoration(
                                          color: i == card
                                              ? theme.accent
                                              : theme.accent
                                                  .withValues(alpha: 0.22),
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                child: Opacity(
                                  opacity: 0.0,
                                  child: IconButton(
                                    icon:
                                        const Icon(CupertinoIcons.chevron_right),
                                    tooltip: 'Next card',
                                    onPressed: () => move(1),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated Swipe Tour Hint that pops up for the first 3 lessons
class _SwipeTourHint extends StatefulWidget {
  final VoidCallback onDismiss;
  const _SwipeTourHint({required this.onDismiss});

  @override
  State<_SwipeTourHint> createState() => _SwipeTourHintState();
}

class _SwipeTourHintState extends State<_SwipeTourHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _nudge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context)) {
      _nudge.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = HolyThemeScope.of(context);

    return AnimatedBuilder(
      animation: _nudge,
      builder: (context, child) => Transform.translate(
        offset: Offset(-8 * _nudge.value, 0),
        child: child,
      ),
      child: GestureDetector(
        onTap: widget.onDismiss,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colors.first.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: theme.accent.withValues(alpha: 0.65),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: theme.accent.withValues(alpha: 0.35),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.accent.withValues(alpha: 0.22),
                  border: Border.all(
                    color: theme.accent.withValues(alpha: 0.45),
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  CupertinoIcons.hand_draw,
                  color: theme.accent,
                  size: 15,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Swipe left to continue',
                style: HolyTypography.ui.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.ink,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_left,
                color: theme.accent,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
