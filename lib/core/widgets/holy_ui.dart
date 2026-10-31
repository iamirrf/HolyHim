import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/services/profile_service.dart';

class BlushBackdrop extends StatelessWidget {
  final Widget child;
  const BlushBackdrop({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        const DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
              Color(0xFFFFFBFD),
              Color(0xFFFAEDF3),
              Color(0xFFFFFCF8)
            ]))),
        const Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _MeshPainter()))),
        child
      ]);
}

class _MeshPainter extends CustomPainter {
  const _MeshPainter();
  @override
  void paint(Canvas canvas, Size size) {
    for (final blob in [
      (const Offset(.96, .12), .8, const Color(0x40DBA7C1)),
      (const Offset(-.12, .64), .8, const Color(0x35F2C5BB)),
      (const Offset(.78, .96), .65, const Color(0x25B8A0D2))
    ]) {
      final center = Offset(size.width * blob.$1.dx, size.height * blob.$1.dy);
      final radius = math.max(size.width, size.height) * blob.$2;
      canvas.drawCircle(
          center,
          radius,
          Paint()
            ..shader = RadialGradient(
                    colors: [blob.$3, blob.$3.withValues(alpha: 0)])
                .createShader(Rect.fromCircle(center: center, radius: radius)));
    }
  }

  @override
  bool shouldRepaint(_MeshPainter oldDelegate) => false;
}

class HolyScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final Widget? bottomNavigationBar;
  final List<Widget>? actions;
  const HolyScaffold(
      {super.key,
      required this.body,
      this.title,
      this.bottomNavigationBar,
      this.actions});
  @override
  Widget build(BuildContext context) => BlushBackdrop(
      child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: title == null
              ? null
              : AppBar(
                  title: Text(title!,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  actions: actions),
          body: SafeArea(child: body),
          bottomNavigationBar: bottomNavigationBar));
}

class ReadingWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ReadingWidth({super.key, required this.child, this.maxWidth = 720});
  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth), child: child));
}

class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool highlighted;
  final double radius;
  const GlassSurface(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(22),
      this.highlighted = false,
      this.radius = 28});
  @override
  Widget build(BuildContext context) => Container(
      padding: padding,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: highlighted
                  ? [const Color(0xFFFFFDFE), const Color(0xFFF4DDE8)]
                  : [
                      Colors.white.withValues(alpha: .94),
                      Colors.white.withValues(alpha: .68)
                    ]),
          border: Border.all(
              color: highlighted
                  ? const Color(0xFFDCAFC4)
                  : Colors.white.withValues(alpha: .96),
              width: 1.3),
          boxShadow: [
            BoxShadow(
                color: AppColors.accentDark
                    .withValues(alpha: highlighted ? .10 : .045),
                blurRadius: 30,
                offset: const Offset(0, 12)),
            BoxShadow(
                color: Colors.white.withValues(alpha: .7),
                blurRadius: 1,
                offset: const Offset(0, -1))
          ]),
      child: child);
}

/// Finger-driven feedback follows Cognein's immediate press vocabulary.
class HolyPressable extends ConsumerStatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String? label;
  final bool selected;
  final double radius;
  const HolyPressable(
      {super.key,
      required this.child,
      required this.onPressed,
      this.label,
      this.selected = false,
      this.radius = 24});
  @override
  ConsumerState<HolyPressable> createState() => _HolyPressableState();
}

class _HolyPressableState extends ConsumerState<HolyPressable> {
  bool _pressed = false;
  void _highlight(bool value) {
    if (_pressed == value) return;
    if (value && ref.read(profileProvider).haptics) {
      HapticFeedback.selectionClick();
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      enabled: widget.onPressed != null,
      selected: widget.selected,
      label: widget.label,
      child: AnimatedScale(
          scale: _pressed ? .975 : 1,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : Duration(milliseconds: _pressed ? 100 : 280),
          curve: Curves.easeOutBack,
          child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                  onTap: widget.onPressed,
                  onHighlightChanged: _highlight,
                  borderRadius: BorderRadius.circular(widget.radius),
                  splashFactory: NoSplash.splashFactory,
                  highlightColor: Colors.transparent,
                  child: widget.child))));
}

class HolyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool secondary;
  final IconData? icon;
  final Widget? leading;
  final Color? foregroundColor;
  const HolyButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.busy = false,
      this.secondary = false,
      this.icon,
      this.leading,
      this.foregroundColor});
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return HolyPressable(
        onPressed: enabled ? onPressed : null,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
            decoration: BoxDecoration(
                gradient: secondary
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: enabled
                            ? [const Color(0xFFA14C72), AppColors.accentDark]
                            : [
                                const Color(0xFFBC9CAA),
                                const Color(0xFFAB8898)
                              ]),
                color: secondary ? Colors.white.withValues(alpha: .78) : null,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: secondary
                        ? AppColors.divider
                        : Colors.white.withValues(alpha: .38)),
                boxShadow: secondary || !enabled
                    ? null
                    : [
                        BoxShadow(
                            color: AppColors.accent.withValues(alpha: .18),
                            blurRadius: 18,
                            offset: const Offset(0, 8))
                      ]),
            child: busy
                ? Center(
                    child: SizedBox.square(
                        dimension: 23,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                secondary ? AppColors.accent : Colors.white)))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 10)
                    ],
                    if (leading == null && icon != null) ...[
                      Icon(icon,
                          size: 21,
                          color: foregroundColor ??
                              (secondary ? AppColors.accent : Colors.white)),
                      const SizedBox(width: 10)
                    ],
                    Flexible(
                        child: Text(label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: foregroundColor ??
                                    (secondary
                                        ? AppColors.accentDark
                                        : Colors.white))))
                  ])));
  }
}

class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: const TextStyle(
          fontSize: 10,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
          height: 1.5));
}

class PageHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  const PageHeading(
      {super.key, required this.eyebrow, required this.title, this.subtitle});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Eyebrow(eyebrow),
        const SizedBox(height: 9),
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium)
        ]
      ]);
}

class HolyMark extends StatelessWidget {
  final double size;
  const HolyMark({super.key, this.size = 88});
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'HolyHer cross',
      image: true,
      child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Color(0xFFF0D4E1)]),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                    color: AppColors.accent.withValues(alpha: .11),
                    blurRadius: 35,
                    offset: const Offset(0, 12))
              ]),
          child: CustomPaint(painter: _MarkPainter())));
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s.width * .045;
    canvas.drawLine(Offset(s.width * .5, s.height * .27),
        Offset(s.width * .5, s.height * .73), paint);
    canvas.drawLine(Offset(s.width * .35, s.height * .43),
        Offset(s.width * .65, s.height * .43), paint);
    paint
      ..strokeWidth = .8
      ..color = AppColors.accent.withValues(alpha: .25);
    canvas.drawArc(
        Rect.fromCircle(
            center: Offset(s.width / 2, s.height / 2), radius: s.width * .39),
        -.8,
        4.9,
        false,
        paint);
    canvas.drawCircle(Offset(s.width * .78, s.height * .22), s.width * .018,
        Paint()..color = AppColors.accent.withValues(alpha: .6));
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}

class MenuRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  const MenuRow(
      {super.key,
      required this.title,
      required this.icon,
      this.subtitle,
      this.onTap,
      this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HolyPressable(
          onPressed: onTap,
          child: GlassSurface(
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.surfaceLight.withValues(alpha: .6),
                        borderRadius: BorderRadius.circular(13)),
                    child: Icon(icon, color: AppColors.accent, size: 20)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(subtitle!,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.5))
                      ]
                    ])),
                const SizedBox(width: 10),
                trailing ??
                    Icon(
                        onTap == null
                            ? Icons.check_rounded
                            : Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.textSecondary)
              ]))));
}

class SectionLabel extends StatelessWidget {
  final String title;
  const SectionLabel(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 25, bottom: 12, left: 3),
      child: Eyebrow(title));
}

class InlineMessage extends StatelessWidget {
  final String text;
  final bool error;
  const InlineMessage(this.text, {super.key, this.error = false});
  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: error ? const Color(0xFFFBE9EC) : AppColors.surface,
              borderRadius: BorderRadius.circular(18)),
          child: Text(text,
              style: TextStyle(
                  color:
                      error ? const Color(0xFF9C263B) : AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5))));
}

void showNotice(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
