import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The moment a lesson is saved: rose-and-gold light that laps the closing card
/// once, behind it, with a few sparks shed in front.
///
/// It is built as two layers around the deck, driven by ONE animation so they
/// can never drift apart, and paced to `assets/sounds/lesson_surge.mp3`, which
/// pans once round the listener on the same curve (see [orbitCurve]; the script
/// that writes the sound evaluates the same Bezier).
///
/// * [LessonAuraLayer] sits behind the deck. A blurred mesh of rose and gold light: two
///   rings of soft blobs orbiting in a TILTED plane, run through a perspective
///   projection, so the near side of each ring is bigger, brighter and moves
///   faster across the screen than the far side, and the whole ring precesses a
///   little as it goes. Blobs are painted far to near, add up like light where
///   they cross, and smear into streaks along the orbit while it is moving fast.
///   A bright comet laps the card's rim in step with them, so the card's edge
///   catches the light as it passes.
/// * [LessonSparkLayer] sits in front. A couple of dozen sparks, shed from the
///   comet's head as it goes, each at its own depth (nearer ones bigger and
///   quicker), drifting up and out and fading. Never more than a handful are
///   alight at once: this is a spark, not a storm.
///
/// After the lap the light settles to a faint, still halo for as long as the
/// card is on screen; nothing keeps animating. With reduced motion the
/// animation is simply parked at its end: the still halo, no lap, no sparks.
abstract final class LessonCelebration {
  /// Length of the whole choreography.
  static const duration = Duration(milliseconds: 2800);

  /// The lap takes this share of [duration]; the rest is the light settling.
  static const orbitShare = 0.8;

  /// How the light's lap is paced: it leaves gently, gathers speed, then glides
  /// to a stop. The same four numbers are in `scripts/make_lesson_sounds.py`
  /// (`orbit_ease`) so the whoosh pans exactly as the light moves.
  static const orbitCurve = Cubic(0.32, 0.0, 0.08, 1.0);

  /// When the four-note chime lands in `lesson_surge.mp3` (the crest of the
  /// whoosh) and when the lap starts to settle: the two taps that go with them.
  static const crestAfter = Duration(milliseconds: 800);
  static const settleAfter = Duration(milliseconds: 930);

  /// [crestAfter] and [settleAfter] as progress of the choreography.
  static double get crestAt =>
      crestAfter.inMilliseconds / duration.inMilliseconds;
  static double get settleAt =>
      settleAfter.inMilliseconds / duration.inMilliseconds;

  /// When the store's review card is asked for, from the moment the lesson was
  /// saved: after the lap has finished and the light is on its way to rest, so
  /// the sheet slides up over a scene that is still glowing.
  static const reviewAfter = Duration(milliseconds: 2500);

  /// How long to wait for the review card when motion is reduced and there is
  /// no lap to wait for: long enough to read "You Completed this Lesson!".
  static const reviewAfterReduced = Duration(milliseconds: 900);

  /// The halo that stays once the lap is over, as a share of its peak.
  static const restGlow = 0.34;

  /// Whole turns of the lap, 0..1, at progress [p] of the choreography.
  static double turnsAt(double p) =>
      orbitCurve.transform((p / orbitShare).clamp(0.0, 1.0));

  /// How bright the light is, 0..1, at progress [p]: it flares fast, holds, and
  /// settles to [restGlow].
  static double glowAt(double p) {
    if (p <= 0) return 0;
    final attack = Curves.easeOutCubic.transform((p / 0.10).clamp(0.0, 1.0));
    final release = _smoothstep(((p - 0.50) / 0.46).clamp(0.0, 1.0));
    return attack * (1 - (1 - restGlow) * release);
  }

  /// How fast the light is moving, 0..1 (its fastest is exactly 1): what streaks
  /// it.
  static double speedAt(double p) =>
      (_rawSpeed(p) / _peakSpeed).clamp(0.0, 1.0);

  /// Turns per unit of progress, by a central difference.
  static double _rawSpeed(double p) {
    const step = 0.002;
    return (turnsAt(p + step) - turnsAt(p - step)) / (2 * step);
  }

  static final double _peakSpeed = () {
    var peak = 0.0;
    for (var i = 0; i <= 800; i++) {
      peak = math.max(peak, _rawSpeed(orbitShare * i / 800));
    }
    return peak;
  }();

  static double _smoothstep(double x) => x * x * (3 - 2 * x);
}

// Electric blue, from the deep end of the ultramarine to ice at the highlight.
const _ultramarine = Color(0xFFA67C37);
const _electric = Color(0xFFC9A227);
const _cyan = Color(0xFFDAB674);
const _ice = Color(0xFF1F262E);

/// One soft blob of light on one of the two rings.
class _Blob {
  /// Where on its ring it starts, in radians.
  final double phase;

  /// +1 or -1: which way round the ring it goes.
  final double direction;

  /// How many laps it makes while the lead light makes one.
  final double lapRatio;

  final Color color;

  /// Radius as a share of the card's half-width.
  final double radius;
  final double alpha;
  final _Ring ring;

  const _Blob(this.ring, this.phase, this.direction, this.lapRatio, this.color,
      this.radius, this.alpha);
}

/// The plane a ring orbits in, tilted about the horizontal axis by [tilt] so
/// one side of it comes towards the viewer and the other recedes.
class _Ring {
  /// Half-width and half-height of the ring as a share of the card's.
  final double reachX;
  final double reachY;

  /// Radians of tilt about the horizontal axis. The sign picks which side
  /// (top or bottom) is the near one.
  final double tilt;

  /// Radians the ring has precessed about the vertical axis by the end of the
  /// lap: the whole gyroscope slowly turns, so nothing is a flat loop.
  final double precession;

  const _Ring(this.reachX, this.reachY, this.tilt, this.precession);
}

// The rings reach past the card, into the margins around it: the card is opaque,
// so light centred behind it would never be seen.
const _farRing = _Ring(1.30, 1.10, 0.52, 0.34);
const _nearRing = _Ring(1.42, 0.98, -0.70, -0.46);

const _blobs = <_Blob>[
  // The far ring: big, deep, slow, the body of the mesh.
  _Blob(_farRing, 0.0, 1, 1, _ultramarine, 1.35, 1.0),
  _Blob(_farRing, math.pi * 0.5, 1, 1, _electric, 1.15, 0.95),
  _Blob(_farRing, math.pi, 1, 1, _ultramarine, 1.35, 1.0),
  _Blob(_farRing, math.pi * 1.5, 1, 1, _electric, 1.15, 0.95),
  // The near ring: smaller, brighter, quicker, going the other way. Where it
  // crosses the far ring the light adds up, which is what makes it a mesh.
  _Blob(_nearRing, 0.5, -1, 1.35, _cyan, 0.85, 0.95),
  _Blob(_nearRing, 0.5 + math.pi * 2 / 3, -1, 1.35, _electric, 0.78, 0.9),
  _Blob(_nearRing, 0.5 + math.pi * 4 / 3, -1, 1.35, _ice, 0.60, 0.7),
];

/// The blurred, orbiting light behind the deck.
class LessonAuraLayer extends StatelessWidget {
  /// 0..1 across [LessonCelebration.duration]. At 0 nothing is drawn.
  final Animation<double> animation;

  /// Where the closing card rests, in this layer's own coordinates.
  final Rect frame;

  /// The card's corner radius, so the comet hugs its edge.
  final double cornerRadius;

  /// Light on a dark scene adds; on a pale one it has to be laid on top.
  final bool dark;

  const LessonAuraLayer({
    super.key,
    required this.animation,
    required this.frame,
    required this.dark,
    this.cornerRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            key: const ValueKey('lesson-aura'),
            painter: AuraPainter(
              animation: animation,
              frame: frame,
              cornerRadius: cornerRadius,
              dark: dark,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

/// The sparks in front of the deck.
class LessonSparkLayer extends StatelessWidget {
  final Animation<double> animation;
  final Rect frame;
  final double cornerRadius;

  /// Over a dark card the sparks are light; over a pale one they would vanish,
  /// so they turn to deep electric blue.
  final bool dark;

  const LessonSparkLayer({
    super.key,
    required this.animation,
    required this.frame,
    required this.dark,
    this.cornerRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            key: const ValueKey('lesson-sparks'),
            painter: SparkPainter(
              animation: animation,
              frame: frame,
              cornerRadius: cornerRadius,
              dark: dark,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

/// Where the ray from [frame]'s centre at [angle] leaves its (inflated)
/// outline, and the outward direction there.
({Offset point, Offset normal}) _rimAt(
    Rect frame, double angle, double inflate) {
  final direction = Offset(math.cos(angle), math.sin(angle));
  final halfW = frame.width / 2 + inflate;
  final halfH = frame.height / 2 + inflate;
  final t = math.min(
    halfW / math.max(direction.dx.abs(), 1e-6),
    halfH / math.max(direction.dy.abs(), 1e-6),
  );
  return (point: frame.center + direction * t, normal: direction);
}

/// The head of the comet, as an angle round the card, at progress [p]. It
/// starts at the top and goes clockwise, once.
double _headAngle(double p) =>
    -math.pi / 2 + 2 * math.pi * LessonCelebration.turnsAt(p);

@visibleForTesting
class AuraPainter extends CustomPainter {
  final Animation<double> animation;
  final Rect frame;
  final double cornerRadius;
  final bool dark;

  AuraPainter({
    required this.animation,
    required this.frame,
    required this.cornerRadius,
    required this.dark,
  }) : super(repaint: animation);

  @visibleForTesting
  static int get blobCount => _blobs.length;

  /// Blob [index]'s place and look at progress [p]: its centre on screen, its
  /// scale (perspective) and how far it is, 0 at the back and 1 at the front.
  /// Exposed so a test can check the depth the picture claims to have.
  @visibleForTesting
  static ({
    Offset centre,
    double scale,
    double depth,
    double tangent
  }) blobPoseAt(int index, double p, Rect frame) =>
      _pose(_blobs[index], p, frame);

  static ({Offset centre, double scale, double depth, double tangent}) _pose(
      _Blob blob, double p, Rect frame) {
    final turns = LessonCelebration.turnsAt(p);
    final angle =
        blob.phase + blob.direction * blob.lapRatio * 2 * math.pi * turns;
    final ring = blob.ring;
    final halfW = frame.width / 2 * ring.reachX;
    // Chosen so the PROJECTED ring spans the card's height, whatever the tilt.
    final halfH = frame.height / 2 * ring.reachY / math.cos(ring.tilt);
    // A point on the ring, in the ring's own plane.
    final px = halfW * math.cos(angle);
    final py = halfH * math.sin(angle);
    // Tilt the plane about the horizontal axis: y shortens, and depth appears.
    var x = px;
    final y = py * math.cos(ring.tilt);
    var z = py * math.sin(ring.tilt);
    // Precess about the vertical axis as the lap goes on.
    final precession = ring.precession * turns;
    final x2 = x * math.cos(precession) + z * math.sin(precession);
    final z2 = -x * math.sin(precession) + z * math.cos(precession);
    x = x2;
    z = z2;
    // Perspective: the eye is a few ring-radii away, so near is bigger.
    final reach = math.max(halfW, halfH);
    final eye = reach * 3.2;
    final scale = eye / (eye - z);
    final centre = frame.center + Offset(x * scale, y * scale);
    final depth = (z / reach).clamp(-1.0, 1.0) * 0.5 + 0.5;
    // Which way it is heading on screen, for the streak.
    const d = 0.01;
    final next = angle + blob.direction * d;
    final nx = halfW * math.cos(next);
    final ny = halfH * math.sin(next) * math.cos(ring.tilt);
    final tangent = math.atan2(ny - y, nx - px);
    return (centre: centre, scale: scale, depth: depth, tangent: tangent);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = animation.value;
    if (p <= 0) return;
    final glow = LessonCelebration.glowAt(p);
    final speed = LessonCelebration.speedAt(p);
    final halfW = frame.width / 2;

    final poses = [
      for (final blob in _blobs) (blob: blob, pose: _pose(blob, p, frame)),
    ]..sort((a, b) => a.pose.depth.compareTo(b.pose.depth));

    for (final entry in poses) {
      final blob = entry.blob;
      final pose = entry.pose;
      // Nearer is brighter, farther is dimmer: the depth you can see.
      final brightness = (0.62 + 0.38 * pose.depth) * glow * blob.alpha;
      final radius = blob.radius * halfW * pose.scale;
      // Smeared along the orbit while it is fast.
      final streak = 1 + 1.1 * speed * speed;
      canvas.save();
      canvas.translate(pose.centre.dx, pose.centre.dy);
      canvas.rotate(pose.tangent);
      canvas.scale(streak, 1 / math.sqrt(streak));
      canvas.drawCircle(
        Offset.zero,
        radius,
        Paint()
          ..blendMode = dark ? BlendMode.plus : BlendMode.srcOver
          ..shader = ui.Gradient.radial(
            Offset.zero,
            radius,
            [
              blob.color.withValues(
                  alpha: ((dark ? 0.95 : 0.95) * brightness).clamp(0.0, 1.0)),
              blob.color.withValues(
                  alpha: ((dark ? 0.55 : 0.60) * brightness).clamp(0.0, 1.0)),
              blob.color.withValues(
                  alpha: ((dark ? 0.18 : 0.22) * brightness).clamp(0.0, 1.0)),
              blob.color.withValues(alpha: 0),
            ],
            const [0.0, 0.32, 0.66, 1.0],
          ),
      );
      canvas.restore();
    }

    _paintComet(canvas, p, glow);
  }

  /// The card's rim, lit by a comet lapping it: a wide soft bloom, then a thin
  /// crisp filament, both on a sweep whose bright head leads and whose tail
  /// fades away behind it. Half of each stroke is hidden by the card itself,
  /// which is what makes the edge look lit from behind.
  void _paintComet(Canvas canvas, double p, double glow) {
    final head = _headAngle(p);
    final turns = LessonCelebration.turnsAt(p);
    // Fully there while the lap runs, gone with it: nothing circles at rest.
    final lap =
        (1 - ((turns - 0.9) / 0.1).clamp(0.0, 1.0)) * math.min(1.0, p / 0.05);
    if (lap <= 0.002) return;
    final rim = RRect.fromRectAndRadius(
      frame.inflate(4),
      Radius.circular(cornerRadius + 4),
    );
    final sweep = ui.Gradient.sweep(
      frame.center,
      [
        _cyan.withValues(alpha: 0),
        _cyan.withValues(alpha: 0),
        _electric.withValues(alpha: 0.35 * lap),
        _cyan.withValues(alpha: 0.85 * lap),
        _ice.withValues(alpha: lap),
        _ice.withValues(alpha: lap),
      ],
      const [0.0, 0.66, 0.82, 0.93, 0.985, 1.0],
      TileMode.clamp,
      0,
      2 * math.pi,
      // Turned about the card's centre, so the seam (the comet's head) lands on
      // `head` and the tail fades away behind it.
      (Matrix4.translationValues(frame.center.dx, frame.center.dy, 0) *
              Matrix4.rotationZ(head) *
              Matrix4.translationValues(-frame.center.dx, -frame.center.dy, 0))
          .storage,
    );
    final blend = dark ? BlendMode.plus : BlendMode.srcOver;
    canvas.drawRRect(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..blendMode = blend
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9)
        ..shader = sweep,
    );
    canvas.drawRRect(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..blendMode = blend
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2)
        ..shader = sweep,
    );
    // The head itself: a small hot point riding the rim.
    final at = _rimAt(frame, head, 4).point;
    canvas.drawCircle(
      at,
      16,
      Paint()
        ..blendMode = blend
        ..shader = ui.Gradient.radial(at, 16, [
          _ice.withValues(alpha: 0.95 * lap * glow),
          _cyan.withValues(alpha: 0.35 * lap * glow),
          _cyan.withValues(alpha: 0),
        ], const [
          0.0,
          0.35,
          1.0
        ]),
    );
  }

  @override
  bool shouldRepaint(AuraPainter old) =>
      old.frame != frame ||
      old.dark != dark ||
      old.cornerRadius != cornerRadius ||
      old.animation != animation;
}

/// One spark: where it is born (on the rim, as the comet's head passes), how
/// long it lives, and how it moves.
class _Spark {
  /// The moment, as progress, it is shed.
  final double born;
  final double life;

  /// The comet's head is somewhere on the rim at [born]; the spark starts a
  /// little way round from it, at this many radians.
  final double scatter;

  /// How far in from the rim (negative) or out from it (positive) it starts.
  /// Half of them start inside the card, so they cross its face.
  final double inset;

  /// 0.6 (far) to 1.4 (near): scales size and speed, and dims the far ones.
  final double depth;

  /// Pixels per second at depth 1, before the drift.
  final double speed;

  /// How much of its heading is "up" rather than "outward", 0..1.
  final double lift;
  final double wobblePhase;
  final bool glint;

  const _Spark(this.born, this.life, this.scatter, this.inset, this.depth,
      this.speed, this.lift, this.wobblePhase, this.glint);
}

/// A fixed set, so the picture is the same every time and a test can pin it.
final List<_Spark> _sparks = () {
  final random = math.Random(2718);
  const count = 18;
  return List<_Spark>.generate(count, (i) {
    // Spread through the lap rather than all at once: a trail, not a burst.
    final born = 0.045 + 0.56 * (i + random.nextDouble() * 0.8) / count;
    return _Spark(
      born,
      0.22 + random.nextDouble() * 0.14,
      (random.nextDouble() - 0.5) * 0.7,
      i.isEven
          ? -(14 + random.nextDouble() * 70)
          : 4 + random.nextDouble() * 18,
      0.6 + random.nextDouble() * 0.8,
      46 + random.nextDouble() * 70,
      0.35 + random.nextDouble() * 0.45,
      random.nextDouble() * 2 * math.pi,
      i % 5 == 2,
    );
  });
}();

@visibleForTesting
class SparkPainter extends CustomPainter {
  final Animation<double> animation;
  final Rect frame;
  final double cornerRadius;
  final bool dark;

  SparkPainter({
    required this.animation,
    required this.frame,
    required this.cornerRadius,
    required this.dark,
  }) : super(repaint: animation);

  /// Sparks that are alight at progress [p]. A test holds this to "a few", so a
  /// later tweak cannot quietly turn the effect into a storm.
  @visibleForTesting
  static int aliveAt(double p) =>
      _sparks.where((s) => p >= s.born && p < s.born + s.life).length;

  @visibleForTesting
  static int get total => _sparks.length;

  @override
  void paint(Canvas canvas, Size size) {
    final p = animation.value;
    // Nothing before it starts, and nothing once it has settled: at rest the
    // card has only its still halo.
    if (p <= 0 || p >= 1) return;
    final seconds = LessonCelebration.duration.inMilliseconds / 1000;
    for (final spark in _sparks) {
      final age = (p - spark.born) / spark.life;
      if (age < 0 || age >= 1) continue;
      final elapsed = (p - spark.born) * seconds;
      // Born on the rim where the comet's head was, a little to either side.
      final head = _headAngle(spark.born) + spark.scatter * 0.25;
      final rim = _rimAt(frame, head, spark.inset);
      final outward = rim.normal;
      final up = const Offset(0, -1);
      final heading = outward * (1 - spark.lift) + up * spark.lift;
      final unit = heading / heading.distance;
      final across = Offset(-unit.dy, unit.dx);
      final travel = spark.speed * spark.depth * elapsed;
      final wobble = math.sin(spark.wobblePhase + elapsed * 3.1) *
          6 *
          spark.depth *
          math.min(1.0, elapsed * 2);
      // A little buoyancy: they rise a touch faster the longer they live.
      final at = rim.point +
          unit * travel +
          across * wobble +
          Offset(0, -9 * elapsed * elapsed);
      // In: quick. Out: long, and not linear, so they melt instead of switch.
      final fadeIn = (age / 0.14).clamp(0.0, 1.0);
      final fadeOut = math.pow(1 - age, 1.4).toDouble();
      final twinkle = 0.86 + 0.14 * math.sin(elapsed * 17 + spark.wobblePhase);
      final far = 0.55 + 0.45 * ((spark.depth - 0.6) / 0.8);
      final alpha = (fadeIn * fadeOut * twinkle * far).clamp(0.0, 1.0);
      final core = 1.5 + 1.7 * spark.depth;
      // Light on a dark card; deep blue, laid on top, on a pale one.
      final heart = dark ? _ice : _ultramarine;
      final halo = dark ? _cyan : _electric;
      canvas.drawCircle(
        at,
        core * 4.2,
        Paint()
          ..blendMode = dark ? BlendMode.plus : BlendMode.srcOver
          ..shader = ui.Gradient.radial(at, core * 4.2, [
            halo.withValues(alpha: (dark ? 0.34 : 0.30) * alpha),
            _electric.withValues(alpha: (dark ? 0.10 : 0.10) * alpha),
            _electric.withValues(alpha: 0),
          ], const [
            0.0,
            0.45,
            1.0
          ]),
      );
      canvas.drawCircle(
        at,
        core,
        Paint()..color = heart.withValues(alpha: (dark ? 0.92 : 0.85) * alpha),
      );
      if (spark.glint) {
        // A four-point glint, thin, that turns as it fades.
        final length = core * 4.2 * (0.6 + 0.4 * fadeIn);
        final turn = elapsed * 1.6 + spark.wobblePhase;
        final line = Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 0.9
          ..color = (dark ? _ice : _electric).withValues(alpha: 0.7 * alpha);
        for (var k = 0; k < 2; k++) {
          final a = turn + k * math.pi / 2;
          final d = Offset(math.cos(a), math.sin(a)) * length;
          canvas.drawLine(at - d, at + d, line);
        }
      }
    }
  }

  @override
  bool shouldRepaint(SparkPainter old) =>
      old.frame != frame ||
      old.cornerRadius != cornerRadius ||
      old.animation != animation;
}
