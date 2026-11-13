import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../themes.dart';
import '../tokens.dart';
import '../typography.dart';
import 'pressable.dart';
import 'paper.dart';
import 'bundled_art.dart';

/// Porcelain and rose-gold medallion; SunRize's spin reveal without a plugin.
class Badge3D extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool earned;
  final String? progress;
  final String? badgeId;
  final double size;
  final VoidCallback? onPressed;

  /// Shows the title under the medallion. Off where a title sits beside it.
  final bool showLabel;
  const Badge3D(
      {super.key,
      this.icon = Icons.auto_awesome_rounded,
      required this.label,
      this.earned = false,
      this.progress,
      this.badgeId,
      this.size = 86,
      this.showLabel = true,
      this.onPressed});
  @override
  State<Badge3D> createState() => _Badge3DState();
}

class _Badge3DState extends State<Badge3D> with SingleTickerProviderStateMixin {
  late final _shimmer =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncShimmer();
  }

  @override
  void didUpdateWidget(Badge3D old) {
    super.didUpdateWidget(old);
    if (old.earned != widget.earned) _syncShimmer();
  }

  void _syncShimmer() {
    if (MediaQuery.disableAnimationsOf(context) || !widget.earned) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  Widget _generated(Widget image, HolyTheme theme) =>
      Stack(fit: StackFit.expand, alignment: Alignment.center, children: [
        if (widget.earned)
          image
        else
          ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
              child: Opacity(
                  opacity: .42,
                  child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        .2126,
                        .7152,
                        .0722,
                        0,
                        0,
                        .2126,
                        .7152,
                        .0722,
                        0,
                        0,
                        .2126,
                        .7152,
                        .0722,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0
                      ]),
                      child: image))),
        if (!widget.earned)
          Icon(Icons.lock_outline_rounded,
              size: widget.size * .26, color: theme.muted),
        if (widget.earned)
          Positioned.fill(
              child: IgnorePointer(
                  child: ClipOval(
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment(-3 + _shimmer.value * 6, -1),
                                  end: Alignment(-1 + _shimmer.value * 6, 1),
                                  colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: .32),
                Colors.white.withValues(alpha: 0)
              ],
                                  stops: const [
                .35,
                .5,
                .65
              ]))))))
      ]);

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Pressable(
        onPressed: widget.onPressed,
        semanticLabel:
            '${widget.label}, ${widget.earned ? 'earned' : widget.progress ?? 'locked'}',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
              animation: _shimmer,
              builder: (context, _) => Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .002)
                    ..rotateX(-.12)
                    ..rotateY(widget.earned
                        ? math.sin(_shimmer.value * math.pi * 2) * .10
                        : 0),
                  child: SizedBox.square(
                      dimension: widget.size,
                      child: BundledArt(
                          asset: HolyArtAssets.badgePath(widget.badgeId),
                          imageBuilder: (image) => _generated(image, t),
                          fit: BoxFit.contain,
                          fallback:
                              Stack(alignment: Alignment.center, children: [
                            Container(
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: widget.earned
                                            ? const [
                                                Color(0xFFFFF4D8),
                                                Color(0xFFD5A084),
                                                Color(0xFFF4CEB5),
                                                Color(0xFFAE6C66)
                                              ]
                                            : [
                                                t.muted.withValues(alpha: .16),
                                                t.muted.withValues(alpha: .06)
                                              ]),
                                    boxShadow: HolyDepth.shadows(
                                        widget.earned ? 3 : 1,
                                        dark: t.isDark))),
                            Positioned.fill(
                                left: 4,
                                top: 3,
                                right: 4,
                                bottom: 6,
                                child: Container(
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white.withValues(
                                                alpha:
                                                    widget.earned ? .75 : .15),
                                            width: 1.5),
                                        gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: widget.earned
                                                ? const [
                                                    Color(0xFFFFFEF6),
                                                    Color(0xFFF5E2DB),
                                                    Color(0xFFFFF9EA)
                                                  ]
                                                : [
                                                    t.glassTint,
                                                    t.glassTint
                                                        .withValues(alpha: .1)
                                                  ])))),
                            CustomPaint(
                                size: Size.square(widget.size * .78),
                                painter: _LaurelPainter(widget.earned
                                    ? const Color(0xFFB47C66)
                                    : t.muted.withValues(alpha: .26))),
                            Icon(
                                widget.earned
                                    ? widget.icon
                                    : Icons.lock_outline_rounded,
                                size: widget.size * .34,
                                color: widget.earned
                                    ? const Color(0xFFAC6E61)
                                    : t.muted.withValues(alpha: .38)),
                            if (widget.earned)
                              Positioned.fill(
                                  child: ClipOval(
                                      child: DecoratedBox(
                                          decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                  begin: Alignment(
                                                      -3 + _shimmer.value * 6,
                                                      -1),
                                                  end: Alignment(
                                                      -1 + _shimmer.value * 6,
                                                      1),
                                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: .45),
                                    Colors.white.withValues(alpha: 0)
                                  ],
                                                  stops: const [
                                    .35,
                                    .5,
                                    .65
                                  ])))))
                          ]))))),
          if (widget.showLabel) ...[
            const SizedBox(height: 12),
            Text(widget.label,
                textAlign: TextAlign.center,
                style: HolyTypography.ui.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.earned ? t.ink : t.muted)),
            if (!widget.earned && widget.progress != null)
              Text(widget.progress!,
                  style:
                      HolyTypography.ui.copyWith(fontSize: 11, color: t.muted))
          ],
        ]));
  }
}

class _LaurelPainter extends CustomPainter {
  final Color color;
  _LaurelPainter(this.color);
  @override
  void paint(Canvas c, Size s) {
    final paint = Paint()..color = color;
    final center = Offset(s.width / 2, s.height / 2);
    final r = s.width * .4;
    for (final side in [-1, 1]) {
      for (var i = 0; i < 7; i++) {
        final angle = (math.pi / 2) + (i / 7 * math.pi * .75) * side;
        final p = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
        c.save();
        c.translate(p.dx, p.dy);
        c.rotate(angle + .5 * side);
        c.drawOval(
            Rect.fromCenter(
                center: Offset.zero,
                width: s.width * .055,
                height: s.width * .13),
            paint);
        c.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_LaurelPainter old) => old.color != color;
}

Future<void> showBadgeReveal(BuildContext context,
        {required String title,
        required String description,
        IconData icon = Icons.auto_awesome_rounded,
        bool earned = true,
        String? progress,
        String? badgeId,
        VoidCallback? onShare}) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 1300),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, child) => Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, .001)
                                ..rotateY((1 - v) * math.pi * 2)
                                ..scaleByDouble(.6 + v * .4, .6 + v * .4, 1, 1),
                              child: child),
                          child: Badge3D(
                              badgeId: badgeId,
                              icon: icon,
                              label: '',
                              earned: earned,
                              progress: progress,
                              size: 160)),
                      Text(title,
                          style: HolyTypography.title,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Text(description,
                          style: HolyTypography.ui,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      if (onShare != null)
                        Pressable(
                            onPressed: onShare,
                            child: const Paper(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 14),
                                child: Text('Share this moment',
                                    style: HolyTypography.ui)))
                    ])))));
