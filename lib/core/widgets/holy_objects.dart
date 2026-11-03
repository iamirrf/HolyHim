import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/data/lessons.dart';
import 'holy_illustrations.dart';
export 'holy_illustrations.dart';

/// A physical foreground plane: a lit upper edge, a rose underside and two
/// different shadow distances. Only featured objects use this material.
class PearlSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius, lift;
  final bool ribbon;
  const PearlSurface(
      {super.key,
      required this.child,
      this.padding = EdgeInsets.zero,
      this.radius = 24,
      this.lift = 0,
      this.ribbon = false});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => DecoratedBox(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                    color: AppColors.textPrimary
                        .withValues(alpha: .09 + lift * .07),
                    blurRadius: 34 + lift * 24,
                    spreadRadius: -5,
                    offset: Offset(0, 16 + lift * 16)),
                BoxShadow(
                    color: AppColors.accent.withValues(alpha: .08 + lift * .05),
                    blurRadius: 22 + lift * 16,
                    spreadRadius: -5,
                    offset: Offset(0, 6 + lift * 5)),
                BoxShadow(
                    color: AppColors.accentDark.withValues(alpha: .08),
                    blurRadius: 5,
                    offset: const Offset(0, 3)),
              ]),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Stack(children: [
                Positioned.fill(
                    child: CustomPaint(
                        painter:
                            _PearlMaterialPainter(radius: radius, lift: lift))),
                Padding(padding: padding, child: child),
                if (ribbon)
                  const Positioned(top: 0, right: 28, child: RibbonDetail()),
              ]))));
}

class _PearlMaterialPainter extends CustomPainter {
  final double radius, lift;
  const _PearlMaterialPainter({required this.radius, required this.lift});
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size,
        rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
              begin: const Alignment(-.8, -1),
              end: const Alignment(1, .9),
              colors: [
                AppColors.pearl,
                AppColors.pearl,
                AppColors.background,
                AppColors.surface
              ],
              stops: [
                0,
                .5,
                .86,
                1
              ]).createShader(rect));
    canvas.save();
    canvas.clipRRect(rrect);
    final light = Rect.fromCircle(
        center: Offset(size.width * .92, size.height * .08),
        radius: size.width * .85);
    canvas.drawOval(
        light,
        Paint()
          ..shader = RadialGradient(colors: [
            AppColors.pearl.withValues(alpha: .8),
            AppColors.pearl.withValues(alpha: 0)
          ]).createShader(light));
    final edgeLight = Path()
      ..moveTo(size.width * .66, 1)
      ..lineTo(size.width - radius, 1)
      ..quadraticBezierTo(size.width - 1, 1, size.width - 1, radius)
      ..lineTo(size.width - 1, size.height * .64);
    canvas.drawPath(
        edgeLight,
        Paint()
          ..color = AppColors.accent.withValues(alpha: .14 + lift * .12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawRRect(
        rrect.deflate(.8),
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.pearl,
                AppColors.pearl,
                AppColors.surfaceLight
              ]).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
    canvas.drawRRect(
        rrect.deflate(3),
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.pearl.withValues(alpha: .72),
                AppColors.pearl.withValues(alpha: 0),
                AppColors.pearl.withValues(alpha: .55)
              ]).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8);
    final edge = Path()
      ..moveTo(radius, 1)
      ..lineTo(size.width - radius, 1);
    canvas.drawPath(
        edge,
        Paint()
          ..shader = LinearGradient(colors: [
            const Color(0x00FFFFFF),
            AppColors.pearl,
            const Color(0x00FFFFFF)
          ]).createShader(
              Rect.fromLTWH(radius, 0, math.max(1, size.width - radius * 2), 2))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PearlMaterialPainter old) => true;
}

class QuietInset extends StatelessWidget {
  final Widget child;
  final bool selected;
  final double radius;
  final EdgeInsetsGeometry padding;
  const QuietInset(
      {super.key,
      required this.child,
      this.selected = false,
      this.radius = 16,
      this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          padding: padding,
          decoration: BoxDecoration(
              color: selected
                  ? AppColors.surface
                  : AppColors.pearl.withValues(alpha: .86),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                  color: selected ? AppColors.accent : AppColors.divider,
                  width: selected ? 1.5 : 1)),
          child: child));
}

class RibbonDetail extends StatelessWidget {
  final double height;
  const RibbonDetail({super.key, this.height = 42});
  @override
  Widget build(BuildContext context) => useHolyPalette(context,
      () => CustomPaint(size: Size(18, height), painter: _RibbonPainter()));
}

class _RibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..lineTo(s.width, 0)
      ..lineTo(s.width, s.height)
      ..lineTo(s.width / 2, s.height - 7)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(colors: [
            AppColors.accentDark,
            AppColors.accent,
            const Color(0xFFB67191)
          ]).createShader(Offset.zero & s));
    canvas.drawLine(
        const Offset(3, 0),
        Offset(3, s.height - 3),
        Paint()
          ..color = AppColors.pearl.withValues(alpha: .35)
          ..strokeWidth = .7);
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => true;
}

class ScripturePage extends StatelessWidget {
  final DailyLesson lesson;
  final bool compact, saved;
  const ScripturePage(
      {super.key,
      required this.lesson,
      this.compact = false,
      this.saved = false});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => PearlSurface(
          ribbon: saved,
          padding:
              EdgeInsets.fromLTRB(compact ? 24 : 32, 28, compact ? 24 : 32, 32),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'DAY ${lesson.day.toString().padLeft(2, '0')}  /  ${saved ? 'KEPT CLOSE' : 'SCRIPTURE'}',
                    style: HolyTypography.label
                        .copyWith(color: AppColors.accent, letterSpacing: 1.2)),
                const SizedBox(height: 24),
                Text(lesson.verseText,
                    style: HolyTypography.scripture
                        .copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: 24),
                Container(
                    height: 1,
                    width: 32,
                    color: AppColors.accent.withValues(alpha: .45)),
                const SizedBox(height: 16),
                Text(lesson.verseReference,
                    style: HolyTypography.supporting
                        .copyWith(color: AppColors.accentDark)),
                const SizedBox(height: 4),
                Text('World English Bible',
                    style: HolyTypography.supporting
                        .copyWith(color: AppColors.textSecondary)),
              ])));
}

class LessonMiniature extends StatelessWidget {
  final DailyLesson lesson;
  const LessonMiniature({super.key, required this.lesson});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => PearlSurface(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DAY ${lesson.day.toString().padLeft(2, '0')}',
                    style: HolyTypography.label
                        .copyWith(color: AppColors.accent, letterSpacing: 1.4)),
                const SizedBox(height: 16),
                const BookGlyph(size: 28),
                const SizedBox(height: 16),
                Text(lesson.title, style: HolyTypography.section),
                const SizedBox(height: 12),
                Text(lesson.verseReference,
                    style: HolyTypography.supporting
                        .copyWith(color: AppColors.textSecondary)),
              ])));
}

enum LessonNodeState { current, available, inProgress, complete, future }

class LessonMedallion extends StatelessWidget {
  final LessonNodeState state;
  final double progress;
  const LessonMedallion({super.key, required this.state, this.progress = 0});
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final done = state == LessonNodeState.complete,
        future = state == LessonNodeState.future;
    return SizedBox.square(
        dimension: 104,
        child: Stack(children: [
          Positioned.fill(
              child: CustomPaint(painter: _MedallionPainter(state, progress))),
          Positioned(
              left: 35,
              top: 32,
              child: done
                  ? Icon(Icons.check_rounded, size: 34, color: AppColors.pearl)
                  : future
                      ? Icon(Icons.lock_outline_rounded,
                          size: 34, color: AppColors.textSecondary)
                      : state == LessonNodeState.inProgress
                          ? Icon(Icons.play_arrow_rounded,
                              size: 34, color: AppColors.accent)
                          : const BookGlyph()),
        ]));
  }
}

class _MedallionPainter extends CustomPainter {
  final LessonNodeState state;
  final double progress;
  const _MedallionPainter(this.state, this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 104, size.height / 104);
    const face = Offset(52, 49);
    final done = state == LessonNodeState.complete,
        future = state == LessonNodeState.future,
        current = state == LessonNodeState.current ||
            state == LessonNodeState.inProgress;
    if (current) {
      canvas.drawCircle(
          const Offset(52, 52),
          52,
          Paint()
            ..shader = const RadialGradient(colors: [
              Color(0x45C783A2),
              Color(0x20E2B7CC),
              Color(0x00F9E5ED)
            ], stops: [
              0,
              .64,
              1
            ]).createShader(const Rect.fromLTWH(0, 0, 104, 104)));
      const track = Rect.fromLTWH(4, 4, 96, 96);
      canvas.drawArc(
          track,
          0,
          math.pi * 2,
          false,
          Paint()
            ..color = AppColors.accent.withValues(alpha: .24)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.25);
      final fraction = progress.clamp(0.0, 1.0);
      if (fraction > 0) {
        canvas.drawArc(
            track,
            -math.pi / 2,
            math.pi * 2 * fraction,
            false,
            Paint()
              ..color = AppColors.accent
              ..strokeWidth = 2.8
              ..strokeCap = StrokeCap.round
              ..style = PaintingStyle.stroke);
      }
      canvas.drawCircle(
          const Offset(52, 4), 2.6, Paint()..color = AppColors.accent);
    }
    canvas.drawOval(
        const Rect.fromLTWH(20, 72, 64, 22),
        Paint()
          ..color = AppColors.accentDark.withValues(alpha: future ? .04 : .12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    canvas.drawCircle(
        const Offset(52, 56),
        37,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: done
                      ? [const Color(0xFF9A456A), const Color(0xFF682941)]
                      : future
                          ? [const Color(0xFFE9DBE3), const Color(0xFFD6C4CF)]
                          : [const Color(0xFFF9EBF2), const Color(0xFFD6A9BF)])
              .createShader(const Rect.fromLTWH(15, 19, 74, 74)));
    final faceRect = Rect.fromCircle(center: face, radius: 37);
    canvas.drawCircle(
        face,
        37,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: done
                      ? [
                          const Color(0xFFC785A2),
                          AppColors.accent,
                          const Color(0xFF843556)
                        ]
                      : future
                          ? [const Color(0xFFF7EFF3), const Color(0xFFE8DCE4)]
                          : [
                              AppColors.pearl,
                              AppColors.pearl,
                              const Color(0xFFF6E7EF)
                            ],
                  stops: future
                      ? [0, 1]
                      : done
                          ? [0, .55, 1]
                          : [0, .64, 1])
              .createShader(faceRect));
    canvas.drawCircle(
        face,
        36.4,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.pearl.withValues(alpha: done ? .7 : 1),
                done ? const Color(0xFFCC90AA) : const Color(0xFFE8CADA)
              ]).createShader(faceRect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3);
    canvas.drawCircle(
        face,
        33.8,
        Paint()
          ..color = AppColors.pearl.withValues(alpha: done ? .24 : .7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8);
    if (current) {
      canvas.drawCircle(
          face,
          37,
          Paint()
            ..color = AppColors.accent.withValues(alpha: .35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .9);
    }
    canvas.drawArc(
        faceRect.deflate(3.2),
        math.pi * 1.12,
        math.pi * .63,
        false,
        Paint()
          ..color = AppColors.pearl.withValues(alpha: .84)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_MedallionPainter old) => true;
}

class RoseRoutePainter extends CustomPainter {
  final List<Offset> points;
  final int completed;
  final Set<int>? completedSegments;
  const RoseRoutePainter(
      {required this.points, this.completed = 0, this.completedSegments});
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < points.length - 1; i++) {
      final a = Offset(points[i].dx * size.width, points[i].dy),
          b = Offset(points[i + 1].dx * size.width, points[i + 1].dy);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, a.dy + (b.dy - a.dy) * .56, b.dx,
            b.dy - (b.dy - a.dy) * .56, b.dx, b.dy);
      canvas.drawPath(
          path,
          Paint()
            ..color = AppColors.divider
            ..strokeWidth = 9
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round);
      canvas.drawPath(
          path,
          Paint()
            ..color = AppColors.pearl.withValues(alpha: .7)
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke);
      if (completedSegments?.contains(i) ?? (i < completed)) {
        canvas.drawPath(
            path,
            Paint()
              ..color = AppColors.accent.withValues(alpha: .12)
              ..strokeWidth = 15
              ..style = PaintingStyle.stroke
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
        canvas.drawPath(
            path,
            Paint()
              ..color = AppColors.accent
              ..strokeWidth = 6.5
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round);
      }
    }
  }

  @override
  bool shouldRepaint(RoseRoutePainter old) => true;
}

class CompletionOrbit extends StatelessWidget {
  final Animation<double> animation;
  final bool accepted;
  const CompletionOrbit(
      {super.key, required this.animation, required this.accepted});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => SizedBox.square(
          dimension: 180,
          child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) => CustomPaint(
                  painter: _OrbitPainter(accepted ? animation.value : 0,
                      MediaQuery.disableAnimationsOf(context)),
                  child: Center(
                      child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [
                                AppColors.pearl,
                                AppColors.surface
                              ])),
                          child: Icon(
                              accepted
                                  ? Icons.check_rounded
                                  : Icons.cloud_upload_outlined,
                              size: 38,
                              color: AppColors.accent)))))));
}

class _OrbitPainter extends CustomPainter {
  final double t;
  final bool reduced;
  const _OrbitPainter(this.t, this.reduced);
  @override
  void paint(Canvas c, Size s) {
    final center = s.center(Offset.zero), settle = math.sin(t * math.pi).abs();
    final paint = Paint()
      ..color = const Color(0xFFE6BE9C).withValues(alpha: .14 + settle * .18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    c.drawCircle(center, 46 + 15 * settle, paint);
    c.drawCircle(
        center,
        52,
        Paint()
          ..color = AppColors.divider
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    if (reduced || t == 0 || t >= 1) return;
    for (final angle in [-.5, .5]) {
      c.save();
      c.translate(center.dx, center.dy);
      c.rotate(angle + t * .5);
      c.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 156, height: 38),
          Paint()
            ..color = const Color(0xFFE5BD9C).withValues(alpha: settle * .28)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4);
      c.restore();
    }
    final random = math.Random(31);
    for (var i = 0; i < 18; i++) {
      final a =
          random.nextDouble() * math.pi * 2 + math.min(t / .8, 1) * math.pi * 2;
      final radius = 55 + random.nextDouble() * 26;
      c.drawCircle(
          center + Offset(math.cos(a), math.sin(a)) * radius,
          1 + random.nextDouble() * 1.4,
          Paint()
            ..color = const Color(0xFFBD8B64).withValues(alpha: settle * .7));
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => true;
}
