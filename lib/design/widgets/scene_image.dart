import 'dart:async';
import 'package:flutter/material.dart';
import '../themes.dart';
import 'bundled_art.dart';

/// A packaged scene with slow camera motion, or the current theme while absent.
/// Can fill a bounded background or wrap content with an intrinsic height.
class SceneArt extends StatefulWidget {
  final String scene;
  final Widget? child;
  final Widget? fallback;
  final bool animate;
  const SceneArt(
      {super.key,
      required this.scene,
      this.child,
      this.fallback,
      this.animate = true});
  @override
  State<SceneArt> createState() => _SceneArtState();
}

class _SceneArtState extends State<SceneArt>
    with SingleTickerProviderStateMixin {
  late final _camera =
      AnimationController(vsync: this, duration: const Duration(seconds: 20));
  AssetBundle? _bundle;
  String? _path;
  int _generation = 0;
  bool _available = false, _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_load());
    _syncMotion();
  }

  @override
  void didUpdateWidget(SceneArt old) {
    super.didUpdateWidget(old);
    if (old.scene != widget.scene) unawaited(_load());
    _syncMotion();
  }

  Future<void> _load() async {
    final bundle = DefaultAssetBundle.of(context);
    final path = HolyArtAssets.scenePath(widget.scene);
    if (identical(bundle, _bundle) && path == _path) return;
    _bundle = bundle;
    _path = path;
    _available = false;
    _failed = false;
    final generation = ++_generation;
    _syncMotion();
    if (path == null) return;
    final exists = await HolyArtAssets.contains(bundle, path);
    if (!mounted || generation != _generation) return;
    setState(() => _available = exists);
    _syncMotion();
  }

  void _syncMotion() {
    if (_available &&
        !_failed &&
        widget.animate &&
        !MediaQuery.disableAnimationsOf(context)) {
      if (!_camera.isAnimating) _camera.repeat(reverse: true);
    } else {
      _camera.stop();
      _camera.value = .25;
    }
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = HolyThemeScope.of(context);
    final fallback = widget.fallback ??
        DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
              theme.colors.first,
              theme.colors[1],
              theme.colors[3]
            ])));
    Widget image = fallback;
    if (_available && !_failed && _path != null) {
      image = Image.asset(_path!,
          bundle: _bundle,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          gaplessPlayback: true, errorBuilder: (_, error, stack) {
        if (!_failed) {
          final generation = _generation;
          scheduleMicrotask(() {
            if (mounted && generation == _generation) {
              setState(() => _failed = true);
              _syncMotion();
            }
          });
        }
        return fallback;
      });
    }
    return ClipRect(
        child: Stack(
            fit: widget.child == null ? StackFit.expand : StackFit.passthrough,
            children: [
          Positioned.fill(
              child: IgnorePointer(
                  child: AnimatedBuilder(
                      animation: _camera,
                      child: image,
                      builder: (context, child) => Transform.translate(
                          offset: Offset((_camera.value - .5) * 8,
                              (_camera.value - .5) * -10),
                          child: Transform.scale(
                              scale: 1.035 + _camera.value * .025,
                              child: child))))),
          if (theme.isDark && _available && !_failed)
            Positioned.fill(
                child: IgnorePointer(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                  theme.colors.first.withValues(alpha: .88),
                  theme.colors[1].withValues(alpha: .72),
                  theme.colors[2].withValues(alpha: .56)
                ],
                                stops: const [
                  0,
                  .55,
                  1
                ]))))),
          if (widget.child != null) widget.child!
        ]));
  }
}
