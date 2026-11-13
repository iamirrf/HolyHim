import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:holyhim/design/design.dart';
import 'package:holyhim/domain/lesson.dart';
import 'package:holyhim/domain/onboarding_flow.dart';
import 'package:holyhim/features/celebration/celebration_screen.dart';
import 'package:holyhim/features/lesson/lesson_screen.dart';
import 'package:holyhim/features/onboarding/onboarding_screen.dart';
import 'package:holyhim/features/walk/walk_screen.dart';
import 'package:holyhim/features/shell/home_shell.dart';
import 'package:holyhim/features/welcome/welcome_screen.dart';
import 'package:holyhim/features/paywall/paywall_screen.dart';
import 'package:holyhim/main.dart';
import 'package:holyhim/services/app_router.dart';
import 'package:holyhim/services/auth_service.dart';
import 'package:holyhim/services/billing.dart';
import 'package:holyhim/services/notifications.dart';
import 'package:holyhim/services/repository.dart';

class _FixtureAuth extends AuthNotifier {
  final bool signedIn;
  _FixtureAuth(this.signedIn);
  @override
  AuthState build() => AuthState(
      user: signedIn
          ? const AuthUser(
              uid: 'fixture-only',
              displayName: 'Mira',
              email: 'mira@example.test')
          : null);
}

class _VerifiedFixtureAccess extends LifetimeController {
  @override
  LifetimeState build() =>
      const LifetimeState(loading: false, purchased: true, verified: true);
}

/// Every simulated server receipt remains unresolved. Local state still changes.
class _UnacknowledgedRepository extends WalkRepository {
  final WalkState initial;
  final ack = Completer<void>();
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
  final bool disposeRouter;
  _Harness(this.container, this.router, this.repository, this.notifications,
      {this.disposeRouter = true});
  Future<void> dispose(WidgetTester tester) async {
    if (disposed) return;
    disposed = true;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    container.dispose();
    if (disposeRouter) router.dispose();
    notifications.dispose();
  }
}

Future<_Harness> _mount(WidgetTester tester,
    {bool onboarded = false,
    int? initialStep,
    bool signedIn = true,
    String path = '/',
    double scale = 1,
    bool productionRouter = false,
    bool reduceMotion = true,
    Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  final profile = AppProfile(
      name: 'Mira',
      birthday: initialStep == null ? null : '1998-05-16',
      hearts: initialStep != null && initialStep >= 6 ? ['Peace'] : const [],
      onboardingDraft: initialStep == null
          ? const {}
          : {
              'step': initialStep,
              'stepId': onboardingStepIds[initialStep],
              'flowVersion': onboardingFlowVersion,
              if (initialStep >= 1) 'firstName': 'Mira',
              if (initialStep >= 3) 'lifeSeason': 'A time of change',
              if (initialStep >= 4) 'faithRoutine': 'I read regularly',
              if (initialStep >= 5) 'obstacle': 'My days are full',
              if (initialStep >= 7) ...{
                'pace': 'Three minutes',
                'reminder': 'No reminders',
              },
              if (initialStep >= 9) 'termsAccepted': true
            },
      haptics: false,
      sounds: false,
      timeZone: 'America/New_York',
      onboardedAt: onboarded ? DateTime(2026, 11, 3) : null);
  final repository = _UnacknowledgedRepository(WalkState(profile: profile));
  final notifications = _PendingPermission();
  final router = productionRouter
      ? null
      : GoRouter(initialLocation: path, routes: [
          GoRoute(
              path: '/:location(.*)',
              pageBuilder: (context, state) =>
                  NoTransitionPage<void>(child: AppGate(uri: state.uri)))
        ]);
  final container = ProviderContainer(overrides: [
    authProvider.overrideWith(() => _FixtureAuth(signedIn)),
    repositoryProvider.overrideWith(() => repository),
    notificationServiceProvider.overrideWithValue(notifications),
    lifetimeProvider.overrideWith(_VerifiedFixtureAccess.new),
    if (router != null) appRouterProvider.overrideWithValue(router),
  ]);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container, child: const HolyHimApp()));
  await tester.pump();
  final harness = _Harness(container,
      router ?? container.read(appRouterProvider), repository, notifications,
      disposeRouter: !productionRouter);
  addTearDown(() => harness.dispose(tester));
  return harness;
}

Future<void> _tap(WidgetTester tester, String text) async {
  if (find.text(text).evaluate().isEmpty) {
    await tester.scrollUntilVisible(find.text(text), 180,
        scrollable: find.byType(Scrollable).last, maxScrolls: 20);
  }
  final target = find.text(text).last;
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
  await tester.pump();
}

Future<void> _hold(WidgetTester tester, String text) async {
  final target = find.text(text);
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  final gesture = await tester.startGesture(tester.getCenter(target));
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1250));
  await gesture.up();
  await tester.pump();
}

void main() {
  setUpAll(tzdata.initializeTimeZones);
  setUp(() {
    HolySounds.player = (String asset, {double gain = 1}) async {};
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });
  testWidgets(
      'all eleven onboarding surfaces finish locally without a sample lesson or promise',
      (tester) async {
    final h = await _mount(tester);
    await _tap(tester, 'Continue'); // birthday
    await _tap(tester, 'Continue'); // life season
    await _tap(tester, 'A time of change');
    await _tap(tester, 'Continue');
    await _tap(tester, 'I’m returning after some time');
    await _tap(tester, 'Continue');
    for (final choice in ['My days are full']) {
      await _tap(tester, choice);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
    }
    await _tap(tester, 'Continue'); // intentions
    await _tap(tester, 'Peace');
    await _tap(tester, 'Continue'); // daily rhythm
    for (final choice in ['One minute', 'No reminders']) {
      await _tap(tester, choice);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
    }
    await _tap(tester, 'Continue'); // routine preview
    await _tap(tester, 'Continue'); // profile setup
    await _tap(tester, 'I agree to the Terms and Privacy Policy.');
    await _tap(tester, 'Continue');
    await tester.pump();
    expect(h.container.read(repositoryProvider).profile.onboarded, isTrue);
    expect(find.text('One minute each day'), findsOneWidget);
    expect(find.text('No reminder selected'), findsOneWidget);
    expect(find.text('Choose a steady moment that fits a full day.'),
        findsOneWidget);
    await _tap(tester, 'Continue to HolyHim');
    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(find.byType(LessonScreen), findsNothing);
    await _tap(tester, 'Continue to HolyHim');
    expect(find.byType(WalkScreen), findsOneWidget);
    expect(h.repository.ack.isCompleted, isFalse);
    expect(h.notifications.requests, 0);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });
  testWidgets('Guide answer can be changed without clearing it',
      (tester) async {
    final h = await _mount(tester, initialStep: 6);
    await _tap(tester, 'One minute');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(h.container.read(repositoryProvider).profile.onboardingDraft['pace'],
        'One minute');
    tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
    await tester.pump();
    await tester.tap(find.text('One minute'));
    await tester.pump();
    expect(find.text('Change your answer'), findsOneWidget);
    await _tap(tester, 'Five minutes');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(h.container.read(repositoryProvider).profile.onboardingDraft['pace'],
        'Five minutes');
    expect(find.text('When would you like your daily verse?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });
  testWidgets(
      'three learning cards, prayer, held Amen, celebration and read-again state',
      (tester) async {
    final h = await _mount(tester, onboarded: true, path: '/lesson/1');
    expect(find.text("Today's Word"), findsOneWidget);
    for (final title in ['What it means', 'For your heart', 'Prayer']) {
      await tester.tap(find.byTooltip('Next card'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(title), findsOneWidget);
    }
    await _hold(tester, 'Hold to say Amen');
    expect(find.byType(CelebrationScreen), findsOneWidget);
    expect(find.text('Amen.'), findsOneWidget);
    expect(
        h.container.read(repositoryProvider).completed.containsKey(1), isTrue);
    await _tap(tester, 'Continue');
    expect(find.byType(WalkScreen), findsOneWidget);
    expect(find.text('Read again'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });
  testWidgets('profile editing cannot reopen completed onboarding',
      (tester) async {
    final h = await _mount(tester, onboarded: true, path: '/profile');
    await tester.tap(find.byWidgetPredicate(
        (w) => w is Pressable && w.semanticLabel == 'Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Amelia');
    await _tap(tester, 'Save profile');
    await tester.pumpAndSettle();
    expect(h.container.read(repositoryProvider).profile.name, 'Amelia');
    expect(h.container.read(repositoryProvider).profile.onboarded, isTrue);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });
  testWidgets(
      'tab route changes preserve the shell without provider writes during build',
      (tester) async {
    final h = await _mount(tester, onboarded: true);
    for (final path in ['/saved', '/growth', '/profile', '/']) {
      h.router.go(path);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    }
    await h.dispose(tester);
  });
  for (final entry in <String, ({bool signedIn, bool onboarded, String path})>{
    'welcome': (signedIn: false, onboarded: false, path: '/'),
    'onboarding': (signedIn: true, onboarded: false, path: '/'),
    'lesson': (signedIn: true, onboarded: true, path: '/lesson/1'),
    'walk': (signedIn: true, onboarded: true, path: '/'),
  }.entries) {
    testWidgets('${entry.key} fits a small iPhone at 200% with Reduce Motion',
        (tester) async {
      final h = await _mount(tester,
          signedIn: entry.value.signedIn,
          onboarded: entry.value.onboarded,
          path: entry.value.path,
          scale: 2,
          size: const Size(375, 667));
      expect(tester.takeException(), isNull);
      final context = tester.element(find.byType(Scaffold).first);
      expect(MediaQuery.disableAnimationsOf(context), isTrue);
      expect(MediaQuery.textScalerOf(context).scale(20), 40);
      if (entry.key == 'welcome') {
        expect(find.byType(WelcomeScreen), findsOneWidget);
      }
      if (entry.key == 'onboarding') {
        expect(find.byType(OnboardingScreen), findsOneWidget);
      }
      if (entry.key == 'lesson') {
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.byTooltip('Next card'));
          await tester.pump(const Duration(milliseconds: 500));
        }
        await tester.ensureVisible(find.text('Hold to say Amen'));
        expect(tester.takeException(), isNull);
      }
      if (entry.key == 'walk') {
        await tester.drag(
            find.byType(CustomScrollView).first, const Offset(0, -450));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      await h.dispose(tester);
    });
  }
  for (var step = 1; step <= 9; step++) {
    testWidgets('onboarding step ${step + 1} fits at 200 percent after resume',
        (tester) async {
      final h = await _mount(tester,
          initialStep: step, scale: 2, size: const Size(375, 667));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      await h.dispose(tester);
    });
  }
  testWidgets('testing paywall fits at 200 percent after resume',
      (tester) async {
    final h = await _mount(tester,
        initialStep: 10, scale: 2, size: const Size(375, 667));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(PaywallScreen), findsOneWidget);
    await h.dispose(tester);
  });
  testWidgets('resuming the save step keeps the paywall in the onboarding flow',
      (tester) async {
    final h = await _mount(tester, initialStep: 9);
    await tester.pump();
    await tester.pump();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(h.container.read(repositoryProvider).profile.onboarded, isTrue);
    await _tap(tester, 'Continue to HolyHim');
    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
    await h.dispose(tester);
  });
  testWidgets('a profile update during a home swipe does not reset the gesture',
      (tester) async {
    final h = await _mount(tester,
        onboarded: true, productionRouter: true, reduceMotion: false);
    final shell = tester.state(find.byType(HomeShell));
    final pager = find.byType(PageView).first;
    final controller = tester.widget<PageView>(pager).controller!;
    final gesture = await tester.startGesture(tester.getCenter(pager));
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-260, 0));
    await tester.pump(const Duration(milliseconds: 16));
    final fractionalPage = controller.page!;
    expect(fractionalPage, greaterThan(.5));
    expect(h.router.routeInformationProvider.value.uri.path, '/');
    h.repository.updateProfile(
        h.container.read(repositoryProvider).profile.copyWith(name: 'Amelia'));
    await tester.pump();
    await tester.pump();
    expect(controller.page, closeTo(fractionalPage, .001));
    expect(tester.state(find.byType(HomeShell)), same(shell));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(h.router.routeInformationProvider.value.uri.path, '/saved');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Today flies into a pushed lesson and closing retains the tab shell',
      (tester) async {
    final h = await _mount(tester,
        onboarded: true, productionRouter: true, reduceMotion: false);
    await tester.pump(const Duration(seconds: 1));
    final shell = tester.state(find.byType(HomeShell));
    final source = find
        .byWidgetPredicate((widget) => widget is Hero && widget.tag == 'art-1');
    final sourceElement = tester.element(source);
    await _tap(tester, 'Read today');
    await tester.pump(const Duration(milliseconds: 120));
    final sourceInFlight = find.descendant(
        of: find.byElementPredicate((element) => element == sourceElement,
            skipOffstage: false),
        matching: find.byType(Offstage, skipOffstage: false));
    expect(sourceInFlight, findsOneWidget);
    expect(tester.widget<Offstage>(sourceInFlight).offstage, isTrue);
    final route = ModalRoute.of(tester.element(find.byType(LessonScreen)))!;
    expect(route.animation!.value, greaterThan(0));
    expect(route.animation!.value, lessThan(1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(h.router.canPop(), isTrue);
    await tester.tap(find.byTooltip('Close lesson'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.state(find.byType(HomeShell)), same(shell));
    expect(find.text('Read today'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });
  testWidgets(
      'notification destination gates stale teasers and locked lesson URLs',
      (tester) async {
    final h = await _mount(tester, onboarded: true, path: '/lesson/12');
    expect(
        find.text('This little moment is still ahead of you.'), findsOneWidget);
    h.router.go('/verse/12');
    await tester.pump();
    expect(find.text("Today's lesson"), findsOneWidget);
    expect(find.byType(LessonScreen), findsNothing);
    await _tap(tester, "Today's lesson");
    expect(find.byType(LessonScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });
}
