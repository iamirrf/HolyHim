// Ported from Cognein's AnimatedGradientCard; see store/v2-design-ports.json.
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// A card with light drifting slowly inside it.
///
/// A base gradient whose angle orbits, and four soft blobs of [glow] on
/// their own phases, all under one blur. The blobs are laid out in a box 20%
/// larger than the card and blurred with a clamped edge, so a blob never pops
/// as it crosses the card's border.
///
/// Everything sits inside one [RepaintBoundary] and one clip, so the drift
/// never repaints what is around the card. Under Reduce Motion it shows one
/// still, representative frame.
class GlowCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;

  /// The base sweep, lightest first.
  final List<Color> colors;

  /// The colour of the drifting light.
  final Color glow;
  final bool animate;

  /// One full cycle. Cards she reads drift slowly.
  final Duration duration;
  final double blurSigma;

  /// Shrinks the blobs so the light reads as contained.
  final double blobScale;

  /// How strong the blobs are; 1 is Cognein's.
  final double glowStrength;

  /// Soft motes of light that fade in and out on their own cycle.
  final bool motes;

  /// A hairline painted over the finished card.
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadows;

  const GlowCard(
      {super.key,
      required this.child,
      required this.colors,
      required this.glow,
      this.animate = true,
      this.borderRadius = 26,
      this.padding = const EdgeInsets.all(20),
      this.duration = const Duration(seconds: 12),
      this.blurSigma = 26,
      this.blobScale = .8,
      this.glowStrength = 1,
      this.motes = false,
      this.borderColor,
      this.borderWidth = 1,
      this.shadows});

  @override
  State<GlowCard> createState() => _GlowCardState();
}

class _GlowCardState extends State<GlowCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(GlowCard old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate) _sync();
  }

  void _sync() {
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _drift
        ..stop()
        ..value = .35;
    } else if (!_drift.isAnimating) {
      _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    Widget card = RepaintBoundary(
        child: ClipRRect(
            borderRadius: radius,
            child: AnimatedBuilder(
                animation: _drift,
                builder: (context, child) =>
                    Stack(fit: StackFit.passthrough, children: [
                      Positioned.fill(
                          child: IgnorePointer(
                              child: _Light(
                                  t: _drift.value,
                                  colors: widget.colors,
                                  glow: widget.glow,
                                  motes: widget.motes,
                                  blurSigma: widget.blurSigma,
                                  blobScale: widget.blobScale,
                                  strength: widget.glowStrength))),
                      child!,
                    ]),
                child: Padding(padding: widget.padding, child: widget.child))));
    if (widget.borderColor != null) {
      card = DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                  color: widget.borderColor!, width: widget.borderWidth)),
          child: card);
    }
    if (widget.shadows == null) return card;
    return DecoratedBox(
        decoration:
            BoxDecoration(borderRadius: radius, boxShadow: widget.shadows),
        child: card);
  }
}

class _Light extends StatelessWidget {
  final double t, blurSigma, blobScale, strength;
  final List<Color> colors;
  final Color glow;
  final bool motes;
  const _Light(
      {required this.t,
      required this.colors,
      required this.glow,
      required this.motes,
      required this.blurSigma,
      required this.blobScale,
      required this.strength});

  static const _tau = math.pi * 2;
  static const _alphas = [.28, .22, .18, .14];

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final angle = t * _tau;
        return ClipRect(
            child: Stack(fit: StackFit.expand, children: [
          Positioned(
              top: -h * .1,
              left: -w * .1,
              width: w * 1.2,
              height: h * 1.2,
              child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                      tileMode: TileMode.clamp),
                  child: SizedBox(
                      width: w * 1.2,
                      height: h * 1.2,
                      child: Stack(clipBehavior: Clip.hardEdge, children: [
                        Positioned.fill(
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                        begin: Alignment(
                                            math.cos(angle), math.sin(angle)),
                                        end: Alignment(
                                            -math.cos(angle), -math.sin(angle)),
                                        colors: colors)))),
                        _blob(w, h, 0, .55 * blobScale, 1, .35),
                        _blob(w, h, 1, .42 * blobScale, -.85, .60),
                        _blob(w, h, 2, .34 * blobScale, .70, -.45),
                        _blob(w, h, 3, .28 * blobScale, -.60, -.75),
                      ])))),
          if (motes)
            Positioned.fill(
                child: Stack(children: [
              _mote(w, h, 0, .30, -.55),
              _mote(w, h, 1, -.40, .35),
              _mote(w, h, 2, .18, -.28),
              _mote(w, h, 3, -.24, -.42),
              _mote(w, h, 4, .34, .20),
            ])),
        ]));
      });

  Widget _blob(
      double w, double h, int index, double radius, double fx, double fy) {
    final boxW = w * 1.2, boxH = h * 1.2;
    final size = boxH * radius * 2;
    final phase = t * _tau + index * (_tau / 4);
    return Positioned(
        left: boxW * .5 + math.cos(phase * fx) * boxW * .32 - size / 2,
        top: boxH * .5 + math.sin(phase * fy) * boxH * .34 - size / 2,
        child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  glow.withValues(
                      alpha: (_alphas[index] * strength).clamp(0.0, 1.0)),
                  glow.withValues(alpha: 0),
                ]))));
  }

  Widget _mote(double w, double h, int index, double fx, double fy) {
    final size = math.max(3.0, h * .014);
    final phase = t * _tau + index * (_tau / 5);
    final pulse = (math.sin(phase + index * 1.7) + 1) / 2;
    return Positioned(
        left: w * .5 + math.cos(phase * fx) * w * .34 - size / 2,
        top: h * .5 + math.sin(phase * fy) * h * .36 - size / 2,
        child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 2.4, sigmaY: 2.4),
            child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: glow.withValues(alpha: pulse * .8)))));
  }
}
