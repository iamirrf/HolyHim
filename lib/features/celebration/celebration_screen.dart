import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../design/design.dart';
import '../../domain/streak.dart';
import '../../domain/completion_moment.dart';
export '../../domain/completion_moment.dart';
import '../../services/auth_service.dart';
import '../../services/repository.dart';
import '../../data/lessons.g.dart';
import '../../services/share_card.dart';

CompletionMoment completionMomentBetween(
        {required int day,
        required WalkState before,
        required WalkState after,
        required DateTime now}) =>
    CompletionMoment.fromProgress(
        day: day,
        beforeCompleted: before.completed,
        completed: after.completed,
        beforeSaved: before.saved,
        saved: after.saved,
        timeZone: after.profile.timeZone,
        promiseStartedAt: after.profile.promiseStartedAt,
        now: now);

final completionMomentProvider = StateProvider<CompletionMoment?>((ref) {
  ref.watch(authProvider.select((state) => state.user?.uid));
  return null;
});

class CelebrationScreen extends ConsumerStatefulWidget {
  final int day;
  const CelebrationScreen({super.key, required this.day});
  @override
  ConsumerState<CelebrationScreen> createState() => _CelebrationScreenState();
}

/// The moment after Amen: the light from the button resolves into a morning
/// sky, then "Amen.", the walk rolling forward, any new medallion, a line to
/// carry today and tomorrow's title.
class _CelebrationScreenState extends ConsumerState<CelebrationScreen>
    with SingleTickerProviderStateMixin {
  late final _light = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100), value: 1);
  CompletionMoment? _moment;

  @override
  void initState() {
    super.initState();
    final receipt = ref.read(completionMomentProvider);
    if (receipt?.day == widget.day) _moment = receipt;
    scheduleMicrotask(() {
      if (mounted && identical(ref.read(completionMomentProvider), receipt)) {
        ref.read(completionMomentProvider.notifier).state = null;
      }
    });
  }

  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context) || _moment == null) {
      _light.value = 0;
    } else {
      HolySounds.lessonSurge();
      _light.reverse();
      Timer(const Duration(milliseconds: 900), () {
        if (mounted) HolyHaptics.celebration();
      });
    }
    if (_moment != null && (widget.day == 3 || widget.day == 10)) {
      Timer(const Duration(seconds: 3), requestStoreReview);
    }
  }

  @override
  void dispose() {
    _light.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final state = ref.watch(repositoryProvider);
    final streak =
        streakFor(state.completed, DateTime.now(), state.profile.timeZone);
    final lesson = lessons[widget.day - 1];
    final next = widget.day < 365 ? lessons[widget.day] : null;
    final badge = _moment?.newlyEarned.firstOrNull;
    final media = MediaQuery.of(context);
    final compact = media.size.height < 740;
    final from = _moment?.previousStreak ?? streak.current;
    return Scaffold(
        backgroundColor: HolyTheme.photoShade,
        body: Stack(fit: StackFit.expand, children: [
          const PhotoStage(
              images: ['assets/art/library/sky-rays.webp'],
              alignment: Alignment(0, .1),
              topVeil: .35,
              bottomVeil: .75,
              child: LightMotes(count: 26)),
          FitColumn(
              crossAxisAlignment: CrossAxisAlignment.center,
              padding: EdgeInsets.fromLTRB(HolySpace.gutter,
                  media.padding.top + (compact ? 20 : 48), HolySpace.gutter,
                  media.padding.bottom + 14),
              children: [
                Rise(
                    delay: const Duration(milliseconds: 500),
                    child: Text('Amen.',
                        style: HolyTypography.accent.copyWith(
                            color: HolyTheme.photoInk,
                            fontSize: compact ? 64 : 80,
                            shadows: const [
                              Shadow(color: Color(0x66000000), blurRadius: 24)
                            ]))),
                const SizedBox(height: 6),
                Rise(
                    delay: const Duration(milliseconds: 800),
                    child: Text('Day ${widget.day} is complete',
                        style: HolyTypography.ui.copyWith(
                            color: HolyTheme.photoInk.withValues(alpha: .9),
                            fontWeight: FontWeight.w600))),
                SizedBox(height: compact ? 14 : 24),
                Rise(
                    delay: const Duration(milliseconds: 1100),
                    child: _WalkCount(from: from, to: streak.current)),
                const Spacer(),
                if (badge != null)
                  Rise(
                      delay: const Duration(milliseconds: 1500),
                      child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Badge3D(
                                    label: badge.title,
                                    badgeId: badge.id,
                                    earned: true,
                                    showLabel: false,
                                    size: compact ? 64 : 78),
                                const SizedBox(width: 14),
                                Flexible(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      const Eyebrow('New medallion',
                                          color: Color(0xFFF6DDB0)),
                                      Text(badge.title,
                                          style: HolyTypography.headline
                                              .copyWith(
                                                  color: HolyTheme.photoInk,
                                                  fontSize: 24)),
                                    ])),
                              ]))),
                Rise(
                    delay: const Duration(milliseconds: 1300),
                    child: Paper(
                        padding: EdgeInsets.all(compact ? 18 : 22),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Eyebrow('Carry this today'),
                              const SizedBox(height: 8),
                              Text(lesson.holdOn,
                                  style: HolyTypography.verse.copyWith(
                                      color: t.ink,
                                      fontSize: compact ? 23 : 26)),
                              if (next != null) ...[
                                const SizedBox(height: 14),
                                const Hairline(),
                                const SizedBox(height: 12),
                                Text.rich(
                                    TextSpan(children: [
                                      TextSpan(
                                          text: 'Tomorrow  ',
                                          style: HolyTypography.label
                                              .copyWith(color: t.accent)),
                                      TextSpan(
                                          text: next.title,
                                          style: HolyTypography.label
                                              .copyWith(color: t.ink)),
                                    ]),
                                    maxLines: 2),
                              ],
                            ]))),
                const SizedBox(height: 14),
                Row(children: [
                  IconControl(
                      icon: CupertinoIcons.square_arrow_up,
                      label: 'Share this verse',
                      onPhoto: true,
                      size: 56,
                      onPressed: () => shareVerseCard(context, lesson)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: HolyButton('Done',
                          style: HolyButtonStyle.photoPrimary,
                          onPressed: () => context.go('/'))),
                ]),
              ]),
          // The light from the Amen button, resolving.
          IgnorePointer(
              child: FadeTransition(
                  opacity: CurvedAnimation(
                      parent: _light, curve: Curves.easeInOutCubic),
                  child: const ColoredBox(color: Color(0xFFFFFBF2)))),
        ]));
  }
}

class _WalkCount extends StatelessWidget {
  final int from, to;
  const _WalkCount({required this.from, required this.to});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
      tween: Tween(begin: from.toDouble(), end: to.toDouble()),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => FrostedGlass(
          onPhoto: true,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(CupertinoIcons.sun_max_fill,
                size: 20, color: Color(0xFFF6D28E)),
            const SizedBox(width: 8),
            RollingNumber(
                value: v.round(),
                style: HolyTypography.numeral
                    .copyWith(color: HolyTheme.photoInk, fontSize: 28)),
            const SizedBox(width: 8),
            Flexible(
                child: Text('day walk',
                    style: HolyTypography.label
                        .copyWith(color: HolyTheme.photoInk))),
          ])));
}

const _review = MethodChannel('holyhim/review');

/// Asks iOS to show its own rating prompt. iOS decides whether to show it
/// and limits how often; nothing here asks twice.
Future<void> requestStoreReview() async {
  try {
    await _review.invokeMethod<void>('request');
  } catch (_) {}
}
