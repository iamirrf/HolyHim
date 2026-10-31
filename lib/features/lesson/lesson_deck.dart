import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/services/profile_service.dart';
import 'package:holyher/core/widgets/holy_motion.dart';

/// Lets the parent trigger the same fly-off-and-advance animation a user swipe
/// produces (used when a video finishes playing on its own).
class LessonDeckController {
  Future<void> Function()? _advance;
  void _attach(Future<void> Function() advance) => _advance = advance;
  void _detach() => _advance = null;
  Future<void> advance() async => _advance?.call();
}

/// A card that swipes off to the side and reveals the next one growing in from
/// behind, and the previous one when swiping back: the interaction the product
/// was asked for by name ("like Tinder").
///
/// The whole area is the gesture surface, so a swipe can start in the margins
/// around the card; the cards themselves are [cardSize], centred.
///
/// Everything a finger causes here is physics, not easing. Letting go hands the
/// finger's velocity to a spring, so a flick carries on at the speed it was
/// flung and a slow drag settles gently. A move the lesson does not allow (an
/// unanswered question, the first or last card) pushes back against the finger
/// and never reveals the card behind it.
class LessonDeck extends ConsumerStatefulWidget {
  final int itemCount;
  final int index;
  final Size cardSize;
  final LessonDeckController controller;
  final bool Function(int from, int to) canMove;
  final ValueChanged<int> onIndexChanged;
  final bool locked;

  /// The card has been let go and is on its way, not when it has arrived: called
  /// the instant a swipe commits, with the [direction] it is going (-1 forward,
  /// 1 back) and how hard it was thrown, 0..1 ([releaseIntensity]). It is what
  /// the whoosh is tied to, so the sound leaves with the card and not after it.
  final void Function(int direction, double intensity)? onCommit;

  /// Builds the card at [index]. [lift] is 0..1 for the card being dragged, and
  /// 0 for every other one.
  final Widget Function(BuildContext context, int index, double lift)
      itemBuilder;

  const LessonDeck({
    super.key,
    required this.itemCount,
    required this.index,
    required this.cardSize,
    required this.controller,
    required this.canMove,
    required this.onIndexChanged,
    required this.locked,
    required this.itemBuilder,
    this.onCommit,
  });

  /// How hard a card was thrown, from the finger's speed at letting go. A slow,
  /// deliberate drag is soft; a flick is full. Never silent, never more than 1.
  static double releaseIntensity(double velocity) =>
      0.4 + 0.6 * (velocity.abs() / 2600).clamp(0.0, 1.0);

  @override
  ConsumerState<LessonDeck> createState() => _LessonDeckState();
}

class _LessonDeckState extends ConsumerState<LessonDeck>
    with SingleTickerProviderStateMixin {
  /// How much of a drag a blocked move follows. It gives, but pushes back.
  static const _resistance = 0.35;

  /// A card leaves once dragged this fraction of the screen, or flung faster
  /// than [_flingVelocity] (logical pixels per second).
  static const _commitFraction = 0.25;
  static const _flingVelocity = 800.0;

  /// With no finger to lend it any, an automatic advance starts moving anyway.
  static const _autoAdvanceVelocity = 1200.0;

  /// How far a drag lifts the card, as a fraction of its width.
  static const _liftFraction = 0.4;

  // Unbounded, and driven by a spring: the value is the card's x offset itself.
  late final AnimationController _anim =
      AnimationController.unbounded(vsync: this);
  double _dragX = 0;
  bool _dragging = false;

  /// The drag has crossed the commit line and ticked. It re-arms once the card
  /// is pulled back a little, so wobbling around the line doesn't buzz.
  bool _pastCommitLine = false;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(_advanceProgrammatically);
    _anim.addListener(() => setState(() => _dragX = _anim.value));
  }

  @override
  void didUpdateWidget(covariant LessonDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._detach();
      widget.controller._attach(_advanceProgrammatically);
    }
  }

  @override
  void dispose() {
    widget.controller._detach();
    _anim.dispose();
    super.dispose();
  }

  void _tick() {
    if (ref.read(profileProvider).haptics) HapticFeedback.selectionClick();
  }

  double get _width => widget.cardSize.width + 48;

  void _onDragStart(DragStartDetails details) {
    if (widget.locked || _anim.isAnimating) return;
    _dragging = true;
    _pastCommitLine = false;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    final dx = details.delta.dx;
    final next = _dragX + dx;
    if (next == 0) {
      setState(() => _dragX = 0);
      return;
    }
    final to = widget.index + (next < 0 ? 1 : -1);
    final blocked = !widget.canMove(widget.index, to);
    setState(() => _dragX += blocked ? dx * _resistance : dx);
    if (blocked) return;
    // A detent under the finger the moment letting go would turn the page.
    final commitLine = _width * _commitFraction;
    if (!_pastCommitLine && _dragX.abs() >= commitLine) {
      _pastCommitLine = true;
      _tick();
    } else if (_pastCommitLine && _dragX.abs() < commitLine * 0.85) {
      _pastCommitLine = false;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    final alreadyTicked = _pastCommitLine;
    _pastCommitLine = false;
    final threshold = _width * _commitFraction;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final wantsForward = _dragX < -threshold || velocity < -_flingVelocity;
    final wantsBackward =
        !wantsForward && (_dragX > threshold || velocity > _flingVelocity);
    if (wantsForward && widget.canMove(widget.index, widget.index + 1)) {
      // One tick per swipe: a flick that never reached the line ticks now.
      if (!alreadyTicked) _tick();
      widget.onCommit?.call(-1, LessonDeck.releaseIntensity(velocity));
      _settle(-1, velocity);
    } else if (wantsBackward &&
        widget.canMove(widget.index, widget.index - 1)) {
      if (!alreadyTicked) _tick();
      widget.onCommit?.call(1, LessonDeck.releaseIntensity(velocity));
      _settle(1, velocity);
    } else {
      if (wantsForward || wantsBackward) _tick();
      _settle(0, velocity);
    }
  }

  Future<void> _advanceProgrammatically() async {
    if (widget.locked || _dragging || _anim.isAnimating) return;
    if (!widget.canMove(widget.index, widget.index + 1)) return;
    widget.onCommit?.call(-1, 0.55);
    await _settle(-1, -_autoAdvanceVelocity);
  }

  /// Springs the card to a resting place: off-screen in [direction] (-1 forward,
  /// 1 back), or home for 0. [velocity] is the finger's, so the motion carries
  /// on from the drag instead of restarting from rest.
  Future<void> _settle(int direction, double velocity) async {
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _dragX = 0);
      if (direction != 0) {
        widget.onIndexChanged(widget.index + (direction < 0 ? 1 : -1));
      }
      return;
    }
    final leaving = direction != 0;
    _anim.value = _dragX;
    await _anim.animateWith(SpringSimulation(
      leaving ? HolyMotion.flyOff : HolyMotion.snapBack,
      _dragX,
      leaving ? direction * _width * 1.25 : 0,
      velocity,
      tolerance: HolyMotion.pixelTolerance,
    ));
    if (!mounted) return;
    setState(() => _dragX = 0);
    if (leaving) {
      widget.onIndexChanged(widget.index + (direction < 0 ? 1 : -1));
    }
  }

  @override
  Widget build(BuildContext context) {
    // A card behind the deck only shows through a drag in a direction that is
    // allowed, so a blocked move never hints that it could have worked.
    final canForward = widget.canMove(widget.index, widget.index + 1);
    final canBackward = widget.canMove(widget.index, widget.index - 1);
    final forwardProgress = _dragX < 0 && canForward
        ? (-_dragX / (_width * 0.6)).clamp(0.0, 1.0)
        : 0.0;
    final backwardProgress = _dragX > 0 && canBackward
        ? (_dragX / (_width * 0.6)).clamp(0.0, 1.0)
        : 0.0;
    final rotation = (_dragX / _width) * 0.15;
    final lift = (_dragX.abs() / (widget.cardSize.width * _liftFraction))
        .clamp(0.0, 1.0);
    // Every rendered card uses the exact same wrapper shape, keyed by its own
    // index, whether it's the current (draggable) card or a peek behind it: only
    // the transform/opacity parameters differ by role. Branching to a *different*
    // wrapper type per role (as an earlier version did) made Flutter tear down
    // and recreate the card, including its video player, every time it crossed
    // between "current" and "peek", losing the pause-on-leave behaviour that
    // relies on the same element updating.
    //
    // The peeks are invisible until a drag starts revealing them, but they are
    // built: their images start loading and their state is ready by the time
    // they arrive.
    final layers = <Widget>[
      if (widget.index - 1 >= 0)
        _layer(widget.index - 1,
            dx: 0,
            rotation: 0,
            scale: 0.92 + 0.08 * backwardProgress,
            opacity: backwardProgress,
            lift: 0,
            ignorePointer: true),
      if (widget.index + 1 < widget.itemCount)
        _layer(widget.index + 1,
            dx: 0,
            rotation: 0,
            scale: 0.92 + 0.08 * forwardProgress,
            opacity: forwardProgress,
            lift: 0,
            ignorePointer: true),
      _layer(widget.index,
          dx: _dragX,
          rotation: rotation,
          scale: 1,
          opacity: 1,
          lift: lift,
          ignorePointer: false),
    ];
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(fit: StackFit.expand, children: layers),
    );
  }

  Widget _layer(
    int index, {
    required double dx,
    required double rotation,
    required double scale,
    required double opacity,
    required double lift,
    required bool ignorePointer,
  }) {
    return ExcludeSemantics(
        excluding: ignorePointer,
        child: IgnorePointer(
          key: ValueKey('lesson-layer-$index'),
          ignoring: ignorePointer,
          child: Center(
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.rotate(
                  angle: rotation,
                  alignment: Alignment.bottomCenter,
                  child: Transform.scale(
                    scale: scale,
                    child: SizedBox.fromSize(
                      size: widget.cardSize,
                      child: widget.itemBuilder(context, index, lift),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ));
  }
}
