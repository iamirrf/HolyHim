import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../themes.dart';

class Petals extends StatefulWidget {
  final Widget child;
  const Petals({super.key, required this.child});
  @override
  State<Petals> createState() => _PetalsState();
}

class _PetalsState extends State<Petals> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2800));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = .65;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        IgnorePointer(
            child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                    painter: _PetalPainter(_controller.value,
                        HolyThemeScope.of(context).accent)))),
        widget.child
      ]);
}

class _PetalPainter extends CustomPainter {
  final double phase;
  final Color accent;
  _PetalPainter(this.phase, this.accent);
  @override
  void paint(Canvas c, Size s) {
    final random = math.Random(7), paint = Paint();
    final center = Offset(s.width * .5, s.height * .48);
    for (var i = 0; i < 48; i++) {
      final a = random.nextDouble() * math.pi * 2;
      final speed = .15 + random.nextDouble() * .65;
      final p = center +
          Offset(math.cos(a) * s.width * speed * phase * 2,
              math.sin(a) * s.height * speed * phase + phase * phase * 180);
      final alpha = (1 - phase).clamp(0.0, 1.0);
      paint.color =
          Color.lerp(accent, const Color(0xFFE8C766), random.nextDouble())!
              .withValues(alpha: alpha * .8);
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(a + phase * 5);
      c.drawOval(
          Rect.fromCenter(
              center: Offset.zero,
              width: 4 + random.nextDouble() * 5,
              height: 9 + random.nextDouble() * 7),
          paint);
      c.restore();
    }
    final rayPaint = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFF2E3B3).withValues(alpha: (1 - phase) * .45),
        Colors.transparent
      ]).createShader(Offset.zero & s);
    c.drawRect(Offset.zero & s, rayPaint);
  }

  @override
  bool shouldRepaint(_PetalPainter old) => phase != old.phase;
}
