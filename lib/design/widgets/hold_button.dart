import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../haptics.dart';
import '../themes.dart';
import '../typography.dart';

/// SunRize's hold-to-complete interaction with a 1.2s heartbeat ramp.
class HoldButton extends StatefulWidget {
  final String label;
  final VoidCallback onComplete;
  final Duration duration;
  final bool enabled, hapticOnComplete;
  const HoldButton(
      {super.key,
      required this.label,
      required this.onComplete,
      this.duration = const Duration(milliseconds: 1200),
      this.enabled = true,
      this.hapticOnComplete = true});
  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(vsync: this, duration: widget.duration);
  static const _beats = [.0, .27, .49, .66, .79, .89, .96];
  int _beat = 0;
  bool _complete = false;
  @override
  void initState() {
    super.initState();
    _controller.addListener(_tick);
    _controller.addStatusListener(_status);
  }

  void _tick() {
    if (_controller.isAnimating &&
        _controller.status == AnimationStatus.forward) {
      while (_beat < _beats.length && _controller.value >= _beats[_beat]) {
        HolyHaptics.tap();
        _beat++;
      }
    }
  }

  void _finish() {
    if (_complete || !widget.enabled) return;
    _complete = true;
    if (widget.hapticOnComplete) HolyHaptics.success();
    widget.onComplete();
  }

  void _status(AnimationStatus status) {
    if (status == AnimationStatus.completed) _finish();
  }

  void _down() {
    if (widget.enabled && !_complete) {
      _beat = 0;
      _controller.forward(from: 0);
    }
  }

  void _up() {
    if (!_complete) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = HolyThemeScope.of(context);
    return Semantics(
        button: true,
        label: widget.label,
        hint: 'Press and hold to complete',
        enabled: widget.enabled,
        onTap: _finish,
        child: FocusableActionDetector(
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
                _finish();
                return null;
              })
            },
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent()
            },
            child: GestureDetector(
                onTapDown: (_) => _down(),
                onTapUp: (_) => _up(),
                onTapCancel: _up,
                child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => Container(
                        constraints: const BoxConstraints(minHeight: 64),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient:
                                LinearGradient(colors: theme.buttonGradient),
                            boxShadow: [
                              BoxShadow(
                                  color: theme.accent.withValues(
                                      alpha: .16 + _controller.value * .22),
                                  blurRadius: 20 + _controller.value * 18,
                                  offset: const Offset(0, 8))
                            ]),
                        child: Stack(alignment: Alignment.center, children: [
                          Positioned.fill(
                              child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _controller.value,
                                  child: ColoredBox(color: theme.holdFill))),
                          Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 16),
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox.square(
                                        dimension: 24,
                                        child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              CircularProgressIndicator(
                                                  value: _controller.value,
                                                  strokeWidth: 2,
                                                  color: theme.buttonInk,
                                                  backgroundColor: theme
                                                      .buttonInk
                                                      .withValues(alpha: .24)),
                                              Icon(
                                                  _complete
                                                      ? Icons.check_rounded
                                                      : Icons
                                                          .favorite_outline_rounded,
                                                  size: 13,
                                                  color: theme.buttonInk)
                                            ])),
                                    const SizedBox(width: 12),
                                    Flexible(
                                        child: Text(widget.label,
                                            textAlign: TextAlign.center,
                                            style: HolyTypography.ui.copyWith(
                                                color: theme.buttonInk,
                                                fontWeight: FontWeight.w700)))
                                  ]))
                        ]))))));
  }
}
