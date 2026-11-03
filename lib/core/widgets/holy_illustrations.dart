import 'package:flutter/material.dart';
import 'package:holyher/core/theme/app_theme.dart';

/// An engraved book symbol for the learning objects; UI controls keep their
/// familiar platform icons. This geometry is shared by every roadmap state.
class BookGlyph extends StatelessWidget {
  final double size;
  final Color color;
  const BookGlyph(
      {super.key, this.size = 34, this.color = const Color(0xFF98516A)});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => ExcludeSemantics(
          child: CustomPaint(
              size: Size.square(size), painter: _BookGlyph(color))));
}

class _BookGlyph extends CustomPainter {
  final Color color;
  const _BookGlyph(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 48);
    final outline = Path()
      ..moveTo(24, 12)
      ..cubicTo(17, 8, 9, 8, 5, 10)
      ..lineTo(5, 36)
      ..cubicTo(11, 34, 18, 35, 24, 39)
      ..cubicTo(30, 35, 37, 34, 43, 36)
      ..lineTo(43, 10)
      ..cubicTo(37, 8, 30, 8, 24, 12)
      ..close();
    canvas.drawPath(outline, Paint()..color = color.withValues(alpha: .09));
    final ink = Paint()
      ..color = color
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(outline, ink);
    canvas.drawLine(const Offset(24, 13), const Offset(24, 38), ink);
    for (final y in [18.0, 24.0, 30.0]) {
      canvas.drawPath(
          Path()
            ..moveTo(10, y)
            ..quadraticBezierTo(15, y - 1, 19, y + 1),
          ink..strokeWidth = 1.7);
      canvas.drawPath(
          Path()
            ..moveTo(29, y + 1)
            ..quadraticBezierTo(34, y - 1, 38, y),
          ink);
    }
  }

  @override
  bool shouldRepaint(_BookGlyph old) => true;
}

/// A reading object, used for the empty library and the lesson introduction.
/// It contains no substitute Scripture: the actual passage remains real text.
class ReadingBookObject extends StatelessWidget {
  final double width;
  const ReadingBookObject({super.key, this.width = 156});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => ExcludeSemantics(
          child: RepaintBoundary(
              child: CustomPaint(
                  size: Size(width, width * .77),
                  painter: const _ReadingBookPainter()))));
}

class _ReadingBookPainter extends CustomPainter {
  const _ReadingBookPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 180, size.height / 138);
    final left = Path()
      ..moveTo(90, 27)
      ..cubicTo(66, 11, 38, 12, 14, 20)
      ..lineTo(14, 110)
      ..cubicTo(39, 103, 65, 107, 90, 124)
      ..close();
    final right = Path()
      ..moveTo(90, 27)
      ..cubicTo(114, 11, 142, 12, 166, 20)
      ..lineTo(166, 110)
      ..cubicTo(141, 103, 115, 107, 90, 124)
      ..close();
    final book = Path()
      ..addPath(left, Offset.zero)
      ..addPath(right, Offset.zero);
    canvas.save();
    canvas.translate(0, 8);
    canvas.drawPath(
        book,
        Paint()
          ..color = AppColors.accentDark.withValues(alpha: .12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.restore();
    for (var i = 3; i >= 1; i--) {
      canvas.save();
      canvas.translate(0, i * 2.0);
      canvas.drawPath(
          book,
          Paint()
            ..color = Color.lerp(
                const Color(0xFFE2CBD7), AppColors.pearl, 1 - i / 4)!);
      canvas.drawPath(
          book,
          Paint()
            ..color = AppColors.pearl.withValues(alpha: .85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .8);
      canvas.restore();
    }
    canvas.drawPath(
        left,
        Paint()
          ..shader = LinearGradient(colors: [
            AppColors.pearl,
            AppColors.pearl,
            AppColors.surfaceLight
          ], stops: [
            0,
            .78,
            1
          ]).createShader(const Rect.fromLTWH(14, 14, 77, 110)));
    canvas.drawPath(
        right,
        Paint()
          ..shader = LinearGradient(colors: [
            AppColors.surfaceLight,
            AppColors.pearl,
            AppColors.pearl
          ], stops: [
            0,
            .2,
            1
          ]).createShader(const Rect.fromLTWH(90, 14, 77, 110)));
    canvas.drawPath(
        book,
        Paint()
          ..color = AppColors.pearl
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
    canvas.drawPath(
        Path()
          ..moveTo(90, 28)
          ..lineTo(90, 122),
        Paint()
          ..color = AppColors.accent.withValues(alpha: .18)
          ..strokeWidth = 1.3);
    final lines = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: .25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final y = 38.0 + i * 10;
      canvas.drawPath(
          Path()
            ..moveTo(27, y)
            ..quadraticBezierTo(48, y - 3, 75, y + 9),
          lines);
      canvas.drawPath(
          Path()
            ..moveTo(105, y + 9)
            ..quadraticBezierTo(130, y - 3, i == 5 ? 142 : 153, y),
          lines);
    }
    final ribbon = Path()
      ..moveTo(102, 24)
      ..quadraticBezierTo(108, 50, 105, 88)
      ..lineTo(101, 118)
      ..lineTo(96, 111)
      ..lineTo(89, 116)
      ..quadraticBezierTo(99, 61, 94, 25)
      ..close();
    canvas.drawPath(
        ribbon,
        Paint()
          ..shader = LinearGradient(colors: [
            AppColors.accentDark,
            const Color(0xFFB56D8E),
            AppColors.accent
          ], begin: Alignment.centerLeft, end: Alignment.centerRight)
              .createShader(const Rect.fromLTWH(90, 24, 18, 94)));
    canvas.drawPath(
        Path()
          ..moveTo(96, 27)
          ..quadraticBezierTo(101, 61, 94, 109),
        Paint()
          ..color = AppColors.pearl.withValues(alpha: .5)
          ..strokeWidth = .8
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_ReadingBookPainter old) => true;
}

class IdentityMedallion extends StatelessWidget {
  final String initial;
  final double size;
  const IdentityMedallion({super.key, required this.initial, this.size = 88});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.pearl,
                    AppColors.surfaceLight,
                    AppColors.pearl
                  ]),
              boxShadow: [
                BoxShadow(
                    color: AppColors.accentDark.withValues(alpha: .07),
                    blurRadius: 22,
                    offset: const Offset(0, 9))
              ]),
          child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.pearl,
                        AppColors.background,
                        const Color(0xFFF5E3EC)
                      ]),
                  border: Border.all(color: AppColors.pearl, width: 1.3)),
              child: Text(initial,
                  style: (size >= 88
                          ? HolyTypography.display
                          : HolyTypography.heading)
                      .copyWith(color: AppColors.accent)))));
}

/// A single line vocabulary for the reader's starting point, focus and rhythm.
class RhythmSymbol extends StatelessWidget {
  final String meaning;
  final double size;
  const RhythmSymbol(this.meaning, {super.key, this.size = 36});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => ExcludeSemantics(
          child: CustomPaint(
              size: Size.square(size),
              painter: _RhythmSymbolPainter(meaning))));
}

class _RhythmSymbolPainter extends CustomPainter {
  final String meaning;
  const _RhythmSymbolPainter(this.meaning);
  @override
  void paint(Canvas c, Size size) {
    c.scale(size.width / 40, size.height / 40);
    final p = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    switch (meaning) {
      case 'peace':
        for (final y in [13.0, 21.0, 29.0]) {
          c.drawPath(
              Path()
                ..moveTo(5, y)
                ..cubicTo(11, y - 5, 16, y + 5, 22, y)
                ..cubicTo(27, y - 4, 31, y + 2, 35, y - 1),
              p);
        }
      case 'confidence':
        c.drawPath(
            Path()
              ..moveTo(10, 33)
              ..lineTo(10, 18)
              ..quadraticBezierTo(20, -1, 30, 18)
              ..lineTo(30, 33),
            p);
        c.drawLine(const Offset(6, 33), const Offset(34, 33), p);
        c.drawLine(const Offset(20, 17), const Offset(20, 29), p);
      case 'hope':
        c.drawArc(
            const Rect.fromLTWH(11, 16, 18, 18), 3.14159, 3.14159, false, p);
        c.drawLine(const Offset(5, 26), const Offset(35, 26), p);
        c.drawLine(const Offset(20, 7), const Offset(20, 11), p);
        c.drawLine(const Offset(7, 12), const Offset(10, 15), p);
        c.drawLine(const Offset(30, 15), const Offset(33, 12), p);
        c.drawLine(const Offset(11, 32), const Offset(29, 32), p);
      case 'guidance':
      case 'apply':
        c.drawPath(
            Path()
              ..moveTo(9, 32)
              ..cubicTo(9, 19, 31, 28, 31, 9),
            p);
        c.drawCircle(const Offset(9, 33), 2.2, p);
        c.drawPath(
            Path()
              ..moveTo(25, 14)
              ..lineTo(31, 8)
              ..lineTo(35, 15),
            p);
      case 'rest':
        c.drawPath(
            Path()
              ..moveTo(28, 7)
              ..cubicTo(8, 3, 0, 27, 19, 34)
              ..cubicTo(27, 37, 34, 31, 35, 24)
              ..cubicTo(20, 29, 13, 15, 28, 7)
              ..close(),
            p);
      case 'busy':
        c.drawCircle(const Offset(20, 20), 14, p);
        c.drawPath(
            Path()
              ..moveTo(20, 10)
              ..lineTo(20, 20)
              ..lineTo(27, 24),
            p);
        c.drawCircle(
            const Offset(20, 20), 1, Paint()..color = AppColors.accent);
      case 'forget':
        c.drawPath(
            Path()
              ..moveTo(9, 29)
              ..quadraticBezierTo(13, 24, 13, 16)
              ..cubicTo(13, 6, 27, 6, 27, 16)
              ..quadraticBezierTo(27, 24, 31, 29)
              ..close(),
            p);
        c.drawArc(const Rect.fromLTWH(17, 29, 6, 7), 0, 3.14159, false, p);
        c.drawLine(const Offset(20, 4), const Offset(20, 7), p);
      case 'language':
        c.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(9, 5, 23, 30), const Radius.circular(4)),
            p);
        for (final y in [13.0, 20.0, 27.0]) {
          c.drawLine(Offset(15, y), Offset(y == 27 ? 24 : 27, y), p);
        }
      case 'new':
        c.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(9, 6, 23, 29), const Radius.circular(4)),
            p);
        c.drawLine(const Offset(14, 7), const Offset(14, 34), p);
        c.drawPath(
            Path()
              ..moveTo(23, 7)
              ..lineTo(23, 19)
              ..lineTo(27, 16)
              ..lineTo(30, 19)
              ..lineTo(30, 7),
            p);
      case 'returning':
        c.drawArc(const Rect.fromLTWH(7, 7, 26, 26), -.8, 5.2, false, p);
        c.drawPath(
            Path()
              ..moveTo(7, 8)
              ..lineTo(7, 17)
              ..lineTo(16, 17),
            p);
        c.drawPath(
            Path()
              ..moveTo(15, 26)
              ..lineTo(20, 21)
              ..lineTo(25, 26),
            p);
        c.drawLine(const Offset(20, 21), const Offset(20, 31), p);
      default:
        c.drawPath(
            Path()
              ..moveTo(20, 10)
              ..quadraticBezierTo(11, 5, 5, 8)
              ..lineTo(5, 31)
              ..quadraticBezierTo(12, 29, 20, 34)
              ..quadraticBezierTo(28, 29, 35, 31)
              ..lineTo(35, 8)
              ..quadraticBezierTo(27, 5, 20, 10)
              ..lineTo(20, 34),
            p);
        for (final y in [16.0, 23.0]) {
          c.drawLine(Offset(10, y), Offset(15, y + 1), p);
          c.drawLine(Offset(25, y + 1), Offset(30, y), p);
        }
    }
  }

  @override
  bool shouldRepaint(_RhythmSymbolPainter old) => true;
}
