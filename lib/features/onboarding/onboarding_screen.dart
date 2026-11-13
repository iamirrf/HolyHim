import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/lessons.g.dart';
import '../../design/design.dart';
import '../../domain/onboarding_flow.dart';
import '../../services/account_cache.dart';
import '../../services/auth_service.dart';
import '../../services/notifications.dart';
import '../../services/repository.dart';
import '../paywall/paywall_screen.dart';
import 'letter.dart';

/// Onboarding version 3. One film: a photograph dissolves underneath while a
/// paper panel asks one thing at a time. Answers are saved as stable IDs.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

const _scenes = [
  'assets/art/library/sky-dawn.webp', // name
  'assets/art/library/sky-stillness.webp', // heart
  'assets/art/library/landscape-path.webp', // season
  'assets/art/library/scripture-morning.webp', // familiarity
  'assets/art/library/landscape-water.webp', // obstacle
  'assets/art/library/scripture-lamp.webp', // reminder
  'assets/art/library/symbol-lilies.webp', // birthday
  'assets/art/library/sky-rays.webp', // building
  'assets/art/library/scripture-garden.webp', // letter
  'assets/art/library/jesus-path.webp', // offer
];

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late int step;
  late final TextEditingController first;
  String? nameError;
  bool saving = false;
  String? saveError;
  bool asking = false;

  AppProfile get profile => ref.read(repositoryProvider).profile;
  Map<String, dynamic> get draft => profile.onboardingDraft;
  OnboardingAnswers get answers => OnboardingAnswers.read(draft,
      name: profile.name, hearts: normalizedHearts(profile.hearts));

  @override
  void initState() {
    super.initState();
    step = resumeOnboardingStep(draft, answers);
    first = TextEditingController(
        text: (draft['firstName'] as String?) ?? firstNameOf(profile.name));
    if (step == 7) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _build());
    }
  }

  @override
  void dispose() {
    first.dispose();
    super.dispose();
  }

  void _patchDraft(Map<String, dynamic> changes) {
    final p = profile;
    ref.read(repositoryProvider.notifier).updateProfile(
        p.copyWith(onboardingDraft: {...p.onboardingDraft, ...changes}));
  }

  void _go(int value) {
    FocusManager.instance.primaryFocus?.unfocus();
    _patchDraft({
      'step': value,
      'stepId': onboardingStepIds[value],
      'flowVersion': onboardingFlowVersion,
    });
    setState(() => step = value);
    HolyHaptics.stepComplete();
    if (value == 7) _build();
  }

  void _back() {
    var previous = step - 1;
    if (previous == 0 && profile.name.trim().isNotEmpty) previous = -1;
    if (previous < 0) return;
    _go(previous);
  }

  // Step 0.
  void _saveName() {
    final name = first.text.trim();
    if (name.isEmpty) {
      setState(() => nameError = 'Tell us what to call you.');
      return;
    }
    final p = profile;
    ref.read(repositoryProvider.notifier).updateProfile(p.copyWith(
        name: name,
        onboardingDraft: {...p.onboardingDraft, 'firstName': name}));
    _go(1);
  }

  void _toggleHeart(String id) {
    final hearts = normalizedHearts(profile.hearts);
    if (hearts.contains(id)) {
      hearts.remove(id);
    } else if (hearts.length < 3) {
      hearts.add(id);
    } else {
      HolyHaptics.error();
      return;
    }
    ref
        .read(repositoryProvider.notifier)
        .updateProfile(profile.copyWith(hearts: hearts));
  }

  void _answer(String key, String id) {
    _patchDraft({key: id});
    // A short beat so the check can draw before the scene moves on.
    Future<void>.delayed(
        Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 420),
        () {
      if (mounted) _go(step + 1);
    });
  }

  Future<void> _reminder(String? answer) async {
    if (asking) return;
    final minutes = reminderMinutesFor(answer);
    final notifications = ref.read(notificationServiceProvider);
    if (minutes == null) {
      final p = profile;
      ref.read(repositoryProvider.notifier).updateProfile(p.copyWith(
          reminderEnabled: false,
          onboardingDraft: {...p.onboardingDraft, 'reminder': 'off'}));
      _go(6);
      return;
    }
    setState(() => asking = true);
    final granted = await notifications
        .requestPermission()
        .timeout(const Duration(seconds: 20), onTimeout: () => false)
        .catchError((Object _) => false);
    if (!mounted) return;
    final p = profile;
    ref.read(repositoryProvider.notifier).updateProfile(p.copyWith(
        reminderMinutes: minutes,
        reminderEnabled: granted,
        onboardingDraft: {
          ...p.onboardingDraft,
          'reminder': reminderAnswerFor(minutes)
        }));
    setState(() => asking = false);
    _go(6);
  }

  void _birthday(String? value) {
    if (value != null) {
      ref
          .read(repositoryProvider.notifier)
          .updateProfile(profile.copyWith(birthday: value));
    }
    _go(7);
  }

  Future<void> _build() async {
    if (saving) return;
    setState(() {
      saving = true;
      saveError = null;
    });
    final started = DateTime.now();
    try {
      await ref.read(repositoryProvider.notifier).finishOnboardingDurably();
      final user = ref.read(authProvider).user;
      if (user != null) ref.read(accountCacheProvider).markOnboarded(user.uid);
      // Let the checklist finish drawing; it is part of the welcome.
      final reduced = mounted && MediaQuery.disableAnimationsOf(context);
      final rest = Duration(milliseconds: reduced ? 600 : 3400) -
          DateTime.now().difference(started);
      if (rest > Duration.zero) await Future<void>.delayed(rest);
      if (!mounted) return;
      setState(() => saving = false);
      HolyHaptics.celebration();
      _go(8);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        saving = false;
        saveError =
            'We could not save your walk on this phone. Please try again.';
      });
    }
  }

  void _finish() {
    _patchDraft({
      'stepId': onboardingDoneStepId,
      'step': 9,
      'flowVersion': onboardingFlowVersion
    });
    context.go('/lesson/1');
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    ref.watch(repositoryProvider.select((s) => s.profile));
    if (step == 9) {
      return OfferScreen(
          onboarding: true,
          onContinue: _finish,
          onBack: () => _go(8));
    }
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom > 60;
    final compact = media.size.height < 720;
    final photoHeight = keyboard
        ? media.padding.top + 56
        : media.size.height *
            (step == 8
                ? (compact ? .16 : .30)
                : step == 7
                    ? .42
                    : (compact ? .25 : .30));
    final canBack = step > 0 &&
        step < 7 &&
        !(step == 1 && profile.name.trim().isNotEmpty);
    final reduced = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: t.paper,
        body: Stack(children: [
          AnimatedPositioned(
              duration:
                  reduced ? Duration.zero : const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              top: 0,
              left: 0,
              right: 0,
              height: photoHeight + HolyRadius.sheet,
              child: PhotoStage(
                  images: _scenes,
                  index: step,
                  alignment: const Alignment(0, .1),
                  topVeil: .38,
                  bottomVeil: .1,
                  child: step >= 7 ? const LightMotes(count: 16) : null)),
          // Top controls over the photograph.
          Positioned(
              top: media.padding.top + 6,
              left: HolySpace.gutter - 6,
              right: HolySpace.gutter,
              child: Row(children: [
                AnimatedOpacity(
                    opacity: canBack ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                        ignoring: !canBack,
                        child: BackControl(onPhoto: true, onPressed: _back))),
                const SizedBox(width: 10),
                if (step < 7)
                  Expanded(
                      child: StepBar(
                          steps: 7,
                          current: step,
                          color: HolyTheme.photoInk)),
              ])),
          AnimatedPositioned(
              duration:
                  reduced ? Duration.zero : const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              top: photoHeight,
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                  decoration: ShapeDecoration(
                      color: t.paper,
                      shape: const RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(HolyRadius.sheet))),
                      shadows: HolyDepth.paper(t, lift: 1.4)),
                  child: Padding(
                      padding: EdgeInsets.only(
                          bottom: keyboard
                              ? media.viewInsets.bottom + 12
                              : media.padding.bottom + 14),
                      child: AnimatedSwitcher(
                          duration: Duration(milliseconds: reduced ? 0 : 360),
                          switchInCurve: Curves.easeOutCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                      position: Tween(
                                              begin: const Offset(0, .03),
                                              end: Offset.zero)
                                          .animate(animation),
                                      child: child)),
                          child: KeyedSubtree(
                              key: ValueKey(step),
                              child: _stepBody(context, keyboard)))))),
        ]));
  }

  Widget _stepBody(BuildContext context, bool keyboard) {
    final name = firstNameOf(profile.name);
    final a = answers;
    switch (step) {
      case 0:
        return _Panel(
            title: 'What should we call you?',
            subtitle: 'Your first name is enough.',
            compactTitle: keyboard,
            footer: HolyButton('Continue', onPressed: _saveName),
            children: [
              HolyField(
                  controller: first,
                  label: 'First name',
                  autofocus: true,
                  error: nameError,
                  maxLength: 40,
                  capitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.givenName],
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (nameError != null) setState(() => nameError = null);
                  },
                  onSubmitted: (_) => _saveName()),
            ]);
      case 1:
        final hearts = a.hearts;
        return _Panel(
            title: name.isEmpty
                ? 'What do you need most?'
                : '$name, what do you need most?',
            subtitle: 'Pick up to three. Your lessons will meet you there.',
            footer: HolyButton('Continue',
                onPressed: hearts.isEmpty ? null : () => _go(2)),
            children: [
              _Grid(children: [
                for (final c in heartChoices)
                  ChoiceTile(
                      dense: true,
                      multi: true,
                      label: c.label,
                      detail: c.detail,
                      selected: hearts.contains(c.id),
                      onPressed: () => _toggleHeart(c.id)),
              ]),
            ]);
      case 2:
        return _Panel(
            title: 'Where are you right now?',
            subtitle: 'There is no wrong answer.',
            children: [
              for (final c in seasonChoices)
                _Gap(ChoiceTile(
                    dense: true,
                    label: c.label,
                    selected: a.season == c.id,
                    onPressed: () => _answer('lifeSeason', c.id))),
            ]);
      case 3:
        return _Panel(
            title: 'How well do you know the Bible?',
            subtitle: 'Every lesson explains the verse in plain words.',
            children: [
              for (final c in familiarityChoices)
                _Gap(ChoiceTile(
                    label: c.label,
                    selected: a.familiarity == c.id,
                    onPressed: () => _answer('familiarity', c.id))),
            ]);
      case 4:
        return _Panel(
            title: 'What usually gets in the way?',
            subtitle: 'We will help with that part.',
            children: [
              for (final c in obstacleChoices)
                _Gap(ChoiceTile(
                    dense: true,
                    label: c.label,
                    selected: a.obstacle == c.id,
                    onPressed: () => _answer('obstacle', c.id))),
            ]);
      case 5:
        return _ReminderStep(
            initial: a.reminder,
            busy: asking,
            onChoose: _reminder,
            preview: lessons.first.teaser);
      case 6:
        return _BirthdayStep(
            initial: profile.birthday, onDone: _birthday);
      case 7:
        return _BuildingStep(
            name: name,
            answers: a,
            error: saveError,
            onRetry: _build,
            reminderOn: profile.reminderEnabled,
            reminderMinutes: profile.reminderMinutes);
      case 8:
        return _Panel(
            footer: HolyButton('Continue', onPressed: () => _go(9)),
            children: [
              FitFlex(
                  min: 300,
                  child: Center(
                      child: SingleChildScrollView(
                          child: PersonalLetter(
                          name: name,
                          answers: a,
                          reminderOn: profile.reminderEnabled,
                          reminderMinutes: profile.reminderMinutes)))),
            ]);
    }
    return const SizedBox.shrink();
  }
}

String firstNameOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.isEmpty ? '' : parts.first;
}

/// The paper panel's composition: title, subtitle, content, footer button.
class _Panel extends StatelessWidget {
  final String? title, subtitle;
  final List<Widget> children;
  final Widget? footer;
  final bool compactTitle;
  const _Panel(
      {this.title,
      this.subtitle,
      required this.children,
      this.footer,
      this.compactTitle = false});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final compact = MediaQuery.sizeOf(context).height < 720;
    final hasExpanded = children.any((c) => c is Expanded || c is FitFlex);
    return FitColumn(
        padding: EdgeInsets.fromLTRB(
            HolySpace.gutter, compact ? 22 : 28, HolySpace.gutter, 0),
        children: [
          if (title != null) ...[
            Semantics(
                header: true,
                child: Text(title!,
                    style: HolyTypography.title.copyWith(
                        color: t.ink,
                        fontSize: compactTitle || compact ? 28 : 32))),
            if (subtitle != null && !compactTitle) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  style: HolyTypography.body.copyWith(color: t.muted)),
            ],
            SizedBox(height: compact ? 14 : 20),
          ],
          ...children,
          if (!hasExpanded) const Spacer(),
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ]);
  }
}

class _Gap extends StatelessWidget {
  final Widget child;
  const _Gap(this.child);
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: child);
}

class _Grid extends StatelessWidget {
  final List<Widget> children;
  const _Grid({required this.children});
  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < children.length; i += 2)
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: children[i]),
                const SizedBox(width: 8),
                Expanded(
                    child: i + 1 < children.length
                        ? children[i + 1]
                        : const SizedBox()),
              ]))),
      ]);
}

/// Reminder time, shown as the actual notification she will receive before
/// iOS asks for permission.
class _ReminderStep extends StatefulWidget {
  final String? initial;
  final bool busy;
  final Future<void> Function(String? answer) onChoose;
  final String preview;
  const _ReminderStep(
      {required this.initial,
      required this.busy,
      required this.onChoose,
      required this.preview});
  @override
  State<_ReminderStep> createState() => _ReminderStepState();
}

class _ReminderStepState extends State<_ReminderStep> {
  late String choice =
      reminderMinutesFor(widget.initial) == null ? '07:00' : widget.initial!;

  String _format(String answer) {
    final m = reminderMinutesFor(answer)!;
    final h = m ~/ 60, min = m % 60;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${min.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
  }

  Future<void> _custom() async {
    final m = reminderMinutesFor(choice) ?? 420;
    var picked = DateTime(2026, 1, 1, m ~/ 60, m % 60);
    final t = HolyThemeScope.of(context);
    final ok = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: t.surface,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                  height: 200,
                  child: CupertinoTheme(
                      data: CupertinoThemeData(
                          brightness:
                              t.isDark ? Brightness.dark : Brightness.light,
                          textTheme: CupertinoTextThemeData(
                              dateTimePickerTextStyle: HolyTypography.ui
                                  .copyWith(color: t.ink, fontSize: 21))),
                      child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.time,
                          minuteInterval: 5,
                          initialDateTime: DateTime(2026, 1, 1, m ~/ 60,
                              (m % 60) - (m % 60) % 5),
                          onDateTimeChanged: (d) => picked = d))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: HolyButton('Set time',
                      onPressed: () => Navigator.pop(context, true))),
            ])));
    if (ok == true && mounted) {
      setState(() => choice = reminderAnswerFor(picked.hour * 60 + picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final isPreset = reminderPresets.any((p) => p.id == choice);
    return _Panel(
        title: 'When should today’s word arrive?',
        subtitle: 'One note a day. You can change it anytime.',
        footer: Column(children: [
          HolyButton('Remind me at ${_format(choice)}',
              loading: widget.busy, onPressed: () => widget.onChoose(choice)),
          TextAction('Not now',
              color: t.muted,
              onPressed: widget.busy ? null : () => widget.onChoose(null)),
        ]),
        children: [
          _NotificationPreview(
              time: _format(choice), body: widget.preview),
          const SizedBox(height: 16),
          Row(children: [
            for (final p in reminderPresets) ...[
              Expanded(
                  child: _TimeChip(
                      label: p.label,
                      detail: p.detail!,
                      selected: choice == p.id,
                      onPressed: () => setState(() => choice = p.id))),
              const SizedBox(width: 8),
            ],
          ]..removeLast()),
          const SizedBox(height: 8),
          Align(
              alignment: Alignment.centerLeft,
              child: TextAction(
                  isPreset ? 'Choose another time' : 'Custom · ${_format(choice)}',
                  onPressed: _custom)),
        ]);
  }
}

class _TimeChip extends StatelessWidget {
  final String label, detail;
  final bool selected;
  final VoidCallback onPressed;
  const _TimeChip(
      {required this.label,
      required this.detail,
      required this.selected,
      required this.onPressed});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Pressable(
        onPressed: () {
          HolyHaptics.chipSelect();
          onPressed();
        },
        selected: selected,
        semanticLabel: '$label, $detail',
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: ShapeDecoration(
                color: selected
                    ? Color.alphaBlend(
                        t.accent.withValues(alpha: .08), t.surface)
                    : t.surface,
                shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(HolyRadius.field),
                    side: BorderSide(
                        color: selected ? t.accent : t.hairline,
                        width: selected ? 1.4 : 1))),
            child: Column(children: [
              Text(label,
                  style: HolyTypography.label.copyWith(
                      color: t.ink,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
              const SizedBox(height: 2),
              Text(detail,
                  style: HolyTypography.caption.copyWith(color: t.muted)),
            ])));
  }
}

/// A faithful picture of the iOS banner she will see.
class _NotificationPreview extends StatelessWidget {
  final String time, body;
  const _NotificationPreview({required this.time, required this.body});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Semantics(
        label: 'Preview: HolyHim at $time. $body',
        excludeSemantics: true,
        child: DecoratedBox(
            decoration: ShapeDecoration(
                color: t.isDark ? const Color(0xFF2C2C2E) : Colors.white,
                shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(22)),
                shadows: HolyDepth.paper(t, lift: .8)),
            child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset('assets/brand/holyhim-mark.png',
                          width: 36, height: 36, fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                              width: 36, height: 36, color: t.accent))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Expanded(
                              child: Text('HolyHim',
                                  style: HolyTypography.label.copyWith(
                                      color: t.isDark
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.w700))),
                          Text(time,
                              style: HolyTypography.caption.copyWith(
                                  color: t.isDark
                                      ? Colors.white60
                                      : Colors.black54)),
                        ]),
                        const SizedBox(height: 2),
                        Text('Today’s word is ready',
                            style: HolyTypography.label.copyWith(
                                color:
                                    t.isDark ? Colors.white : Colors.black)),
                        Text(body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: HolyTypography.caption.copyWith(
                                color: t.isDark
                                    ? Colors.white70
                                    : Colors.black87)),
                      ])),
                ]))));
  }
}

class _BirthdayStep extends StatefulWidget {
  final String? initial;
  final ValueChanged<String?> onDone;
  const _BirthdayStep({required this.initial, required this.onDone});
  @override
  State<_BirthdayStep> createState() => _BirthdayStepState();
}

class _BirthdayStepState extends State<_BirthdayStep> {
  late DateTime value =
      DateTime.tryParse(widget.initial ?? '') ?? DateTime(1995, 6, 15);
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final now = DateTime.now();
    return _Panel(
        title: 'When is your birthday?',
        subtitle: 'So we can send a blessing on your day. This is optional.',
        footer: Column(children: [
          HolyButton('Save my birthday',
              onPressed: () => widget.onDone(
                  '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}')),
          TextAction('Skip', color: t.muted, onPressed: () => widget.onDone(null)),
        ]),
        children: [
          FitFlex(
              min: 180,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 216, minHeight: 120),
                  child: CupertinoTheme(
                      data: CupertinoThemeData(
                          brightness:
                              t.isDark ? Brightness.dark : Brightness.light,
                          textTheme: CupertinoTextThemeData(
                              dateTimePickerTextStyle: HolyTypography.ui
                                  .copyWith(color: t.ink, fontSize: 21))),
                      child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.date,
                          initialDateTime: value,
                          minimumDate: DateTime(now.year - 100, 1, 1),
                          maximumDate: DateTime(now.year - 13, now.month, now.day),
                          onDateTimeChanged: (d) => value = d)))),
        ]);
  }
}

/// "Building your walk": a short checklist that draws itself while the
/// profile is saved.
class _BuildingStep extends StatefulWidget {
  final String name;
  final OnboardingAnswers answers;
  final String? error;
  final VoidCallback onRetry;
  final bool reminderOn;
  final int reminderMinutes;
  const _BuildingStep(
      {required this.name,
      required this.answers,
      required this.error,
      required this.onRetry,
      required this.reminderOn,
      required this.reminderMinutes});
  @override
  State<_BuildingStep> createState() => _BuildingStepState();
}

class _BuildingStepState extends State<_BuildingStep> {
  int done = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 750), (t) {
      if (!mounted) return;
      setState(() => done++);
      HolyHaptics.chipSelect();
      if (done >= 4) t.cancel();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final heart = labelFor(heartChoices, widget.answers.hearts.firstOrNull)
            ?.toLowerCase() ??
        'peace';
    final m = widget.reminderMinutes;
    final h12 = (m ~/ 60) % 12 == 0 ? 12 : (m ~/ 60) % 12;
    final time =
        '$h12:${(m % 60).toString().padLeft(2, '0')} ${m < 720 ? 'AM' : 'PM'}';
    final lines = [
      'Choosing verses for $heart',
      'Writing each lesson in plain words',
      widget.reminderOn
          ? 'Setting your note for $time'
          : 'Saving your place for any time of day',
      'Preparing Day 1: ${lessons.first.title}',
    ];
    return _Panel(
        title: widget.name.isEmpty
            ? 'Building your walk'
            : 'Building your walk, ${widget.name}',
        footer: widget.error == null
            ? null
            : HolyButton('Try again', onPressed: widget.onRetry),
        children: [
          for (var i = 0; i < lines.length; i++)
            Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: i <= done ? 1 : .35,
                    child: Row(children: [
                      HolyCheck(checked: i < done, size: 24, color: t.olive),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Text(lines[i],
                              style: HolyTypography.ui.copyWith(color: t.ink))),
                    ]))),
          if (widget.error != null)
            Text(widget.error!,
                style: HolyTypography.caption.copyWith(color: t.accent)),
        ]);
  }
}
