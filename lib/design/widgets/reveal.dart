import 'dart:ui';
import 'package:flutter/material.dart';
import '../motion.dart';

class Reveal extends StatefulWidget {
  final Widget child;
  final int index;
  const Reveal({super.key, required this.child, this.index = 0});
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(vsync: this, duration: HolyMotion.enter);
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    if (!_started) {
      _started = true;
      Future<void>.delayed(Duration(milliseconds: widget.index * 60), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final p = HolyMotion.enterCurve.transform(_controller.value);
        return Opacity(
            opacity: p,
            child: Transform.translate(
                offset: Offset(0, 12 * (1 - p)),
                child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                        sigmaX: 8 * (1 - p), sigmaY: 8 * (1 - p)),
                    child: child)));
      });
}

class WordReveal extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  const WordReveal(
      {super.key,
      required this.text,
      this.style,
      this.textAlign = TextAlign.start});
  @override
  State<WordReveal> createState() => _WordRevealState();
}

class _WordRevealState extends State<WordReveal>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
      vsync: this,
      duration: Duration(
          milliseconds: widget.text.split(RegExp(r'\s+')).length * 42 + 300));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.text.split(RegExp(r'\s+'));
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    return Semantics(
        label: widget.text,
        child: ExcludeSemantics(
            child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Text.rich(
                    TextSpan(
                        children: List.generate(
                            words.length,
                            (i) => TextSpan(
                                text:
                                    '${words[i]}${i < words.length - 1 ? ' ' : ''}',
                                style: style.copyWith(
                                    color: (style.color ??
                                            Theme.of(context)
                                                .colorScheme
                                                .onSurface)
                                        .withValues(
                                            alpha: ((_controller.value *
                                                            (words.length + 4) -
                                                        i) /
                                                    4)
                                                .clamp(0.0, 1.0)))))),
                    textAlign: widget.textAlign,
                    style: style))));
  }
}
