import 'package:holyher/services/reading_service.dart';
import 'package:holyher/services/reading_destination.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/features/auth/auth_screen.dart';
import 'package:holyher/features/home/home_shell.dart';
import 'package:holyher/features/lesson/lesson_screen.dart';
import 'package:holyher/features/onboarding/onboarding_screen.dart';
import 'package:holyher/features/settings/settings_screen.dart';
import 'package:holyher/features/support/support_screens.dart';
import 'package:holyher/features/support/contact_screen.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/learning_service.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/profile_service.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/streak_service.dart';
import 'package:holyher/services/reminder_service.dart';
import 'support.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
      user: AuthUser(uid: 'test-reader', email: 'reader@example.com'));
  @override
  Future<void> signInEmail(String email, String password) async {
    state = const AuthState(
        error: 'That email and password did not match. Please try again.');
  }
}

class _Profile extends ProfileNotifier {
  final UserProfile initial;
  _Profile(this.initial);
  @override
  UserProfile build() => initial;
  @override
  Future<void> save(UserProfile value) async {
    state = value;
  }

  @override
  Future<void> saveDraft(UserProfile value) => save(value);
  @override
  Future<void> setReminder(int? value) async {
    state =
        state.copyWith(reminderMinutes: value, clearReminder: value == null);
  }
}

class _Progress extends ProgressNotifier {
  final ProgressState initial;
  _Progress(this.initial);
  @override
  ProgressState build() => initial;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> startJourney() async {
    state = state.copyWith(
        journeyStarted: true,
        unlockedThrough: 1,
        startDate: '2026-10-31',
        timeZone: 'America/New_York');
  }
}

class _Streak extends StreakNotifier {
  @override
  StreakState build() => const StreakState(current: 3, longest: 7);
}

void main() {
  final boundary = GlobalKey();
  const profile = UserProfile(
      name: 'Amira',
      familiarity: 'regular',
      focus: 'peace',
      obstacle: 'busy',
      sounds: false,
      onboardingComplete: true,
      loaded: true);
  setUpAll(() async {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  Future<ProviderContainer> start(WidgetTester tester, Widget screen,
      {Size size = const Size(390, 844),
      double scale = 1,
      MemoryStore? store,
      UserProfile userProfile = profile,
      ProgressState progress = const ProgressState(
          journeyStarted: true,
          unlockedThrough: 365,
          timeZone: 'America/New_York')}) async {
    await tester.pumpWidget(const SizedBox());
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          authProvider.overrideWith(_Auth.new),
          profileProvider.overrideWith(() => _Profile(userProfile)),
          progressProvider.overrideWith(() => _Progress(progress)),
          streakProvider.overrideWith(_Streak.new),
          localStoreProvider.overrideWithValue(store ?? MemoryStore()),
          learningGatewayProvider.overrideWithValue(null),
          reminderEnabledProvider.overrideWith((ref) async => false)
        ],
        child: RepaintBoundary(
            key: boundary,
            child: MaterialApp(
                theme: buildAppTheme(),
                debugShowCheckedModeBanner: false,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(scale),
                        disableAnimations: true),
                    child: child!),
                home: screen))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  Future<void> tap(WidgetTester tester, String text) async {
    if (text == 'Next') {
      while (find.text('Next part').evaluate().isNotEmpty) {
        await tester.ensureVisible(find.text('Next part').last);
        await tester.tap(find.text('Next part').last);
        await tester.pumpAndSettle();
      }
    }
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('QA_SCREENSHOTS')) return;
    await tester.pump();
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('store/rebuild-gallery/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('free shell exposes Walk, Saved and Profile with roadmap search',
      (tester) async {
    await start(tester, const HomeShell());
    expect(find.text('Walk'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    await capture(tester, 'learn-phone');
    await tap(tester, 'Search');
    await tester.enterText(find.byType(TextField).first, 'Jeremiah 29:11');
    await tester.pumpAndSettle();
    expect(find.text('Hope During a Long Wait'), findsOneWidget);
    await tap(tester, 'Saved');
    expect(find.text('Keep a verse close.'), findsOneWidget);
    await capture(tester, 'saved-empty-phone');
    await tap(tester, 'Profile');
    expect(find.text('HolyHer 365 edition'), findsOneWidget);
  });
  testWidgets(
      'future lesson opens a calendar explanation without a payment action',
      (tester) async {
    await start(tester, LessonScreen(lesson: lessons[1]),
        progress:
            const ProgressState(journeyStarted: true, unlockedThrough: 1));
    expect(find.text('Day 2 is still ahead.'), findsOneWidget);
    expect(find.textContaining('purchase'), findsNothing);
  });
  testWidgets(
      'five reading cards require a final action and queue completion without answers',
      (tester) async {
    final store = MemoryStore();
    final container =
        await start(tester, LessonScreen(lesson: lessons.first), store: store);
    expect(container.read(progressProvider).completedDays, isEmpty);
    for (var i = 0; i < 4; i++) {
      await tap(tester, 'Continue');
      expect(container.read(progressProvider).completedDays, isEmpty);
    }
    expect(find.text('Finish my reading'), findsOneWidget);
    expect(find.textContaining('question'), findsNothing);
    await capture(tester, 'prayer-phone');
    await tap(tester, 'Finish my reading');
    expect(container.read(progressProvider).completedDays, {1});
    expect(container.read(readingSyncProvider).pending.length, 1);
    expect(store.values['reading_outbox_v1'], isNotNull);
    expect(find.text('Walk a little lighter.'), findsOneWidget);
    expect(find.textContaining('Synchronization is pending'), findsOneWidget);
    await capture(tester, 'reading-pending-phone');
  });
  testWidgets(
      'local completion failure stays recoverable without accepted progress',
      (tester) async {
    final store = MemoryStore();
    final container =
        await start(tester, LessonScreen(lesson: lessons.first), store: store);
    for (var i = 0; i < 4; i++) {
      await tap(tester, 'Continue');
    }
    store.writesAllowed = 0;
    await tap(tester, 'Finish my reading');
    expect(container.read(progressProvider).completedDays, isEmpty);
    expect(find.textContaining('could not be saved'), findsOneWidget);
    store.writesAllowed = null;
    await tap(tester, 'Finish my reading');
    expect(container.read(progressProvider).completedDays, {1});
  });
  testWidgets(
      'optional personalization reaches real Day 1 and queues exactly one destination',
      (tester) async {
    final container = await start(tester, const OnboardingScreen(),
        userProfile: profile.copyWith(onboardingComplete: false));
    await tester.enterText(find.byType(TextField).first, 'Amira');
    await tap(tester, 'Continue');
    expect(find.text('What does your heart need?'), findsOneWidget);
    await tap(tester, 'Rest');
    await tap(tester, 'Continue');
    expect(find.text('A gentle invitation.'), findsOneWidget);
    await tap(tester, 'Skip');
    expect(find.text(lessons.first.verseText), findsOneWidget);
    expect(container.read(profileProvider).onboardingComplete, isFalse);
    await tap(tester, 'Begin my walk');
    expect(container.read(profileProvider).onboardingComplete, isTrue);
    expect(container.read(profileProvider).name, 'Amira');
    expect(container.read(profileProvider).focus, 'rest');
    expect(container.read(profileProvider).reminderMinutes, isNull);
    expect(container.read(readingDestinationProvider)?.day, 1);
  });
  testWidgets('support form validates before sending', (tester) async {
    await start(tester, const ContactScreen());
    await tap(tester, 'Send message');
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Write at least 10 characters.'), findsOneWidget);
  });
  testWidgets('email authentication retains validation', (tester) async {
    await start(tester, const AuthScreen());
    await tap(tester, 'Sign in');
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });
  for (final viewport in [
    (const Size(320, 568), 3.0, 'phone-3x'),
    (const Size(1194, 834), 1.0, 'ipad-landscape'),
    (const Size(600, 700), 2.0, 'split-view')
  ]) {
    testWidgets(
        '${viewport.$3} keeps learning, settings and support scrollable',
        (tester) async {
      for (final screen in [
        const HomeShell(),
        LessonScreen(lesson: lessons.first),
        const SettingsScreen(),
        const HelpScreen(),
        const ContactScreen()
      ]) {
        await start(tester, screen, size: viewport.$1, scale: viewport.$2);
        await capture(tester, '${viewport.$3}-${screen.runtimeType}');
        expect(tester.takeException(), isNull);
      }
    });
  }
}
