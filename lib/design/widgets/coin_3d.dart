import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../haptics.dart';
import 'bundled_art.dart';

/// A medallion with nothing around it: only its own art, turning in 3D. It
/// sways in the light, spins under a finger and flips on a tap; the glint
/// touches the art alone. Locked medallions rest in muted grey.
class Coin3D extends StatefulWidget {
  final String badgeId;
  final bool earned;
  final double size;

  /// Drag to spin and tap to flip (in a detail view); otherwise it only sways.
  final bool interactive;

  /// Face straight on without swaying, for still images such as share cards.
  final bool still;

  /// Arrives spinning, two full turns that slow to a stop facing her.
  final bool spinIn;
  final VoidCallback? onTap;
  const Coin3D(
      {super.key,
      required this.badgeId,
      required this.earned,
      this.size = 88,
      this.interactive = false,
      this.still = false,
      this.spinIn = false,
      this.onTap});

  @override
  State<Coin3D> createState() => _Coin3DState();
}

class _Coin3DState extends State<Coin3D> with TickerProviderStateMixin {
  // The medallion's turn around its vertical axis, in radians.
  late final spin = AnimationController.unbounded(vsync: this);
  late final sway = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 3600 + widget.badgeId.length * 97));

  @override
  void initState() {
    super.initState();
    if (widget.spinIn) spin.value = -math.pi * 4;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduced = MediaQuery.disableAnimationsOf(context);
      if (widget.spinIn) {
        if (reduced) {
          spin.value = 0;
        } else {
          spin.animateTo(0,
              duration: const Duration(milliseconds: 1900),
              curve: Curves.easeOutCubic);
        }
      }
      if (!widget.still && !reduced) sway.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    spin.dispose();
    sway.dispose();
    super.dispose();
  }

  void _settle(double velocity) {
    // Coast with friction, then come to rest on the nearest face.
    final coast = FrictionSimulation(.25, spin.value, velocity).finalX;
    final rest = (coast / math.pi).roundToDouble() * math.pi;
    spin.animateWith(SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 60, damping: 11),
        spin.value,
        rest,
        velocity));
    HolyHaptics.detent();
  }

  void _flip() {
    HolyHaptics.tap();
    final target = ((spin.value / math.pi).roundToDouble() + 1) * math.pi;
    spin.animateTo(target,
        duration: const Duration(milliseconds: 700), curve: Curves.easeOutBack);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    Widget medallion = AnimatedBuilder(
        animation: Listenable.merge([spin, sway]),
        builder: (context, _) {
          final swayAngle = widget.still || !sway.isAnimating
              ? 0.0
              : (Curves.easeInOutSine.transform(sway.value) - .5) * .6;
          final angle = spin.value + swayAngle;
          final front = math.cos(angle) >= 0;
          final glint = math.sin(angle * 2) * .5 + .5;
          Matrix4 at(double z) => Matrix4.identity()
            ..setEntry(3, 2, .0016)
            ..rotateY(angle)
            ..translateByDouble(0, 0, z, 1);
          // Thickness made from the medallion itself: darker copies of its own
          // art stacked behind the face, so the edge is its own gold rim.
          final depth = size * .075;
          const layers = 8;
          final edge = [
            for (var i = layers; i >= 1; i--)
              Transform(
                  alignment: Alignment.center,
                  transform: at((front ? 1 : -1) * depth * i / layers),
                  child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                          Color.lerp(const Color(0xFF8A5A1C),
                                  const Color(0xFF3A2410), i / layers)!
                              .withValues(alpha: .55),
                          BlendMode.srcATop),
                      child: _Art(
                          badgeId: widget.badgeId,
                          earned: widget.earned,
                          glint: 0,
                          size: size,
                          plain: true))),
          ];
          return Stack(fit: StackFit.expand, children: [
            ...edge,
            Transform(
                alignment: Alignment.center,
                transform: at(0),
                child: front
                    ? _Art(
                        badgeId: widget.badgeId,
                        earned: widget.earned,
                        glint: glint,
                        size: size)
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(math.pi),
                        child: Opacity(
                            opacity: .7,
                            child: _Art(
                                badgeId: widget.badgeId,
                                earned: widget.earned,
                                glint: glint,
                                size: size,
                                back: true)))),
          ]);
        });
    if (widget.interactive) {
      medallion = GestureDetector(
          onHorizontalDragUpdate: (d) => spin.value += d.delta.dx / size * 2.2,
          onHorizontalDragEnd: (d) =>
              _settle(d.velocity.pixelsPerSecond.dx / size * 2.2),
          onTap: _flip,
          child: medallion);
    } else if (widget.onTap != null) {
      medallion = GestureDetector(onTap: widget.onTap, child: medallion);
    }
    return SizedBox.square(dimension: size, child: medallion);
  }
}

class _Art extends StatelessWidget {
  final String badgeId;
  final bool earned, back, plain;
  final double glint, size;
  const _Art(
      {required this.badgeId,
      required this.earned,
      required this.glint,
      required this.size,
      this.back = false,
      this.plain = false});

  static const _grey = ColorFilter.matrix([
    .2126, .7152, .0722, 0, 0, //
    .2126, .7152, .0722, 0, 0, //
    .2126, .7152, .0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    Widget art = Image.asset(
        HolyArtAssets.badgePath(badgeId) ?? 'assets/art/badges/days-001.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        cacheWidth: (size * 3).round(),
        errorBuilder: (c, e, s) => SizedBox.square(dimension: size));
    if (plain) {
      return earned ? art : ColorFiltered(colorFilter: _grey, child: art);
    }
    // Light that travels as it turns, laid only on the art's own pixels.
    art = ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
                begin: Alignment(-1.6 + glint * 3.2, -1),
                end: Alignment(-.8 + glint * 3.2, 1),
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white
                      .withValues(alpha: back ? .1 : (earned ? .34 : .16)),
                  Colors.white.withValues(alpha: 0),
                ]).createShader(rect),
        child: art);
    if (!earned) {
      art = Stack(alignment: Alignment.center, children: [
        Opacity(
            opacity: .5, child: ColorFiltered(colorFilter: _grey, child: art)),
        if (!back)
          Icon(CupertinoIcons.lock_fill,
              size: size * .22, color: const Color(0xCC6E6560)),
      ]);
    }
    return art;
  }
}
