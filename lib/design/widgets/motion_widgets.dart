import 'dart:async';
import 'package:flutter/material.dart';
import '../motion.dart';

/// Content that rises into place: a short fade and lift, staggered by
/// [index]. Reduce Motion shows it immediately.
class Rise extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final double distance;
  const Rise(
      {super.key,
      required this.child,
      this.index = 0,
      this.delay = Duration.zero,
      this.distance = HolyMotion.rise});
  @override
  State<Rise> createState() => _RiseState();
}

class _RiseState extends State<Rise> with SingleTickerProviderStateMixin {
  late final _in = AnimationController(
      vsync: this, duration: HolyMotion.hero);
  Timer? _start;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _start?.cancel();
      _in.value = 1;
    } else if (_in.value == 0 && _start == null) {
      _start = Timer(widget.delay + HolyMotion.staggered(widget.index),
          () {
        if (mounted) _in.forward();
      });
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _in, curve: HolyMotion.curveIn);
    return AnimatedBuilder(
        animation: curve,
        child: widget.child,
        builder: (context, child) => Opacity(
            opacity: curve.value,
            child: Transform.translate(
                offset: Offset(0, widget.distance * (1 - curve.value)),
                child: child)));
  }
}

/// A band of light that passes across [child] once, like sun catching
/// gilded letters. Used on the wordmark at launch.
class LightSweep extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Color color;
  const LightSweep(
      {super.key,
      required this.child,
      this.delay = const Duration(milliseconds: 500),
      this.color = const Color(0xFFFFF1D6)});
  @override
  State<LightSweep> createState() => _LightSweepState();
}

class _LightSweepState extends State<LightSweep>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));
  Timer? _start;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context) && _start == null) {
      _start = Timer(widget.delay, () {
        if (mounted) _sweep.forward();
      });
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _sweep,
      child: widget.child,
      builder: (context, child) {
        if (_sweep.value == 0 || _sweep.value == 1) return child!;
        final x = Curves.easeInOut.transform(_sweep.value) * 3 - 1.5;
        return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment(x - .6, -.4),
                    end: Alignment(x + .6, .4),
                    colors: [
                      widget.color.withValues(alpha: 0),
                      widget.color.withValues(alpha: .95),
                      widget.color.withValues(alpha: 0),
                    ],
                    stops: const [.35, .5, .65])
                .createShader(bounds),
            child: child);
      });
}

/// Paragraphs that arrive one after another, each rising gently.
class LineReveal extends StatelessWidget {
  final List<Widget> lines;
  final Duration delay;
  final Duration step;
  const LineReveal(
      {super.key,
      required this.lines,
      this.delay = Duration.zero,
      this.step = const Duration(milliseconds: 520)});
  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++)
          Rise(delay: delay + step * i, distance: 10, child: lines[i]),
      ]);
}
