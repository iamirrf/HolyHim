import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../haptics.dart';
import '../motion.dart';

/// Cognein's velocity-preserving press spring, with finger-local depth tilt.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final BorderRadius borderRadius;
  final String? semanticLabel;
  final bool selected, haptic;
  final double pressedScale;
  final Key? interactionKey;
  const Pressable(
      {super.key,
      required this.child,
      required this.onPressed,
      this.borderRadius = BorderRadius.zero,
      this.semanticLabel,
      this.selected = false,
      this.haptic = true,
      this.pressedScale = .96,
      this.interactionKey});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final _scale = AnimationController.unbounded(vsync: this, value: 1);
  Offset _tilt = Offset.zero;
  bool _pressed = false;
  void _highlight(bool down) {
    if (_pressed == down || widget.onPressed == null) return;
    _pressed = down;
    if (down && widget.haptic) HolyHaptics.detent();
    if (MediaQuery.disableAnimationsOf(context)) {
      _scale.value = 1;
      return;
    }
    if (down) {
      _scale.animateTo(widget.pressedScale,
          duration: HolyMotion.pressIn, curve: HolyMotion.pressInCurve);
    } else {
      _scale.animateWith(SpringSimulation(
          HolyMotion.pressRelease, _scale.value, 1, _scale.velocity));
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      enabled: widget.onPressed != null,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: LayoutBuilder(
          builder: (context, c) => Listener(
              onPointerDown: (e) {
                if (MediaQuery.disableAnimationsOf(context) ||
                    widget.onPressed == null) {
                  return;
                }
                final w = c.hasBoundedWidth ? c.maxWidth : 200.0,
                    h = c.hasBoundedHeight ? c.maxHeight : 80.0;
                _tilt = Offset(((e.localPosition.dx / w) - .5) * 2,
                    ((e.localPosition.dy / h) - .5) * 2);
              },
              child: AnimatedBuilder(
                  animation: _scale,
                  child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                          key: widget.interactionKey,
                          onTap: widget.onPressed,
                          onHighlightChanged: _highlight,
                          borderRadius: widget.borderRadius,
                          splashFactory: NoSplash.splashFactory,
                          highlightColor: Colors.transparent,
                          child: widget.child)),
                  builder: (context, child) {
                    final force = ((1 - _scale.value) / .04).clamp(-.2, 1.0);
                    return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, .001)
                          ..rotateX(-_tilt.dy * math.pi / 45 * force)
                          ..rotateY(_tilt.dx * math.pi / 45 * force)
                          ..scaleByDouble(_scale.value, _scale.value, 1, 1),
                        child: child);
                  }))));
}
