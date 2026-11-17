import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../data/lessons.g.dart';
import '../../../design/art_catalog.dart';
import '../../../design/design.dart';
import '../onboarding_copy.dart';
import '../widgets/onboarding_tokens.dart';
import '../widgets/step_title.dart';

/// His first seven days. Three of the real lesson cards rise and fan out in
/// perspective, then a path runs down the week below them and each day
/// lights, with a soft sound, as the line reaches it. The titles are the real
/// lessons he is about to read, so nothing here is a promise the app has to
/// keep later.
class FirstWeekStep extends StatefulWidget {
  final String name;
  final Color accent, glow;

  /// His own words, said back to him. Null shows the plain subtitle.
  final String? echo;

  /// True once he has seen the path draw; coming back shows it finished.
  final bool revealed;
  final VoidCallback onRevealed;
  const FirstWeekStep(
      {super.key,
      required this.name,
      required this.accent,
      required this.glow,
      required this.revealed,
      required this.onRevealed,
      this.echo});

  @override
  State<FirstWeekStep> createState() => _FirstWeekStepState();
}

class _FirstWeekStepState extends State<FirstWeekStep>
    with SingleTickerProviderStateMixin {
  static const _days = 7;
  late final AnimationController _draw = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
      value: widget.revealed ? 1 : 0);
  Timer? _start;
  int _lit = 0;

  @override
  void initState() {
    super.initState();
    _lit = widget.revealed ? _days : 0;
    _draw.addListener(_onDraw);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.revealed || _start != null || _draw.value > 0) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Shown whole, at once; the listener then reports it as seen.
      _lit = _days;
      _draw.value = 1;
      return;
    }
    // After the cards have fanned out, so the first day is seen lighting.
    _start = Timer(const Duration(milliseconds: 1250), () {
      if (mounted) _draw.forward();
    });
  }

  void _onDraw() {
    // Day i lights when the line, easing down the week, reaches it.
    final reached =
        (Curves.easeInOut.transform(_draw.value) * (_days - 1) + 1.001)
            .floor()
            .clamp(0, _days);
    final lit = _draw.value == 0 ? 0 : reached;
    if (lit != _lit) {
      if (lit > _lit && !widget.revealed) {
        HolyHaptics.detent();
        // A soft pat for each day, and a small bright note for the last.
        unawaited(lit == _days
            ? HolySounds.lessonCorrect()
            : HolySounds.lessonLand(intensity: .32 + lit * .04));
      }
      setState(() => _lit = lit);
    }
    if (_draw.value == 1 && !widget.revealed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRevealed();
      });
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final week = lessons.take(_days).toList();
    return Padding(
        padding: OnboardingTokens.pageInsets(context),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StepTitle(
              text: OnboardingCopy.firstWeekTitle(widget.name),
              subtitle: widget.echo ?? OnboardingCopy.firstWeekSubtitle),
          const SizedBox(height: 14),
          Expanded(child: LayoutBuilder(builder: (context, box) {
            const gap = 14.0;
            const chrome = 14.0 + 26 + 12; // padding, label, padding
            // A row is never shorter than its words.
            final scale = MediaQuery.textScalerOf(context).scale(1.0);
            final minRow = (40.0 * scale).clamp(40.0, 80.0);
            // The week comes first; the cards take what room is left, and
            // step aside on a short screen rather than shrink past reading.
            final spare = box.maxHeight - chrome - minRow * _days - gap;
            final fan = math.min(box.maxHeight * .32, spare).clamp(0.0, 168.0);
            final showFan = fan >= 96;
            // At the largest text the week may not fit at all; then, and
            // only then, it scrolls.
            final fits = box.maxHeight >= chrome + minRow * _days;
            final row = fits
                ? ((box.maxHeight - chrome - (showFan ? fan + gap : 0)) / _days)
                    .clamp(minRow, 54.0)
                : minRow;
            final twoLines = row >= 46;
            final content = Column(mainAxisSize: MainAxisSize.min, children: [
              if (showFan) ...[
                SizedBox(
                    height: fan,
                    child: _Fan(
                        days: [for (final l in week.take(3)) l.day],
                        titles: [for (final l in week.take(3)) l.title],
                        accent: widget.accent)),
                const SizedBox(height: gap),
              ],
              Rise(
                  delay: const Duration(milliseconds: 520),
                  child: GlowCard(
                      colors: OnboardingTokens.glowBase,
                      glow: widget.glow,
                      glowStrength: .9,
                      blobScale: .7,
                      borderRadius: OnboardingTokens.panelRadius,
                      borderColor: OnboardingTokens.panelBorder,
                      shadows: OnboardingTokens.cardShadow,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                                height: 26,
                                child: Text(OnboardingCopy.firstWeekLabel,
                                    maxLines: 1,
                                    style: HolyTypography.eyebrow
                                        .copyWith(color: widget.accent))),
                            SizedBox(
                                height: row * _days,
                                child: Stack(children: [
                                  Positioned.fill(
                                      child: AnimatedBuilder(
                                          animation: _draw,
                                          builder: (context, _) => CustomPaint(
                                              painter: _PathPainter(
                                                  progress: Curves.easeInOut
                                                      .transform(_draw.value),
                                                  row: row,
                                                  days: _days,
                                                  color: widget.accent)))),
                                  Column(children: [
                                    for (var i = 0; i < week.length; i++)
                                      SizedBox(
                                          height: row,
                                          child: _DayRow(
                                              day: week[i].day,
                                              emoji: OnboardingCopy
                                                  .firstWeekEmoji[i],
                                              title: week[i].title,
                                              reference: twoLines
                                                  ? week[i].reference
                                                  : null,
                                              lit: i < _lit,
                                              accent: widget.accent)),
                                  ]),
                                ])),
                          ]))),
            ]);
            return fits ? content : SingleChildScrollView(child: content);
          })),
        ]));
  }
}

/// Three lesson cards fanned in perspective: Day 1 in front, Days 2 and 3
/// turned away behind it. They rise into place one after another, then
/// breathe very slightly, as cards held in a hand do.
class _Fan extends StatefulWidget {
  final List<int> days;
  final List<String> titles;
  final Color accent;
  const _Fan({required this.days, required this.titles, required this.accent});
  @override
  State<_Fan> createState() => _FanState();
}

class _FanState extends State<_Fan> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _float = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 5200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _in.value = 1;
      _float.stop();
    } else if (_in.value == 0 && !_in.isAnimating) {
      Future<void>.delayed(const Duration(milliseconds: 260), () {
        if (mounted) _in.forward();
      });
      _float.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _in.dispose();
    _float.dispose();
    super.dispose();
  }

  /// Where each card rests: Day 2 to the left, Day 3 to the right, Day 1 in
  /// front. Each crops a different part of the chapter's photograph.
  static const _rest = [
    (x: 0.0, turn: 0.0, tilt: 0.0, z: 0.0, focus: Alignment(0, .62)),
    (x: -.62, turn: .42, tilt: -.10, z: 40.0, focus: Alignment(.86, .18)),
    (x: .62, turn: -.42, tilt: .10, z: 40.0, focus: Alignment(-.86, .14)),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final h = box.maxHeight;
        final w = h * .74;
        return AnimatedBuilder(
            animation: Listenable.merge([_in, _float]),
            builder: (context, _) {
              final breath =
                  Curves.easeInOutSine.transform(_float.value) * 2 - 1;
              // Back cards first, so Day 1 is painted on top.
              final order = [1, 2, 0];
              return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    for (final i in order) _card(i, w, h, breath, box.maxWidth),
                  ]);
            });
      });

  Widget _card(int i, double w, double h, double breath, double width) {
    final rest = _rest[i];
    // Day 1 rises first, then the two behind it open out.
    final start = i == 0 ? 0.0 : .28 + (i - 1) * .1;
    final t = Curves.easeOutBack
        .transform(((_in.value - start) / (1 - start)).clamp(0.0, 1.0));
    final open = t.clamp(0.0, 1.2);
    final x = rest.x * (width / 2 - w / 2) * open;
    final lift = (1 - t) * 26 - (i == 0 ? breath * 3 : -breath * 2);
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, .0016)
      ..translateByDouble(x, lift, rest.z * open, 1)
      ..rotateY(rest.turn * open + (i == 0 ? breath * .03 : 0))
      ..rotateZ(rest.tilt * open);
    return Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform(
            alignment: Alignment.center,
            transform: matrix,
            child: SizedBox(
                width: w,
                height: h,
                child: _LessonCard(
                    day: widget.days[i],
                    title: widget.titles[i],
                    focus: rest.focus,
                    front: i == 0,
                    height: h,
                    accent: widget.accent))));
  }
}

class _LessonCard extends StatelessWidget {
  final int day;
  final String title;
  final Alignment focus;
  final bool front;
  final Color accent;

  /// The card's height, which its words are sized from.
  final double height;
  const _LessonCard(
      {required this.day,
      required this.title,
      required this.focus,
      required this.front,
      required this.accent,
      required this.height});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Semantics(
        label: 'Day $day. $title',
        excludeSemantics: true,
        child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: radius, boxShadow: [
              BoxShadow(
                  color: OnboardingTokens.shade
                      .withValues(alpha: front ? .42 : .30),
                  blurRadius: front ? 22 : 14,
                  offset: Offset(0, front ? 12 : 8)),
            ]),
            child: ClipRRect(
                borderRadius: radius,
                child: Stack(fit: StackFit.expand, children: [
                  // The chapter's photograph, brought close on one part of
                  // it, so the three cards are three views of one morning.
                  ClipRect(
                      child: Transform.scale(
                          scale: 1.9,
                          alignment: focus,
                          child: BundledArt(
                              asset: HolyArtCatalog.assetForDay(day),
                              alignment: focus,
                              fallback: const ColoredBox(
                                  color: HolyTheme.photoShade)))),
                  DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [
                        .35,
                        1
                      ],
                              colors: [
                        HolyTheme.photoShade.withValues(alpha: 0),
                        HolyTheme.photoShade.withValues(alpha: .78),
                      ]))),
                  DecoratedBox(
                      decoration: BoxDecoration(
                          borderRadius: radius,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: .7),
                              width: 1.2))),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DecoratedBox(
                                decoration: ShapeDecoration(
                                    color: Colors.white.withValues(alpha: .9),
                                    shape: const StadiumBorder()),
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    child: Text('DAY $day',
                                        textScaler: TextScaler.noScaling,
                                        style: HolyTypography.eyebrow.copyWith(
                                            fontSize: 9,
                                            letterSpacing: 1.1,
                                            color: accent)))),
                            const Spacer(),
                            Text(title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                textScaler: TextScaler.noScaling,
                                style: HolyTypography.headline.copyWith(
                                    fontSize:
                                        math.min(17, 13 + (front ? 4 : 2)),
                                    height: 1.08,
                                    color: HolyTheme.photoInk)),
                          ])),
                ]))));
  }
}

class _DayRow extends StatelessWidget {
  final int day;
  final String emoji, title;
  final String? reference;
  final bool lit;
  final Color accent;
  const _DayRow(
      {required this.day,
      required this.emoji,
      required this.title,
      required this.reference,
      required this.lit,
      required this.accent});

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduced ? Duration.zero : const Duration(milliseconds: 380);
    return Semantics(
        label: 'Day $day. $title${reference == null ? '' : '. $reference'}',
        excludeSemantics: true,
        child: Row(children: [
          AnimatedScale(
              scale: lit ? 1 : .86,
              duration: duration,
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // Opaque, so the line passes behind the day.
                      color: lit ? accent : OnboardingTokens.white,
                      border: Border.all(
                          color: lit
                              ? accent
                              : OnboardingTokens.plum.withValues(alpha: .18)),
                      boxShadow: lit
                          ? [
                              BoxShadow(
                                  color: accent.withValues(alpha: .38),
                                  blurRadius: 10,
                                  spreadRadius: 1)
                            ]
                          : null),
                  child: Text('$day',
                      textScaler: TextScaler.noScaling,
                      style: HolyTypography.label.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: lit
                              ? OnboardingTokens.onPlum
                              : OnboardingTokens.textTertiary)))),
          const SizedBox(width: 12),
          Expanded(
              child: AnimatedOpacity(
                  duration: duration,
                  opacity: lit ? 1 : .5,
                  child: Row(children: [
                    Text(emoji,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(fontSize: 15, height: 1)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HolyTypography.ui.copyWith(
                                  fontSize: 14.5,
                                  height: 1.2,
                                  fontWeight: FontWeight.w600,
                                  color: OnboardingTokens.textPrimary)),
                          if (reference != null)
                            Text(reference!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HolyTypography.caption.copyWith(
                                    fontSize: 11.5,
                                    height: 1.25,
                                    color: OnboardingTokens.textSecondary)),
                        ])),
                  ]))),
        ]));
  }
}

/// The line down the week: a faint track for the whole of it, and the lit
/// part drawn over that as far as [progress] has reached.
class _PathPainter extends CustomPainter {
  final double progress, row;
  final int days;
  final Color color;
  _PathPainter(
      {required this.progress,
      required this.row,
      required this.days,
      required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const x = 13.0;
    final top = row / 2, bottom = row * (days - .5);
    final track = Paint()
      ..color = OnboardingTokens.plum.withValues(alpha: .10)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, top), Offset(x, bottom), track);
    if (progress <= 0) return;
    final end = top + (bottom - top) * progress;
    canvas.drawLine(
        Offset(x, top),
        Offset(x, end),
        Paint()
          ..color = color
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round);
    if (progress < 1) {
      // The travelling point of light at the line's tip.
      canvas.drawCircle(
          Offset(x, end),
          6,
          Paint()
            ..color = color.withValues(alpha: .5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.progress != progress || old.row != row || old.color != color;
}
