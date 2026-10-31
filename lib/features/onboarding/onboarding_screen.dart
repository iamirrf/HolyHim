import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/features/onboarding/personalization.dart';
import 'package:holyher/features/support/support_screens.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/profile_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final bool editing;
  const OnboardingScreen({super.key, this.editing = false});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late UserProfile _draft;
  late TextEditingController _name;
  int _step = 0;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _draft = ref.read(profileProvider);
    _step = widget.editing ? 0 : _draft.onboardingStep.clamp(0, 6);
    _name = TextEditingController(
        text: _draft.name.isEmpty
            ? ref.read(authProvider).user?.displayName ?? ''
            : _draft.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => switch (_step) {
        1 => _draft.familiarity.isNotEmpty,
        2 => _draft.focus.isNotEmpty,
        3 => _draft.obstacle.isNotEmpty,
        _ => true
      };
  Future<void> _next() async {
    if (_busy || !_valid) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_step == 4) {
        try {
          await ref
              .read(profileProvider.notifier)
              .setReminder(_draft.reminderMinutes);
        } catch (error) {
          if (error is! StateError ||
              !error.message.toString().contains('Allow notifications')) {
            rethrow;
          }
          _draft = _draft.copyWith(clearReminder: true);
          if (mounted) {
            showNotice(context,
                'Reminders stay off. You can enable them later in Settings.');
          }
        }
      }
      _draft = _draft.copyWith(
          name: _name.text.trim(),
          onboardingStep: (_step + 1).clamp(0, 6),
          onboardingComplete: widget.editing || _step == 6);
      await ref.read(profileProvider.notifier).save(_draft);
      if (_step == 6) {
        if (mounted && widget.editing) Navigator.of(context).pop();
      } else if (mounted) {
        setState(() => _step++);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Your setup could not be saved. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _customReminder() async {
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
            hour: (_draft.reminderMinutes ?? 480) ~/ 60,
            minute: (_draft.reminderMinutes ?? 480) % 60));
    if (time != null) {
      setState(() => _draft =
          _draft.copyWith(reminderMinutes: time.hour * 60 + time.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      0 => 'Let’s make this\nyour moment.',
      1 => 'Where are you\nstarting from?',
      2 => 'What would you like\nto carry more of?',
      3 => 'What makes a daily\nrhythm difficult?',
      4 => 'A little space\nin your day.',
      5 => 'A rhythm made\nfor you.',
      _ => 'Here’s how\nit begins.'
    };
    final subtitle = switch (_step) {
      0 => 'What would you like us to call you? Your first name is plenty.',
      1 =>
        'There is no right place to begin. We’ll make the reading feel welcoming.',
      2 =>
        'Choose one focus. Every reader follows the same 365-day journey, with a personal question to bring it into everyday life.',
      3 => 'We’ll offer a small, practical way to help you keep showing up.',
      4 => 'Choose an optional daily reminder. You can change it any time.',
      5 =>
        'One new lesson each calendar day. A verse, a confidence, a reason, hope, and something to carry.',
      _ => 'Your first verse, exactly as it appears in your first lesson.'
    };
    return PopScope(
        canPop: widget.editing && !_busy,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _step > 0 && !_busy) setState(() => _step--);
        },
        child: HolyScaffold(
            body: ReadingWidth(
                maxWidth: 650,
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 24, 14),
                      child: Row(children: [
                        IconButton(
                            tooltip: _step == 0 ? 'Back' : 'Previous step',
                            onPressed: _busy
                                ? null
                                : () {
                                    if (_step > 0) {
                                      setState(() => _step--);
                                    } else if (widget.editing) {
                                      Navigator.of(context).pop();
                                    } else {
                                      ref.read(authProvider.notifier).signOut();
                                    }
                                  },
                            icon:
                                const Icon(Icons.arrow_back_rounded, size: 21)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                    value: (_step + 1) / 7,
                                    minHeight: 4,
                                    backgroundColor: AppColors.divider))),
                        const SizedBox(width: 16),
                        Text('${_step + 1} / 7',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary))
                      ])),
                  Expanded(
                      child: SingleChildScrollView(
                          key: ValueKey('setup-$_step'),
                          padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                PageHeading(
                                    eyebrow: _step < 5
                                        ? 'Your daily rhythm'
                                        : _step == 5
                                            ? 'Your setup is saved'
                                            : 'A first look',
                                    title: title,
                                    subtitle: subtitle),
                                const SizedBox(height: 26),
                                if (_step == 0) ...[
                                  const Align(
                                      alignment: Alignment.centerLeft,
                                      child: HolyMark(size: 76)),
                                  const SizedBox(height: 26),
                                  TextField(
                                      controller: _name,
                                      maxLength: 40,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      autofillHints: const [
                                        AutofillHints.givenName
                                      ],
                                      decoration: const InputDecoration(
                                          labelText: 'Preferred name',
                                          helperText:
                                              'Optional. This stays in your private profile.'))
                                ],
                                if (_step == 1) ...[
                                  _choice(
                                      'New to it',
                                      'A welcoming place to begin.',
                                      Icons.wb_sunny_outlined,
                                      _draft.familiarity == 'new',
                                      () => setState(() => _draft =
                                          _draft.copyWith(familiarity: 'new'))),
                                  _choice(
                                      'Returning',
                                      'Picking up a familiar thread.',
                                      Icons.spa_outlined,
                                      _draft.familiarity == 'returning',
                                      () => setState(() => _draft = _draft
                                          .copyWith(familiarity: 'returning'))),
                                  _choice(
                                      'Read regularly',
                                      'A fresh pause in a steady practice.',
                                      Icons.menu_book_outlined,
                                      _draft.familiarity == 'regular',
                                      () => setState(() => _draft = _draft
                                          .copyWith(familiarity: 'regular'))),
                                ],
                                if (_step == 2)
                                  for (final choice in [
                                    (
                                      'peace',
                                      'Peace',
                                      'A calmer place to bring what weighs on you.',
                                      Icons.waves_rounded
                                    ),
                                    (
                                      'confidence',
                                      'Confidence',
                                      'Courage rooted in who God is.',
                                      Icons.wb_twilight_rounded
                                    ),
                                    (
                                      'hope',
                                      'Hope',
                                      'A reason to keep looking forward.',
                                      Icons.auto_awesome_outlined
                                    ),
                                    (
                                      'guidance',
                                      'Guidance',
                                      'Light for one faithful next step.',
                                      Icons.explore_outlined
                                    ),
                                    (
                                      'rest',
                                      'Rest',
                                      'Room to receive instead of striving.',
                                      Icons.nightlight_outlined
                                    )
                                  ])
                                    _choice(
                                        choice.$2,
                                        choice.$3,
                                        choice.$4,
                                        _draft.focus == choice.$1,
                                        () => setState(() => _draft =
                                            _draft.copyWith(focus: choice.$1))),
                                if (_step == 3)
                                  for (final choice in [
                                    (
                                      'busy',
                                      'Busy days',
                                      'There never seems to be a quiet moment.',
                                      Icons.schedule_rounded
                                    ),
                                    (
                                      'forget',
                                      'I forget',
                                      'A little nudge would help.',
                                      Icons.notifications_none_rounded
                                    ),
                                    (
                                      'language',
                                      'Unfamiliar wording',
                                      'I want help understanding what I read.',
                                      Icons.auto_stories_outlined
                                    ),
                                    (
                                      'apply',
                                      'Putting it into practice',
                                      'I want to connect the verse to real life.',
                                      Icons.favorite_border_rounded
                                    )
                                  ])
                                    _choice(
                                        choice.$2,
                                        choice.$3,
                                        choice.$4,
                                        _draft.obstacle == choice.$1,
                                        () => setState(() => _draft = _draft
                                            .copyWith(obstacle: choice.$1))),
                                if (_step == 4) ...[
                                  for (final choice in [
                                    (480, 'Morning', '8:00 AM'),
                                    (720, 'A midday pause', '12:00 PM'),
                                    (1200, 'Evening', '8:00 PM')
                                  ])
                                    _choice(
                                        choice.$2,
                                        choice.$3,
                                        Icons.notifications_none_rounded,
                                        _draft.reminderMinutes == choice.$1,
                                        () => setState(() => _draft =
                                            _draft.copyWith(
                                                reminderMinutes: choice.$1))),
                                  _choice(
                                      'Choose a time',
                                      reminderLabel(_draft.reminderMinutes),
                                      Icons.access_time_rounded,
                                      _draft.reminderMinutes != null &&
                                          ![480, 720, 1200]
                                              .contains(_draft.reminderMinutes),
                                      _customReminder),
                                  _choice(
                                      'No reminder for now',
                                      'Your own time, your own rhythm.',
                                      Icons.notifications_off_outlined,
                                      _draft.reminderMinutes == null,
                                      () => setState(() => _draft = _draft
                                          .copyWith(clearReminder: true))),
                                ],
                                if (_step == 5) ...[
                                  const Align(
                                      alignment: Alignment.center,
                                      child: HolyMark(size: 90)),
                                  const SizedBox(height: 26),
                                  GlassSurface(
                                      highlighted: true,
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Eyebrow(_draft.name.isEmpty
                                                ? 'Your daily rhythm'
                                                : '${_draft.name}’s daily rhythm'),
                                            const SizedBox(height: 14),
                                            Text(
                                                'A year of faith.\nA little more ${focusLabel(_draft.focus).toLowerCase()}.',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineMedium),
                                            const SizedBox(height: 20),
                                            _planLine(Icons.menu_book_outlined,
                                                '365 lessons, one daily step'),
                                            _planLine(
                                                Icons.favorite_border_rounded,
                                                'Your focus: ${focusLabel(_draft.focus)}'),
                                            _planLine(
                                                Icons.schedule_rounded,
                                                reminderLabel(
                                                    _draft.reminderMinutes)),
                                            const Divider(height: 30),
                                            Text(rhythmTip(_draft.obstacle),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium)
                                          ])),
                                ],
                                if (_step == 6)
                                  GlassSurface(
                                      highlighted: true,
                                      padding: const EdgeInsets.all(28),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Eyebrow('Day 1 · Verse'),
                                            const SizedBox(height: 20),
                                            Text(lessons.first.title,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineMedium),
                                            const SizedBox(height: 24),
                                            const Icon(
                                                Icons.format_quote_rounded,
                                                color: AppColors.accent,
                                                size: 34),
                                            const SizedBox(height: 10),
                                            Text(lessons.first.verseText,
                                                style: const TextStyle(
                                                    fontSize: 20,
                                                    height: 1.7,
                                                    color:
                                                        AppColors.accentDark)),
                                            const SizedBox(height: 20),
                                            Text(lessons.first.verseReference,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors
                                                        .textSecondary)),
                                            const SizedBox(height: 28),
                                            const Divider(),
                                            const SizedBox(height: 10),
                                            const Text(
                                                'Then turn to Confidence, Reason, Hope, and Carry. One quiet moment, with something to take into your day.',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    height: 1.7,
                                                    color: AppColors
                                                        .textSecondary))
                                          ])),
                                if (_error != null)
                                  InlineMessage(_error!, error: true),
                                const SizedBox(height: 28),
                                HolyButton(
                                    label: _step == 6
                                        ? (widget.editing
                                            ? 'Save my rhythm'
                                            : 'Continue to HolyHer')
                                        : _step == 5
                                            ? 'See my first verse'
                                            : 'Continue',
                                    onPressed: _valid && !_busy ? _next : null,
                                    busy: _busy,
                                    icon: Icons.arrow_forward_rounded),
                                if (_step == 0)
                                  TextButton(
                                      onPressed: _busy ? null : _next,
                                      child: const Text(
                                          'Continue without a name')),
                                const SizedBox(height: 14),
                                const LegalFooter(),
                              ]))),
                ]))));
  }

  Widget _choice(String title, String subtitle, IconData icon, bool selected,
          VoidCallback onTap) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: HolyPressable(
              onPressed: _busy ? null : onTap,
              selected: selected,
              child: GlassSurface(
                  highlighted: selected,
                  radius: 23,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Row(children: [
                    Icon(icon, size: 25, color: AppColors.accent),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 5),
                          Text(subtitle,
                              style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.6,
                                  color: AppColors.textSecondary))
                        ])),
                    const SizedBox(width: 10),
                    Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 21,
                        color: selected ? AppColors.accent : AppColors.divider)
                  ]))));
  Widget _planLine(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(width: 12),
        Expanded(
            child:
                Text(text, style: const TextStyle(fontSize: 13, height: 1.5)))
      ]));
}
