import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../themes.dart';
import 'animated_mesh_background.dart';
import 'backdrop_host.dart';
import 'particle_field.dart';

/// The cool blue of the hour before sunrise, the light every mesh is built on.
const _blueHour = Color(0xFF2B4468);
const _blueHourLight = Color(0xFFB9C7D8);

extension HolyMesh on HolyTheme {
  /// One mesh per home tab, all from the reader's theme: blue hour on the
  /// walk, slate for the brothers, brass on the board, pine for growth and
  /// charcoal and brass on the profile. Fractional [page] values blend
  /// neighbours, so a swipe carries the light across.
  MeshTheme meshAt(double page) {
    const n = 5;
    final p = page % n;
    final a = p.floor() % n, b = (a + 1) % n;
    return MeshTheme.lerp(_meshFor(a), _meshFor(b), p - p.floor());
  }

  MeshTheme _meshFor(int tab) {
    final cool = isDark ? _blueHour : _blueHourLight;
    final glow = switch (tab) {
      0 => Color.lerp(cool, accent, .18)!,
      1 => Color.lerp(cool, const Color(0xFF4B5D86), .5)!,
      2 => accent,
      3 => olive,
      _ => Color.lerp(cool, accent, .45)!,
    };
    final strength = isDark ? 1.0 : .62;
    Color mix(Color a, Color b, double x) => Color.lerp(a, b, x * strength)!;
    return MeshTheme(
      baseColors: [
        sunk,
        mix(surface, glow, .22),
        mix(paper, glow, .30),
        mix(surface, cool, .16),
        sunk,
      ],
      b1Start: glow.withValues(alpha: .34 * strength),
      b1End: glow.withValues(alpha: 0),
      b2Start: cool.withValues(alpha: .30 * strength),
      b2End: sunk.withValues(alpha: 0),
      b3Start: accent.withValues(alpha: (tab == 2 ? .30 : .18) * strength),
      b3End: accent.withValues(alpha: 0),
      b4Start: accent.withValues(alpha: (tab == 0 ? .30 : .20) * strength),
      b4Mid: glow.withValues(alpha: .10 * strength),
      b4End: paper.withValues(alpha: 0),
    );
  }
}

/// The living field behind the home tabs: Cognein's drifting mesh in the
/// reader's colours, a slow fall of embers, and a shade that keeps text
/// readable. It also publishes the field's colour to [BackdropHost], so the
/// glass header fades into the page rather than into a flat slab.
class HolyAtmosphere extends StatefulWidget {
  /// The home pager's position; fractional while a swipe is under way.
  final ValueListenable<double> page;
  final Widget child;
  final bool embers;
  const HolyAtmosphere(
      {super.key, required this.page, required this.child, this.embers = true});

  @override
  State<HolyAtmosphere> createState() => _HolyAtmosphereState();
}

class _HolyAtmosphereState extends State<HolyAtmosphere> {
  final _tint = ValueNotifier<Color>(const Color(0xFF0E1217));

  @override
  void dispose() {
    _tint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final opaque = HolyThemeScope.opaqueOf(context);
    _tint.value = t.paper;
    return BackdropHost(
        tint: _tint,
        child: Stack(fit: StackFit.expand, children: [
          ColoredBox(color: t.paper),
          if (!opaque)
            IgnorePointer(
                child: ValueListenableBuilder<double>(
                    valueListenable: widget.page,
                    builder: (context, page, _) =>
                        AnimatedMeshBackground(theme: t.meshAt(page)))),
          // Keeps the mesh a light behind the page, never a pattern on it.
          IgnorePointer(
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                t.paper.withValues(alpha: t.isDark ? .30 : .18),
                t.paper.withValues(alpha: t.isDark ? .12 : .06),
                t.paper.withValues(alpha: t.isDark ? .42 : .30),
              ],
                          stops: const [0, .45, 1])))),
          if (widget.embers && !opaque)
            IgnorePointer(
                child: ParticleField(
                    config: ParticleConfig(
                        count: 26,
                        color: t.particle,
                        blurSigma: 1.1,
                        minSize: 1.1,
                        maxSize: 2.8,
                        speed: .16,
                        horizontalOscillation: 12))),
          widget.child,
        ]));
  }
}
