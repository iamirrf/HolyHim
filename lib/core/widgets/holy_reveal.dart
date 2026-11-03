import 'dart:async';
import 'package:flutter/material.dart';

/// A one-time entrance. Provider emissions update the child without replaying
/// its arrival; hidden routes and backgrounded applications pause the motion.
class HolyReveal extends StatefulWidget {
  final Widget child;
  final Duration duration, delay;
  final double distance;
  const HolyReveal(
      {super.key,
      required this.child,
      this.duration = const Duration(milliseconds: 420),
      this.delay = Duration.zero,
      this.distance = 12});
  @override
  State<HolyReveal> createState() => _HolyRevealState();
}

class _HolyRevealState extends State<HolyReveal>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  Timer? _delay;
  bool _started = false, _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reconcile();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _reconcile();
  }

  void _reconcile() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _delay?.cancel();
      _delay = null;
      _started = true;
      _controller.value = 1;
      return;
    }
    if (!_foreground || !TickerMode.valuesOf(context).enabled) {
      _delay?.cancel();
      _delay = null;
      _controller.stop(canceled: false);
      return;
    }
    if (!_started) {
      if (_delay != null) return;
      if (widget.delay == Duration.zero) {
        _started = true;
        _controller.forward();
      } else {
        _delay = Timer(widget.delay, () {
          _delay = null;
          if (mounted) {
            _started = true;
            _controller.forward();
          }
        });
      }
    } else if (!_controller.isCompleted && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Opacity(
            opacity: t,
            child: Transform.translate(
                offset: Offset(0, widget.distance * (1 - t)), child: child));
      });
}
