import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../design/design.dart';
import '../../design/widgets/avatar_cropper.dart';
import '../../services/auth_service.dart';
import '../../services/avatar_service.dart';
import '../../services/repository.dart';
import '../../services/account_cache.dart';
import '../../services/billing.dart';
import '../../services/notifications.dart';
import '../../services/navigation_state.dart';
import '../common.dart';
import '../paywall/paywall_screen.dart';
import 'birthday_step.dart';
import 'chat_step.dart';
import 'routine_preview.dart';
import '../../design/widgets/morphing_progress_indicator.dart';
import '../../domain/onboarding_flow.dart';
import '../../domain/personalized_plan.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late int step;
  late final TextEditingController first, last, username;
  final search = TextEditingController();
  bool chatReady = false, saving = false, saved = false, photoBusy = false;
  String? saveError, photoError;
  int permissionDecision = 0;
  Map<String, dynamic> get draft =>
      ref.read(repositoryProvider).profile.onboardingDraft;
  @override
  void initState() {
    super.initState();
    final profile = ref.read(repositoryProvider).profile;
    step = resumeOnboardingStep(profile.onboardingDraft,
        hasBirthday: profile.birthday != null,
        hasIntentions: profile.hearts.isNotEmpty);
    final names = profile.name.trim().split(RegExp(r'\s+'));
    first = TextEditingController(
        text: draft['firstName'] as String? ?? names.first);
    last = TextEditingController(
        text: draft['lastName'] as String? ??
            (names.length > 1 ? names.skip(1).join(' ') : ''));
    username = TextEditingController(text: profile.username);
    if (step == 9) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        saveProfile();
      });
    }
    if (step == 10) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final access = ref.read(lifetimeProvider);
        context.go(access.active ? '/' : '/paywall');
      });
    }
  }

  Widget _sketchHeader(String asset, {double height = 135}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          height: height,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const RadialGradient(
              center: Alignment.center,
              radius: 0.95,
              colors: [Colors.black, Colors.black, Colors.transparent],
              stops: [0.0, 0.75, 1.0],
            ).createShader(bounds),
            child: Image.asset(
              asset,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
        ),
      );

  @override
  void dispose() {
    first.dispose();
    last.dispose();
    username.dispose();
    search.dispose();
    super.dispose();
  }

  void patch(Map<String, dynamic> changes) {
    final repo = ref.read(repositoryProvider.notifier),
        profile = ref.read(repositoryProvider).profile;
    repo.updateProfile(profile
        .copyWith(onboardingDraft: {...profile.onboardingDraft, ...changes}));
  }

  void go(int value) {
    FocusScope.of(context).unfocus();
    patch({
      'step': value,
      'stepId': onboardingStepIds[value],
      'flowVersion': onboardingFlowVersion
    });
    setState(() {
      step = value;
      chatReady = false;
      search.clear();
    });
    HolyHaptics.stepComplete();
  }

  Future<void> next() async {
    if (!valid) return;
    if (step == 0) {
      patch({'firstName': first.text.trim(), 'lastName': last.text.trim()});
      final profile = ref.read(repositoryProvider).profile;
      ref.read(repositoryProvider.notifier).updateProfile(profile.copyWith(
          name: '${first.text.trim()} ${last.text.trim()}'.trim()));
    }
    if (step == 8) {
      ref.read(repositoryProvider.notifier).updateProfile(ref
          .read(repositoryProvider)
          .profile
          .copyWith(username: username.text.trim()));
      go(9);
      await saveProfile();
      return;
    }
    if (step == 9) {
      HolyHaptics.celebration();
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(accountCacheProvider).markOnboarded(user.uid);
      }
      go(10);
      return;
    }
    go(step + 1);
  }

  Future<void> saveProfile() async {
    if (!mounted || saving) return;
    setState(() {
      saving = true;
      saveError = null;
    });
    try {
      await ref.read(repositoryProvider.notifier).finishOnboardingDurably();
      if (mounted) {
        setState(() {
          saved = true;
          saving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          saveError =
              'Your profile could not be saved on this device. Please try again.';
        });
      }
    }
  }

  Future<void> answer(String id, String value) async {
    final questions = step == 4 ? diagnosis : routine;
    final index = questions.indexWhere((q) => q.id == id);
    final next = Map<String, dynamic>.from(draft);
    final changed = next[id] != value;
    next[id] = value;
    if (changed) {
      for (final q in questions.skip(index + 1)) {
        next.remove(q.id);
      }
    }
    final profile = ref.read(repositoryProvider).profile;
    ref
        .read(repositoryProvider.notifier)
        .updateProfile(profile.copyWith(onboardingDraft: next));
    if (id == 'reminder' && next[id] != null) {
      final decision = ++permissionDecision;
      final minutes = switch (value) {
        'Morning · 7 AM' => 420,
        'Midday · 12 PM' => 720,
        'Evening · 8 PM' => 1200,
        _ => 420
      };
      final wants = value != 'No reminders';
      ref.read(repositoryProvider.notifier).updateProfile(ref
          .read(repositoryProvider)
          .profile
          .copyWith(reminderMinutes: minutes, reminderEnabled: false));
      if (wants) {
        final granted = await ref
            .read(notificationServiceProvider)
            .requestPermission()
            .timeout(const Duration(seconds: 5), onTimeout: () => false);
        if (mounted && decision == permissionDecision) {
          ref.read(repositoryProvider.notifier).updateProfile(ref
              .read(repositoryProvider)
              .profile
              .copyWith(reminderEnabled: granted));
        }
      }
    }
  }

  List<GuideQuestion> get diagnosis => [
        const GuideQuestion(
            'obstacle', 'What makes a daily Scripture moment difficult?', [
          'My days are full',
          'Understanding Scripture is hard',
          'I forget to return',
          'Beginning feels hard',
          'No particular obstacle'
        ],
            responses: {
              'My days are full':
                  'A short, dependable pause can anchor a full day. We’ll keep your chosen time visible.',
              'Understanding Scripture is hard':
                  'Meaning will give you context before Reflection asks you to respond.',
              'I forget to return':
                  'You can choose a daily verse reminder, and your place in a lesson will be saved.',
              'Beginning feels hard':
                  'We’ll start with one clear reading — steady, at your pace.',
              'No particular obstacle':
                  'Make this moment your own. No rush, no performance — just you and the Word.'
            }),
      ];
  List<GuideQuestion> get routine => [
        const GuideQuestion(
            'pace', 'How much time feels realistic on an ordinary day?', [
          'One minute',
          'Three minutes',
          'Five minutes',
          'A little longer'
        ],
            responses: {
              'One minute':
                  'One minute is enough time to begin. You can stay longer whenever you want.',
              'Three minutes':
                  'We’ll set aside three planned minutes for each daily moment.',
              'Five minutes':
                  'We’ll set aside five planned minutes for each daily moment.',
              'A little longer':
                  'Your rhythm can stay flexible. The preview will leave the total open.'
            }),
        const GuideQuestion(
            'reminder', 'When would you like your daily verse?', [
          'Morning · 7 AM',
          'Midday · 12 PM',
          'Evening · 8 PM',
          'No reminders'
        ],
            responses: {
              'Morning · 7 AM':
                  'We’ll check notification permission and show the actual reminder status in your preview.',
              'Midday · 12 PM':
                  'We’ll check notification permission and show the actual reminder status in your preview.',
              'Evening · 8 PM':
                  'We’ll check notification permission and show the actual reminder status in your preview.',
              'No reminders':
                  'That is fine. You can return whenever it suits you.'
            }),
      ];
  bool get valid => switch (step) {
        0 => first.text.trim().isNotEmpty &&
            '${first.text.trim()} ${last.text.trim()}'.trim().length <= 80,
        1 =>
          BirthdayStep.eligible(ref.read(repositoryProvider).profile.birthday),
        2 => draft['lifeSeason'] != null,
        3 => draft['faithRoutine'] != null,
        4 || 6 => chatReady,
        5 => ref.read(repositoryProvider).profile.hearts.isNotEmpty,
        8 => draft['termsAccepted'] == true && !photoBusy,
        9 => saved,
        _ => true,
      };
  Future<void> photo() async {
    if (photoBusy) return;
    final uid = ref.read(authProvider).user?.uid;
    if (uid == null) return;
    try {
      final bytes = await pickAndCropAvatar(context,
          accent: HolyThemeScope.of(context).accent);
      if (bytes == null || !mounted) return;
      setState(() {
        photoBusy = true;
        photoError = null;
      });
      final service = ref.read(avatarServiceProvider);
      final url = await service.upload(uid, bytes);
      if (!mounted || ref.read(authProvider).user?.uid != uid) return;
      ref.read(repositoryProvider.notifier).updateProfile(
          ref.read(repositoryProvider).profile.copyWith(avatarUrl: url));
    } catch (_) {
      if (mounted) {
        setState(() =>
            photoError = 'That photo could not be saved. Tap to try again.');
      }
    } finally {
      if (mounted) setState(() => photoBusy = false);
    }
  }

  Widget title(String text, [String? description]) => Column(children: [
        Text(text,
            textAlign: TextAlign.center,
            style: HolyTypography.display.copyWith(fontSize: 28)),
        if (description != null) ...[
          const SizedBox(height: 14),
          Text(description, textAlign: TextAlign.center, style: muted(context))
        ],
        const SizedBox(height: 30),
      ]);
  Widget input(TextEditingController controller, String label,
          {ValueChanged<String>? changed, int maxLength = 80}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Glass(
              radius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
              child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  maxLength: maxLength,
                  onChanged: changed ?? (_) => setState(() {}),
                  decoration: InputDecoration(
                      labelText: label,
                      border: InputBorder.none,
                      counterText: ''))));
  Widget choices(String field, List<String> options) {
    final filtered = options
        .where((v) => v.toLowerCase().contains(search.text.toLowerCase()));
    return Column(children: [
      for (final option in filtered)
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Pressable(
                onPressed: () => patch({field: option}),
                selected: draft[field] == option,
                semanticLabel: option,
                child: Glass(
                    radius: 22,
                    padding: const EdgeInsets.all(18),
                    child: Row(children: [
                      Icon(
                          draft[field] == option
                              ? CupertinoIcons.check_mark_circled_solid
                              : CupertinoIcons.circle,
                          color: HolyThemeScope.of(context).accent,
                          size: 22),
                      const SizedBox(width: 14),
                      Expanded(child: Text(option, style: ui(context))),
                    ]))))
    ]);
  }

  Widget content() {
    final profile = ref.watch(repositoryProvider).profile,
        theme = HolyThemeScope.of(context);
    switch (step) {
      case 0:
        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          _sketchHeader('assets/artwork/sketch_jesus_child_path.png',
              height: 140),
          title('What should we\ncall you?', 'A name for your daily welcome.'),
          input(first, 'First name', changed: (v) => patch({'firstName': v})),
          input(last, 'Last name · optional',
              changed: (v) => patch({'lastName': v}))
        ]);
      case 1:
        return Column(children: [
          title('When is your\nbirthday?'),
          BirthdayStep(
              value: profile.birthday,
              onChanged: (v) => ref
                  .read(repositoryProvider.notifier)
                  .updateProfile(profile.copyWith(birthday: v)))
        ]);
      case 2:
        return Column(children: [
          _sketchHeader('assets/artwork/sketch_jesus_child_path.png',
              height: 125),
          title('What season are\nyou in?', 'Choose what feels closest today.'),
          choices('lifeSeason', [
            'A full season',
            'A time of change',
            'Providing for others',
            'Finding my footing',
            'Making space for faith',
            'Something else'
          ])
        ]);
      case 3:
        return Column(children: [
          _sketchHeader('assets/artwork/sketch_bible_open.png', height: 125),
          title('Where are you\nwith Scripture?'),
          choices('faithRoutine', [
            'I’m new to Scripture',
            'I’m returning after some time',
            'I’m finding a steady rhythm',
            'I read regularly'
          ])
        ]);
      case 4:
      case 6:
        return GuideChat(
            key: ValueKey('chat-$step'),
            questions: step == 4 ? diagnosis : routine,
            answers: profile.onboardingDraft,
            onAnswer: answer,
            onReady: (value) {
              if (mounted && chatReady != value) {
                setState(() => chatReady = value);
              }
            });
      case 5:
        return Column(children: [
          _sketchHeader('assets/artwork/sketch_bible_open.png', height: 115),
          title('What would you\nlike to grow?', 'Choose up to three.'),
          Text('${profile.hearts.length} of 3 selected', style: muted(context)),
          const SizedBox(height: 18),
          for (final goal in [
            'Peace',
            'Strength',
            'Hope',
            'Rest',
            'Healing',
            'Joy',
            'Purpose',
            'Courage'
          ])
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Pressable(
                    selected: profile.hearts.contains(goal),
                    semanticLabel: goal,
                    onPressed: () {
                      final hearts = [...profile.hearts];
                      if (hearts.contains(goal)) {
                        hearts.remove(goal);
                      } else if (hearts.length < 3) {
                        hearts.add(goal);
                      } else {
                        toast(context, 'Choose up to three intentions.');
                        return;
                      }
                      ref
                          .read(repositoryProvider.notifier)
                          .updateProfile(profile.copyWith(hearts: hearts));
                      HolyHaptics.chipSelect();
                    },
                    child: Glass(
                        radius: 20,
                        child: Row(children: [
                          Icon(
                              profile.hearts.contains(goal)
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.circle,
                              color: theme.accent),
                          const SizedBox(width: 14),
                          Expanded(child: Text(goal, style: ui(context))),
                        ]))))
        ]);
      case 7:
        return RoutinePreview(
            plan: PersonalizedPlan.fromAnswers(profile.onboardingDraft,
                profile.hearts, profile.reminderEnabled));
      case 8:
        return Column(children: [
          title('Make this\nyour quiet place.'),
          Pressable(
              onPressed: photoBusy ? null : photo,
              semanticLabel: 'Choose profile photo',
              child: Stack(alignment: Alignment.bottomRight, children: [
                CircleAvatar(
                    radius: 48,
                    backgroundColor: theme.accent.withValues(alpha: .12),
                    backgroundImage: profile.avatarUrl == null
                        ? null
                        : NetworkImage(profile.avatarUrl!),
                    child: photoBusy
                        ? const CircularProgressIndicator()
                        : profile.avatarUrl == null
                            ? Icon(CupertinoIcons.person,
                                size: 40, color: theme.accent)
                            : null),
                Glass(
                    radius: 20,
                    padding: const EdgeInsets.all(7),
                    child: Icon(CupertinoIcons.camera_fill,
                        size: 17, color: theme.accent)),
              ])),
          const SizedBox(height: 20),
          if (photoError != null) Text(photoError!, style: muted(context)),
          input(username, 'Display name · optional',
              maxLength: 40,
              changed: (v) => ref
                  .read(repositoryProvider.notifier)
                  .updateProfile(ref
                      .read(repositoryProvider)
                      .profile
                      .copyWith(username: v))),
          SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Daily verse reminder'),
              value: profile.reminderEnabled,
              onChanged: (v) async {
                final decision = ++permissionDecision;
                ref
                    .read(repositoryProvider.notifier)
                    .updateProfile(profile.copyWith(reminderEnabled: false));
                if (v) {
                  final granted = await ref
                      .read(notificationServiceProvider)
                      .requestPermission()
                      .timeout(const Duration(seconds: 5),
                          onTimeout: () => false);
                  if (mounted && decision == permissionDecision) {
                    ref.read(repositoryProvider.notifier).updateProfile(ref
                        .read(repositoryProvider)
                        .profile
                        .copyWith(reminderEnabled: granted));
                  }
                }
              }),
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: draft['termsAccepted'] == true,
              onChanged: (v) => patch({'termsAccepted': v == true}),
              title: Text('I agree to the Terms and Privacy Policy.',
                  style: muted(context))),
          Wrap(alignment: WrapAlignment.center, children: [
            TextButton(
                onPressed: () => openLegal(context, 'Terms of Use', 'terms'),
                child: const Text('Terms')),
            TextButton(
                onPressed: () =>
                    openLegal(context, 'Privacy Policy', 'privacy'),
                child: const Text('Privacy')),
          ]),
        ]);
      case 9:
        final plan = PersonalizedPlan.fromAnswers(
            profile.onboardingDraft, profile.hearts, profile.reminderEnabled);
        return Column(children: [
          _sketchHeader('assets/artwork/sketch_bible_dove.png', height: 135),
          title(
              saving
                  ? 'Saving your\nHolyHim profile.'
                  : saved
                      ? 'Your walk\nis ready.'
                      : 'Let’s try\nthat again.',
              'Be strong and courageous. — Joshua 1:9'),
          Glass(
              radius: 28,
              child: Column(children: [
                if (saving)
                  const CupertinoActivityIndicator()
                else
                  Icon(
                      saved
                          ? CupertinoIcons.check_mark_circled
                          : CupertinoIcons.exclamationmark_circle,
                      size: 48,
                      color: theme.accent),
                const SizedBox(height: 24),
                Text(profile.name, style: HolyTypography.title),
                const SizedBox(height: 18),
                Text(plan.context, style: ui(context)),
                const SizedBox(height: 12),
                Text('${plan.pace} each day', style: ui(context)),
                const SizedBox(height: 8),
                Text(plan.reminder, style: muted(context)),
                const SizedBox(height: 12),
                Text(plan.orientation,
                    style: muted(context), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(plan.advice,
                    style: muted(context), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(plan.encouragement,
                    style: ui(context), textAlign: TextAlign.center),
                const SizedBox(height: 18),
                Text(
                    saved
                        ? 'Saved on this device. Your account will sync when connected.'
                        : saveError ?? 'Keeping your choices together.',
                    textAlign: TextAlign.center,
                    style: muted(context)),
                if (saveError != null)
                  TextButton(
                      onPressed: saveProfile, child: const Text('Try again')),
              ])),
          const SizedBox(height: 24),
          const Badge3D(
              badgeId: 'days-1',
              icon: CupertinoIcons.leaf_arrow_circlepath,
              label: 'A Beautiful Beginning',
              earned: false)
        ]);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(repositoryProvider);
    if (step == 10) {
      return PaywallScreen(onContinue: () {
        final destination = ref.read(pendingDestinationProvider);
        ref.read(pendingDestinationProvider.notifier).state = null;
        final profile = ref.read(repositoryProvider).profile;
        ref
            .read(repositoryProvider.notifier)
            .updateProfile(profile.copyWith(onboardingDraft: const {}));
        context.go(destination ?? '/');
      });
    }
    final chat = step == 4 || step == 6;
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                          child: Row(children: [
                            if (step > 0 && step < 9)
                              CircleControl(
                                  icon: CupertinoIcons.chevron_left,
                                  label: 'Back',
                                  onPressed: () => go(step - 1))
                            else
                              const SizedBox(width: 48),
                            Expanded(
                                child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Semantics(
                                        label: 'Step ${step + 1} of 11',
                                        child: MorphingProgressIndicator(
                                            totalSteps: 11,
                                            currentStep: step,
                                            accentColor:
                                                HolyThemeScope.of(context)
                                                    .accent)))),
                            const SizedBox(width: 48),
                          ])),
                      Expanded(
                          child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: AnimatedSwitcher(
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                          ? Duration.zero
                                          : const Duration(milliseconds: 600),
                                  transitionBuilder: (child, animation) => FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                          position: Tween(
                                                  begin: const Offset(.06, 0),
                                                  end: Offset.zero)
                                              .animate(CurvedAnimation(
                                                  parent: animation,
                                                  curve: Curves.easeOutCubic)),
                                          child: child)),
                                  child: KeyedSubtree(
                                      key: ValueKey(step),
                                      child: chat ? content() : SingleChildScrollView(padding: const EdgeInsets.only(top: 18, bottom: 24), child: content()))))),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                          child: ActionButton(
                              step == 9 ? 'Continue to HolyHim' : 'Continue',
                              onPressed: valid ? next : null)),
                    ])))));
  }
}
