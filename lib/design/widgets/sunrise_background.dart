import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../themes.dart';
import 'animated_mesh_background.dart';

/// SunRize's theme background: a soft three-colour gradient from top to
/// bottom with fine particles drifting slowly upward. Still under Reduce
/// Motion.
class SunriseBackground extends StatefulWidget {
  final HolyTheme theme;
  final Widget child;

  /// How far the field is pulled toward plain paper, from 0 (full colour) to
  /// 1 (paper). Screens that set small text straight on the field use
  /// [calmField].
  final double calm;

  /// The pull toward paper at which secondary text keeps 4.5:1 on every
  /// colour of the field, in every theme. Pinned by primary_contrast_test.
  static const calmField = .7;

  const SunriseBackground(
      {super.key, required this.theme, required this.child, this.calm = 0});

  /// Each theme's light, top to bottom. Sunrise is SunRize's own. The
  /// colours live on the theme, so they tween with it.
  static List<Color> gradientFor(HolyTheme t) => t.field;

  /// SunRize's moving mesh in this theme's colours: a sweeping base and
  /// four soft blobs drifting under one blur.
  ///
  /// The accent mixes are held where body ink keeps 4.5:1 and secondary text
  /// 3:1 on every colour, so words set on the field stay readable wherever a
  /// blob drifts.
  static MeshTheme meshFor(HolyTheme t, {double calm = 0}) {
    final g = gradientFor(t);
    final a = g[0], b = g[1], c = g[2];
    final tint = Color.lerp(c, t.accent, t.isDark ? .26 : .20)!;
    final glow = t.isDark
        ? Color.lerp(c, t.accent, .32)!
        : Color.lerp(Colors.white, b, .35)!;
    final mesh = MeshTheme(
        baseColors: [a, b, a, c, b],
        b1Start: c,
        b1End: b,
        b2Start: b,
        b2End: a,
        b3Start: tint,
        b3End: c,
        b4Start: glow,
        b4Mid: b,
        b4End: c);
    if (calm <= 0) return mesh;
    final p = t.paper;
    return MeshTheme.lerp(
        mesh,
        MeshTheme(
            baseColors: [p, p, p, p, p],
            b1Start: p,
            b1End: p,
            b2Start: p,
            b2End: p,
            b3Start: p,
            b3End: p,
            b4Start: p,
            b4Mid: p,
            b4End: p),
        calm);
  }

  /// The field's colour along its top edge, for glass bars that sit on it.
  static Color topColor(HolyTheme t, {double calm = 0}) =>
      Color.lerp(gradientFor(t).first, t.paper, calm.clamp(0.0, 1.0))!;

  @override
  State<SunriseBackground> createState() => _SunriseBackgroundState();
}

class _SunriseBackgroundState extends State<SunriseBackground>
    with SingleTickerProviderStateMixin {
  static const _driftPeriod = Duration(seconds: 24);
  late final AnimationController _drift =
      AnimationController(vsync: this, duration: _driftPeriod);
  late final List<_Mote> _motes =
      List.generate(26, (i) => _Mote(math.Random(i * 31 + 7)));
  late MeshTheme _mesh =
      SunriseBackground.meshFor(widget.theme, calm: widget.calm);

  @override
  void initState() {
    super.initState();
    // Seeded from the clock, like the mesh: each screen paints its own
    // field, and the particles should be in the same place on all of them.
    _drift.value =
        (DateTime.now().millisecondsSinceEpoch % _driftPeriod.inMilliseconds) /
            _driftPeriod.inMilliseconds;
  }

  @override
  void didUpdateWidget(SunriseBackground old) {
    super.didUpdateWidget(old);
    if (old.theme != widget.theme || old.calm != widget.calm) {
      _mesh = SunriseBackground.meshFor(widget.theme, calm: widget.calm);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(fit: StackFit.expand, children: [
      // Fine particles, softened, drifting up through the light.
      IgnorePointer(
          child: RepaintBoundary(
              child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 1.6, sigmaY: 1.6),
                  child: AnimatedBuilder(
                      animation: _drift,
                      builder: (context, _) => CustomPaint(
                          painter: _MotesPainter(
                              _motes, _drift.value, Colors.white)))))),
      widget.child,
    ]);
    // ThemeHost already tweens the theme frame by frame, field colours
    // included, so the mesh follows the paper exactly. A second animation
    // here would restart on every frame of that tween and trail behind it.
    return AnimatedMeshBackground(theme: _mesh, child: content);
  }
}

class _Mote {
  final double x, y, size, speed, phase;
  _Mote(math.Random r)
      : x = r.nextDouble(),
        y = r.nextDouble(),
        size = r.nextDouble() * 3.4 + 1.4,
        speed = r.nextDouble() * .5 + .25,
        phase = r.nextDouble() * math.pi * 2;
}

class _MotesPainter extends CustomPainter {
  final List<_Mote> motes;
  final double progress;
  final Color color;
  _MotesPainter(this.motes, this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    for (final m in motes) {
      final y = (m.y - progress * m.speed) % 1.0;
      final x = m.x + math.sin(progress * math.pi * 2 + m.phase) * .012;
      canvas.drawCircle(
          Offset(x * size.width, y * size.height),
          m.size,
          Paint()
            ..color = color.withValues(alpha: .42)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4));
    }
  }

  @override
  bool shouldRepaint(_MotesPainter old) => old.progress != progress;
}
