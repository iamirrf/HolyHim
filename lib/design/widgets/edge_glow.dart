// Ported from Cognein; see store/v2-design-ports.json.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A slow, rotating sapphire glow hugging the inside of a rounded edge.
///
/// This is the AI Coach screen's glow, made reusable: the same sweep colours,
/// the same three layers (a wide bloom, a tighter body and a glossy 1px
/// highlight) and the same 8 second turn. Two things differ, both because a card
/// is not a display:
///
/// * [scale] shrinks the bloom so it stays graceful on something a few hundred
///   points wide, where the coach's full-screen bloom would swallow the content.
/// * [energy] is handed in by the caller instead of being animated here, so a
///   drag can drive it one-to-one with the finger. (The coach eases its own
///   intensity with `easeInOut`, which is right for a request the app starts and
///   wrong for a gesture a finger owns.)
///
/// Place it in a `Positioned.fill` above the content and inside the clip that
/// rounds the card: it paints strokes centred just inside [corners], so the
/// outer half of each stroke is cut away by the clip and the rest reads as light
/// bleeding in from the edge. It never takes pointer events and is invisible to
/// semantics.
///
/// The turn stops when [animate] is false, when the route is covered
/// (`TickerMode`), and when the platform asks for reduced motion. A stopped glow
/// still paints a single representative frame.
class RoseEdgeGlow extends StatefulWidget {
  /// The contour the glow follows; match the clip it sits inside.
  final BorderRadius corners;

  /// 0..1. 0 is the resting glow; 1 is the brightest, widest state.
  final double energy;

  /// Multiplies every stroke width and blur radius.
  final double scale;

  /// Multiplies the glow's opacity. Below 1 for surfaces that should glow
  /// quietly.
  final double intensity;

  /// Distance in from the edge to the centre line of the strokes.
  final double inset;

  /// Whether the sweep turns. False for a card that is behind the deck.
  final bool animate;

  /// Six sweep colours (start, two lights, a dark, a mid, and the start again)
  /// to glow in a hue other than sapphire. Null keeps the sapphire palette.
  final List<Color>? colors;

  const RoseEdgeGlow({
    super.key,
    required this.corners,
    this.energy = 0,
    this.scale = 1,
    this.intensity = 1,
    this.inset = 3,
    this.animate = true,
    this.colors,
  }) : assert(colors == null || colors.length == 6);

  @override
  State<RoseEdgeGlow> createState() => _RoseEdgeGlowState();
}

class _RoseEdgeGlowState extends State<RoseEdgeGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase =
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
  void didUpdateWidget(RoseEdgeGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) _sync();
  }

  void _sync() {
    if (_turning) {
      if (!_phase.isAnimating) _phase.repeat();
    } else {
      _phase.stop();
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _RoseEdgePainter(
                phase: _phase,
                energy: widget.energy.clamp(0.0, 1.0),
                dark: Theme.of(context).brightness == Brightness.dark,
                corners: widget.corners,
                scale: widget.scale,
                intensity: widget.intensity,
                inset: widget.inset,
                colors: widget.colors,
              ),
            ),
          ),
        ),
      );
}

const _sapphire = [
  Color(0xFFD4AF37),
  Color(0xFFF2E3B3),
  Color(0xFFFFF1DA),
  Color(0xFF8C6D1F),
  Color(0xFFE3C98A),
  Color(0xFFD4AF37),
];

class _RoseEdgePainter extends CustomPainter {
  final Animation<double> phase;
  final double energy;
  final bool dark;
  final BorderRadius corners;
  final double scale;
  final double intensity;
  final double inset;
  final List<Color>? colors;

  _RoseEdgePainter({
    required this.phase,
    required this.energy,
    required this.dark,
    required this.corners,
    required this.scale,
    required this.intensity,
    required this.inset,
    this.colors,
  }) : super(repaint: phase);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;
    final outline = corners.toRRect(bounds).deflate(inset);
    final breath = 0.95 + 0.05 * math.sin(phase.value * math.pi * 4);
    final strength = ((dark ? 0.62 : 0.42) + energy * (dark ? 0.28 : 0.34)) *
        breath *
        intensity;
    final shader = SweepGradient(
      transform: GradientRotation(phase.value * math.pi * 2),
      colors: [
        for (final (i, color) in (colors ?? _sapphire).indexed)
          color.withValues(alpha: strength * const [1, 1, 0.85, 0.32, 1, 1][i]),
      ],
      stops: const [0, 0.22, 0.32, 0.48, 0.76, 1],
    ).createShader(bounds);
    // A wide bloom that widens as the energy rises.
    canvas.drawRRect(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (26 + energy * 22) * scale
        ..shader = shader
        ..maskFilter =
            ui.MaskFilter.blur(ui.BlurStyle.normal, (15 + energy * 13) * scale),
    );
    canvas.drawRRect(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (5 + energy * 4) * scale
        ..shader = shader
        ..maskFilter =
            ui.MaskFilter.blur(ui.BlurStyle.normal, (3 + energy * 2) * scale),
    );
    // A narrow travelling highlight gives the edge its glossy sapphire finish.
    canvas.drawRRect(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1.2 + energy * 0.8) * math.max(scale, 0.75)
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_RoseEdgePainter oldDelegate) =>
      dark != oldDelegate.dark ||
      corners != oldDelegate.corners ||
      energy != oldDelegate.energy ||
      scale != oldDelegate.scale ||
      intensity != oldDelegate.intensity ||
      inset != oldDelegate.inset ||
      colors != oldDelegate.colors ||
      phase != oldDelegate.phase;
}
