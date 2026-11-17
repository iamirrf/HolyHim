// The welcome's structure and motion are ported from Cognein; see
// store/v2-design-ports.json.
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/lessons.g.dart';
import '../../design/design.dart';
import '../../domain/notification_plan.dart';
import '../../domain/onboarding_flow.dart';
import '../../services/account_cache.dart';
import '../../services/auth_service.dart';
import '../../services/notifications.dart';
import '../../services/repository.dart';
import '../notification_access.dart';
import '../paywall/paywall_screen.dart';
import 'chat/chat_script.dart';
import 'chat/chat_step.dart';
import 'onboarding_copy.dart';
import 'onboarding_moods.dart';
import 'steps/birthday_step.dart';
import 'steps/building_step.dart';
import 'steps/day_one_step.dart';
import 'steps/first_week_step.dart';
import 'steps/letter_step.dart';
import 'steps/name_step.dart';
import 'widgets/note_preview.dart';
import 'widgets/onboarding_scaffold.dart';
import 'widgets/onboarding_tokens.dart';
import 'widgets/select_step.dart';

/// The welcome, version 3: eleven steps on one moving field.
///
/// It is always in morning light, whatever theme he later picks: a pale
/// field lit by one soft colour per step, plum ink, white glass, and one
/// plum button with rose-gold light round its edge. Every beat has a sound
/// and a touch. Answers are saved as stable IDs the moment they are given,
/// so a relaunch returns to the step he was on.
class OnboardingScreen extends StatelessWidget {
  /// He has done this before and asked to do it again from Profile.
  final bool retake;
  const OnboardingScreen({super.key, this.retake = false});

  static final _theme = HolyThemeData.build(HolyThemes.blush);

  /// Whether a relaunch part-way through says "Welcome back". Off for
  /// still renders, where the toast would cover the step.
  @visibleForTesting
  static bool resumeToast = true;

  @override
  Widget build(BuildContext context) {
    final outer = context.dependOnInheritedWidgetOfExactType<HolyThemeScope>();
    // First Light is already HolyHim's ivory, plum and rose, so every shared
    // control (fields, buttons, sheets) is right for the pale field with no
    // colours of its own.
    return HolyThemeScope(
        theme: HolyThemes.blush,
        reduceTransparency: outer?.reduceTransparency ?? false,
        child: Theme(data: _theme, child: _Flow(retake: retake)));
  }
}

String firstNameOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.isEmpty ? '' : parts.first;
}

class _Flow extends ConsumerStatefulWidget {
  final bool retake;
  const _Flow({required this.retake});
  @override
  ConsumerState<_Flow> createState() => _FlowState();
}

class _FlowState extends ConsumerState<_Flow> {
  static const _name = 0,
      _birthday = 1,
      _heart = 2,
      _season = 3,
      _bible = 4,
      _week = 5,
      _note = 6,
      _building = 7,
      _letter = 8,
      _dayOne = 9,
      _offer = 10;

  late int step;
  late final TextEditingController first;
  String? nameError;
  bool saving = false;

  /// The save has landed and the card is lifting; the letter is next.
  bool saved = false;
  String? saveError;

  /// Whether this run showed the name step, so Back may return to it. A name
  /// from Apple or Google is never asked for.
  late bool _askedName;

  /// She is retaking the welcome with a note already on: the last reply in
  /// the note conversation keeps it, where "Not now" would switch it off.
  late final bool _offerKeep;
  bool _kept = false;

  bool _bibleDone = false, _noteDone = false, _weekShown = false;
  DateTime? _birthdayPicked;

  late final ChatScript _bibleChat =
      OnboardingCopy.bibleChat(name: () => firstNameOf(profile.name));
  late final ChatScript _noteChat = OnboardingCopy.noteChat(
      name: () => firstNameOf(profile.name),
      keep: _offerKeep,
      react: _noteReaction);

  AppProfile get profile => ref.read(repositoryProvider).profile;
  Map<String, dynamic> get draft => profile.onboardingDraft;
  OnboardingAnswers get answers => OnboardingAnswers.read(draft,
      name: profile.name, hearts: normalizedHearts(profile.hearts));

  @override
  void initState() {
    super.initState();
    step = widget.retake ? _name : resumeOnboardingStep(draft, answers);
    _askedName = step == _name;
    _offerKeep = widget.retake && profile.reminderEnabled;
    _weekShown = step > _week;
    first = TextEditingController(
        text: (draft['firstName'] as String?) ?? firstNameOf(profile.name));
    unawaited(HolySounds.warmUp());
    if (step == _building) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _build());
    }
    // A relaunch that lands him back mid-way says so, once.
    final resumed = !widget.retake && step > 0 && draft['stepId'] != null;
    if (resumed && OnboardingScreen.resumeToast) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _toasted = true;
        GlassToast.info(context, OnboardingCopy.resumed);
      });
    }
  }

  /// This flow put the "Welcome back" toast up, so it takes it down.
  bool _toasted = false;

  @override
  void dispose() {
    if (_toasted) GlassToast.dismiss();
    first.dispose();
    super.dispose();
  }

  void _update(AppProfile next) =>
      ref.read(repositoryProvider.notifier).updateProfile(next);

  void _patchDraft(Map<String, dynamic> changes) {
    final p = profile;
    _update(p.copyWith(onboardingDraft: {...p.onboardingDraft, ...changes}));
  }

  void _go(int value) {
    FocusManager.instance.primaryFocus?.unfocus();
    final forward = value > step;
    _patchDraft({
      'step': value,
      'stepId': onboardingStepIds[value],
      'flowVersion': onboardingFlowVersion,
    });
    setState(() => step = value);
    if (forward) {
      HolyHaptics.stepComplete();
      unawaited(HolySounds.lessonSwipe(intensity: .52));
    } else {
      HolyHaptics.chipDeselect();
      unawaited(HolySounds.lessonSwipe(forward: false, intensity: .4));
    }
    if (value == _building) _build();
  }

  bool get _canBack => switch (step) {
        _birthday => _askedName,
        >= _heart && <= _note => true,
        // The letter never goes back into the save.
        _dayOne || _offer => true,
        _ => false,
      };

  // Name.
  void _saveName() {
    final name = first.text.trim();
    if (name.isEmpty) {
      setState(() => nameError = OnboardingCopy.nameError);
      return;
    }
    final p = profile;
    _update(p.copyWith(
        // A full name from Apple or Google stays whole unless he changes
        // the part he was shown.
        name: name == firstNameOf(p.name) ? p.name : name,
        onboardingDraft: {...p.onboardingDraft, 'firstName': name}));
    _go(_birthday);
  }

  // Birthday.
  void _saveBirthday() {
    final d = _birthdayPicked;
    if (d != null) {
      _update(profile.copyWith(
          birthday: '${d.year.toString().padLeft(4, '0')}-'
              '${d.month.toString().padLeft(2, '0')}-'
              '${d.day.toString().padLeft(2, '0')}'));
    }
    _go(_heart);
  }

  // Heart.
  void _toggleHeart(String id) {
    final hearts = normalizedHearts(profile.hearts);
    if (hearts.contains(id)) {
      hearts.remove(id);
    } else if (hearts.length < 3) {
      hearts.add(id);
      // A soft pat for a choice, a small bright note for the third.
      unawaited(hearts.length == 3
          ? HolySounds.lessonCorrect()
          : HolySounds.lessonLand(intensity: .48));
    } else {
      return;
    }
    _update(profile.copyWith(hearts: hearts));
  }

  void _chooseSeason(String id) {
    if (answers.season != id) unawaited(HolySounds.lessonLand(intensity: .5));
    _patchDraft({'lifeSeason': id});
  }

  // The conversation about the Bible.
  ChatAnswer? _bibleAnswer(String question) {
    final a = answers;
    final familiarity = question == 'familiarity';
    final id = familiarity ? a.familiarity : a.obstacle;
    final choices = familiarity ? familiarityChoices : obstacleChoices;
    final label = labelFor(choices, id);
    return id == null || label == null
        ? null
        : ChatAnswer(id, label, emoji: emojiFor(choices, id));
  }

  // The conversation about his daily note.
  ChatAnswer? _noteAnswer(String question) {
    final stored = answers.reminder;
    if (stored == null) return null;
    final minutes = reminderMinutesFor(stored);
    if (minutes == null) {
      return const ChatAnswer(
          OnboardingCopy.noteOff, OnboardingCopy.noteOffLabel,
          emoji: OnboardingCopy.noteOffEmoji);
    }
    for (final preset in reminderPresets) {
      if (preset.id == stored) {
        return ChatAnswer(stored, '${preset.label} · ${preset.detail}',
            emoji: preset.emoji);
      }
    }
    return ChatAnswer(stored, OnboardingCopy.clock(minutes),
        emoji: OnboardingCopy.noteCustomEmoji);
  }

  String? _noteReaction(String answerId) {
    if (_kept || answerId == OnboardingCopy.noteKeep) {
      return OnboardingCopy.noteKept;
    }
    final minutes = reminderMinutesFor(answerId);
    if (minutes == null) return OnboardingCopy.noteDeclined;
    return profile.reminderEnabled
        ? OnboardingCopy.noteSet(OnboardingCopy.clock(minutes))
        : OnboardingCopy.noteDenied;
  }

  /// "Choose another time": a time wheel in a sheet. Null if he closes it.
  Future<ChatAnswer?> _pickNoteTime(String question, ChatReply reply) async {
    final current =
        reminderMinutesFor(answers.reminder) ?? profile.reminderMinutes;
    var picked = DateTime(2026, 1, 1, current ~/ 60, current % 60);
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
                          initialDateTime: DateTime(2026, 1, 1, current ~/ 60,
                              (current % 60) - (current % 60) % 5),
                          onDateTimeChanged: (d) => picked = d))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: HolyButton('Set time',
                      onPressed: () => Navigator.pop(context, true))),
            ])));
    if (ok != true) return null;
    final minutes = picked.hour * 60 + picked.minute;
    return ChatAnswer(reminderAnswerFor(minutes), OnboardingCopy.clock(minutes),
        emoji: OnboardingCopy.noteCustomEmoji);
  }

  Future<void> _onNoteAnswer(String question, ChatAnswer answer) async {
    _kept = answer.id == OnboardingCopy.noteKeep;
    if (_kept) {
      // His note stays exactly as it is; only the answer is recorded.
      _patchDraft({'reminder': reminderAnswerFor(profile.reminderMinutes)});
      return;
    }
    final minutes = reminderMinutesFor(answer.id);
    if (minutes == null) {
      final p = profile;
      _update(p.copyWith(
          reminderEnabled: false,
          onboardingDraft: {...p.onboardingDraft, 'reminder': 'off'}));
      return;
    }
    // iOS's own prompt the first time; Settings if he said no before.
    final granted = ref.read(notificationServiceProvider).supported
        ? await enableNotifications(context, ref)
            .catchError((Object _) => false)
        : false;
    if (!mounted) return;
    final p = profile;
    _update(p.copyWith(
        reminderMinutes: minutes,
        reminderEnabled: granted,
        onboardingDraft: {
          ...p.onboardingDraft,
          'reminder': reminderAnswerFor(minutes)
        }));
  }

  Widget _notePreview(String question) {
    final minutes = reminderMinutesFor(answers.reminder) ?? 420;
    return NotePreview(
        time: OnboardingCopy.clock(minutes),
        title: lessonNoteTitle(minutes ~/ 60, firstNameOf(profile.name)),
        body: lessonNoteBody(lessons.first));
  }

  // Building.
  Future<void> _build() async {
    if (saving) return;
    setState(() {
      saving = true;
      saved = false;
      saveError = null;
    });
    final started = DateTime.now();
    try {
      await ref.read(repositoryProvider.notifier).finishOnboardingDurably();
      final user = ref.read(authProvider).user;
      if (user != null) ref.read(accountCacheProvider).markOnboarded(user.uid);
      // Let the medallion land and the checklist finish; they are part of
      // the welcome.
      final reduced = mounted && MediaQuery.disableAnimationsOf(context);
      final rest = Duration(milliseconds: reduced ? 600 : 4100) -
          DateTime.now().difference(started);
      if (rest > Duration.zero) await Future<void>.delayed(rest);
      if (!mounted) return;
      // The save has landed: the card lifts, with a chime.
      setState(() => saved = true);
      HolyHaptics.celebration();
      unawaited(HolySounds.purchaseChime());
      await Future<void>.delayed(Duration(milliseconds: reduced ? 200 : 1150));
      if (!mounted) return;
      setState(() => saving = false);
      _go(_letter);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        saving = false;
        saveError = OnboardingCopy.saveError;
      });
    }
  }

  void _finish() {
    _patchDraft({
      'stepId': onboardingDoneStepId,
      'step': _offer,
      'flowVersion': onboardingFlowVersion
    });
    // A first welcome ends in Day 1. A second one ends where he started.
    context.go(widget.retake ? '/' : '/lesson/1');
  }

  /// Leaves a retake part-way: nothing more is asked, and his walk is as it
  /// was.
  void _close() {
    FocusManager.instance.primaryFocus?.unfocus();
    _patchDraft({'stepId': onboardingDoneStepId});
    context.go('/profile');
  }

  void _continue() {
    switch (step) {
      case _name:
        _saveName();
      case _birthday:
        _saveBirthday();
      case _building:
        _build();
      default:
        _go(step + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(repositoryProvider.select((s) => s.profile));
    final a = answers;
    final name = firstNameOf(profile.name);
    final moods = OnboardingMoods.steps;
    Color accent(int i) => moods[i].accent;
    Color glow(int i) => moods[i].glow;
    final echo =
        OnboardingCopy.echo(a.obstacle, reminderOn: profile.reminderEnabled);

    final canContinue = switch (step) {
      _name => first.text.trim().isNotEmpty,
      _heart => a.hearts.isNotEmpty,
      _season => a.season != null,
      _bible => _bibleDone,
      _week => _weekShown,
      _note => _noteDone,
      _building => saveError != null,
      _ => true,
    };
    final label = switch (step) {
      _birthday => OnboardingCopy.birthdaySave,
      _bible => OnboardingCopy.showFirstWeek,
      _note => OnboardingCopy.buildWalk,
      _building => OnboardingCopy.tryAgain,
      _ => OnboardingCopy.continueLabel,
    };
    // One small line under the button on every step.
    final microcopy = switch (step) {
      _name => OnboardingCopy.nameLine,
      _birthday => OnboardingCopy.birthdayLine,
      _heart => OnboardingCopy.heartCount(a.hearts.length),
      _season => OnboardingCopy.seasonLine,
      _bible || _note => (step == _bible ? a.familiarity : a.reminder) == null
          ? OnboardingCopy.chatLine
          : OnboardingCopy.chatHint,
      _week => OnboardingCopy.firstWeekLine,
      _letter => OnboardingCopy.letterLine,
      _dayOne => OnboardingCopy.dayOneLine,
      _ => null,
    };

    return OnboardingScaffold(
        moods: moods,
        currentIndex: step,
        canContinue: canContinue,
        continueLabel: label,
        onContinue: _continue,
        // The save has no button unless it fails; the offer brings its own.
        showContinue:
            step != _offer && (step != _building || saveError != null),
        // Building and the letter share one card: the page between them
        // dissolves in place.
        dissolve: const {_building},
        secondaryLabel: step == _birthday ? OnboardingCopy.skip : null,
        onSecondary: step == _birthday ? () => _go(_heart) : null,
        microcopy: microcopy,
        onBack: _canBack ? () => _go(step - 1) : null,
        onClose: widget.retake && step < _building ? _close : null,
        pages: [
          NameStep(
              controller: first,
              error: nameError,
              onChanged: (_) => setState(() => nameError = null),
              onSubmitted: _saveName),
          BirthdayStep(
              initial: profile.birthday,
              accent: accent(_birthday),
              onChanged: (d) => _birthdayPicked = d),
          SelectStep(
              title: OnboardingCopy.heartTitle(name),
              subtitle: OnboardingCopy.heartSubtitle,
              choices: heartChoices,
              selected: a.hearts,
              max: 3,
              accent: accent(_heart),
              onTap: _toggleHeart),
          SelectStep(
              title: OnboardingCopy.seasonTitle,
              subtitle: OnboardingCopy.seasonSubtitle,
              choices: seasonChoices,
              selected: [if (a.season != null) a.season!],
              accent: accent(_season),
              onTap: _chooseSeason),
          OnboardingChatStep(
              key: const ValueKey('bible-chat'),
              script: _bibleChat,
              accent: accent(_bible),
              answerOf: _bibleAnswer,
              onAnswer: (question, answer) async =>
                  _patchDraft({question: answer.id}),
              onCompleteChanged: (done) {
                if (mounted) setState(() => _bibleDone = done);
              }),
          FirstWeekStep(
              name: name,
              accent: accent(_week),
              glow: glow(_week),
              echo: echo,
              revealed: _weekShown,
              onRevealed: () => setState(() => _weekShown = true)),
          OnboardingChatStep(
              key: const ValueKey('note-chat'),
              script: _noteChat,
              accent: accent(_note),
              answerOf: _noteAnswer,
              resolve: _pickNoteTime,
              onAnswer: _onNoteAnswer,
              attachment: _notePreview,
              onCompleteChanged: (done) {
                if (mounted) setState(() => _noteDone = done);
              }),
          BuildingStep(
              name: name,
              answers: a,
              error: saveError,
              saved: saved,
              accent: accent(_building),
              glow: glow(_building),
              reminderOn: profile.reminderEnabled,
              reminderMinutes: profile.reminderMinutes),
          LetterStep(
              name: name,
              answers: a,
              glow: glow(_letter),
              reminderOn: profile.reminderEnabled,
              reminderMinutes: profile.reminderMinutes),
          DayOneStep(accent: accent(_dayOne)),
          Builder(
              builder: (context) => Padding(
                  padding:
                      OnboardingTokens.pageInsets(context, top: 6, bottom: 4),
                  child: OfferBody(onboarding: true, onContinue: _finish))),
        ]);
  }
}
