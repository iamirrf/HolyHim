import 'package:flutter/material.dart';
import '../typography.dart';

class RollingNumber extends StatelessWidget {
  final int value;
  final TextStyle? style;
  const RollingNumber({super.key, required this.value, this.style});
  @override
  Widget build(BuildContext context) => Semantics(
      label: '$value',
      child: ExcludeSemantics(
          child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value.toDouble()),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, n, _) => Text('${n.round()}',
                  style: style ?? HolyTypography.display))));
}
