import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../themes.dart';
import 'animated_mesh_background.dart';
import 'particle_field.dart';
import 'backdrop_host.dart';

class Atmosphere extends StatefulWidget {
  final HolyTheme theme;
  final Widget child;
  final double mood;
  final ValueListenable<double>? moodListenable;
  final bool reduceTransparency;
  const Atmosphere(
      {super.key,
      required this.theme,
      required this.child,
      this.mood = 0,
      this.moodListenable,
      this.reduceTransparency = false});
  @override
  State<Atmosphere> createState() => _AtmosphereState();
}

class _AtmosphereState extends State<Atmosphere> {
  final _tint = ValueNotifier<Color>(HolyThemes.charcoal.colors.first);
  @override
  void dispose() {
    _tint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<HolyTheme>(
      tween: _ThemeTween(begin: widget.theme, end: widget.theme),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
      child: widget.child,
      builder: (context, theme, child) {
        _tint.value = theme.colors.first;
        return HolyThemeScope(
            theme: theme,
            reduceTransparency: widget.reduceTransparency,
            child: BackdropHost(
                tint: _tint,
                child: Stack(fit: StackFit.expand, children: [
                  IgnorePointer(
                      child: RepaintBoundary(
                          child: widget.moodListenable == null
                              ? AnimatedMeshBackground(
                                  theme: theme.meshAt(widget.mood))
                              : ValueListenableBuilder<double>(
                                  valueListenable: widget.moodListenable!,
                                  builder: (context, mood, _) =>
                                      AnimatedMeshBackground(
                                          theme: theme.meshAt(mood))))),
                  IgnorePointer(
                      child: ParticleField(
                          config: ParticleConfig(
                              count: 28,
                              color: theme.particle,
                              blurSigma: 1.2,
                              minSize: 1.3,
                              maxSize: 3.2,
                              speed: .18,
                              horizontalOscillation: 13))),
                  child!,
                ])));
      });
}

class _ThemeTween extends Tween<HolyTheme> {
  _ThemeTween({required HolyTheme super.begin, required HolyTheme super.end});
  @override
  HolyTheme lerp(double t) => HolyTheme.lerp(begin!, end!, t);
}
