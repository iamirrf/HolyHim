import 'package:flutter/material.dart';
import '../themes.dart';

/// Provides the active theme to the tree and animates between themes when
/// the reader picks a new one, so the paper changes colour like light.
class ThemeHost extends StatelessWidget {
  final HolyTheme theme;
  final bool reduceTransparency;
  final Widget child;
  const ThemeHost(
      {super.key,
      required this.theme,
      required this.child,
      this.reduceTransparency = false});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<HolyTheme>(
      tween: _ThemeTween(begin: theme, end: theme),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
      child: child,
      builder: (context, value, child) => HolyThemeScope(
          theme: value,
          reduceTransparency: reduceTransparency,
          child: ColoredBox(color: value.paper, child: child)));
}

class _ThemeTween extends Tween<HolyTheme> {
  _ThemeTween({required HolyTheme super.begin, required HolyTheme super.end});
  @override
  HolyTheme lerp(double t) => HolyTheme.lerp(begin!, end!, t);
}
