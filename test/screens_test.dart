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
import 'package:holyher/features/landing/landing_screen.dart';
import 'package:holyher/features/lesson/lesson_screen.dart';
import 'package:holyher/features/lesson/lesson_deck.dart';
import 'package:holyher/features/onboarding/onboarding_screen.dart';
import 'package:holyher/features/paywall/paywall_screen.dart';
import 'package:holyher/features/settings/settings_screen.dart';
import 'package:holyher/features/support/support_screens.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/paywall_service.dart';
import 'package:holyher/services/profile_service.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/streak_service.dart';
import 'package:holyher/services/reminder_service.dart';
import 'support.dart';

class _Auth extends AuthNotifier {
  final AuthState initial;
  _Auth(this.initial);
  @override
  AuthState build() => initial;
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
  Future<void> save(UserProfile profile) async {
    state = profile.copyWith(loaded: true);
  }

  @override
  Future<void> setReminder(int? value) async {
    state =
        state.copyWith(reminderMinutes: value, clearReminder: value == null);
  }

  @override
  Future<void> setHaptics(bool value) async {
    state = state.copyWith(haptics: value);
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
  Future<void> completeDay(int day) async {
    if (state.isUnlocked(day)) {
      state = state.copyWith(completedDays: {...state.completedDays, day});
    }
  }
}

class _Paywall extends PaywallNotifier {
  final bool initial;
  int purchaseAttempts = 0;
  _Paywall(this.initial);
  @override
  bool build() => initial;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> unlock() async {
    purchaseAttempts++;
    return false;
  }

  @override
  Future<bool> restore() async => false;
}

class _Streak extends StreakNotifier {
  final StreakState initial;
  _Streak(this.initial);
  @override
  StreakState build() => initial;
  @override
  Future<void> markTodayActive() async {}
}

void main() {
  final captureKey = GlobalKey();
  const profile = UserProfile(
      name: 'Amira',
      familiarity: 'regular',
      focus: 'peace',
      obstacle: 'busy',
      onboardingComplete: true,
      loaded: true);
  const activeJourney = ProgressState(journeyStarted: true, unlockedThrough: 1);
  setUpAll(() async {
    final font = FontLoader('Lexend');
    for (final weight in [
      'Thin',
      'ExtraLight',
      'Light',
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
      'Black'
    ]) {
      font.addFont(rootBundle.load('assets/fonts/Lexend-$weight.ttf'));
    }
    await font.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  Future<ProviderContainer> start(WidgetTester tester, Widget screen,
      {Size size = const Size(390, 844),
      double scale = 1,
      UserProfile userProfile = profile,
      ProgressState progress = activeJourney,
      bool premium = true,
      bool reminderEnabled = false,
      StreakState streak = const StreakState(current: 3, longest: 7),
      AuthState auth = const AuthState(
          user: AuthUser(
              uid: 'test-reader', email: 'reader@example.com'))}) async {
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          authProvider.overrideWith(() => _Auth(auth)),
          profileProvider.overrideWith(() => _Profile(userProfile)),
          progressProvider.overrideWith(() => _Progress(progress)),
          paywallProvider.overrideWith(() => _Paywall(premium)),
          purchaseProvider
              .overrideWith((ref) => const PurchaseState(configured: true)),
          streakProvider.overrideWith(() => _Streak(streak)),
          reminderEnabledProvider.overrideWith((ref) async => reminderEnabled),
          localStoreProvider.overrideWithValue(MemoryStore()),
          localClockProvider.overrideWithValue(() => DateTime(2026, 10, 29, 8))
        ],
        child: RepaintBoundary(
            key: captureKey,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildAppTheme(),
                home: screen))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: '${screen.runtimeType} at $size / $scale');
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  Future<Finder> reveal(WidgetTester tester, String text) async {
    final found = find.text(text);
    if (found.evaluate().isEmpty) {
      await tester.scrollUntilVisible(found, 220,
          scrollable: find.byType(Scrollable).first);
    }
    final target = found.last;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(target), alignment: .5);
    await tester.pumpAndSettle();
    expect(target.hitTestable(), findsOneWidget,
        reason: '$text must be reachable in the viewport');
    return target;
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final target = await reveal(tester, text);
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(WidgetTester tester, String name,
      {double pixelRatio = 1, String directory = 'build/qa'}) async {
    await tester.runAsync(() async {
      final boundary = captureKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$directory/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
      'five cards keep completion on Carry and separate devotional voice',
      (tester) async {
    final source = lessons.first;
    final sample = DailyLesson(
        day: source.day,
        title: source.title,
        verseReference: source.verseReference,
        verseText: source.verseText,
        confidence: source.confidence,
        reason: source.reason,
        hope: source.hope,
        reflection: source.reflection,
        theme: source.theme,
        translation: source.translation,
        devotionalReflection:
            'I can bring this ordinary moment to God and remember that I am not alone.');
    final container = await start(tester, Builder(builder: (context) {
      return Scaffold(
          body: Center(
              child: TextButton(
        onPressed: () => Navigator.push<void>(context,
            MaterialPageRoute(builder: (_) => LessonScreen(lesson: sample))),
        child: const Text('Open lesson'),
      )));
    }));
    await tap(tester, 'Open lesson');
    expect(find.text(lessons.first.verseText), findsOneWidget);
    expect(find.text('Complete today’s message'), findsNothing);
    await capture(tester, 'lesson-verse');
    for (var i = 0; i < 3; i++) {
      await tap(tester, 'Next card');
      expect(find.text('Complete today’s message'), findsNothing);
    }
    expect(find.text('DEVOTIONAL REFLECTION'), findsOneWidget);
    expect(find.text(sample.devotionalReflection), findsOneWidget);
    await capture(tester, 'lesson-hope');
    await tap(tester, 'Next card');
    expect(find.text('Complete today’s message'), findsOneWidget);
    await tap(tester, 'Complete today’s message');
    expect(container.read(progressProvider).completedDays, contains(1));
    expect(find.text('Let it stay\nwith you.'), findsOneWidget);
    await capture(tester, 'lesson-complete');
    await tap(tester, 'Return to my day');
    expect(find.text('Open lesson'), findsOneWidget);
  });
  testWidgets('direct navigation cannot open a locked lesson', (tester) async {
    await start(tester, LessonScreen(lesson: lessons[1]));
    expect(find.text('Day 2 is still ahead.'), findsOneWidget);
    expect(find.text('Next card'), findsNothing);
  });
  testWidgets('an unlocked day still requires a verified purchase',
      (tester) async {
    await start(tester, LessonScreen(lesson: lessons.first), premium: false);
    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(find.text(lessons.first.verseText), findsNothing);
  });
  testWidgets(
      'lesson swipe deck respects its first boundary and moves both ways',
      (tester) async {
    await start(tester, LessonScreen(lesson: lessons.first));
    final deck = find.byType(LessonDeck);
    await tester.drag(deck, const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('1 / 5'), findsOneWidget);
    await tester.drag(deck, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 5'), findsOneWidget);
    await tester.drag(deck, const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('1 / 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('questionnaire saves real choices and previews exact Day 1',
      (tester) async {
    final container = await start(tester, const OnboardingScreen(),
        userProfile: const UserProfile(
            loaded: true, familiarity: '', focus: '', obstacle: ''));
    await tester.enterText(find.byType(TextField), 'Amira');
    await tap(tester, 'Continue');
    await tap(tester, 'New to it');
    await tap(tester, 'Continue');
    await tap(tester, 'Peace');
    await tap(tester, 'Continue');
    await tap(tester, 'Busy days');
    await tap(tester, 'Continue');
    await tap(tester, 'No reminder for now');
    await tap(tester, 'Continue');
    expect(container.read(profileProvider).focus, 'peace');
    expect(container.read(profileProvider).onboardingComplete, isFalse);
    expect(find.text('YOUR SETUP IS SAVED'), findsOneWidget);
    await capture(tester, 'onboarding-plan');
    await tap(tester, 'See my first verse');
    expect(find.text(lessons.first.verseText), findsOneWidget);
    await tap(tester, 'Continue to HolyHer');
    expect(container.read(profileProvider).onboardingComplete, isTrue);
  });
  testWidgets('paywall has one lifetime offer and never locally grants access',
      (tester) async {
    final container =
        await start(tester, const PaywallScreen(), premium: false);
    expect(find.text(r'$1.99'), findsOneWidget);
    expect(find.text('Annual'), findsNothing);
    expect(find.text('Monthly'), findsNothing);
    await capture(tester, 'paywall');
    await tap(tester, r'Unlock forever · $1.99');
    expect(container.read(paywallProvider), isFalse);
    await tap(tester, 'Restore purchases');
    expect(container.read(paywallProvider), isFalse);
    expect(find.text('No lifetime purchase was found for this store account.'),
        findsOneWidget);
  });
  testWidgets('email auth validates and shows service errors', (tester) async {
    await start(tester, const AuthScreen(), auth: const AuthState());
    await tap(tester, 'Continue with email');
    await tap(tester, 'Sign in');
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    await tester.enterText(
        find.byType(TextFormField).at(0), 'reader@example.com');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'incorrect-password');
    await tap(tester, 'Sign in');
    expect(
        find.text('That email and password did not match. Please try again.'),
        findsOneWidget);
  });
  testWidgets('Today, virtual Journey and Profile have working destinations',
      (tester) async {
    await start(tester, const HomeShell());
    expect(find.text('Make a little room\nfor your soul.'), findsOneWidget);
    await capture(tester, 'today');
    await tap(tester, 'Journey');
    expect(
        find.text('0 of ${lessons.length} messages complete'), findsOneWidget);
    expect(find.text(lessons.last.title), findsNothing);
    await capture(tester, 'journey');
    await tap(tester, 'Profile');
    expect(find.text('Amira’s\nquiet space.'), findsOneWidget);
    await capture(tester, 'profile');
    await tap(tester, 'Settings');
    expect(find.byType(SettingsScreen), findsOneWidget);
  });
  testWidgets(
      'a synced reminder preference is not called enabled before device scheduling',
      (tester) async {
    final preference = profile.copyWith(reminderMinutes: 480);
    await start(tester, const SettingsScreen(), userProfile: preference);
    expect(find.text('Preferred reminder time'), findsOneWidget);
    expect(find.text('8:00 AM · Tap to enable on this device'), findsOneWidget);
    await start(tester, const SettingsScreen(),
        userProfile: preference, reminderEnabled: true);
    expect(find.text('Daily reminder'), findsOneWidget);
    expect(find.text('8:00 AM · Enabled on this device'), findsOneWidget);
  });
  testWidgets('phone 3x text and iPad landscape have no layout overflow',
      (tester) async {
    for (final scenario in [
      (const Size(320, 844), 3.0),
      (const Size(1194, 834), 1.0),
      (const Size(844, 390), 1.0)
    ]) {
      for (final screen in [
        const LandingScreen(),
        const AuthScreen(),
        const OnboardingScreen(),
        const PaywallScreen(),
        const HomeShell(),
        const SettingsScreen(),
        const HelpScreen(),
        const PrivacyScreen(),
        const TermsScreen(),
        LessonScreen(lesson: lessons.first)
      ]) {
        await start(tester, screen, size: scenario.$1, scale: scenario.$2);
        expect(tester.takeException(), isNull,
            reason: '${screen.runtimeType} at ${scenario.$1} / ${scenario.$2}');
      }
    }
    await start(tester, const HomeShell(), size: const Size(1194, 834));
    await capture(tester, 'ipad-today');
    await start(tester, LessonScreen(lesson: lessons.first),
        size: const Size(320, 844), scale: 3);
    await capture(tester, 'large-text-lesson');
  });
  testWidgets(
      'longest catalog readings remain navigable at 320 by 568 with 3x text',
      (tester) async {
    DailyLesson longest(int Function(DailyLesson) measure) =>
        lessons.reduce((a, b) => measure(a) >= measure(b) ? a : b);
    final samples = <int, DailyLesson>{
      for (final lesson in [
        longest((lesson) => lesson.title.length),
        longest((lesson) => lesson.verseText.length),
        longest((lesson) => [
              lesson.confidence,
              lesson.reason,
              lesson.hope,
              lesson.devotionalReflection,
              lesson.reflection
            ].map((text) => text.length).reduce((a, b) => a > b ? a : b)),
      ])
        lesson.day: lesson,
    };
    for (final lesson in samples.values) {
      await start(tester, LessonScreen(lesson: lesson),
          size: const Size(320, 568),
          scale: 3,
          progress: ProgressState(
              journeyStarted: true, unlockedThrough: lessons.length));
      for (var index = 0; index < 4; index++) {
        await tap(tester, 'Next card');
        expect(find.text('${index + 2} / 5'), findsOneWidget);
      }
      await reveal(tester, 'Complete');
      await capture(tester, 'long-reading-day-${lesson.day}-carry');
      expect(tester.takeException(), isNull,
          reason: 'Day ${lesson.day} longest reading');
    }
  });
  testWidgets('capture App Store screens from the complete bundled library',
      (tester) async {
    expect(lessons.length, 365);
    const reader = UserProfile(
        familiarity: 'regular',
        focus: 'peace',
        obstacle: 'busy',
        onboardingComplete: true,
        loaded: true);
    for (final device in [
      (const Size(402, 874), 3.0, 'iphone-1206x2622'),
      (const Size(1032, 1376), 2.0, 'ipad-2064x2752')
    ]) {
      final directory = 'store/screenshots/raw/${device.$3}';
      await start(tester, const HomeShell(),
          size: device.$1, userProfile: reader, streak: const StreakState());
      await capture(tester, '01-today',
          pixelRatio: device.$2, directory: directory);
      await tap(tester, 'Journey');
      await capture(tester, '05-journey',
          pixelRatio: device.$2, directory: directory);
      await tap(tester, 'Today');
      await tap(tester, 'Open today’s message');
      await capture(tester, '02-verse',
          pixelRatio: device.$2, directory: directory);
      await tap(tester, 'Next card');
      await tap(tester, 'Next card');
      await capture(tester, '03-reason',
          pixelRatio: device.$2, directory: directory);
      await tap(tester, 'Next card');
      await tap(tester, 'Next card');
      await capture(tester, '04-carry',
          pixelRatio: device.$2, directory: directory);
    }
    await start(tester, const PaywallScreen(),
        size: const Size(402, 874), userProfile: reader);
    await capture(tester, 'paywall',
        pixelRatio: 3, directory: 'store/iap-review');
  }, skip: !const bool.fromEnvironment('STORE_SCREENSHOTS'));
}
