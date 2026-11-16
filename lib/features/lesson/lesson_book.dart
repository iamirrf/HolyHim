import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../design/design.dart';

/// Wide enough for two pages side by side: iPhone Duo's inner display (in
/// either posture) and any other regular-width canvas. Phones keep the deck.
bool showsLessonAsBook(Size size) => size.width >= 600 && size.height >= 520;

/// The lesson as an open book: two pages a spread, the spine on the fold
/// (where a partly open iPhone Duo has no usable screen), and a leaf that
/// turns in 3D between spreads.
class LessonBook extends StatefulWidget {
  /// 0: Today's Word and What it means. 1: For your heart and Prayer.
  final int spread;

  /// Page content for pages 0 to 3, without the page itself.
  final Widget Function(int page) page;
  final String runningHead, runningTitle;
  final ValueChanged<int> onTurn;
  final bool locked;
  const LessonBook(
      {super.key,
      required this.spread,
      required this.page,
      required this.runningHead,
      required this.runningTitle,
      required this.onTurn,
      this.locked = false});

  @override
  State<LessonBook> createState() => _LessonBookState();
}

class _LessonBookState extends State<LessonBook>
    with SingleTickerProviderStateMixin {
  late final turn = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 820));
  int from = 0, to = 0;

  @override
  void initState() {
    super.initState();
    from = to = widget.spread;
  }

  @override
  void didUpdateWidget(LessonBook old) {
    super.didUpdateWidget(old);
    if (widget.spread != to) {
      from = turn.isAnimating ? to : old.spread;
      to = widget.spread;
      if (MediaQuery.disableAnimationsOf(context)) {
        from = to;
        turn.value = 0;
      } else {
        turn.forward(from: 0).whenComplete(() {
          if (mounted) setState(() => from = to);
        });
      }
    }
  }

  @override
  void dispose() {
    turn.dispose();
    super.dispose();
  }

  void _request(int delta) {
    if (widget.locked || turn.isAnimating) return;
    final next = widget.spread + delta;
    if (next >= 0 && next <= 1) widget.onTurn(next);
  }

  Widget _page(int index) => _BookPage(
      left: index.isEven,
      number: index + 1,
      head: index.isEven ? widget.runningHead : widget.runningTitle,
      child: widget.page(index));

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return LayoutBuilder(builder: (context, box) {
      final half = box.maxWidth / 2;
      return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v < -200) _request(1);
            if (v > 200) _request(-1);
          },
          onTapUp: (details) {
            final x = details.localPosition.dx / box.maxWidth;
            if (x > .8) _request(1);
            if (x < .2) _request(-1);
          },
          child: Stack(clipBehavior: Clip.none, children: [
            // The page block's edges, then its shadow on the light.
            Positioned.fill(child: _PageEdges(color: t.surface)),
            AnimatedBuilder(
                animation: turn,
                builder: (context, _) {
                  final animating = from != to && turn.value < 1;
                  if (!animating) {
                    return Row(children: [
                      SizedBox(width: half, child: _page(to * 2)),
                      SizedBox(width: half, child: _page(to * 2 + 1)),
                    ]);
                  }
                  final forward = to > from;
                  final p = Curves.easeInOutCubic.transform(turn.value);
                  // Underneath: the pages the leaf uncovers.
                  final left = forward ? _page(from * 2) : _page(to * 2);
                  final right =
                      forward ? _page(to * 2 + 1) : _page(from * 2 + 1);
                  final firstHalf = p < .5;
                  // The leaf: its front is the page lifting, its back the page landing.
                  final leaf = forward
                      ? (firstHalf ? _page(from * 2 + 1) : _page(to * 2))
                      : (firstHalf ? _page(from * 2) : _page(to * 2 + 1));
                  final onRight = forward ? firstHalf : !firstHalf;
                  final angle = forward
                      ? (firstHalf ? -math.pi * p : math.pi * (1 - p))
                      : (firstHalf ? math.pi * p : -math.pi * (1 - p));
                  final shade = math.sin(math.pi * p) * .28;
                  return Stack(children: [
                    Row(children: [
                      SizedBox(width: half, child: left),
                      SizedBox(width: half, child: right),
                    ]),
                    // The uncovered page darkens under the lifting leaf.
                    Positioned(
                        left: onRight ? half : 0,
                        width: half,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                            child: ColoredBox(
                                color: Colors.black
                                    .withValues(alpha: shade * .35)))),
                    Positioned(
                        left: onRight ? half : 0,
                        width: half,
                        top: 0,
                        bottom: 0,
                        child: Transform(
                            alignment: onRight
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, .0011)
                              ..rotateY(angle),
                            child: Stack(fit: StackFit.expand, children: [
                              leaf,
                              IgnorePointer(
                                  child: DecoratedBox(
                                      decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                              begin: onRight
                                                  ? Alignment.centerLeft
                                                  : Alignment.centerRight,
                                              end: onRight
                                                  ? Alignment.centerRight
                                                  : Alignment.centerLeft,
                                              colors: [
                                    Colors.black.withValues(alpha: shade),
                                    Colors.black.withValues(alpha: shade * .2),
                                  ])))),
                            ]))),
                  ]);
                }),
          ]));
    });
  }
}

/// One page: paper, a running head, the reading, a folio, and the shadow of
/// the spine on its inner edge.
class _BookPage extends StatelessWidget {
  final bool left;
  final int number;
  final String head;
  final Widget child;
  const _BookPage(
      {required this.left,
      required this.number,
      required this.head,
      required this.child});

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    const outer = 30.0, inner = 40.0; // the gutter keeps words off the fold
    const radius = Radius.circular(HolyRadius.card - 8);
    return DecoratedBox(
        decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.horizontal(
                left: left ? radius : Radius.zero,
                right: left ? Radius.zero : radius),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: t.isDark ? .35 : .18),
                  blurRadius: 30,
                  offset: const Offset(0, 16))
            ]),
        child: Stack(children: [
          // The spine's shadow, deepest at the fold.
          Positioned(
              top: 0,
              bottom: 0,
              left: left ? null : 0,
              right: left ? 0 : null,
              width: 46,
              child: IgnorePointer(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: left
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              end: left
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              colors: [
                    Colors.black.withValues(alpha: t.isDark ? .32 : .13),
                    Colors.black.withValues(alpha: 0),
                  ]))))),
          Padding(
              padding: EdgeInsets.fromLTRB(
                  left ? outer : inner, 22, left ? inner : outer, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(head.toUpperCase(),
                        textAlign: left ? TextAlign.left : TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HolyTypography.eyebrow
                            .copyWith(color: t.muted, letterSpacing: 1.6)),
                    const SizedBox(height: 18),
                    Expanded(child: child),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Flourish(color: t.gold, width: 18),
                      const SizedBox(width: 8),
                      Text('$number',
                          style: HolyTypography.numeral
                              .copyWith(color: t.gold, fontSize: 18)),
                      const SizedBox(width: 8),
                      Transform.flip(
                          flipX: true,
                          child: Flourish(color: t.gold, width: 18)),
                    ]),
                  ])),
        ]));
  }
}

/// A few sheets showing at the book's outer edges, so it reads as a volume.
class _PageEdges extends StatelessWidget {
  final Color color;
  const _PageEdges({required this.color});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _EdgePainter(color));
}

class _EdgePainter extends CustomPainter {
  final Color color;
  _EdgePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = Colors.black.withValues(alpha: .12);
    for (var i = 4; i >= 1; i--) {
      final inset = i * 2.4;
      final r = RRect.fromRectAndRadius(
          Rect.fromLTRB(-inset, inset * .9, size.width + inset,
              size.height + inset * 1.4),
          const Radius.circular(20));
      canvas.drawRRect(
          r, Paint()..color = Color.lerp(color, Colors.black, i * .03)!);
      canvas.drawRRect(r, line);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => old.color != color;
}
