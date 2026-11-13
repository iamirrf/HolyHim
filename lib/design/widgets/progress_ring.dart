import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../themes.dart';

class ProgressRing extends StatelessWidget {
  final double progress, size, strokeWidth;
  final Widget? child;
  const ProgressRing(
      {super.key,
      required this.progress,
      this.size = 72,
      this.strokeWidth = 5,
      this.child});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Semantics(
        label: '${(progress.clamp(0, 1) * 100).round()} percent complete',
        child: SizedBox.square(
            dimension: size,
            child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.clamp(0, 1)),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 700),
                builder: (context, p, _) => CustomPaint(
                    painter: _RingPainter(p, strokeWidth, t.accentGradient,
                        t.accent.withValues(alpha: .10)),
                    child: Center(child: child)))));
  }
}

class _RingPainter extends CustomPainter {
  final double progress, stroke;
  final List<Color> colors;
  final Color track;
  _RingPainter(this.progress, this.stroke, this.colors, this.track);
  @override
  void paint(Canvas c, Size s) {
    final b = (Offset.zero & s).deflate(stroke / 2 + 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    c.drawOval(b, p..color = track);
    if (progress > 0) {
      c.drawArc(b, -math.pi / 2, math.pi * 2 * progress, false,
          p..shader = LinearGradient(colors: colors).createShader(b));
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.colors != colors;
}
