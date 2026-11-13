import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../themes.dart';

/// The light outside, by local hour. Photographs are tinted toward it so the
/// app feels like the same morning, afternoon or evening the reader is in.
enum DayLight { dawn, day, dusk, night }

DayLight dayLightAt(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 9) return DayLight.dawn;
  if (h >= 9 && h < 17) return DayLight.day;
  if (h >= 17 && h < 20) return DayLight.dusk;
  return DayLight.night;
}

/// A full-bleed photograph that behaves like light rather than a picture:
/// it exposes from dark on arrival, drifts slowly (Ken Burns), leans with
/// the phone (parallax), cross-dissolves when [images] advance, and is
/// tinted for the hour. Reduce Motion keeps only the dissolve.
class PhotoStage extends StatefulWidget {
  final List<String> images;

  /// Index into [images]. When null the stage advances on its own every
  /// [interval].
  final int? index;
  final Duration interval;
  final Alignment alignment;
  final bool expose;
  final bool parallax;
  final bool kenBurns;
  final bool timeOfDay;

  /// Strength of the darkening veil at the top and bottom edges (0 to 1),
  /// tuned so text never sits on a busy area.
  final double topVeil, bottomVeil;
  final Color veilColor;
  final Widget? child;
  final DateTime? now;
  const PhotoStage(
      {super.key,
      required this.images,
      this.index,
      this.interval = const Duration(seconds: 7),
      this.alignment = Alignment.center,
      this.expose = false,
      this.parallax = true,
      this.kenBurns = true,
      this.timeOfDay = true,
      this.topVeil = .35,
      this.bottomVeil = .55,
      this.veilColor = HolyTheme.photoShade,
      this.child,
      this.now});

  @override
  State<PhotoStage> createState() => _PhotoStageState();
}

class _PhotoStageState extends State<PhotoStage> with TickerProviderStateMixin {
  late final _drift = AnimationController(
      vsync: this, duration: const Duration(seconds: 24));
  late final _exposure = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));
  final _tilt = ValueNotifier(Offset.zero);
  StreamSubscription<AccelerometerEvent>? _sensor;
  Timer? _cycle;
  int _auto = 0;
  bool _reduced = false;

  int get _current => (widget.index ?? _auto) % widget.images.length;

  @override
  void initState() {
    super.initState();
    if (!widget.expose) _exposure.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reduced && (_drift.isAnimating || reduced)) {
      _precacheNext();
      return;
    }
    _reduced = reduced;
    if (reduced) {
      _drift.stop();
      _exposure.value = 1;
      _sensor?.cancel();
      _sensor = null;
      _tilt.value = Offset.zero;
    } else {
      if (widget.kenBurns) _drift.repeat(reverse: true);
      if (widget.expose && _exposure.value < 1) _exposure.forward();
      _listenTilt();
    }
    _schedule();
    _precacheNext();
  }

  void _listenTilt() {
    if (!widget.parallax || _sensor != null || kIsWeb) return;
    // iPhone only for now; Android parallax arrives with the Android build.
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      var smoothed = Offset.zero;
      _sensor = accelerometerEventStream(
              samplingPeriod: SensorInterval.uiInterval)
          .listen((e) {
        // Gravity along x/y gives the phone's lean; low-pass it heavily so
        // the picture floats instead of shaking.
        final target = Offset(
            (e.x / 9.8).clamp(-1.0, 1.0), ((e.y / 9.8) - .7).clamp(-1.0, 1.0));
        smoothed = Offset.lerp(smoothed, target, .06)!;
        _tilt.value = smoothed;
      }, onError: (_) {}, cancelOnError: true);
    } catch (_) {/* No sensor: the stage simply stays still. */}
  }

  void _schedule() {
    _cycle?.cancel();
    if (widget.index != null || widget.images.length < 2) return;
    _cycle = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      setState(() => _auto++);
      _precacheNext();
    });
  }

  void _precacheNext() {
    if (widget.images.length < 2) return;
    final next = widget.images[(_current + 1) % widget.images.length];
    precacheImage(AssetImage(next), context).catchError((Object _) {});
  }

  @override
  void didUpdateWidget(PhotoStage old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index || old.images.length != widget.images.length) {
      _schedule();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _precacheNext();
      });
    }
  }

  @override
  void dispose() {
    _cycle?.cancel();
    _sensor?.cancel();
    _drift.dispose();
    _exposure.dispose();
    _tilt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final light = dayLightAt(widget.now ?? DateTime.now());
    final asset = widget.images[_current];
    final photo = AnimatedSwitcher(
        duration: Duration(milliseconds: _reduced ? 400 : 1600),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: [...previous, if (current != null) current]),
        child: Image.asset(asset,
            key: ValueKey(asset),
            fit: BoxFit.cover,
            alignment: widget.alignment,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stack) =>
                const ColoredBox(color: Color(0xFFE9CFC4))));
    return ExcludeSemantics(
        excluding: true,
        child: ClipRect(
            child: Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: Color(0xFF2A1A20)),
          AnimatedBuilder(
              animation: Listenable.merge([_drift, _exposure, _tilt]),
              child: photo,
              builder: (context, child) {
                final d = Curves.easeInOut.transform(_drift.value);
                final e = Curves.easeOutCubic.transform(_exposure.value);
                // Push-in on exposure, then a slow breathing drift.
                final scale = 1.06 + .05 * d + (1 - e) * .06;
                final tilt = _tilt.value;
                return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..translateByDouble(
                          -tilt.dx * 12 + (d - .5) * 10, tilt.dy * 10, 0, 1)
                      ..scaleByDouble(scale, scale, 1, 1),
                    child: Opacity(opacity: .25 + .75 * e, child: child));
              }),
          if (widget.timeOfDay) _DayLightTint(light: light),
          if (widget.topVeil > 0 || widget.bottomVeil > 0)
            DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, .28, .55, 1],
                        colors: [
                  widget.veilColor.withValues(alpha: widget.topVeil),
                  widget.veilColor.withValues(alpha: widget.topVeil * .15),
                  widget.veilColor.withValues(alpha: widget.bottomVeil * .1),
                  widget.veilColor.withValues(alpha: widget.bottomVeil),
                ]))),
          if (widget.child != null) widget.child!,
        ])));
  }
}

class _DayLightTint extends StatelessWidget {
  final DayLight light;
  const _DayLightTint({required this.light});
  @override
  Widget build(BuildContext context) {
    final (Color color, double alpha, BlendMode mode) = switch (light) {
      DayLight.dawn => (const Color(0xFFFFC9A8), .10, BlendMode.softLight),
      DayLight.day => (const Color(0xFFFFF4E0), .0, BlendMode.softLight),
      DayLight.dusk => (const Color(0xFFE88A6A), .16, BlendMode.softLight),
      DayLight.night => (const Color(0xFF1C1A3A), .34, BlendMode.multiply),
    };
    if (alpha == 0) return const SizedBox.shrink();
    return IgnorePointer(
        child: DecoratedBox(
            decoration: BoxDecoration(
                color: color.withValues(alpha: alpha),
                backgroundBlendMode: mode),
            child: const SizedBox.expand()));
  }
}

/// Specks of light drifting up through the air, like dust in a sunbeam.
class LightMotes extends StatefulWidget {
  final int count;
  final Color color;
  final double opacity;
  const LightMotes(
      {super.key,
      this.count = 22,
      this.color = const Color(0xFFFFE2B8),
      this.opacity = 1});
  @override
  State<LightMotes> createState() => _LightMotesState();
}

class _LightMotesState extends State<LightMotes>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
      vsync: this, duration: const Duration(seconds: 60));
  late final List<_Mote> _motes = List.generate(widget.count, (i) {
    final r = math.Random(i * 7919 + 13);
    return _Mote(r.nextDouble(), r.nextDouble(), .4 + r.nextDouble() * 1.6,
        .006 + r.nextDouble() * .014, r.nextDouble() * math.pi * 2,
        .25 + r.nextDouble() * .55);
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: RepaintBoundary(
          child: CustomPaint(
              size: Size.infinite,
              painter: _MotePainter(
                  _clock, _motes, widget.color, widget.opacity))));
}

class _Mote {
  final double x, y, radius, speed, phase, alpha;
  const _Mote(this.x, this.y, this.radius, this.speed, this.phase, this.alpha);
}

class _MotePainter extends CustomPainter {
  final Animation<double> clock;
  final List<_Mote> motes;
  final Color color;
  final double opacity;
  _MotePainter(this.clock, this.motes, this.color, this.opacity)
      : super(repaint: clock);
  @override
  void paint(Canvas canvas, Size size) {
    final seconds = clock.value * 60;
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    for (final m in motes) {
      final y = (m.y - seconds * m.speed) % 1.0;
      final x = m.x + math.sin(seconds * .35 + m.phase) * .025;
      final twinkle = .55 + .45 * math.sin(seconds * 1.3 + m.phase * 3);
      // Fade in from the bottom and out near the top.
      final edge = (math.min(y, 1 - y) * 5).clamp(0.0, 1.0);
      paint.color =
          color.withValues(alpha: m.alpha * twinkle * edge * opacity);
      canvas.drawCircle(
          Offset(x * size.width, y * size.height), m.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_MotePainter old) => false;
}
