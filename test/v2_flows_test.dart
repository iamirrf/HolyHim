import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:holyhim/design/design.dart';
import 'package:holyhim/domain/lesson.dart';
import 'package:holyhim/domain/onboarding_flow.dart';
import 'package:holyhim/features/celebration/celebration_screen.dart';
import 'package:holyhim/features/lesson/lesson_screen.dart';
import 'package:holyhim/features/onboarding/onboarding_screen.dart';
import 'package:holyhim/features/paywall/paywall_screen.dart';
import 'package:holyhim/features/shell/home_shell.dart';
import 'package:holyhim/features/today/today_screen.dart';
import 'package:holyhim/features/welcome/welcome_screen.dart';
import 'package:holyhim/main.dart';
import 'package:holyhim/services/app_router.dart';
import 'package:holyhim/services/auth_service.dart';
import 'package:holyhim/services/billing.dart';
import 'package:holyhim/services/notifications.dart';
import 'package:holyhim/services/repository.dart';
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

class _FixtureAccess extends LifetimeController {
  final bool owned;
  _FixtureAccess(this.owned);
  @override
  LifetimeState build() =>
      LifetimeState(loading: false, purchased: owned, verified: true);
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
    state = state.copyWith(
        completed: {...state.completed, day: '2026-11-12'});
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
    String name = 'Mira Rose',
    String displayName = 'Mira Rose',
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
  final router = GoRouter(initialLocation: path, routes: [
    GoRoute(path: '/:location(.*)', pageBuilder: appRoutePage)
  ]);
  final container = ProviderContainer(overrides: [
    authProvider.overrideWith(() => _FixtureAuth(signedIn, displayName)),
    repositoryProvider.overrideWith(() => repository),
    notificationServiceProvider.overrideWithValue(notifications),
    lifetimeProvider.overrideWith(() => _FixtureAccess(owned)),
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
  await tester.ensureVisible(target);
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
    expect(find.text('Hi Mira. What does your heart need?'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets(
      'onboarding stores stable IDs, asks permission only on request and ends in Day 1',
      (tester) async {
    final h = await _mount(tester, name: '', displayName: '');
    expect(find.text('What should we call you?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Mira');
    await _tap(tester, 'Continue');
    expect(h.container.read(repositoryProvider).profile.name, 'Mira');
    expect(find.text('Hi Mira. What does your heart need?'), findsOneWidget);
    await _tap(tester, 'Peace');
    await _tap(tester, 'Hope');
    await _tap(tester, 'Continue');
    await _tap(tester, 'Things are changing');
    await _tap(tester, 'I am coming back to it');
    await _tap(tester, 'It is hard to understand');
    expect(find.text('When should today’s word arrive?'), findsOneWidget);
    expect(h.notifications.requests, 0);
    await _tap(tester, 'Not now');
    expect(h.notifications.requests, 0);
    await _tap(tester, 'Skip');
    final draft = _draft(tester, h);
    expect(draft['flowVersion'], onboardingFlowVersion);
    expect(draft['lifeSeason'], 'change');
    expect(draft['familiarity'], 'returning');
    expect(draft['obstacle'], 'understanding');
    expect(draft['reminder'], 'off');
    expect(h.container.read(repositoryProvider).profile.hearts,
        ['peace', 'hope']);
    // Building, then the letter.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(h.container.read(repositoryProvider).profile.onboarded, isTrue);
    expect(find.text('Dear Mira,'), findsOneWidget);
    await _tap(tester, 'Continue');
    expect(find.byType(OfferScreen), findsOneWidget);
    await _tap(tester, 'Start my 7 free days');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LessonScreen), findsOneWidget);
    expect(_draft(tester, h)['stepId'], onboardingDoneStepId);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('choosing a reminder asks iOS only after the tap',
      (tester) async {
    final h = await _mount(tester, hearts: ['rest'], draft: {
      'flowVersion': onboardingFlowVersion,
      'stepId': 'reminder',
      'lifeSeason': 'full',
      'familiarity': 'new',
      'obstacle': 'busy',
    });
    expect(find.text('When should today’s word arrive?'), findsOneWidget);
    expect(h.notifications.requests, 0);
    await _tap(tester, 'Evening');
    await _tap(tester, 'Remind me at 8:30 PM', settle: Duration.zero);
    expect(h.notifications.requests, 1);
    h.notifications.permission.complete(true);
    await tester.pump(const Duration(milliseconds: 500));
    final profile = h.container.read(repositoryProvider).profile;
    expect(profile.reminderMinutes, 20 * 60 + 30);
    expect(profile.reminderEnabled, isTrue);
    expect(profile.onboardingDraft['reminder'], '20:30');
    await h.dispose(tester);
  });

  testWidgets('a version 2 profile saved at the offer resumes at the letter',
      (tester) async {
    final h = await _mount(tester, onboarded: true, draft: {
      'flowVersion': 2,
      'stepId': 'lifetimeAccess',
      'step': 10,
      'firstName': 'Mira',
      'lifeSeason': 'A time of change',
      'faithRoutine': 'I read regularly',
      'obstacle': 'My days are full',
      'reminder': 'No reminders',
    });
    h.container.read(repositoryProvider.notifier).updateProfile(
        h.container.read(repositoryProvider).profile.copyWith(hearts: ['Peace']));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(UncontrolledProviderScope(
        container: h.container, child: const HolyHimApp()));
    await tester.pump();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Dear Mira,'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('Today opens the lesson and closing returns to the same shell',
      (tester) async {
    final h = await _mount(tester, onboarded: true, reduceMotion: false);
    await tester.pump(const Duration(seconds: 1));
    final shell = tester.state(find.byType(HomeShell));
    await _tap(tester, 'Begin Day 1', settle: const Duration(milliseconds: 700));
    expect(find.byType(LessonScreen), findsOneWidget);
    expect(h.router.canPop(), isTrue);
    await tester.tap(find.byTooltip('Close lesson'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.state(find.byType(HomeShell)), same(shell));
    expect(find.byType(TodayScreen), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('four cards, a held Amen and the celebration', (tester) async {
    final h = await _mount(tester, onboarded: true, path: '/lesson/1');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Next card'));
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(find.text('Hold to say Amen'), findsOneWidget);
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Hold to say Amen')));
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CelebrationScreen), findsOneWidget);
    expect(find.text('Amen.'), findsOneWidget);
    expect(h.container.read(repositoryProvider).completed.containsKey(1), isTrue);
    await h.dispose(tester);
  });

  testWidgets('Day 8 needs the unlock; completed and free days stay open',
      (tester) async {
    final week = {for (var d = 1; d <= 7; d++) d: '2026-11-0$d'};
    final h = await _mount(tester,
        onboarded: true, completed: week, path: '/lesson/8');
    expect(find.byType(OfferScreen), findsOneWidget);
    expect(find.byType(LessonScreen), findsNothing);
    h.router.go('/lesson/3');
    await tester.pump();
    await tester.pump();
    expect(find.byType(LessonScreen), findsOneWidget);
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
    final h = await _mount(tester, onboarded: true, path: '/lesson/12');
    expect(find.text('Not quite yet'), findsOneWidget);
    h.router.go('/verse/12');
    await tester.pump();
    expect(find.text('Open today’s lesson'), findsOneWidget);
    await h.dispose(tester);
  });
}
