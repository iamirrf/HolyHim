import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../themes.dart';
import '../typography.dart';
import 'backdrop.dart';

/// A thin arc that chases its tail: the only activity indicator in the app.
class HolySpinner extends StatefulWidget {
  final Color? color;
  final double size;
  final double stroke;
  const HolySpinner({super.key, this.color, this.size = 22, this.stroke = 2});
  @override
  State<HolySpinner> createState() => _HolySpinnerState();
}

class _HolySpinnerState extends State<HolySpinner>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();
  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? HolyThemeScope.of(context).accent;
    return Semantics(
        label: 'Loading',
        child: SizedBox.square(
            dimension: widget.size,
            child: AnimatedBuilder(
                animation: _spin,
                builder: (context, _) => CustomPaint(
                    painter: _ArcPainter(
                        _spin.value, color, widget.stroke)))));
  }
}

class _ArcPainter extends CustomPainter {
  final double t;
  final Color color;
  final double stroke;
  _ArcPainter(this.t, this.color, this.stroke);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final track = Paint()
      ..color = color.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect.deflate(stroke), 0, math.pi * 2, false, track);
    // Sweep breathes between a short and a long arc while rotating.
    final sweep = math.pi * (.35 + .9 * (.5 - .5 * math.cos(t * math.pi * 2)));
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(
        rect.deflate(stroke), t * math.pi * 2 - math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.t != t || old.color != color;
}

/// Full-screen branded loading: the wordmark on paper with a slow breath.
class BrandLoader extends StatefulWidget {
  final String? message;
  const BrandLoader({super.key, this.message});
  @override
  State<BrandLoader> createState() => _BrandLoaderState();
}

class _BrandLoaderState extends State<BrandLoader>
    with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath.value = 1;
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return ColoredBox(
        color: backdropPaper(context, t),
        child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          FadeTransition(
              opacity: Tween(begin: .55, end: 1.0).animate(CurvedAnimation(
                  parent: _breath, curve: Curves.easeInOut)),
              child: Wordmark(size: 40, color: t.ink)),
          const SizedBox(height: 22),
          HolySpinner(color: t.accent, size: 18, stroke: 1.6),
          if (widget.message != null) ...[
            const SizedBox(height: 16),
            Text(widget.message!,
                textAlign: TextAlign.center,
                style: HolyTypography.caption.copyWith(color: t.muted)),
          ]
        ])));
  }
}
