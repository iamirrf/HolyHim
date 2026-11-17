import 'package:flutter/material.dart';
import '../themes.dart';
import 'backdrop_host.dart';
import 'sunrise_background.dart';

/// The living field behind a screen: the theme's moving mesh, the same one
/// on every screen.
///
/// Each screen family mounts its own, and routes stay opaque, so the iOS
/// slide, the back swipe and shared-element flights behave as they always
/// have. The mesh and its particles are seeded from the clock, so every copy
/// shows the same field at the same moment and a route change does not read
/// as a new background.
///
/// Inside another backdrop this paints nothing and lets the outer field show
/// through. It publishes the field's top colour through [BackdropHost], which
/// is what glass bars tint themselves with.
class HolyBackdrop extends StatefulWidget {
  final Widget child;

  /// Pulls the field toward paper, for screens that set small text on it.
  final bool calm;
  const HolyBackdrop({super.key, required this.child, this.calm = false});

  @override
  State<HolyBackdrop> createState() => _HolyBackdropState();
}

class _HolyBackdropState extends State<HolyBackdrop> {
  final _tint = ValueNotifier<Color>(const Color(0x00000000));

  double get _calm => widget.calm ? SunriseBackground.calmField : 0;

  void _sync() {
    final t = HolyThemeScope.of(context);
    _tint.value = HolyThemeScope.opaqueOf(context)
        ? t.paper
        : SunriseBackground.topColor(t, calm: _calm);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(HolyBackdrop old) {
    super.didUpdateWidget(old);
    if (old.calm != widget.calm) _sync();
  }

  @override
  void dispose() {
    _tint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (BackdropHost.isHosted(context)) return widget.child;
    final t = HolyThemeScope.of(context);
    return Stack(fit: StackFit.expand, children: [
      // Reduce Transparency and Increase Contrast ask for a plain page.
      if (HolyThemeScope.opaqueOf(context))
        ColoredBox(color: t.paper)
      else
        SunriseBackground(
            theme: t, calm: _calm, child: const SizedBox.shrink()),
      BackdropHost(tint: _tint, child: widget.child),
    ]);
  }
}

/// Paper for a surface on its own; clear when a backdrop is painting the
/// field behind it.
Color backdropPaper(BuildContext context, HolyTheme t) =>
    BackdropHost.isHosted(context) ? Colors.transparent : t.paper;
