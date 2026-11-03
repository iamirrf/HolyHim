import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:holyher/core/constants/app_constants.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:holyher/core/theme/app_theme.dart';

/// Theme-aware offline composition. Generated artwork is independent of text.
class LessonArtwork extends StatelessWidget {
  final int day;
  final Widget? child;
  final bool quiet;
  const LessonArtwork(
      {super.key, required this.day, this.child, this.quiet = false});
  static final Future<Map<String, dynamic>> _manifest = rootBundle
      .loadString('assets/artwork/manifest.json')
      .then((raw) => Map<String, dynamic>.from(jsonDecode(raw) as Map));
  Widget _image() => FutureBuilder<Map<String, dynamic>>(
      future: _manifest,
      builder: (context, snapshot) {
        final entry = (snapshot.data?['assets']
            as Map?)?[day.toString().padLeft(3, '0')] as Map?;
        if (entry?['reviewStatus'] != 'approved') {
          return const SizedBox.shrink();
        }
        final path = (entry!['path'] as String).replaceFirst('public/', '/');
        final local =
            'assets/artwork/day-${day.toString().padLeft(3, '0')}.webp';
        final image = day <= 5
            ? Image.asset(local,
                fit: BoxFit.cover,
                errorBuilder: (_, e, s) => const SizedBox.shrink())
            : CachedNetworkImage(
                imageUrl: '${AppConstants.websiteUrl}$path',
                cacheKey: '${entry['sha256']}',
                fit: BoxFit.cover,
                placeholder: (_, u) => const SizedBox.shrink(),
                errorWidget: (_, u, e) => const SizedBox.shrink());
        return Stack(fit: StackFit.expand, children: [
          image,
          ColoredBox(
              color: AppColors.pearl.withValues(alpha: quiet ? .92 : .25))
        ]);
      });
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                AppColors.pearl,
                AppColors.background,
                AppColors.surface.withValues(alpha: .7)
              ])),
          child: Stack(fit: StackFit.passthrough, children: [
            Positioned.fill(
                child: ExcludeSemantics(
                    child: CustomPaint(
                        painter:
                            _BotanicalPainter(day, AppColors.palette, quiet)))),
            Positioned.fill(child: ExcludeSemantics(child: _image())),
            if (child != null) child!,
          ])));
}

class _BotanicalPainter extends CustomPainter {
  final int day;
  final HolyPalette palette;
  final bool quiet;
  const _BotanicalPainter(this.day, this.palette, this.quiet);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final origin = Offset(size.width * .88, size.height * .88);
    final end = Offset(size.width * .62, size.height * .38);
    final path = Path()
      ..moveTo(origin.dx, origin.dy)
      ..quadraticBezierTo(size.width * .73, size.height * .68, end.dx, end.dy);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = palette.accent.withValues(alpha: quiet ? .08 : .23);
    canvas.drawPath(path, paint);
    paint.style = PaintingStyle.fill;
    for (var i = 0; i < 8; i++) {
      final t = (i + 1) / 10;
      final p = Offset.lerp(origin, end, t)!;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(-.5 + (i.isEven ? -.5 : 1));
      paint.color = palette.accent.withValues(alpha: quiet ? .06 : .11);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(i.isEven ? -13 : 13, -9), width: 13, height: 37),
          paint);
      canvas.restore();
    }
    // Soft pearl petals frame the reading area; no decorative layer moves text.
    final center =
        Offset(size.width * (.11 + (day % 4) * .025), size.height * .87);
    for (var i = 0; i < 7; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * math.pi * 2 / 7);
      paint
        ..color = palette.edge.withValues(alpha: quiet ? .09 : .30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawOval(const Rect.fromLTWH(-13, -44, 26, 48), paint);
      canvas.restore();
    }
    paint
      ..maskFilter = null
      ..color = palette.champagne.withValues(alpha: quiet ? .1 : .6);
    canvas.drawCircle(center, 8, paint);
  }

  @override
  bool shouldRepaint(_BotanicalPainter old) =>
      day != old.day || palette != old.palette || quiet != old.quiet;
}
