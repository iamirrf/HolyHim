import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../haptics.dart';

/// Struck metals. Brass is HolyHim's own; gold, silver and bronze rank the
/// board; steel is a coin not yet earned; pine marks a grace day.
enum CoinMetal { brass, gold, silver, bronze, steel, pine }

@immutable
class CoinFinish {
  final Color hi, mid, low, edge, deep;
  const CoinFinish(this.hi, this.mid, this.low, this.edge, this.deep);

  static CoinFinish of(CoinMetal metal) => switch (metal) {
        CoinMetal.brass => const CoinFinish(Color(0xFFF7DFA4), Color(0xFFD8A657),
            Color(0xFF8C6024), Color(0xFF6E4A19), Color(0xFF3A2709)),
        CoinMetal.gold => const CoinFinish(Color(0xFFFFF1BC), Color(0xFFF0BF4C),
            Color(0xFFA9781B), Color(0xFF85590F), Color(0xFF4A3106)),
        CoinMetal.silver => const CoinFinish(Color(0xFFFFFFFF), Color(0xFFC9D2DC),
            Color(0xFF7D8795), Color(0xFF5B6471), Color(0xFF2B3139)),
        CoinMetal.bronze => const CoinFinish(Color(0xFFF2C59E), Color(0xFFBF7B47),
            Color(0xFF7A4321), Color(0xFF5A2F15), Color(0xFF2E170A)),
        CoinMetal.steel => const CoinFinish(Color(0xFF97A3B2), Color(0xFF515C6B),
            Color(0xFF2A313B), Color(0xFF1D232B), Color(0xFF0E1217)),
        CoinMetal.pine => const CoinFinish(Color(0xFFD3E6CC), Color(0xFF8FB08A),
            Color(0xFF4E6B4A), Color(0xFF3A5236), Color(0xFF1B291A)),
      };
}

/// A coin seen in three dimensions: a struck face, a reeded edge with real
/// thickness that shows as it turns, a reverse, and light that slides across
/// the metal with the turn. Pure paint: [CoinBadge] makes it spin.
class HolyCoin extends StatelessWidget {
  final double size;

  /// Rotation about the vertical axis, in radians. Past a quarter turn the
  /// reverse comes round.
  final double turn;

  /// Rotation about the horizontal axis, in radians.
  final double tilt;
  final CoinMetal metal;

  /// A struck face from the medallion art. Without one the coin is engraved
  /// with [face].
  final String? image;
  final Widget? face;
  final Widget? back;

  /// Not yet earned: struck in steel, the art pressed dark into it.
  final bool muted;

  /// Halo behind the coin, 0 to 1.
  final double glow;

  /// Edge depth as a share of the diameter.
  final double thickness;
  const HolyCoin(
      {super.key,
      required this.size,
      this.turn = 0,
      this.tilt = 0,
      this.metal = CoinMetal.brass,
      this.image,
      this.face,
      this.back,
      this.muted = false,
      this.glow = 0,
      this.thickness = .09});

  static const _slices = 9;

  @override
  Widget build(BuildContext context) {
    final finish = CoinFinish.of(muted ? CoinMetal.steel : metal);
    final depth = size * thickness;
    final showBack = math.cos(turn) < 0;
    Matrix4 at(double z) => Matrix4.identity()
      ..setEntry(3, 2, .0012)
      ..rotateX(tilt)
      ..rotateY(turn)
      ..translateByDouble(0.0, 0.0, z, 1.0);
    Widget layer(double z, Widget child) => Transform(
        alignment: Alignment.center, transform: at(z), child: child);

    final edge = [
      for (var i = 0; i < _slices; i++)
        layer(
            -depth / 2 + depth * (i + .5) / _slices,
            _EdgeSlice(
                size: size,
                finish: finish,
                shade: (i / (_slices - 1) - .5).abs() * 2)),
    ];
    final front = layer(
        -depth / 2,
        _Face(
            size: size,
            finish: finish,
            turn: turn,
            image: image,
            muted: muted,
            child: face));
    final reverse = layer(
        depth / 2,
        Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(math.pi),
            child: _Face(
                size: size,
                finish: finish,
                turn: turn + math.pi,
                muted: muted,
                child: back ?? _Emblem(size: size, finish: finish))));

    return SizedBox.square(
        dimension: size,
        child: Stack(clipBehavior: Clip.none, children: [
          if (glow > 0)
            Positioned.fill(
                child: DecoratedBox(
                    decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
              BoxShadow(
                  color: finish.mid.withValues(alpha: .55 * glow),
                  blurRadius: size * .42,
                  spreadRadius: size * .04),
            ]))),
          // The coin's own shadow, on the page rather than the metal.
          Positioned(
              left: size * .12,
              right: size * .12,
              bottom: -size * .07,
              height: size * .16,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(
                          Radius.elliptical(size * .4, size * .08)),
                      boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: .38),
                    blurRadius: size * .12),
              ]))),
          ...showBack
              ? [front, ...edge, reverse]
              : [reverse, ...edge.reversed, front],
        ]));
  }
}

class _EdgeSlice extends StatelessWidget {
  final double size, shade;
  final CoinFinish finish;
  const _EdgeSlice(
      {required this.size, required this.finish, required this.shade});
  @override
  Widget build(BuildContext context) {
    final base = Color.lerp(finish.low, finish.edge, shade)!;
    return SizedBox.square(
        dimension: size,
        child: DecoratedBox(
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Fine reeding: seen side on, the rim reads as milled metal.
                gradient: SweepGradient(
                    endAngle: math.pi / 60,
                    tileMode: TileMode.repeated,
                    colors: [base, Color.lerp(base, finish.hi, .45)!, base],
                    stops: const [0, .5, 1]))));
  }
}

class _Face extends StatelessWidget {
  final double size, turn;
  final CoinFinish finish;
  final String? image;
  final bool muted;
  final Widget? child;
  const _Face(
      {required this.size,
      required this.finish,
      required this.turn,
      required this.muted,
      this.image,
      this.child});

  static const _steel = ColorFilter.matrix([
    .16, .30, .06, 0, 6, //
    .16, .32, .07, 0, 10,
    .17, .34, .09, 0, 16,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    // The highlight slides across as the coin turns.
    final s = (math.sin(turn) + 1) / 2;
    final art = image == null
        ? CustomPaint(
            size: Size.square(size),
            painter: _StrikePainter(finish),
            child: SizedBox.square(
                dimension: size,
                child: Center(
                    child: IconTheme(
                        data: IconThemeData(
                            color: finish.deep.withValues(alpha: .86),
                            size: size * .42,
                            shadows: [
                              Shadow(
                                  color: finish.hi.withValues(alpha: .7),
                                  offset: Offset(size * .008, size * .012)),
                            ]),
                        child: DefaultTextStyle(
                            style: TextStyle(
                                fontFamily: 'SourceSerif4Display',
                                fontWeight: FontWeight.w700,
                                fontSize: size * .36,
                                height: 1,
                                color: finish.deep.withValues(alpha: .88),
                                shadows: [
                                  Shadow(
                                      color: finish.hi.withValues(alpha: .75),
                                      offset:
                                          Offset(size * .008, size * .014)),
                                ]),
                            child: child ?? const SizedBox.shrink())))))
        : muted
            ? ColorFiltered(
                colorFilter: _steel,
                child: Image.asset(image!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    excludeFromSemantics: true))
            : Image.asset(image!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true);
    return SizedBox.square(
        dimension: size,
        child: ClipOval(
            child: Stack(fit: StackFit.expand, children: [
          DecoratedBox(
              decoration: BoxDecoration(
                  gradient: RadialGradient(
                      center: const Alignment(-.35, -.45),
                      radius: 1.05,
                      colors: [finish.hi, finish.mid, finish.low]))),
          art,
          IgnorePointer(
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment(-2.2 + 3.4 * s, -1),
                          end: Alignment(-1.0 + 3.4 * s, 1),
                          colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: muted ? .10 : .34),
                Colors.white.withValues(alpha: 0),
              ],
                          stops: const [.3, .5, .7])))),
          IgnorePointer(
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: RadialGradient(
                          center: const Alignment(-.45, -.6),
                          radius: .55,
                          colors: [
                Colors.white.withValues(alpha: muted ? .08 : .26),
                Colors.white.withValues(alpha: 0),
              ])))),
        ])));
  }
}

/// An engraved face: bevelled rim, a ring of beads and a sunken field.
class _StrikePainter extends CustomPainter {
  final CoinFinish f;
  const _StrikePainter(this.f);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Offset.zero & size;
    final bevel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .14
      ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [f.hi, f.mid, f.edge])
          .createShader(rect);
    canvas.drawCircle(c, r * .93, bevel);
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .035
      ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [f.edge, f.hi])
          .createShader(rect);
    canvas.drawCircle(c, r * .82, groove);
    final field = Paint()
      ..shader = RadialGradient(
              center: const Alignment(.2, .25),
              radius: .9,
              colors: [f.mid, Color.lerp(f.mid, f.low, .55)!])
          .createShader(Rect.fromCircle(center: c, radius: r * .8));
    canvas.drawCircle(c, r * .8, field);
    final bead = Paint()..color = f.hi.withValues(alpha: .55);
    final beadShade = Paint()..color = f.edge.withValues(alpha: .5);
    const beads = 36;
    for (var i = 0; i < beads; i++) {
      final a = i / beads * math.pi * 2;
      final p = c + Offset(math.cos(a), math.sin(a)) * r * .73;
      canvas.drawCircle(p + Offset(r * .008, r * .01), r * .02, beadShade);
      canvas.drawCircle(p, r * .018, bead);
    }
  }

  @override
  bool shouldRepaint(_StrikePainter old) => old.f != f;
}

/// HolyHim's reverse: a cross over the line of first light.
class _Emblem extends StatelessWidget {
  final double size;
  final CoinFinish finish;
  const _Emblem({required this.size, required this.finish});
  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size.square(size), painter: _EmblemPainter(finish));
}

class _EmblemPainter extends CustomPainter {
  final CoinFinish f;
  const _EmblemPainter(this.f);
  @override
  void paint(Canvas canvas, Size size) {
    _StrikePainter(f).paint(canvas, size);
    final w = size.width;
    final ink = Paint()..color = f.deep.withValues(alpha: .8);
    final lit = Paint()..color = f.hi.withValues(alpha: .6);
    final stem = Rect.fromCenter(
        center: Offset(w * .5, w * .47), width: w * .07, height: w * .40);
    final arm = Rect.fromCenter(
        center: Offset(w * .5, w * .39), width: w * .27, height: w * .07);
    for (final r in [stem, arm]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(r.shift(Offset(w * .006, w * .01)),
              Radius.circular(w * .01)),
          lit);
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(w * .01)), ink);
    }
    final horizon = Paint()
      ..color = f.deep.withValues(alpha: .55)
      ..strokeWidth = w * .02
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * .3, w * .7), Offset(w * .7, w * .7), horizon);
    canvas.drawLine(
        Offset(w * .38, w * .76), Offset(w * .62, w * .76), horizon);
  }

  @override
  bool shouldRepaint(_EmblemPainter old) => old.f != f;
}

/// A [HolyCoin] you can handle: drag to turn it, flick to spin it, tap for a
/// full turn that lands with a little wobble. [idle] gives it a slow sway so
/// a featured coin catches the light on its own.
class CoinBadge extends StatefulWidget {
  final double size;
  final CoinMetal metal;
  final String? image;
  final Widget? face, back;
  final bool muted, idle;

  /// One full turn the first time it is shown, for a coin just earned.
  final bool spinOnAppear;
  final double glow;
  final VoidCallback? onTap;
  final String? semanticLabel;
  const CoinBadge(
      {super.key,
      required this.size,
      this.metal = CoinMetal.brass,
      this.image,
      this.face,
      this.back,
      this.muted = false,
      this.idle = false,
      this.spinOnAppear = false,
      this.glow = 0,
      this.onTap,
      this.semanticLabel});

  @override
  State<CoinBadge> createState() => _CoinBadgeState();
}

class _CoinBadgeState extends State<CoinBadge> with TickerProviderStateMixin {
  late final _turn = AnimationController.unbounded(vsync: this);
  late final _sway = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 5200));
  static final _spring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 90, ratio: .62);
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (widget.idle && !_reduced) {
      if (!_sway.isAnimating) _sway.repeat();
    } else {
      _sway.stop();
    }
    if (widget.spinOnAppear && !_reduced && _turn.value == 0) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _settle(math.pi * 2, velocity: 9);
      });
    }
  }

  @override
  void didUpdateWidget(CoinBadge old) {
    super.didUpdateWidget(old);
    if (widget.idle != old.idle) {
      widget.idle && !_reduced ? _sway.repeat() : _sway.stop();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    _sway.dispose();
    super.dispose();
  }

  void _settle(double target, {double velocity = 0}) {
    _turn.animateWith(SpringSimulation(_spring, _turn.value, target, velocity,
        tolerance: const Tolerance(distance: .002, velocity: .02)));
  }

  double get _nearestFront =>
      (_turn.value / (math.pi * 2)).roundToDouble() * math.pi * 2;

  void _tap() {
    widget.onTap?.call();
    if (_reduced) return;
    HolyHaptics.chipSelect();
    _settle(_nearestFront + math.pi * 2, velocity: 8);
  }

  @override
  Widget build(BuildContext context) {
    final coin = AnimatedBuilder(
        animation: Listenable.merge([_turn, _sway]),
        builder: (context, _) {
          final s = _sway.value * math.pi * 2;
          final sway = widget.idle && !_reduced;
          return HolyCoin(
              size: widget.size,
              turn: _turn.value + (sway ? math.sin(s) * .32 : 0),
              tilt: sway ? math.cos(s) * .10 : 0,
              metal: widget.metal,
              image: widget.image,
              face: widget.face,
              back: widget.back,
              muted: widget.muted,
              glow: widget.glow);
        });
    return Semantics(
        button: widget.onTap != null,
        label: widget.semanticLabel,
        excludeSemantics: widget.semanticLabel != null,
        child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _tap,
            onHorizontalDragStart: _reduced ? null : (_) => _turn.stop(),
            onHorizontalDragUpdate: _reduced
                ? null
                : (d) => _turn.value += d.delta.dx / widget.size * math.pi,
            onHorizontalDragEnd: _reduced
                ? null
                : (d) {
                    final v = d.velocity.pixelsPerSecond.dx /
                        widget.size *
                        math.pi;
                    final projected = _turn.value + v * .35;
                    final target =
                        (projected / (math.pi * 2)).roundToDouble() *
                            math.pi *
                            2;
                    HolyHaptics.detent();
                    _settle(target, velocity: v);
                  },
            child: coin));
  }
}
