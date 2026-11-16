// Ported from Cognein; see store/v2-design-ports.json.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Appearance and motion of a [ParticleField].
@immutable
class ParticleConfig {
  final int count;
  final Color color;
  final double minSize;
  final double maxSize;

  /// Pixels moved per frame along [drift], before per-particle variation.
  final double speed;

  /// Direction of travel. `Offset(0, -1)` floats upward.
  final Offset drift;

  /// Fades particles out near the top and bottom edges.
  final bool fadeEdges;

  /// Amplitude, in pixels, of the horizontal sine sway.
  final double horizontalOscillation;

  /// Seconds for one full sway cycle.
  final double oscillationPeriod;

  /// Soft-focus radius applied to each particle.
  final double blurSigma;

  const ParticleConfig({
    this.count = 25,
    this.color = const Color(0x4DFFFFFF),
    this.minSize = 1.5,
    this.maxSize = 4.0,
    this.speed = 0.3,
    this.drift = const Offset(0, -1),
    this.fadeEdges = true,
    this.horizontalOscillation = 15.0,
    this.oscillationPeriod = 10.0,
    this.blurSigma = 0,
  });
}

/// A drifting field of soft dots, painted on a single canvas.
///
/// Kept in its own [RepaintBoundary] so the per-frame repaint never dirties the
/// (much more expensive) blurred mesh background behind it.
///
/// Renders a single static frame when the platform requests reduced motion.
class ParticleField extends StatefulWidget {
  final ParticleConfig config;

  const ParticleField({super.key, this.config = const ParticleConfig()});

  @override
  State<ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<ParticleField>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final math.Random _random = math.Random();
  List<_Particle> _particles = const [];
  Size _lastSize = Size.zero;
  double _seconds = 0;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() => _seconds = elapsed.inMilliseconds / 1000.0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  /// Particles are seeded from the laid-out size, and re-seeded when it changes
  /// (rotation, split screen) so they never cluster in a stale rectangle.
  void _ensureParticles(Size size) {
    if (_particles.isNotEmpty && size == _lastSize) return;
    _lastSize = size;
    _particles = List<_Particle>.generate(
      widget.config.count,
      (_) => _Particle(
        x: _random.nextDouble() * size.width,
        y: _random.nextDouble() * size.height,
        size: widget.config.minSize +
            _random.nextDouble() *
                (widget.config.maxSize - widget.config.minSize),
        alpha: 0.2 + _random.nextDouble() * 0.4,
        phase: _random.nextDouble() * math.pi * 2,
        speedMultiplier: 0.7 + _random.nextDouble() * 0.6,
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (!size.isEmpty) _ensureParticles(size);
          return CustomPaint(
            size: size,
            painter: _ParticlePainter(
              particles: _particles,
              config: widget.config,
              time: _seconds,
              bounds: size,
              animate: !_reduceMotion,
            ),
          );
        },
      ),
    );
  }
}

class _Particle {
  double x;
  double y;
  final double size;
  final double alpha;
  final double phase;
  final double speedMultiplier;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.alpha,
    required this.phase,
    required this.speedMultiplier,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final ParticleConfig config;
  final double time;
  final Size bounds;
  final bool animate;

  _ParticlePainter({
    required this.particles,
    required this.config,
    required this.time,
    required this.bounds,
    required this.animate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = config.blurSigma > 0
          ? MaskFilter.blur(BlurStyle.normal, config.blurSigma)
          : null;
    for (final particle in particles) {
      if (animate) {
        particle.x += config.drift.dx * config.speed * particle.speedMultiplier;
        particle.y += config.drift.dy * config.speed * particle.speedMultiplier;
        particle.x +=
            math.sin(time / config.oscillationPeriod + particle.phase) *
                config.horizontalOscillation *
                0.01;

        // Wrap rather than respawn, so density stays constant.
        if (particle.y < -10) particle.y = bounds.height + 10;
        if (particle.y > bounds.height + 10) particle.y = -10;
        if (particle.x < -10) particle.x = bounds.width + 10;
        if (particle.x > bounds.width + 10) particle.x = -10;
      }

      var alpha = particle.alpha;
      if (config.fadeEdges && bounds.height > 0) {
        const edgeMargin = 40.0;
        final topFade = (particle.y / edgeMargin).clamp(0.0, 1.0);
        final bottomFade =
            ((bounds.height - particle.y) / edgeMargin).clamp(0.0, 1.0);
        alpha *= topFade * bottomFade;
      }
      if (alpha <= 0) continue;

      paint.color = config.color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(particle.x, particle.y), particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      animate || oldDelegate.bounds != bounds;
}
