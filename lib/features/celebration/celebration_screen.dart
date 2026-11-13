import 'dart:async';
import 'dart:math' as math;
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
import '../common.dart';

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

class _CelebrationScreenState extends ConsumerState<CelebrationScreen>
    with SingleTickerProviderStateMixin {
  late final _animation =
      AnimationController(vsync: this, duration: LessonCelebration.duration);
  CompletionMoment? _moment;
  bool _started = false, _crest = false, _settled = false;
  @override
  void initState() {
    super.initState();
    final receipt = ref.read(completionMomentProvider);
    if (receipt?.day == widget.day) _moment = receipt;
    _animation.addListener(() {
      if (!HolyHaptics.enabled) return;
      if (!_crest && _animation.value >= LessonCelebration.crestAt) {
        _crest = true;
        unawaited(HapticFeedback.mediumImpact());
      }
      if (!_settled && _animation.value >= LessonCelebration.settleAt) {
        _settled = true;
        unawaited(HapticFeedback.selectionClick());
      }
    });
    scheduleMicrotask(() {
      if (mounted && identical(ref.read(completionMomentProvider), receipt)) {
        ref.read(completionMomentProvider.notifier).state = null;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_moment == null || MediaQuery.disableAnimationsOf(context)) {
      _crest = _settled = true;
      _animation.value = 1;
      if (_moment != null) HolyHaptics.tap();
    } else {
      HolyHaptics.tap();
      HolySounds.lessonSurge();
      _animation.forward();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(repositoryProvider);
    final theme = HolyThemeScope.of(context);
    final streak =
        streakFor(state.completed, DateTime.now(), state.profile.timeZone);
    final badges = _moment?.newlyEarned ?? [];
    return Scaffold(
        body: SafeArea(child: LayoutBuilder(builder: (context, bounds) {
      final width = math.min(bounds.maxWidth - 48, 430.0);
      final height =
          math.min(bounds.maxHeight - 130, 510.0).clamp(180.0, 510.0);
      final frame = Rect.fromCenter(
          center: Offset(bounds.maxWidth / 2, (bounds.maxHeight - 80) / 2),
          width: width,
          height: height);
      return Stack(fit: StackFit.expand, children: [
        if (_moment != null)
          LessonAuraLayer(
              animation: _animation,
              frame: frame,
              dark: theme.isDark,
              cornerRadius: 30),
        Positioned.fromRect(
            rect: frame,
            child: Glass(
                radius: 30,
                padding: const EdgeInsets.all(28),
                child: SingleChildScrollView(
                    child: Column(children: [
                  Text('Amen.',
                      style: HolyTypography.wordmark
                          .copyWith(fontSize: 72, color: theme.accent)),
                  const SizedBox(height: 12),
                  Text(
                      _moment == null
                          ? 'A word to carry with you.'
                          : 'Your moment is complete.',
                      textAlign: TextAlign.center,
                      style: HolyTypography.title.copyWith(fontSize: 25)),
                  const SizedBox(height: 28),
                  Icon(CupertinoIcons.flame_fill,
                      color: theme.accent, size: 27),
                  Text('${streak.current}',
                      style: HolyTypography.display.copyWith(fontSize: 56)),
                  Text('${streak.current == 1 ? 'day' : 'days'} in your walk',
                      style: muted(context)),
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Badge3D(
                        badgeId: badges.first.id,
                        icon: CupertinoIcons.sparkles,
                        label: badges.first.title,
                        earned: true,
                        onPressed: () => showBadgeReveal(context,
                            title: badges.first.title,
                            description: badges.first.description,
                            earned: true,
                            badgeId: badges.first.id)),
                  ],
                ])))),
        if (_moment != null)
          LessonSparkLayer(
              animation: _animation,
              frame: frame,
              dark: theme.isDark,
              cornerRadius: 30),
        Positioned(
            left: 28,
            right: 28,
            bottom: 22,
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: ActionButton('Continue',
                        onPressed: () => context.go('/'))))),
      ]);
    })));
  }
}
