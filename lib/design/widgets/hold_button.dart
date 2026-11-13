import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../haptics.dart';
import '../themes.dart';
import '../tokens.dart';
import '../typography.dart';

/// SunRize's hold-to-complete interaction with a 1.2s heartbeat ramp.
class HoldButton extends StatefulWidget {
  final String label;
  final VoidCallback onComplete;
  final Duration duration;
  final bool enabled, hapticOnComplete;

  /// Hold progress from 0 to 1, for light that gathers around the button.
  final ValueChanged<double>? onProgress;
  const HoldButton(
      {super.key,
      required this.label,
      required this.onComplete,
      this.duration = const Duration(milliseconds: 1200),
      this.enabled = true,
      this.hapticOnComplete = true,
      this.onProgress});
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
    widget.onProgress?.call(_controller.value);
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
                    builder: (context, _) {
                      final v = Curves.easeOut.transform(_controller.value);
                      return Transform.scale(
                          scale: 1 - .02 * v + (_complete ? .02 : 0),
                          child: Container(
                              constraints: const BoxConstraints(minHeight: 60),
                              clipBehavior: Clip.antiAlias,
                              decoration: ShapeDecoration(
                                  color: theme.primary,
                                  shape: RoundedSuperellipseBorder(
                                      borderRadius:
                                          BorderRadius.circular(HolyRadius.button)),
                                  shadows: [
                                    BoxShadow(
                                        color: theme.gold
                                            .withValues(alpha: .10 + v * .45),
                                        blurRadius: 18 + v * 34,
                                        spreadRadius: v * 4,
                                        offset: const Offset(0, 6))
                                  ]),
                              child: Stack(alignment: Alignment.center, children: [
                                // Light gathers from the centre as she holds.
                                Positioned.fill(
                                    child: DecoratedBox(
                                        decoration: BoxDecoration(
                                            gradient: RadialGradient(
                                                radius: .2 + v * 2.2,
                                                colors: [
                                  theme.gold.withValues(alpha: .55 * v),
                                  theme.gold.withValues(alpha: 0),
                                ])))),
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 22, vertical: 16),
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox.square(
                                              dimension: 22,
                                              child: CustomPaint(
                                                  painter: _RingPainter(
                                                      _controller.value,
                                                      theme.onPrimary))),
                                          const SizedBox(width: 12),
                                          Flexible(
                                              child: Text(widget.label,
                                                  textAlign: TextAlign.center,
                                                  style: HolyTypography.button
                                                      .copyWith(
                                                          color: theme
                                                              .onPrimary)))
                                        ]))
                              ])));
                    }))));
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  _RingPainter(this.value, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawArc(
        r.deflate(1),
        0,
        6.2832,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color.withValues(alpha: .28));
    canvas.drawArc(
        r.deflate(1),
        -1.5708,
        6.2832 * value,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..color = color);
    // A small cross at the centre, filling in as the hold completes.
    final c = size.center(Offset.zero);
    final ink = Paint()
      ..color = color.withValues(alpha: .5 + .5 * value)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c.translate(0, -5), c.translate(0, 5), ink);
    canvas.drawLine(c.translate(-3.5, -1.5), c.translate(3.5, -1.5), ink);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}
