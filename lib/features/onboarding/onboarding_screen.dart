import 'package:holyher/services/reading_guidance.dart';
import 'package:holyher/core/widgets/holy_pickers.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/core/widgets/lesson_artwork.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/features/onboarding/checkpoint.dart';
import 'package:holyher/services/profile_service.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/reminder_service.dart';
import 'package:holyher/services/reading_destination.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final bool editing;
  final String? initialStage;
  const OnboardingScreen({super.key, this.editing = false, this.initialStage});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<OnboardingScreen> {
  late UserProfile _draft;
  late TextEditingController _name;
  late int _step;
  bool _busy = false, _submitted = false;
  String? _error;
  Future<void> _writes = Future.value();
  @override
  void initState() {
    super.initState();
    _draft = ref.read(profileProvider);
    _step = widget.initialStage == null
        ? _draft.onboardingStep.clamp(0, 3)
        : OnboardingStages.ids.indexOf(widget.initialStage!).clamp(0, 3);
    _name = TextEditingController(text: _draft.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _update(UserProfile draft) {
    setState(() => _draft = draft);
    final notifier = ref.read(profileProvider.notifier);
    _writes = _writes
        .catchError((Object _) {})
        .then((_) => notifier.saveDraft(draft));
    unawaited(_writes.catchError((Object _) {
      if (mounted) {
        setState(() => _error =
            'Your draft could not be saved on this device. Retry to continue.');
      }
    }));
  }

  Future<void> _advance() async {
    if (_busy || _submitted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _writes.catchError((Object _) {});
      await ref
          .read(profileProvider.notifier)
          .saveDraft(_draft.copyWith(name: _name.text.trim()));
      if (_step < 3) {
        final next =
            _draft.copyWith(name: _name.text.trim(), onboardingStep: _step + 1);
        await ref.read(profileProvider.notifier).saveDraft(next);
        if (mounted) {
          setState(() {
            _draft = next;
            _step++;
          });
        }
      } else {
        if (!widget.editing) {
          await ref
              .read(progressProvider.notifier)
              .startJourney()
              .timeout(const Duration(seconds: 20));
        }
        // Set one destination before the acknowledged profile transition. The
        // signed-in root consumes it only after both setup and journey exist.
        if (!widget.editing && ref.read(readingDestinationProvider) == null) {
          ref.read(readingDestinationProvider.notifier).state =
              const ReadingDestination(1);
        }
        await ref
            .read(profileProvider.notifier)
            .save(_draft.copyWith(
                name: _name.text.trim(),
                onboardingStep: 3,
                onboardingComplete: true))
            .timeout(const Duration(seconds: 20));
        _submitted = true;
        if (mounted && widget.editing) Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Your setup is saved here. Reconnect and Retry to finish.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reminder() async {
    if (_busy) return;
    final picked = await showHolyTimePicker(context,
        initialTime: TimeOfDay(
            hour: (_draft.suggestedReminderMinutes ?? 480) ~/ 60,
            minute: (_draft.suggestedReminderMinutes ?? 480) % 60));
    if (picked == null || !mounted) return;
    final minutes = picked.hour * 60 + picked.minute;
    // The OS prompt follows the explicit reminder opt-in, never the preview.
    setState(() => _busy = true);
    try {
      final allowed = await ref.read(reminderServiceProvider).schedule(minutes);
      _update(_draft.copyWith(
          suggestedReminderMinutes: minutes,
          reminderMinutes: allowed ? minutes : null,
          clearReminder: !allowed,
          reminderDecision: allowed ? 'enabled' : 'denied'));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Your reminder could not be set. You can continue and try in Settings.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    ref.watch(profileProvider.select((p) => p.theme));
    final title = const [
      'A walk that feels like yours.',
      'What does your heart need?',
      'A gentle invitation.',
      'Your first step awaits.'
    ][_step];
    return HolyScaffold(
        body: ReadingWidth(
            maxWidth: 560,
            child: Column(children: [
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    IconButton(
                        tooltip: 'Back',
                        onPressed: _busy
                            ? null
                            : () => _step > 0
                                ? setState(() => _step--)
                                : Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_rounded)),
                    const Spacer(),
                    const HolyMark(size: 28),
                    const Spacer(),
                    if (_step < 3)
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  if (_step == 2) {
                                    _update(_draft.copyWith(
                                        reminderDecision: 'declined',
                                        clearReminder: true));
                                  }
                                  _advance();
                                },
                          child: const Text('Skip'))
                    else
                      const SizedBox(width: 60)
                  ])),
              Expanded(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 30),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow(_step == 3
                                ? 'Day 1 · 2–3 minutes'
                                : 'A little about you · Optional'),
                            const SizedBox(height: 18),
                            Text(title,
                                style: HolyTypography.display
                                    .copyWith(color: AppColors.textPrimary)),
                            const SizedBox(height: 20),
                            if (_step == 0) ...[
                              const Text(
                                  'Come as you are. You can change any of this later.'),
                              const SizedBox(height: 26),
                              TextField(
                                  controller: _name,
                                  maxLength: 80,
                                  textCapitalization: TextCapitalization.words,
                                  autofillHints: const [
                                    AutofillHints.givenName
                                  ],
                                  decoration: const InputDecoration(
                                      labelText: 'Your name (optional)'),
                                  onChanged: (v) =>
                                      _update(_draft.copyWith(name: v.trim()))),
                              const SizedBox(height: 20),
                              const Text('How familiar does the Bible feel?'),
                              const SizedBox(height: 12),
                              for (final choice in [
                                ('new', 'I’m finding my way'),
                                ('returning', 'I’m coming back'),
                                ('regular', 'It’s part of my life')
                              ])
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: ChoiceChip(
                                        label: Text(choice.$2),
                                        selected: _draft.onboardingAnswered
                                                .contains('starting-point') &&
                                            _draft.familiarity == choice.$1,
                                        onSelected: (_) => _update(_draft
                                                .copyWith(
                                                    familiarity: choice.$1,
                                                    onboardingAnswered: {
                                                  ..._draft.onboardingAnswered,
                                                  'starting-point'
                                                })))),
                            ],
                            if (_step == 1) ...[
                              const Text(
                                  'A little guidance for where you are today. Your Scripture journey stays the same.'),
                              const SizedBox(height: 26),
                              Wrap(spacing: 10, runSpacing: 12, children: [
                                for (final choice in [
                                  ('peace', 'Peace'),
                                  ('courage', 'Courage'),
                                  ('hope', 'Hope'),
                                  ('guidance', 'Guidance'),
                                  ('rest', 'Rest')
                                ])
                                  ChoiceChip(
                                      label: Text(choice.$2),
                                      selected: _draft.onboardingAnswered
                                              .contains('focus') &&
                                          _draft.focus == choice.$1,
                                      onSelected: (_) => _update(_draft
                                              .copyWith(
                                                  focus: choice.$1,
                                                  onboardingAnswered: {
                                                ..._draft.onboardingAnswered,
                                                'focus'
                                              })))
                              ])
                            ],
                            if (_step == 2) ...[
                              const Text(
                                  'Let a little Scripture meet you in the middle of your day.'),
                              const SizedBox(height: 26),
                              GlassSurface(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    const Eyebrow('HolyHer · Reminder preview'),
                                    const SizedBox(height: 14),
                                    Text(
                                        '“${lessons.first.verseText.split('.').first}.”',
                                        style: HolyTypography.scripture),
                                    const SizedBox(height: 12),
                                    const Text(
                                        'Deuteronomy 31:6 · Continue your walk with God',
                                        style: HolyTypography.supporting)
                                  ])),
                              const SizedBox(height: 24),
                              HolyButton(
                                  label: _draft.reminderDecision == 'enabled'
                                      ? 'Change reminder time'
                                      : 'Choose a time',
                                  onPressed: _busy ? null : _reminder,
                                  icon: Icons.notifications_none_rounded),
                              if (_draft.reminderDecision == 'denied')
                                const Padding(
                                    padding: EdgeInsets.only(top: 14),
                                    child: Text(
                                        'Notifications are off on this device. You can enable them in device Settings or continue without a reminder.')),
                            ],
                            if (_step == 3) ...[
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: LessonArtwork(
                                      day: 1,
                                      child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              24, 34, 24, 110),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Eyebrow(
                                                    'Scripture · Meaning · Encouragement · Hope · Prayer'),
                                                const SizedBox(height: 20),
                                                Text(lessons.first.title,
                                                    style:
                                                        HolyTypography.heading),
                                                const SizedBox(height: 18),
                                                Text(lessons.first.verseText,
                                                    style: HolyTypography
                                                        .scripture),
                                                const SizedBox(height: 18),
                                                Text(
                                                    lessons
                                                        .first.verseReference,
                                                    style: HolyTypography
                                                        .supporting)
                                              ])))),
                              const SizedBox(height: 18),
                              Text(
                                  readingGuidance(
                                      _draft.focus, _draft.familiarity),
                                  style: HolyTypography.supporting),
                              const SizedBox(height: 12),
                              const Text(
                                  'Five quiet cards. Two to three minutes. A year of walking with God, one day at a time. Free access, always.',
                                  style: HolyTypography.supporting),
                            ],
                          ]))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
                  child: Column(children: [
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Semantics(
                              liveRegion: true,
                              child: Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppColors.error)))),
                    HolyButton(
                        label: _busy
                            ? 'Saving your place…'
                            : _error != null
                                ? 'Retry'
                                : _step == 3
                                    ? 'Begin my walk'
                                    : 'Continue',
                        onPressed: _busy ? null : _advance,
                        icon: Icons.arrow_forward_rounded),
                    const SizedBox(height: 16),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                            4,
                            (i) => Container(
                                width: i == _step ? 24 : 5,
                                height: 5,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: i == _step
                                        ? AppColors.accent
                                        : AppColors.divider)))),
                  ])),
            ])));
  }
}
