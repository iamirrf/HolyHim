// Ported from the pinned Cognein pulsing-dots implementation.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Which kind of surface a loader is drawn on.
///
/// The brand palette is pale (`#B3D4FC`), which is right on the app's dark
/// backdrops and close to invisible on a light card (1.4:1). [auto] follows the
/// theme, which is correct for most screens. Surfaces that are dark whatever the
/// user's theme setting - onboarding, auth, the paywall, splash, the startup
/// gate, video - must say [onDark], for the same reason `GlassBackButton` has
/// `onDarkSurface`: they paint their own backdrop and never follow the theme.
enum LoaderTone { auto, onDark, onLight }

/// The colours of one loader.
@immutable
class DotsPalette {
  /// [ring] is the expanding halo. Its opacity comes from [ringAlpha] (scaled
  /// down as the halo grows), not from the colour's own alpha.
  const DotsPalette({
    required this.rest,
    required this.peak,
    required this.ring,
    this.ringAlpha = 0.7,
  });

  /// A single foreground colour, for a loader sitting on a coloured button or
  /// card where the brand blues would clash. Dots swell from a translucent
  /// [foreground] to a solid one.
  factory DotsPalette.onColor(Color foreground) => DotsPalette(
        rest: foreground.withValues(alpha: 0.55),
        peak: foreground,
        ring: foreground,
        ringAlpha: 0.45,
      );

  final Color rest;
  final Color peak;
  final Color ring;
  final double ringAlpha;

  /// The brand loader, exactly as specified: `#B3D4FC` swelling to `#6793FB`,
  /// with a `rgba(178, 212, 252, .7)` halo.
  static const DotsPalette brand = DotsPalette(
    rest: Color(0xFFDCAFC4),
    peak: Color(0xFF9C456B),
    ring: Color(0xFFF2D0DF),
  );

  /// The same hues, deepened until they read on a light surface. Held by a
  /// contrast test (rest >= 2.2:1, peak >= 4.5:1 on the light scaffold and card
  /// colours) so a later tweak cannot quietly make the loader invisible again.
  static const DotsPalette brandOnLight = DotsPalette(
    rest: Color(0xFFB47994),
    peak: Color(0xFF9C456B),
    ring: Color(0xFFC68CA7),
    ringAlpha: 0.55,
  );

  @override
  bool operator ==(Object other) =>
      other is DotsPalette &&
      other.rest == rest &&
      other.peak == peak &&
      other.ring == ring &&
      other.ringAlpha == ringAlpha;

  @override
  int get hashCode => Object.hash(rest, peak, ring, ringAlpha);
}

/// Where one dot is in the wave, as a pure function of time.
///
/// Kept out of the painter so the timing is testable without pixels. The
/// motion is one smooth sine over 1.6s, so a dot has no plateau or kink to
/// catch the eye anywhere in the loop: it eases up to a soft crest and back
/// down with the same gentleness, and each dot follows the one before it by
/// a fraction of a beat, which reads as a slow ripple rather than a pulse.
@immutable
class DotPulse {
  const DotPulse._(this.progress);

  /// The whole loop.
  static const Duration period = Duration(milliseconds: 1600);
  static const double periodSeconds = 1.6;

  /// Each dot trails the one before it by this much. Small enough that the
  /// whole row is inside one swell (five dots span about a third of a cycle),
  /// so the ripple travels smoothly instead of the dots looking like separate
  /// blinkers.
  static const double firstDelaySeconds = -0.32;
  static const double staggerSeconds = 0.13;

  /// A negative delay means the dot is already that far into its cycle.
  static double delayOf(int index) =>
      firstDelaySeconds + staggerSeconds * index;

  /// 0 = at rest (small, pale, halo collapsed); 1 = at the crest (full size,
  /// saturated, lifted, halo spread and faded).
  final double progress;

  /// The dot breathes between 70% and 100% of its size. The nominal size is the
  /// crest, so a loader is never bigger than the size it was asked for.
  double get scale => 0.7 + 0.3 * progress;

  /// How far the dot has floated up, as a fraction of its own diameter. A small
  /// lift on the crest is what makes the wave feel like it is moving rather
  /// than blinking.
  double get lift => 0.12 * progress;

  factory DotPulse.at(int index, double seconds) {
    // Dart's % is Euclidean, so a dot that has not "started" yet (positive
    // delay) still lands in [0, 1) rather than going negative.
    final u = ((seconds - delayOf(index)) / periodSeconds) % 1.0;
    // Cosine, not a cubic-bezier: it is smooth at the top and the bottom, and
    // exactly periodic.
    return DotPulse._(0.5 - 0.5 * math.cos(2 * math.pi * u));
  }
}

/// Five dots that breathe and glow in a slow travelling ripple. The app's one
/// loader.
///
/// Everything is proportional to [dotSize] (gap is half a dot, the halo and the
/// lift are a fraction of one), so the same animation reads at 12px on a page
/// and at 3px in a list row. The page-size loader is 84px wide; its halo and
/// lift bleed a little beyond the row, so give it an unclipped ancestor, or
/// turn [ring] off - the small presets in `AppLoader` do.
///
/// One controller and one painter per loader, repainting a single layer: it
/// costs the same whether it is a lone page loader or one of several. Runs only
/// while its ticker is enabled and animations are not reduced; otherwise it
/// paints one still frame, so a hidden tab or a reduce-motion user pays nothing
/// and still sees a loader.
///
/// Deliberately depends on nothing but Flutter: `StartupGate` shows it before
/// Riverpod, ScreenUtil or the app's theme exist.
class PulsingDotsLoader extends StatefulWidget {
  const PulsingDotsLoader({
    super.key,
    this.dotSize = 12,
    this.count = 5,
    this.tone = LoaderTone.auto,
    this.palette,
    this.ring = true,
    this.semanticsLabel = 'Loading',
  })  : assert(dotSize > 0),
        assert(count > 0);

  final double dotSize;
  final int count;
  final LoaderTone tone;

  /// Overrides [tone]. Use [DotsPalette.onColor] on a coloured surface.
  final DotsPalette? palette;

  /// Whether the halo is drawn. Off for small sizes, where it would be cropped
  /// by the button or avatar the loader sits in.
  final bool ring;

  /// Announced by screen readers. Pass null when the loader sits inside a
  /// control that already describes its own busy state (a button), so the two
  /// do not talk over each other.
  final String? semanticsLabel;

  /// The width of a row of [count] dots, with a half-dot gap.
  static double widthFor(double dotSize, {int count = 5}) =>
      count * dotSize + (count - 1) * dotSize / 2;

  /// The palette a loader with these settings draws in under [context].
  /// Public so the tone rules can be tested without reading pixels.
  @visibleForTesting
  static DotsPalette paletteFor(
    BuildContext context, {
    LoaderTone tone = LoaderTone.auto,
    DotsPalette? palette,
  }) {
    if (palette != null) return palette;
    final onDark = switch (tone) {
      LoaderTone.onDark => true,
      LoaderTone.onLight => false,
      LoaderTone.auto => Theme.of(context).brightness == Brightness.dark,
    };
    return onDark ? DotsPalette.brand : DotsPalette.brandOnLight;
  }

  @override
  State<PulsingDotsLoader> createState() => _PulsingDotsLoaderState();
}

class _PulsingDotsLoaderState extends State<PulsingDotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: DotPulse.period);

  /// The frame shown when the loop is not running: 0.32s in, where the first dot
  /// is just short of its crest and the last has barely started, so the wave is
  /// spread across the row (and every dot still has a halo) rather than every
  /// dot sitting at the same size.
  static const double _stillFrame = 0.32 / DotPulse.periodSeconds;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final run = TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (run) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
      _clock.value = _stillFrame;
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Natural size when the parent is loose; centred, not stretched, when it is
    // tight (an Expanded, a SizedBox with a width, a Column that stretches its
    // children). A bare CustomPaint would take the parent's whole width and
    // leave the dots against its left edge.
    final dots = Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox(
        width: PulsingDotsLoader.widthFor(widget.dotSize, count: widget.count),
        height: widget.dotSize,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _DotsPainter(
              clock: _clock,
              dotSize: widget.dotSize,
              count: widget.count,
              palette: PulsingDotsLoader.paletteFor(
                context,
                tone: widget.tone,
                palette: widget.palette,
              ),
              ring: widget.ring,
            ),
          ),
        ),
      ),
    );
    final label = widget.semanticsLabel;
    if (label == null) return ExcludeSemantics(child: dots);
    return Semantics(label: label, liveRegion: true, child: dots);
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter({
    required this.clock,
    required this.dotSize,
    required this.count,
    required this.palette,
    required this.ring,
  }) : super(repaint: clock);

  final Animation<double> clock;
  final double dotSize;
  final int count;
  final DotsPalette palette;
  final bool ring;

  @override
  void paint(Canvas canvas, Size size) {
    final seconds = clock.value * DotPulse.periodSeconds;
    final radius = dotSize / 2;
    final pitch = dotSize + dotSize / 2;
    final centerY = size.height / 2;
    final dot = Paint();
    final halo = Paint()..style = PaintingStyle.stroke;

    for (var i = 0; i < count; i++) {
      final pulse = DotPulse.at(i, seconds);
      final p = pulse.progress;
      // Floats up a little as it crests.
      final center = Offset(radius + i * pitch, centerY - dotSize * pulse.lift);
      final dotRadius = radius * pulse.scale;

      if (ring) {
        // The annulus just outside the dot, drawn as a stroke rather than a disc
        // under it, so a translucent dot never shows its own halo through
        // itself. It is a breath, not a ripple: it spreads to under a dot's
        // radius and is at most about 40% as bright as the palette says.
        final spread = radius * 0.8 * p * pulse.scale;
        final alpha = palette.ringAlpha * 0.6 * (1 - p);
        if (spread > 0.05 && alpha > 0.01) {
          halo
            ..strokeWidth = spread
            ..color = palette.ring.withValues(alpha: alpha);
          canvas.drawCircle(center, dotRadius + spread / 2, halo);
        }
      }

      dot.color = Color.lerp(palette.rest, palette.peak, p)!;
      canvas.drawCircle(center, dotRadius, dot);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.clock != clock ||
      old.dotSize != dotSize ||
      old.count != count ||
      old.palette != palette ||
      old.ring != ring;
}
