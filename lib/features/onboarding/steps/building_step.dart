import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/lessons.g.dart';
import '../../../design/design.dart';
import '../../../design/widgets/coin_3d.dart';
import '../../../domain/onboarding_flow.dart';
import '../onboarding_copy.dart';
import '../widgets/onboarding_tokens.dart';
import '../widgets/step_title.dart';

/// "Building your walk". Her first medallion spins in, the one Day 1 will
/// give her; then a short checklist ticks itself off while the profile is
/// saved, and the card gives a small, glad lift when the save lands.
///
/// It shares its card with the letter that follows: when the save lands the
/// card stays where it is and the letter opens in it.
class BuildingStep extends StatefulWidget {
  final String name;
  final OnboardingAnswers answers;
  final String? error;

  /// The save has landed.
  final bool saved;
  final bool reminderOn;
  final int reminderMinutes;
  final Color accent, glow;
  const BuildingStep(
      {super.key,
      required this.name,
      required this.answers,
      required this.error,
      required this.reminderOn,
      required this.reminderMinutes,
      required this.accent,
      required this.glow,
      this.saved = false});

  /// When the first line ticks, after the medallion has come to rest.
  static const firstTick = Duration(milliseconds: 1300);
  static const tickEvery = Duration(milliseconds: 640);

  @override
  State<BuildingStep> createState() => _BuildingStepState();
}

class _BuildingStepState extends State<BuildingStep>
    with SingleTickerProviderStateMixin {
  static const _lines = 4;
  int done = 0;
  Timer? _timer;
  late final AnimationController _pop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 620));

  @override
  void initState() {
    super.initState();
    _timer = Timer(BuildingStep.firstTick, () {
      if (!mounted) return;
      _tick();
      _timer = Timer.periodic(BuildingStep.tickEvery, (t) {
        if (!mounted || done >= _lines) {
          t.cancel();
          return;
        }
        _tick();
      });
    });
  }

  void _tick() {
    setState(() => done++);
    HolyHaptics.chipSelect();
    unawaited(HolySounds.lessonLand(intensity: .3 + done * .05));
  }

  @override
  void didUpdateWidget(BuildingStep old) {
    super.didUpdateWidget(old);
    if (widget.saved && !old.saved) {
      _timer?.cancel();
      setState(() => done = _lines);
      if (!MediaQuery.disableAnimationsOf(context)) _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heart = labelFor(heartChoices, widget.answers.hearts.firstOrNull)
            ?.toLowerCase() ??
        'peace';
    final lines = [
      'Choosing verses for $heart',
      'Writing each lesson in plain words',
      widget.reminderOn
          ? 'Setting your note for ${OnboardingCopy.clock(widget.reminderMinutes)}'
          : 'Saving your place for any time of day',
      'Preparing Day 1: ${lessons.first.title}',
    ];
    return Padding(
        padding: OnboardingTokens.pageInsets(context),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StepTitle(text: OnboardingCopy.buildingTitle(widget.name)),
          const SizedBox(height: 18),
          Expanded(
              child: AnimatedBuilder(
                  animation: _pop,
                  builder: (context, child) {
                    // Up and back, once: a breath of gladness.
                    final v = _pop.value;
                    final lift = v < .4
                        ? Curves.easeOut.transform(v / .4)
                        : 1 - Curves.easeInOutBack.transform((v - .4) / .6);
                    return Transform.scale(
                        scale: 1 + .035 * lift.clamp(-.2, 1.0), child: child);
                  },
                  child: GlowCard(
                      colors: OnboardingTokens.glowBase,
                      glow: widget.glow,
                      blobScale: .75,
                      borderRadius: OnboardingTokens.panelRadius,
                      borderColor: OnboardingTokens.panelBorder,
                      shadows: OnboardingTokens.cardShadow,
                      padding: EdgeInsets.zero,
                      child: LayoutBuilder(builder: (context, box) {
                        final coin = (box.maxHeight * .30).clamp(84.0, 150.0);
                        return Center(
                            child: SingleChildScrollView(
                                padding:
                                    const EdgeInsets.fromLTRB(22, 18, 22, 10),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Center(
                                          child: _Medallion(
                                              size: coin, glow: widget.glow)),
                                      const SizedBox(height: 10),
                                      Rise(
                                          delay:
                                              const Duration(milliseconds: 900),
                                          distance: 8,
                                          child: Column(children: [
                                            Text(
                                                OnboardingCopy.medallionCaption,
                                                textAlign: TextAlign.center,
                                                style: HolyTypography.headline
                                                    .copyWith(
                                                        fontSize: 23,
                                                        color: OnboardingTokens
                                                            .textPrimary)),
                                            const SizedBox(height: 2),
                                            Text(
                                                OnboardingCopy.medallionName
                                                    .toUpperCase(),
                                                textAlign: TextAlign.center,
                                                style: HolyTypography.eyebrow
                                                    .copyWith(
                                                        fontSize: 10.5,
                                                        color: widget.accent)),
                                          ])),
                                      const SizedBox(height: 18),
                                      for (var i = 0; i < lines.length; i++)
                                        Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12),
                                            child: AnimatedOpacity(
                                                duration: const Duration(
                                                    milliseconds: 320),
                                                opacity: i <= done ? 1 : .36,
                                                child: Row(children: [
                                                  HolyCheck(
                                                      checked: i < done,
                                                      size: 22,
                                                      color: widget.accent,
                                                      ink: OnboardingTokens
                                                          .onPlum),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                      child: Text(lines[i],
                                                          style: HolyTypography
                                                              .ui
                                                              .copyWith(
                                                                  fontSize: 15,
                                                                  color: OnboardingTokens
                                                                      .textPrimary))),
                                                ]))),
                                      if (widget.error != null)
                                        Semantics(
                                            liveRegion: true,
                                            child: Text(widget.error!,
                                                style: HolyTypography.caption
                                                    .copyWith(
                                                        color: widget.accent))),
                                    ])));
                      })))),
        ]));
  }
}

/// The Day 1 medallion, spinning in out of a soft glow.
class _Medallion extends StatelessWidget {
  final double size;
  final Color glow;
  const _Medallion({required this.size, required this.glow});

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
        tween: Tween(begin: reduced ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 1500),
        curve: Curves.easeOutBack,
        builder: (context, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(scale: .55 + .45 * t, child: child)),
        child: Stack(alignment: Alignment.center, children: [
          // A halo behind the coin, in the step's light.
          Container(
              width: size * 1.25,
              height: size * 1.25,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    glow.withValues(alpha: .55),
                    glow.withValues(alpha: 0),
                  ]))),
          Semantics(
              label: 'The ${OnboardingCopy.medallionName} medallion',
              child: Coin3D(
                  badgeId: 'days-1', earned: true, size: size, spinIn: true)),
        ]));
  }
}
