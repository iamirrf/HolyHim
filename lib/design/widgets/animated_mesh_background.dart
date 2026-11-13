// Ported from Cognein; see store/v2-design-ports.json.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// Colour set for one [AnimatedMeshBackground] mood.
///
/// Mirrors a CSS blob/mesh `:root` block: five colours for the sweeping base
/// gradient plus four blob gradients layered over it. Every field participates
/// in [lerp], which is what lets a caller morph continuously between two moods
/// while a page scrolls.
@immutable
class MeshTheme {
  /// Five colours for the sweeping base gradient, at stops 0/.25/.5/.75/1.
  ///
  /// Must contain exactly five entries — the stop list is fixed. This cannot
  /// be a constructor assert because list length is not const-evaluable, so
  /// it is checked in [lerp] instead.
  ///
  /// `baseColors[2]` is load-bearing: it doubles as the accent for anything
  /// drawn over the background (progress dots, particles), so it must stay
  /// bright enough to read against the surrounding dark tones.
  final List<Color> baseColors;

  /// Blob 1 — linear, top-left drift.
  final Color b1Start;
  final Color b1End;

  /// Blob 2 — linear, the largest blob; keeps the field dark.
  final Color b2Start;
  final Color b2End;

  /// Blob 3 — linear, bottom-left drift.
  final Color b3Start;
  final Color b3End;

  /// Blob 4 — radial, the drifting glow orb.
  final Color b4Start;
  final Color b4Mid;
  final Color b4End;

  const MeshTheme({
    required this.baseColors,
    required this.b1Start,
    required this.b1End,
    required this.b2Start,
    required this.b2End,
    required this.b3Start,
    required this.b3End,
    required this.b4Start,
    required this.b4Mid,
    required this.b4End,
  });

  /// The accent colour derived from this theme, for content drawn on top.
  Color get accent => baseColors[2];

  /// Interpolates every field, for smooth transitions between moods.
  static MeshTheme lerp(MeshTheme a, MeshTheme b, double t) {
    assert(a.baseColors.length == 5 && b.baseColors.length == 5,
        'MeshTheme needs exactly 5 base colors');
    if (t <= 0) return a;
    if (t >= 1) return b;
    return MeshTheme(
      baseColors: List<Color>.generate(
        5,
        (i) => Color.lerp(a.baseColors[i], b.baseColors[i], t)!,
      ),
      b1Start: Color.lerp(a.b1Start, b.b1Start, t)!,
      b1End: Color.lerp(a.b1End, b.b1End, t)!,
      b2Start: Color.lerp(a.b2Start, b.b2Start, t)!,
      b2End: Color.lerp(a.b2End, b.b2End, t)!,
      b3Start: Color.lerp(a.b3Start, b.b3Start, t)!,
      b3End: Color.lerp(a.b3End, b.b3End, t)!,
      b4Start: Color.lerp(a.b4Start, b.b4Start, t)!,
      b4Mid: Color.lerp(a.b4Mid, b.b4Mid, t)!,
      b4End: Color.lerp(a.b4End, b.b4End, t)!,
    );
  }
}

/// Slow, ambient blob-mesh background.
///
/// A five-colour linear gradient whose axis rotates, with four blurred circles
/// drifting over it on sine/cosine paths at different frequencies. The whole
/// stack sits behind a **single** blur pass, which is what keeps it cheap: one
/// full-screen filter for five layers rather than one per layer.
///
/// The painted content is oversized by 20% and offset by -10% on both axes so
/// the circles' hard edges never enter the visible frame.
///
/// Honours the platform "reduce motion" setting by rendering a static frame.
class AnimatedMeshBackground extends StatefulWidget {
  final MeshTheme theme;

  /// Drawn on top of the mesh, filling the same box.
  final Widget? child;

  /// Duration of one full ambient cycle. The controller reverses, so a visible
  /// loop is twice this.
  final Duration duration;

  const AnimatedMeshBackground({
    super.key,
    required this.theme,
    this.child,
    this.duration = const Duration(seconds: 20),
  });

  @override
  State<AnimatedMeshBackground> createState() => _AnimatedMeshBackgroundState();
}

class _AnimatedMeshBackgroundState extends State<AnimatedMeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    // Seeded from wall-clock time rather than 0: several instances of this
    // widget can be visible in the same moment (this field crossfading with
    // `AppBackdrop`'s persistent one during a route transition), and starting
    // each at a fresh frame zero would show their blobs in different
    // positions instead of drifting together.
    final cycleMs = widget.duration.inMilliseconds * 2;
    final elapsedMs = DateTime.now().millisecondsSinceEpoch % cycleMs;
    final phase = elapsedMs / widget.duration.inMilliseconds;
    _controller.value = phase <= 1 ? phase : 2 - phase;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-evaluated here rather than in initState because the accessibility
    // setting can change while the app is running.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
      _controller.value =
          0.25; // A pleasant static frame, not a degenerate one.
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Reaches the window's edges even when the screen's content is held to
        // a centred column on a wide desktop window.
        SizedBox.expand(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => _MeshLayer(
                t: _controller.value,
                theme: widget.theme,
              ),
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

/// One frame of the mesh, at animation position [t] in `[0, 1]`.
class _MeshLayer extends StatelessWidget {
  final double t;
  final MeshTheme theme;

  const _MeshLayer({required this.t, required this.theme});

  static const double _tau = math.pi * 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: -h * 0.1,
                left: -w * 0.1,
                width: w * 1.2,
                height: h * 1.2,
                // One blur for the base gradient and all four blobs.
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: 30,
                    sigmaY: 30,
                    tileMode: TileMode.clamp,
                  ),
                  child: SizedBox(
                    width: w * 1.2,
                    height: h * 1.2,
                    // Bounded on purpose: with `Clip.none` the blob positions
                    // extend the filter's input bounds, and because they move
                    // every frame the clamped edge moves with them — a faint
                    // shimmer/pop along the screen edges. Clipping to the
                    // fixed 1.2× box keeps the input bounds stable; the
                    // visible region is the inner 1/1.2, so the clip edge is
                    // never on screen.
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned.fill(child: _buildBaseGradient()),
                        // Blob 1 — 80% of the oversized box, top-left drift.
                        _blob(
                          blobW: w * 0.96,
                          blobH: h * 0.96,
                          left: -w * 0.12 + math.sin(t * _tau * 0.5) * w * 0.18,
                          top: -h * 0.12 + math.cos(t * _tau * 0.35) * h * 0.12,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [theme.b1Start, theme.b1End],
                          ),
                        ),
                        // Blob 2 — 90%, the largest; drifts through the centre.
                        _blob(
                          blobW: w * 1.08,
                          blobH: h * 1.08,
                          left: w * 0.36 +
                              math.sin(t * _tau * 0.45 + 1.0) * w * -0.18,
                          top: h * 0.24 +
                              math.cos(t * _tau * 0.4 + 1.0) * h * -0.18,
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [theme.b2Start, theme.b2End],
                          ),
                        ),
                        // Blob 3 — 70%, bottom-left drift.
                        _blob(
                          blobW: w * 0.84,
                          blobH: h * 0.84,
                          left: -w * 0.12 +
                              math.sin(t * _tau * 0.36 + 2.0) * w * 0.24,
                          top: h * 0.48 +
                              math.cos(t * _tau * 0.32 + 2.0) * h * -0.36,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [theme.b3Start, theme.b3End],
                          ),
                        ),
                        // Blob 4 — 60%, radial; the glow orb orbiting top-right.
                        _blob(
                          blobW: w * 0.72,
                          blobH: h * 0.72,
                          left: w * 0.48 +
                              math.sin(t * _tau * 0.4 + 3.0) * w * -0.36,
                          top: -h * 0.12 +
                              math.cos(t * _tau * 0.38 + 3.0) * h * 0.24,
                          gradient: RadialGradient(
                            colors: [theme.b4Start, theme.b4Mid, theme.b4End],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The base gradient, with its axis rotating slowly around the centre.
  Widget _buildBaseGradient() {
    final sweep = t * _tau * 0.3 + math.pi * 0.75;
    final dx = math.cos(sweep);
    final dy = math.sin(sweep);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(dx, dy),
          end: Alignment(-dx, -dy),
          colors: theme.baseColors,
          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        ),
      ),
    );
  }

  Widget _blob({
    required double blobW,
    required double blobH,
    required double left,
    required double top,
    required Gradient gradient,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: blobW,
        height: blobH,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
      ),
    );
  }
}
