// Ported from Cognein's SapphireEdgeGlow; see store/v2-design-ports.json.
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A slow, turning brass light hugging the inside of a rounded edge.
///
/// Three strokes share one sweep: a wide bloom, a tighter body and a glossy
/// hairline. The sweep turns once every eight seconds. Place it in a
/// `Positioned.fill` above the content and inside the clip that rounds the
/// surface: the strokes sit just inside [corners], so the clip cuts their
/// outer half away and the rest reads as light coming in from the edge.
///
/// It stops turning when [animate] is false, when its route is covered, and
/// under Reduce Motion, and then paints one still frame.
class EdgeGlow extends StatefulWidget {
  final BorderRadius corners;

  /// 0 to 1: the resting glow up to the brightest, widest one.
  final double energy;

  /// Multiplies every stroke width and blur.
  final double scale;

  /// Multiplies the glow's opacity.
  final double intensity;

  /// From the edge to the centre line of the strokes.
  final double inset;
  final bool animate;

  /// Six sweep colours: a start, two lights, a dark, a mid, the start again.
  final List<Color> colors;

  /// Whether the surface under the glow is dark, which takes a stronger
  /// light.
  final bool onDark;

  const EdgeGlow(
      {super.key,
      required this.corners,
      this.energy = 0,
      this.scale = 1,
      this.intensity = 1,
      this.inset = 3,
      this.animate = true,
      this.colors = roseGold,
      this.onDark = true})
      : assert(colors.length == 6);

  /// Brass, bone and candle light round the edge, with one deep bronze.
  /// The shared engine's name is kept so upstream syncs stay clean.
  static const roseGold = [
    Color(0xFFE8C27A),
    Color(0xFFFFE7B0),
    Color(0xFFFFF6E0),
    Color(0xFF8E6427),
    Color(0xFFD8A657),
    Color(0xFFE8C27A),
  ];

  @override
  State<EdgeGlow> createState() => _EdgeGlowState();
}

class _EdgeGlowState extends State<EdgeGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn =
      AnimationController(vsync: this, duration: const Duration(seconds: 8));

  bool get _turning =>
      widget.animate &&
      TickerMode.valuesOf(context).enabled &&
      !MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(EdgeGlow old) {
    super.didUpdateWidget(old);
    if (widget.animate != old.animate) _sync();
  }

  void _sync() {
    if (_turning) {
      if (!_turn.isAnimating) _turn.repeat();
    } else {
      _turn.stop();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: ExcludeSemantics(
          child: RepaintBoundary(
              child: CustomPaint(
                  painter: _EdgePainter(
                      turn: _turn,
                      energy: widget.energy.clamp(0.0, 1.0),
                      onDark: widget.onDark,
                      corners: widget.corners,
                      scale: widget.scale,
                      intensity: widget.intensity,
                      inset: widget.inset,
                      colors: widget.colors)))));
}

class _EdgePainter extends CustomPainter {
  final Animation<double> turn;
  final double energy, scale, intensity, inset;
  final bool onDark;
  final BorderRadius corners;
  final List<Color> colors;
  _EdgePainter(
      {required this.turn,
      required this.energy,
      required this.onDark,
      required this.corners,
      required this.scale,
      required this.intensity,
      required this.inset,
      required this.colors})
      : super(repaint: turn);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;
    final outline = corners.toRRect(bounds).deflate(inset);
    final breath = .95 + .05 * math.sin(turn.value * math.pi * 4);
    final strength = ((onDark ? .62 : .42) + energy * (onDark ? .28 : .34)) *
        breath *
        intensity;
    const weights = [1.0, 1.0, .85, .32, 1.0, 1.0];
    final shader = SweepGradient(
        transform: GradientRotation(turn.value * math.pi * 2),
        colors: [
          for (var i = 0; i < 6; i++)
            colors[i].withValues(alpha: (strength * weights[i]).clamp(0, 1)),
        ],
        stops: const [
          0,
          .22,
          .32,
          .48,
          .76,
          1
        ]).createShader(bounds);
    canvas.drawRRect(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (26 + energy * 22) * scale
          ..shader = shader
          ..maskFilter = ui.MaskFilter.blur(
              ui.BlurStyle.normal, (15 + energy * 13) * scale));
    canvas.drawRRect(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (5 + energy * 4) * scale
          ..shader = shader
          ..maskFilter = ui.MaskFilter.blur(
              ui.BlurStyle.normal, (3 + energy * 2) * scale));
    canvas.drawRRect(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (1.2 + energy * .8) * math.max(scale, .75)
          ..shader = shader);
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      onDark != old.onDark ||
      corners != old.corners ||
      energy != old.energy ||
      scale != old.scale ||
      intensity != old.intensity ||
      inset != old.inset ||
      colors != old.colors ||
      turn != old.turn;
}
