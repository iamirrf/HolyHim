import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../themes.dart';

/// SunRize's premium card, in the theme's metal: a border that slowly turns,
/// and a card of drifting metal and champagne light under a single soft
/// blur. Gold in First Light, rose gold in Rosé, silver in Starlight. Still
/// under Reduce Motion.
class PremiumCard extends StatefulWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  const PremiumCard(
      {super.key,
      required this.child,
      this.radius = 26,
      this.padding = const EdgeInsets.symmetric(vertical: 20, horizontal: 18)});
  @override
  State<PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<PremiumCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t =
      AnimationController(vsync: this, duration: const Duration(seconds: 9));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _t.stop();
    } else if (!_t.isAnimating) {
      _t.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.radius;
    final metal = HolyThemeScope.of(context).metal;
    final accent = HolyThemeScope.of(context).accent;
    return AnimatedBuilder(
        animation: _t,
        builder: (context, child) {
          final t = _t.value;
          return DecoratedBox(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(r + 2.5),
                  gradient: SweepGradient(
                      transform: GradientRotation(t * math.pi * 2),
                      colors: [
                        metal[0],
                        metal[1],
                        Color.lerp(metal[1], accent, .35)!,
                        metal[2],
                        metal[0],
                      ]),
                  boxShadow: [
                    BoxShadow(
                        color: metal[1].withValues(alpha: .32),
                        blurRadius: 22,
                        offset: const Offset(0, 8)),
                  ]),
              child: Padding(
                  padding: const EdgeInsets.all(2.5),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(r),
                      child: Stack(children: [
                        Positioned.fill(
                            child: _Light(t: t, metal: metal, accent: accent)),
                        Padding(padding: widget.padding, child: child),
                      ]))));
        },
        child: widget.child);
  }
}

class _Light extends StatelessWidget {
  final double t;
  final List<Color> metal;
  final Color accent;
  const _Light({required this.t, required this.metal, required this.accent});
  @override
  Widget build(BuildContext context) {
    const tau = math.pi * 2;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      Widget blob(double left, double top, double bw, double bh,
              List<Color> colors) =>
          Positioned(
              left: left,
              top: top,
              width: bw,
              height: bh,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: colors))));
      return ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
              sigmaX: 26, sigmaY: 26, tileMode: TileMode.mirror),
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment(-1 + t, -1),
                            end: Alignment(1 - t * .5, 1),
                            colors: [
                  Color.lerp(metal[0], Colors.white, .7)!,
                  metal[0],
                  Color.lerp(metal[0], Colors.white, .35)!,
                  metal[1],
                ])))),
            blob(-w * .1 + math.sin(t * tau) * w * .15,
                -h * .1 + math.cos(t * tau) * h * .1, w * .8, h * .8, [
              Color.lerp(metal[0], Colors.white, .5)!,
              metal[1],
            ]),
            blob(w * .45 + math.cos(t * tau) * w * .12,
                h * .2 + math.sin(t * tau) * h * .2, w * .7, h * .9, [
              Color.lerp(metal[0], accent, .25)!,
              Colors.white,
            ]),
            blob(w * .1 + math.sin(t * tau + 2) * w * .1,
                h * .45 + math.cos(t * tau + 1) * h * .1, w * .6, h * .7, [
              metal[2],
              Color.lerp(metal[0], Colors.white, .6)!,
            ]),
          ]));
    });
  }
}
