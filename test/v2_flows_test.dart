import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:holyhim/data/lessons.g.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/domain/lesson.dart';
import 'package:holyhim/domain/onboarding_flow.dart';
import 'package:holyhim/features/celebration/celebration_screen.dart';
import 'package:holyhim/features/lesson/lesson_screen.dart';
import 'package:holyhim/features/onboarding/onboarding_screen.dart';
import 'package:holyhim/features/paywall/paywall_screen.dart';
import 'package:holyhim/features/shell/home_shell.dart';
import 'package:holyhim/features/walk/walk_screen.dart';
import 'package:holyhim/features/welcome/welcome_screen.dart';
import 'package:holyhim/main.dart';
import 'package:holyhim/services/app_router.dart';
import 'package:holyhim/services/auth_service.dart';
import 'package:holyhim/services/billing.dart';
import 'package:holyhim/services/notifications.dart';
import 'package:holyhim/services/repository.dart';
import '../tool/render/fixtures.dart' show offerState;
import '../tool/render/harness.dart' show loadFonts;

class _FixtureAuth extends AuthNotifier {
  final bool signedIn;
  final String displayName;
  _FixtureAuth(this.signedIn, this.displayName);
  @override
  AuthState build() => AuthState(
      user: signedIn
          ? AuthUser(
              uid: 'fixture-only',
              displayName: displayName,
              email: 'mira@example.test')
          : null);
}

/// A member, or someone the store offers the two plans to. Buying opens
/// every lesson, as the store's answer would.
class _FixtureAccess extends AccessController {
  final bool owned;
  _FixtureAccess(this.owned);
  @override
  AccessState build() => owned
      ? const AccessState(loading: false, purchased: true, verified: true)
      : offerState;
  @override
  Future<bool> purchase(MemberPlan plan) async {
    state =
        state.copyWith(member: true, inTrial: plan.hasTrial, willRenew: true);
    return true;
  }
}

/// Every simulated server receipt stays unresolved; local state still moves.
class _UnacknowledgedRepository extends WalkRepository {
  final WalkState initial;
  int writes = 0;
  _UnacknowledgedRepository(this.initial);
  @override
  WalkState build() => initial;
  @override
  void updateProfile(AppProfile profile) {
    writes++;
    state = state.copyWith(profile: profile);
  }

  @override
  void finishOnboarding([AppProfile? profile]) => updateProfile(
      (profile ?? state.profile).copyWith(onboardedAt: DateTime.now()));
  @override
  Future<void> finishOnboardingDurably([AppProfile? profile]) async =>
      finishOnboarding(profile);
  @override
  Future<bool> completeDurably(int day, {DateTime? now}) async {
    state = state.copyWith(completed: {...state.completed, day: '2026-11-12'});
    return true;
  }
}

class _PendingPermission extends NotificationService {
  @override
  Future<void> initialize() async {}
  final permission = Completer<bool>();
  int requests = 0;
  @override
  Future<String> deviceTimeZone() async => 'America/New_York';
  @override
  bool get supported => true;
  @override
  Future<String> permissionStatus() async => 'notDetermined';
  @override
  Future<bool> requestPermission() {
    requests++;
    return permission.future;
  }

  @override
  void reconcile(
      {required String uid,
      required AppProfile profile,
      required Map<int, String> completed,
      required List<Lesson> lessons}) {}
  @override
  Future<void> cancel() async {}
}

class _Harness {
  final ProviderContainer container;
  final GoRouter router;
  final _UnacknowledgedRepository repository;
  final _PendingPermission notifications;
  bool disposed = false;
  _Harness(this.container, this.router, this.repository, this.notifications);
  Future<void> dispose(WidgetTester tester) async {
    if (disposed) return;
    disposed = true;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    container.dispose();
    notifications.dispose();
  }
}

Future<_Harness> _mount(WidgetTester tester,
    {bool onboarded = false,
    String name = 'Daniel Reyes',
    String displayName = 'Daniel Reyes',
    Map<String, dynamic> draft = const {},
    Map<int, String> completed = const {},
    List<String> hearts = const [],
    bool owned = false,
    bool signedIn = true,
    String path = '/',
    bool reduceMotion = true,
    Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  final profile = AppProfile(
      name: name,
      hearts: hearts,
      onboardingDraft: draft,
      haptics: false,
      sounds: false,
      timeZone: 'America/New_York',
      onboardedAt: onboarded ? DateTime(2026, 11, 3) : null);
  final repository = _UnacknowledgedRepository(
      WalkState(profile: profile, completed: completed));
  final notifications = _PendingPermission();
  final router = GoRouter(
      initialLocation: path,
      routes: [GoRoute(path: '/:location(.*)', pageBuilder: appRoutePage)]);
  final container = ProviderContainer(overrides: [
    authProvider.overrideWith(() => _FixtureAuth(signedIn, displayName)),
    repositoryProvider.overrideWith(() => repository),
    notificationServiceProvider.overrideWithValue(notifications),
    accessProvider.overrideWith(() => _FixtureAccess(owned)),
    appRouterProvider.overrideWithValue(router),
  ]);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container, child: const HolyHimApp()));
  await tester.pump();
  final harness = _Harness(container, router, repository, notifications);
  addTearDown(() => harness.dispose(tester));
  return harness;
}

Future<void> _tap(WidgetTester tester, String text,
    {Duration settle = const Duration(milliseconds: 500)}) async {
  final target = find.text(text).last;
  // Centred, so a floating header or tab bar never sits over it.
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
  await tester.pump(settle);
}

Map<String, dynamic> _draft(WidgetTester tester, _Harness h) =>
    h.container.read(repositoryProvider).profile.onboardingDraft;

void main() {
  setUpAll(() async {
    tzdata.initializeTimeZones();
    await loadFonts();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HolySounds.player = (String asset, {double gain = 1}) async {};
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  testWidgets('signed-out people see the welcome screen', (tester) async {
    final h = await _mount(tester, signedIn: false);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a name from Apple or Google is never asked for', (tester) async {
    final h = await _mount(tester);
    expect(find.text('What should we call you?'), findsNothing);
    expect(find.text('When is your birthday?'), findsOneWidget);
    // There is no way back to a question that was never asked.
    expect(find.byTooltip('Back'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets(
      'onboarding stores stable IDs, asks permission only on request and ends in Day 1',
      (tester) async {
    final h = await _mount(tester, name: '', displayName: '');
    AppProfile profile() => h.container.read(repositoryProvider).profile;
    expect(find.text('What should we call you?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Daniel');
    await tester.pump();
    await _tap(tester, 'Continue');
    expect(profile().name, 'Daniel');

    // Birthday is optional, and skipping it saves nothing.
    expect(find.text('When is your birthday?'), findsOneWidget);
    await _tap(tester, 'Skip');
    expect(profile().birthday, isNull);

    expect(find.text('Daniel, what do you need most?'), findsOneWidget);
    await _tap(tester, 'Peace');
    await _tap(tester, 'Courage');
    await _tap(tester, 'Continue');

    // An answer is a choice, not a page turn: Continue moves him on.
    await _tap(tester, 'Life is changing fast');
    expect(find.text('Where are you right now?'), findsOneWidget);
    await _tap(tester, 'Continue');

    // The conversation about the Bible.
    expect(find.text('Good to have you here, Daniel.'), findsOneWidget);
    expect(find.text('How well do you know the Bible?'), findsOneWidget);
    await _tap(tester, 'I am coming back to it');
    expect(find.text('Welcome back. We will take it one day at a time.'),
        findsOneWidget);
    await _tap(tester, 'It is hard to understand');
    expect(
        find.text('Thanks, Daniel. That is all I need.'), findsOneWidget);
    await _tap(tester, 'Show me my first week');

    // His first week is the real first seven lessons.
    expect(find.text('Daniel, here is your first week'), findsOneWidget);
    // Days 1 to 3 also stand on the cards fanned above the path.
    for (final lesson in lessons.take(7)) {
      expect(find.text(lesson.title),
          lesson.day <= 3 ? findsNWidgets(2) : findsOneWidget);
    }
    await _tap(tester, 'Continue');

    // The conversation about his note.
    expect(find.textContaining('When should today’s word arrive?'),
        findsOneWidget);
    expect(h.notifications.requests, 0);
    await _tap(tester, 'Not now');
    expect(h.notifications.requests, 0);
    expect(profile().reminderEnabled, isFalse);
    await _tap(tester, 'Build my road');

    final draft = _draft(tester, h);
    expect(draft['flowVersion'], onboardingFlowVersion);
    expect(draft['lifeSeason'], 'change');
    expect(draft['familiarity'], 'returning');
    expect(draft['obstacle'], 'understanding');
    expect(draft['reminder'], 'off');
    expect(profile().hearts, ['peace', 'courage']);
    // Building, then the letter.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(profile().onboarded, isTrue);
    expect(find.text('Daniel,'), findsOneWidget);
    // The save is behind him: there is no way back into it.
    expect(find.byTooltip('Back'), findsNothing);
    await _tap(tester, 'Continue');
    expect(find.text('Here is where you start'), findsOneWidget);
    expect(find.text(lessons.first.title), findsOneWidget);
    await _tap(tester, 'Continue');
    // The offer has no way past it but the free week or the subscription.
    expect(find.byType(OfferBody), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    await _tap(tester, 'Start my 7 days free');
    expect(find.text('You’re in.'), findsOneWidget);
    await _tap(tester, 'Begin Day 1');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LessonScreen), findsOneWidget);
    expect(_draft(tester, h)['stepId'], onboardingDoneStepId);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('choosing a time for his note asks iOS only after the tap',
      (tester) async {
    final h = await _mount(tester, hearts: [
      'discipline'
    ], draft: {
      'flowVersion': onboardingFlowVersion,
      'stepId': 'reminder',
      'lifeSeason': 'full',
      'familiarity': 'new',
      'obstacle': 'busy',
    });
    expect(find.textContaining('When should today’s word arrive?'),
        findsOneWidget);
    expect(h.notifications.requests, 0);
    await _tap(tester, 'Evening · 8:30 PM', settle: Duration.zero);
    expect(h.notifications.requests, 1);
    // He has not answered iOS yet: the conversation waits with him.
    expect(find.textContaining('One note a day at'), findsNothing);
    h.notifications.permission.complete(true);
    await tester.pump(const Duration(milliseconds: 500));
    final profile = h.container.read(repositoryProvider).profile;
    expect(profile.reminderMinutes, 20 * 60 + 30);
    expect(profile.reminderEnabled, isTrue);
    expect(profile.onboardingDraft['reminder'], '20:30');
    expect(
        find.text(
            'Done. One note a day at 8:30 PM. You can change it any time.'),
        findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a reply can be taken back by tapping it', (tester) async {
    final h = await _mount(tester, hearts: [
      'discipline'
    ], draft: {
      'flowVersion': onboardingFlowVersion,
      'stepId': 'familiarity',
      'lifeSeason': 'full',
    });
    await _tap(tester, 'I know a few stories');
    await _tap(tester, 'Nothing really');
    expect(_draft(tester, h)['familiarity'], 'some');
    expect(find.text('Show me my first week'), findsOneWidget);
    // His first reply goes back to its question, and the step is open again.
    await _tap(tester, 'I know a few stories');
    expect(find.text('What usually gets in the way?'), findsNothing);
    await _tap(tester, 'I read it most days');
    expect(_draft(tester, h)['familiarity'], 'daily');
    expect(find.text('What usually gets in the way?'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('retaking the welcome starts at his name and can be closed',
      (tester) async {
    final h = await _mount(tester,
        onboarded: true,
        owned: true,
        hearts: ['peace'],
        path: '/onboarding?redo=1',
        draft: {
          'flowVersion': onboardingFlowVersion,
          'stepId': 'name',
          'step': 0
        });
    expect(find.text('What should we call you?'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Daniel');
    // Passing his first name through does not shorten his full name.
    await _tap(tester, 'Continue');
    expect(h.container.read(repositoryProvider).profile.name, 'Daniel Reyes');
    expect(find.text('When is your birthday?'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(HomeShell), findsOneWidget);
    expect(h.container.read(repositoryProvider).profile.onboarded, isTrue);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('the welcome plays through with its motion on', (tester) async {
    // Every other test here reduces motion. This one leaves it on, so the
    // page turns, the typing, the first-week path and the dissolve into the
    // letter all run.
    final h =
        await _mount(tester, name: '', displayName: '', reduceMotion: false);
    Future<void> play([int milliseconds = 1600]) async {
      for (var i = 0; i < milliseconds ~/ 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> press(String text, [int then = 1600]) async {
      await tester.tap(find.text(text).last);
      await play(then);
      expect(tester.takeException(), isNull, reason: 'after "$text"');
    }

    await play();
    await tester.enterText(find.byType(TextField), 'Daniel');
    await tester.pump();
    await press('Continue');
    await press('Skip');
    await press('Peace', 500);
    await press('Continue');
    await press('Life is changing fast', 500);
    // HolyHim writes his opening lines and the first question.
    await press('Continue', 7000);
    expect(find.text('How well do you know the Bible?'), findsOneWidget);
    await press('I am new to the Bible', 5000);
    await press('Nothing really', 5000);
    // The path draws down the week before Continue opens.
    await press('Show me my first week', 5500);
    await press('Continue', 6000);
    await press('Not now', 4000);
    // The checklist, the save, then the card opens into his letter.
    await press('Build my road', 6500);
    expect(find.text('Daniel,'), findsOneWidget);
    await press('Continue');
    await press('Continue');
    expect(find.byType(OfferBody), findsOneWidget);
    expect(_draft(tester, h)['stepId'], 'offer');
    await h.dispose(tester);
  });

  testWidgets('a version 2 profile saved at the offer resumes at the letter',
      (tester) async {
    final h = await _mount(tester, onboarded: true, draft: {
      'flowVersion': 2,
      'stepId': 'lifetimeAccess',
      'step': 10,
      'firstName': 'Daniel',
      'lifeSeason': 'A time of change',
      'faithRoutine': 'I read regularly',
      'obstacle': 'My days are full',
      'reminder': 'No reminders',
    });
    h.container.read(repositoryProvider.notifier).updateProfile(h.container
        .read(repositoryProvider)
        .profile
        .copyWith(hearts: ['Peace']));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(UncontrolledProviderScope(
        container: h.container, child: const HolyHimApp()));
    await tester.pump();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Daniel,'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('Today opens the lesson and closing returns to the same shell',
      (tester) async {
    final h =
        await _mount(tester, onboarded: true, owned: true, reduceMotion: false);
    await tester.pump(const Duration(seconds: 1));
    final shell = tester.state(find.byType(HomeShell));
    await _tap(tester, 'Begin Day 1',
        settle: const Duration(milliseconds: 700));
    expect(find.byType(LessonScreen), findsOneWidget);
    expect(h.router.canPop(), isTrue);
    await tester.tap(find.byTooltip('Close lesson'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.state(find.byType(HomeShell)), same(shell));
    expect(find.byType(WalkScreen), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('four cards, a held Amen and the celebration', (tester) async {
    final h =
        await _mount(tester, onboarded: true, owned: true, path: '/lesson/1');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Next card'));
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(find.text('Hold to say Amen'), findsOneWidget);
    final gesture = await tester
        .startGesture(tester.getCenter(find.text('Hold to say Amen')));
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CelebrationScreen), findsOneWidget);
    expect(find.text('Amen.'), findsOneWidget);
    expect(
        h.container.read(repositoryProvider).completed.containsKey(1), isTrue);
    await h.dispose(tester);
  });

  testWidgets('after the welcome nothing opens without membership',
      (tester) async {
    final week = {for (var d = 1; d <= 7; d++) d: '2026-11-0$d'};
    final h = await _mount(tester,
        onboarded: true, completed: week, path: '/lesson/3');
    expect(find.byType(OfferScreen), findsOneWidget);
    expect(find.byType(LessonScreen), findsNothing);
    expect(find.byTooltip('Close'), findsNothing);
    h.router.go('/');
    await tester.pump();
    await tester.pump();
    expect(find.byType(HomeShell), findsNothing);
    // The free week opens the door, once he has seen that he is in, and
    // takes him where he was going.
    await _tap(tester, 'Start my 7 days free');
    expect(find.text('You’re in.'), findsOneWidget);
    await _tap(tester, 'Continue');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LessonScreen), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('every route meets the same offer, and it never closes',
      (tester) async {
    final h = await _mount(tester, onboarded: true);
    for (final path in [
      for (final tab in homeTabs) tab.path,
      '/journey',
      '/onboarding',
      '/offer',
      '/paywall',
      '/account',
      '/saved',
      '/verse/1',
      '/lesson/today',
      '/lesson/1',
    ]) {
      h.router.go(path);
      await tester.pump();
      await tester.pump();
      expect(find.byType(OfferScreen), findsOneWidget, reason: path);
      expect(find.byType(HomeShell), findsNothing, reason: path);
      expect(find.byTooltip('Close'), findsNothing, reason: path);
      expect(find.byIcon(CupertinoIcons.xmark), findsNothing, reason: path);
    }
    await h.dispose(tester);
  });

  testWidgets('owners open Day 8 directly', (tester) async {
    final week = {for (var d = 1; d <= 7; d++) d: '2026-11-0$d'};
    final h = await _mount(tester,
        onboarded: true, completed: week, owned: true, path: '/lesson/8');
    expect(find.byType(LessonScreen), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a future lesson link explains itself and offers a way back',
      (tester) async {
    final h =
        await _mount(tester, onboarded: true, owned: true, path: '/lesson/12');
    expect(find.text('Not quite yet'), findsOneWidget);
    h.router.go('/verse/12');
    await tester.pump();
    expect(find.text('Open today’s lesson'), findsOneWidget);
    await h.dispose(tester);
  });
}
