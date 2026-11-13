import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../themes.dart';
import '../art_catalog.dart';
import 'bundled_art.dart';

/// Art always has a painted themed fallback; a missing download stays graceful.
class ArtImage extends StatefulWidget {
  final int day;
  final Widget? child;
  final double parallax;
  final bool animate;
  final String? asset;
  const ArtImage(
      {super.key,
      this.day = 1,
      this.child,
      this.parallax = 0,
      this.animate = true,
      this.asset});
  @override
  State<ArtImage> createState() => _ArtImageState();
}

class _ArtImageState extends State<ArtImage>
    with SingleTickerProviderStateMixin {
  late final _kenBurns =
      AnimationController(vsync: this, duration: const Duration(seconds: 20));
  StreamSubscription<AccelerometerEvent>? _sensor;
  Offset _tilt = Offset.zero;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ArtImage old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate) _sync();
  }

  void _sync() {
    final motion = widget.animate && !MediaQuery.disableAnimationsOf(context);
    if (motion) {
      if (!_kenBurns.isAnimating) _kenBurns.repeat(reverse: true);
      if (!kIsWeb && _sensor == null) {
        _sensor =
            accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
                .listen((e) {
          if (mounted) {
            setState(() => _tilt =
                Offset((e.x / 9.8).clamp(-.5, .5), (e.y / 9.8).clamp(-.5, .5)));
          }
        }, onError: (Object _) {});
      }
    } else {
      _kenBurns.stop();
      _sensor?.cancel();
      _sensor = null;
      _tilt = Offset.zero;
    }
  }

  @override
  void dispose() {
    _sensor?.cancel();
    _kenBurns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = HolyThemeScope.of(context);
    Widget fallback() => CustomPaint(
        painter: _FloralPainter(theme, widget.day),
        child: const SizedBox.expand());
    final asset = widget.asset ?? HolyArtCatalog.assetForDay(widget.day);
    final art = BundledArt(asset: asset, fallback: fallback());
    return ClipRect(
        child: Stack(fit: StackFit.expand, children: [
      AnimatedBuilder(
          animation: _kenBurns,
          child: art,
          builder: (context, child) => Transform.translate(
              offset:
                  Offset(_tilt.dx * 8, widget.parallax * .16 + _tilt.dy * 8),
              child: Transform.scale(
                  scale: 1.04 + _kenBurns.value * .035, child: child))),
      if (widget.child != null) widget.child!
    ]));
  }
}

class _FloralPainter extends CustomPainter {
  final HolyTheme theme;
  final int day;
  _FloralPainter(this.theme, this.day);
  @override
  void paint(Canvas c, Size s) {
    final bounds = Offset.zero & s;
    c.drawRect(
        bounds,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colors.first,
                theme.colors[1],
                theme.colors[3]
              ]).createShader(bounds));
    final r = math.Random(day), paint = Paint();
    for (var i = 0; i < 7; i++) {
      final origin = Offset(s.width * (.2 + r.nextDouble() * .85),
          s.height * (.66 + r.nextDouble() * .4));
      final stem = Path()
        ..moveTo(origin.dx, origin.dy + s.height * .3)
        ..quadraticBezierTo(origin.dx - s.width * .14,
            origin.dy + s.height * .1, origin.dx, origin.dy);
      paint
        ..shader = null
        ..color = Color.lerp(theme.accent, const Color(0xFFA67C37), .55)!
            .withValues(alpha: .16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      c.drawPath(stem, paint);
      paint.style = PaintingStyle.fill;
      final size = s.width * (.05 + r.nextDouble() * .08);
      for (var j = 0; j < 6; j++) {
        c.save();
        c.translate(origin.dx, origin.dy);
        c.rotate(j * math.pi / 3 + r.nextDouble() * .3);
        final rect = Rect.fromCenter(
            center: Offset(0, -size * .55),
            width: size * .75,
            height: size * 1.4);
        paint.shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: .9),
          theme.colors[2].withValues(alpha: .45)
        ]).createShader(rect);
        c.drawOval(rect, paint);
        c.restore();
      }
      paint
        ..shader = null
        ..color = theme.accent.withValues(alpha: .2);
      c.drawCircle(origin, size * .13, paint);
    }
    paint
      .shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colors.first.withValues(alpha: .4),
            Colors.transparent
          ]).createShader(bounds);
    c.drawRect(bounds, paint);
  }

  @override
  bool shouldRepaint(_FloralPainter old) =>
      old.theme != theme || old.day != day;
}
