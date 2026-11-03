import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
export 'holy_objects.dart';
export 'holy_reveal.dart';
import 'holy_objects.dart';
import 'package:holyher/core/widgets/holy_material.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:holyher/core/widgets/holy_motion.dart';
import 'package:holyher/services/feedback_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';

class _BackdropScope extends InheritedWidget {
  const _BackdropScope({required super.child});
  @override
  bool updateShouldNotify(_BackdropScope oldWidget) => false;
}

class BlushBackdrop extends StatefulWidget {
  final Widget child;
  const BlushBackdrop({super.key, required this.child});
  @override
  State<BlushBackdrop> createState() => _BlushBackdropState();
}

class _BlushBackdropState extends State<BlushBackdrop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _motion =
      AnimationController(vsync: this, duration: const Duration(seconds: 20));
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _reconcile() {
    if (context.dependOnInheritedWidgetOfExactType<_BackdropScope>() != null) {
      _motion.stop();
      return;
    }
    if (!_foreground ||
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _motion.stop();
      if (MediaQuery.disableAnimationsOf(context)) _motion.value = .25;
    } else if (!_motion.isAnimating) {
      _motion.repeat(reverse: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reconcile();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _reconcile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    if (context.dependOnInheritedWidgetOfExactType<_BackdropScope>() != null) {
      return widget.child;
    }
    return _BackdropScope(
        child: Stack(fit: StackFit.expand, children: [
      ColoredBox(color: AppColors.background),
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: LayoutBuilder(builder: (context, box) {
              return ClipRect(
                  child: Stack(children: [
                Positioned(
                  left: -box.maxWidth * .1,
                  top: -box.maxHeight * .1,
                  width: box.maxWidth * 1.2,
                  height: box.maxHeight * 1.2,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                        sigmaX: 30, sigmaY: 30, tileMode: TileMode.clamp),
                    child: AnimatedBuilder(
                        animation: _motion,
                        builder: (context, _) => CustomPaint(
                            painter: _MeshPainter(
                                _motion.value, AppColors.palette))),
                  ),
                ),
              ]));
            }),
          ),
        ),
      ),
      Positioned.fill(
          child: IgnorePointer(
              child: RepaintBoundary(
                  child: AnimatedBuilder(
                      animation: _motion,
                      builder: (context, _) => CustomPaint(
                          painter: _PearlParticles(
                              _motion.value, AppColors.palette)))))),
      widget.child
    ]));
  }
}

class _MeshPainter extends CustomPainter {
  final double phase;
  final HolyPalette palette;
  const _MeshPainter(this.phase, this.palette);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.background,
                palette.background,
                palette.card,
                palette.blush.withValues(alpha: .4),
                palette.background
              ],
              stops: [
                0,
                .25,
                .5,
                .75,
                1
              ]).createShader(Offset.zero & size));
    for (var i = 0; i < 4; i++) {
      final origins = [
        const Offset(1.02, .08),
        const Offset(-.32, .46),
        const Offset(.12, 1.08),
        const Offset(.94, .86)
      ];
      final colors = [
        palette.edge.withValues(alpha: .30),
        palette.blush.withValues(alpha: .25),
        palette.champagne.withValues(alpha: .15),
        palette.accent.withValues(alpha: .12)
      ];
      final frequency = .5 + i * .17;
      final center = Offset(
          size.width *
              (origins[i].dx +
                  .08 * math.sin(phase * math.pi * 2 * frequency + i)),
          size.height *
              (origins[i].dy +
                  .06 * math.cos(phase * math.pi * 2 * frequency + i)));
      final radius = math.max(size.width, size.height) * (.45 + i * .08);
      canvas.drawCircle(
          center,
          radius,
          Paint()
            ..shader = RadialGradient(
                    colors: [colors[i], colors[i].withValues(alpha: 0)])
                .createShader(Rect.fromCircle(center: center, radius: radius)));
    }
  }

  @override
  bool shouldRepaint(_MeshPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.palette != palette;
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
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => BlushBackdrop(
          child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: title == null
                  ? null
                  : PreferredSize(
                      preferredSize: const Size.fromHeight(kToolbarHeight),
                      child: HolyFadingMaterial(
                          child: AppBar(
                              title: Text(title!,
                                  style: HolyTypography.action
                                      .copyWith(color: AppColors.textPrimary)),
                              actions: actions))),
              body: SafeArea(child: body),
              bottomNavigationBar: bottomNavigationBar)));
}

class ReadingWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ReadingWidth({super.key, required this.child, this.maxWidth = 720});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth), child: child)));
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
  Widget build(BuildContext context) =>
      useHolyPalette(context, () => QuietInset(padding: padding, child: child));
}

/// Finger-driven feedback follows Cognein's immediate press vocabulary.
class HolyPressable extends ConsumerStatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String? label;
  final bool? selected;
  final double radius;
  final bool semanticButton;
  const HolyPressable(
      {super.key,
      required this.child,
      required this.onPressed,
      this.label,
      this.selected,
      this.semanticButton = true,
      this.radius = 24});
  @override
  ConsumerState<HolyPressable> createState() => _HolyPressableState();
}

class _HolyPressableState extends ConsumerState<HolyPressable>
    with SingleTickerProviderStateMixin {
  late final _scale = AnimationController.unbounded(vsync: this, value: 1);
  bool _pressed = false;
  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _highlight(bool value) {
    if (_pressed == value) return;
    _pressed = value;
    if (value && widget.onPressed != null) {
      ref.read(feedbackProvider).selection();
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _scale.value = value ? HolyMotion.pressedScale : 1;
    } else if (value) {
      _scale.animateTo(HolyMotion.pressedScale,
          duration: HolyMotion.pressIn, curve: HolyMotion.pressInCurve);
    } else {
      _scale.animateWith(SpringSimulation(
          HolyMotion.pressRelease, _scale.value, 1, _scale.velocity));
    }
  }

  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => Semantics(
          button: widget.semanticButton,
          enabled: widget.semanticButton ? widget.onPressed != null : null,
          selected: widget.selected,
          label: widget.label,
          onTap: widget.label != null ? widget.onPressed : null,
          excludeSemantics: widget.label != null,
          child: ScaleTransition(
              scale: _scale,
              child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                      onTap: widget.onPressed,
                      onHighlightChanged: _highlight,
                      borderRadius: BorderRadius.circular(widget.radius),
                      splashFactory: NoSplash.splashFactory,
                      highlightColor: Colors.transparent,
                      canRequestFocus: widget.onPressed != null,
                      child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(minWidth: 44, minHeight: 44),
                          child: widget.child))))));
}

class HolyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool secondary;
  final bool destructive;
  final IconData? icon;
  final Widget? leading;
  final Color? foregroundColor;
  const HolyButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.busy = false,
      this.secondary = false,
      this.destructive = false,
      this.icon,
      this.leading,
      this.foregroundColor});
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final enabled = onPressed != null && !busy;
    return HolyPressable(
        onPressed: enabled ? onPressed : null,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            decoration: BoxDecoration(
                gradient: secondary
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: enabled
                            ? destructive
                                ? [AppColors.error, const Color(0xFF6E1829)]
                                : [AppColors.accent, AppColors.accentDark]
                            : [
                                const Color(0xFFBC9CAA),
                                const Color(0xFFAB8898)
                              ]),
                color:
                    secondary ? AppColors.pearl.withValues(alpha: .78) : null,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: secondary
                        ? AppColors.textSecondary.withValues(alpha: .78)
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
                            color: secondary
                                ? AppColors.accent
                                : (AppColors.palette.isDark
                                    ? AppColors.background
                                    : Colors.white))))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 10)
                    ],
                    if (leading == null && icon != null) ...[
                      Icon(icon,
                          size: 21,
                          color: foregroundColor ??
                              (secondary
                                  ? AppColors.accent
                                  : (AppColors.palette.isDark
                                      ? AppColors.background
                                      : Colors.white))),
                      const SizedBox(width: 10)
                    ],
                    Flexible(
                        child: Text(label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: foregroundColor ??
                                    (secondary
                                        ? AppColors.accentDark
                                        : (AppColors.palette.isDark
                                            ? AppColors.background
                                            : Colors.white)))))
                  ])));
  }
}

class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final identifier =
        RegExp(r'^(day|unit)\s+\d', caseSensitive: false).hasMatch(text);
    final label = identifier
        ? text.toUpperCase()
        : text.isEmpty
            ? text
            : '${text[0].toUpperCase()}${text.substring(1)}';
    return Text(label,
        style: HolyTypography.label.copyWith(
            letterSpacing: identifier ? 1.2 : 0, color: AppColors.accent));
  }
}

class PageHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  const PageHeading(
      {super.key, required this.eyebrow, required this.title, this.subtitle});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Eyebrow(eyebrow),
            const SizedBox(height: 9),
            Text(title, style: HolyTypography.heading),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium)
            ]
          ]));
}

class HolyMark extends StatelessWidget {
  final double size;
  final bool launch;
  const HolyMark({super.key, this.size = 88, this.launch = false});
  static Future<void> prepare() async {
    final ready = Completer<void>();
    final stream = const AssetImage('assets/brand/holyher-mark.png')
        .resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((image, synchronous) {
      if (!ready.isCompleted) ready.complete();
    }, onError: (Object error, StackTrace? stack) {
      if (!ready.isCompleted) ready.completeError(error, stack);
    });
    stream.addListener(listener);
    try {
      await ready.future;
    } finally {
      stream.removeListener(listener);
    }
  }

  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => Semantics(
          label: 'HolyHer cross',
          image: true,
          child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * .23),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.accentDark.withValues(alpha: .12),
                        blurRadius: size * .22,
                        offset: Offset(0, size * .08))
                  ]),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(launch ? 0 : size * .23),
                  child: Stack(children: [
                    Image.asset('assets/brand/holyher-mark.png',
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true),
                    Positioned.fill(
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    launch ? 0 : size * .23),
                                border: Border.all(
                                    color: Colors.white
                                        .withValues(alpha: launch ? 0 : .65),
                                    width: 1))))
                  ])))));
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
  Widget build(BuildContext context) {
    Theme.of(context);
    final row = Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: HolyPressable(
            onPressed: onTap,
            semanticButton: onTap != null,
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
                decoration: BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: AppColors.divider))),
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
                        Text(title, style: HolyTypography.body),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(subtitle!,
                              style: HolyTypography.supporting
                                  .copyWith(color: AppColors.textSecondary))
                        ]
                      ])),
                  const SizedBox(width: 10),
                  trailing ??
                      (onTap == null
                          ? const SizedBox.shrink()
                          : Icon(Icons.chevron_right_rounded,
                              size: 20, color: AppColors.textSecondary))
                ]))));
    return onTap == null && trailing is Switch
        ? MergeSemantics(child: row)
        : row;
  }
}

class SectionLabel extends StatelessWidget {
  final String title;
  const SectionLabel(this.title, {super.key});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => Padding(
          padding: const EdgeInsets.only(top: 25, bottom: 12, left: 3),
          child: Text(title,
              style: HolyTypography.supporting.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary))));
}

class InlineMessage extends StatelessWidget {
  final String text;
  final bool error;
  const InlineMessage(this.text, {super.key, this.error = false});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => Semantics(
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
                      color: error
                          ? const Color(0xFF9C263B)
                          : AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.43)))));
}

void showNotice(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class HolyRecovery extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onSignOut;
  const HolyRecovery(
      {super.key,
      required this.message,
      required this.onRetry,
      this.onSignOut});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => HolyScaffold(
          body: Center(
              child: ReadingWidth(
                  maxWidth: 488,
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(child: HolyMark(size: 72)),
                            const SizedBox(height: 32),
                            const Text('Let’s reconnect.',
                                textAlign: TextAlign.center,
                                style: HolyTypography.heading),
                            const SizedBox(height: 16),
                            Text(message, textAlign: TextAlign.center),
                            const SizedBox(height: 28),
                            HolyButton(label: 'Retry', onPressed: onRetry),
                            if (onSignOut != null)
                              TextButton(
                                  onPressed: onSignOut,
                                  child: const Text('Sign out'))
                          ]))))));
}

class _PearlParticles extends CustomPainter {
  final double phase;
  final HolyPalette palette;
  const _PearlParticles(this.phase, this.palette);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = palette.accent.withValues(alpha: .12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);
    for (var i = 0; i < 16; i++) {
      final x =
          ((i * .6180339) % 1 + .015 * math.sin(phase * math.pi * 2 + i)) *
              size.width;
      final y =
          ((i * .381966 + .12) % 1 + .02 * math.cos(phase * math.pi * 2 + i)) *
              size.height;
      canvas.drawCircle(Offset(x, y), 1.2 + (i % 3) * .5, paint);
    }
  }

  @override
  bool shouldRepaint(_PearlParticles old) =>
      old.phase != phase || old.palette != palette;
}
