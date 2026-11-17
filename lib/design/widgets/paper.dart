import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../themes.dart';
import '../tokens.dart';
import 'hide_region.dart';

/// The reading surface: opaque warm paper with a hairline and one soft
/// shadow. Every card, sheet and panel in the app is a [Paper].
class Paper extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double lift;
  final Color? color;
  final bool hairline;
  final BorderRadius? borderRadius;
  const Paper(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(HolySpace.xl),
      this.radius = HolyRadius.card,
      this.lift = 1,
      this.color,
      this.hairline = true,
      this.borderRadius});

  @override
  Widget build(BuildContext context) => Hideable(child: _build(context));

  Widget _build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final shape = RoundedSuperellipseBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(radius),
        side: hairline
            ? BorderSide(color: t.hairline, width: .8)
            : BorderSide.none);
    return DecoratedBox(
        decoration: ShapeDecoration(
            color: color ?? t.surface,
            shape: shape,
            shadows: lift > 0 ? HolyDepth.paper(t, lift: lift) : null),
        child: ClipPath(
            clipper: ShapeBorderClipper(shape: shape),
            child: Padding(padding: padding, child: child)));
  }
}

/// Frosted glass, reserved for two jobs: the floating tab bar and controls
/// that sit directly on a photograph. Falls back to an opaque fill when the
/// person has asked for reduced transparency.
class FrostedGlass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool onPhoto;
  const FrostedGlass(
      {super.key,
      required this.child,
      this.radius = 999,
      this.padding = EdgeInsets.zero,
      this.onPhoto = false});

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final opaque = HolyThemeScope.opaqueOf(context);
    final shape = RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(
            color: onPhoto
                ? Colors.white.withValues(alpha: .28)
                : t.hairline.withValues(alpha: .9),
            width: .8));
    final fill = onPhoto
        ? (opaque
            ? const Color(0xE6271A20)
            : Colors.white.withValues(alpha: .16))
        : (opaque ? t.surface : t.surface.withValues(alpha: t.isDark ? .70 : .74));
    final content = DecoratedBox(
        decoration: ShapeDecoration(color: fill, shape: shape),
        child: Padding(padding: padding, child: child));
    return ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: opaque
            ? content
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: content));
  }
}

/// A thin rule in the hairline colour.
class Hairline extends StatelessWidget {
  final double indent;
  const Hairline({super.key, this.indent = 0});
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(left: indent),
      child: SizedBox(
          height: .8,
          width: double.infinity,
          child: ColoredBox(color: HolyThemeScope.of(context).hairline)));
}

/// A small gold ornament used between a title and its text.
class Flourish extends StatelessWidget {
  final double width;
  final Color? color;
  const Flourish({super.key, this.width = 56, this.color});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: CustomPaint(
          size: Size(width, 8),
          painter: _FlourishPainter(color ?? HolyThemeScope.of(context).gold)));
}

class _FlourishPainter extends CustomPainter {
  final Color color;
  _FlourishPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color.withValues(alpha: .75)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final mid = size.height / 2, cx = size.width / 2;
    canvas.drawLine(Offset(0, mid), Offset(cx - 7, mid), line);
    canvas.drawLine(Offset(cx + 7, mid), Offset(size.width, mid), line);
    final diamond = Path()
      ..moveTo(cx, mid - 3.5)
      ..lineTo(cx + 3.5, mid)
      ..lineTo(cx, mid + 3.5)
      ..lineTo(cx - 3.5, mid)
      ..close();
    canvas.drawPath(diamond, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FlourishPainter old) => old.color != color;
}
