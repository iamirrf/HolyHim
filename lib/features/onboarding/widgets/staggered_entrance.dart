// Ported from Cognein; see store/v2-design-ports.json.
import 'package:flutter/material.dart';

/// Brings a list of children in one after another.
///
/// Each child takes its own slice of a single controller, so a list of six
/// answers costs one animation, not six. Children rise a short way and fade
/// in, [stagger] apart, which reads as the answers settling onto the page.
class StaggeredEntrance extends StatefulWidget {
  final List<Widget> children;

  /// How far each child rises as it arrives.
  final double rise;

  /// How long one child takes to arrive.
  final Duration item;

  /// The gap between one child starting and the next.
  final Duration stagger;

  /// Held back before the first child starts, so a page that is still
  /// sliding in does not spend its entrance offscreen.
  final Duration delay;

  /// Lays the animated children out. Receives them in order.
  final Widget Function(List<Widget> children) builder;
  const StaggeredEntrance(
      {super.key,
      required this.children,
      required this.builder,
      this.rise = 16,
      this.item = const Duration(milliseconds: 460),
      this.stagger = const Duration(milliseconds: 40),
      this.delay = const Duration(milliseconds: 120)});

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  int get _total =>
      widget.delay.inMilliseconds +
      widget.item.inMilliseconds +
      widget.stagger.inMilliseconds * (widget.children.length - 1).clamp(0, 99);

  @override
  void initState() {
    super.initState();
    // Started here, so the first frame already has the entrance running.
    _controller = AnimationController(
        vsync: this, duration: Duration(milliseconds: _total))
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.builder(widget.children);
    }
    final total = _total.toDouble();
    return widget.builder([
      for (var i = 0; i < widget.children.length; i++)
        _Arrival(
            animation: CurvedAnimation(
                parent: _controller,
                curve: Interval(
                    ((widget.delay.inMilliseconds +
                                widget.stagger.inMilliseconds * i) /
                            total)
                        .clamp(0.0, 1.0),
                    ((widget.delay.inMilliseconds +
                                widget.stagger.inMilliseconds * i +
                                widget.item.inMilliseconds) /
                            total)
                        .clamp(0.0, 1.0),
                    curve: Curves.easeOutCubic)),
            rise: widget.rise,
            child: widget.children[i]),
    ]);
  }
}

class _Arrival extends StatelessWidget {
  final Animation<double> animation;
  final double rise;
  final Widget child;
  const _Arrival(
      {required this.animation, required this.rise, required this.child});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Opacity(
          opacity: animation.value,
          child: Transform.translate(
              offset: Offset(0, rise * (1 - animation.value)), child: child)));
}
