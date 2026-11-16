import 'dart:ui';
import 'package:flutter/material.dart';
import '../themes.dart';
import '../tokens.dart';
import 'hide_region.dart';

class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final int elevation;
  final Color? tint;
  final double borderWidth;
  const Glass(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(24),
      this.radius = 28,
      this.elevation = 1,
      this.tint,
      this.borderWidth = 1.0});
  @override
  Widget build(BuildContext context) => Hideable(child: _build(context));

  Widget _build(BuildContext context) {
    final theme = HolyThemeScope.of(context),
        opaque = HolyThemeScope.opaqueOf(context);
    final shape =
        RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(radius));
    final surface = DecoratedBox(
        decoration: ShapeDecoration(
            shape: shape,
            color: opaque ? theme.colors.first : null,
            gradient: opaque
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                        (tint ?? theme.glassTint)
                            .withValues(alpha: theme.isDark ? .54 : .78),
                        (tint ?? theme.glassTint)
                            .withValues(alpha: theme.isDark ? .32 : .42)
                      ])),
        child: DecoratedBox(
            decoration: ShapeDecoration(
                shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(radius),
                    side: BorderSide(
                        color: Colors.white
                            .withValues(alpha: theme.isDark ? .20 : .85),
                        width: borderWidth)),
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: .12),
                      Colors.white.withValues(alpha: 0)
                    ],
                    stops: const [
                      0,
                      .35
                    ])),
            child: Padding(padding: padding, child: child)));
    return DecoratedBox(
        decoration: ShapeDecoration(
            shape: shape,
            shadows: HolyDepth.shadows(elevation, dark: theme.isDark)),
        child: ClipPath(
            clipper: ShapeBorderClipper(shape: shape),
            child: opaque
                ? surface
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: surface)));
  }
}

class DepthCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final int elevation;
  const DepthCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(24),
      this.radius = 28,
      this.elevation = 2});
  @override
  Widget build(BuildContext context) => Glass(
      padding: padding, radius: radius, elevation: elevation, child: child);
}

class GlassCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String label;
  final double size;
  const GlassCircle(
      {super.key,
      required this.icon,
      required this.onPressed,
      required this.label,
      this.size = 44});
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: label,
      child: GestureDetector(
          onTap: onPressed,
          child: Glass(
              radius: size / 2,
              padding: EdgeInsets.zero,
              child: SizedBox.square(
                  dimension: size,
                  child: Icon(icon,
                      size: 20, color: HolyThemeScope.of(context).ink)))));
}
