import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/features/lesson/lesson_cards.dart';
import 'package:holyher/features/paywall/paywall_screen.dart';
import 'package:holyher/services/paywall_service.dart';
import 'package:holyher/services/progress_service.dart';

class LessonScreen extends ConsumerStatefulWidget {
  final DailyLesson lesson;
  const LessonScreen({super.key, required this.lesson});
  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  bool _saving = false;
  bool _celebrating = false;
  String? _error;
  Future<void> _complete() async {
    if (_saving) return;
    if (ref.read(progressProvider).completedDays.contains(widget.lesson.day)) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(progressProvider.notifier).completeDay(widget.lesson.day);
      if (!mounted) return;
      setState(() {
        _celebrating = true;
        _saving = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Your completion could not be saved. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(paywallProvider)) return const PaywallScreen();
    final progress = ref.watch(progressProvider);
    final allowed = progress.isUnlocked(widget.lesson.day);
    return HolyScaffold(
        title: _celebrating ? 'A moment well spent' : 'Your daily message',
        body: !allowed
            ? Center(
                child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: GlassSurface(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.lock_outline_rounded,
                          color: AppColors.accent, size: 36),
                      const SizedBox(height: 18),
                      Text('Day ${widget.lesson.day} is still ahead.',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      const Text(
                          'One new lesson opens each calendar day. Enjoy the message waiting for you today.',
                          textAlign: TextAlign.center)
                    ]))))
            : _celebrating
                ? _CompletedLesson(
                    day: widget.lesson.day,
                    pending: progress.pendingDays.contains(widget.lesson.day))
                : Column(children: [
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: InlineMessage(_error!, error: true)),
                    Expanded(
                        child: LessonCards(
                            lesson: widget.lesson,
                            done: progress.completedDays
                                .contains(widget.lesson.day),
                            saving: _saving,
                            onComplete: _complete))
                  ]));
  }
}

class _CompletedLesson extends StatelessWidget {
  final int day;
  final bool pending;
  const _CompletedLesson({required this.day, required this.pending});
  @override
  Widget build(BuildContext context) => ReadingWidth(
      maxWidth: 550,
      child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight:
                          (box.maxHeight - 56).clamp(0, double.infinity)),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                            tween: Tween(
                                begin: MediaQuery.disableAnimationsOf(context)
                                    ? 1
                                    : .8,
                                end: 1),
                            duration: const Duration(milliseconds: 650),
                            curve: Curves.easeOutBack,
                            builder: (context, value, child) =>
                                Transform.scale(scale: value, child: child),
                            child: Container(
                                width: 112,
                                height: 112,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border:
                                        Border.all(color: AppColors.divider),
                                    boxShadow: [
                                      BoxShadow(
                                          color: AppColors.accent
                                              .withValues(alpha: .15),
                                          blurRadius: 50,
                                          spreadRadius: 20)
                                    ]),
                                child: const Icon(Icons.check_rounded,
                                    size: 49, color: AppColors.accent))),
                        const SizedBox(height: 35),
                        Eyebrow('Day $day · Complete'),
                        const SizedBox(height: 14),
                        Text('Let it stay\nwith you.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineLarge),
                        const SizedBox(height: 18),
                        const Text(
                            'You made a little room for faith today.\nCarry one thought into what comes next.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 15,
                                height: 1.8,
                                color: AppColors.textSecondary)),
                        if (pending) ...[
                          const SizedBox(height: 18),
                          const Text(
                              'Saved on this device. Your progress will sync when you’re online.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12,
                                  height: 1.6,
                                  color: AppColors.textSecondary))
                        ],
                        const SizedBox(height: 35),
                        HolyButton(
                            label: 'Return to my day',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icons.arrow_forward_rounded),
                      ])))));
}
