import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/core/constants/app_constants.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/features/home/home_shell.dart';
import 'package:holyher/features/lesson/lesson_screen.dart';
import 'package:holyher/features/onboarding/onboarding_screen.dart';
import 'package:holyher/main.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/streak_service.dart';
import 'support.dart';

void main() {
  final boundaryKey = GlobalKey();

  setUpAll(() async {
    final loader = FontLoader('Lexend')
      ..addFont(rootBundle.load('assets/fonts/Lexend-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Lexend-Bold.ttf'));
    await loader.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  Future<void> start(WidgetTester tester, MemoryStore store,
      {double width = 390, double scale = 1, Widget? screen}) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.view.physicalSize = Size(width, 844);
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
        localStoreProvider.overrideWithValue(store),
        localClockProvider.overrideWithValue(() => DateTime(2026, 10, 29)),
      ],
      child: RepaintBoundary(
          key: boundaryKey,
          child: screen == null
              ? const HolyHerApp()
              : MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: buildAppTheme(),
                  home: screen)),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final boundary = boundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) fail('Missing QA boundary');
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes, isNotNull);
      if (bytes != null) {
        final file = File('build/qa/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes.buffer.asUint8List());
      }
      image.dispose();
    });
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets(
      'full first-launch flow, hard gate, lesson completion, persisted return',
      (tester) async {
    final store = MemoryStore();
    await start(tester, store);
    expect(find.text('HOLYHER'), findsOneWidget);
    expect(find.text(AppConstants.tagline), findsOneWidget);
    await capture(tester, 'landing');
    await tap(tester, 'Get Started');
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tap(tester, 'Next');
    expect(find.text('Confidence, with reason'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(350, 0));
    await tester.pumpAndSettle();
    expect(find.text('One message a day'), findsOneWidget);
    await tap(tester, 'Next');
    await tap(tester, 'Next');
    expect(find.text('Your streak stays alive'), findsOneWidget);
    await capture(tester, 'onboarding');
    await tap(tester, 'Begin');
    expect(find.text('Annual'), findsOneWidget);
    expect(find.text(AppConstants.annualStart), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Annual'), findsOneWidget);
    await capture(tester, 'paywall');
    await tap(tester, 'Monthly');
    expect(find.text(AppConstants.monthlyStart), findsOneWidget);
    await tap(tester, 'Annual');
    await tap(tester, AppConstants.annualStart);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('1 day streak'), findsOneWidget);
    await capture(tester, 'today');
    await tap(tester, lessons.first.title);
    expect(find.text(lessons.first.verseText), findsOneWidget);
    await capture(tester, 'lesson');
    await tap(tester, "Complete today's message");
    expect(find.text(lessons[1].title), findsOneWidget);
    await tap(tester, 'Journey');
    expect(
        find.text('1 of ${lessons.length} messages complete'), findsOneWidget);
    await capture(tester, 'journey');
    await tap(tester, lessons.first.title);
    expect(find.text('Completed'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
        find.text('1 of ${lessons.length} messages complete'), findsOneWidget);
    await tap(tester, 'Profile');
    expect(find.text('Premium'), findsOneWidget);
    await capture(tester, 'profile');
    await start(tester, MemoryStore(store.values));
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text(lessons[1].title), findsOneWidget);
    expect(find.text('1 day streak'), findsOneWidget);
  });

  testWidgets(
      'all complete is honest and Home independently rejects locked state',
      (tester) async {
    final store = MemoryStore({
      'progress_onboarding_complete': true,
      'paywall_lifetime_unlocked': true,
      'progress_completed_days': [
        for (final lesson in lessons) '${lesson.day}'
      ],
    });
    await start(tester, store);
    expect(find.textContaining('All available messages are complete'),
        findsOneWidget);
    await tap(tester, 'Journey');
    expect(
        find.text('${lessons.length} of ${lessons.length} messages complete'),
        findsOneWidget);
    await tester.drag(
        find.byKey(const PageStorageKey('journey')), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(find.text('Days 11–365 are being written.'), findsOneWidget);
    await capture(tester, 'journey-complete');
    await start(tester, MemoryStore(), screen: const HomeShell());
    expect(find.text('Annual'), findsOneWidget);
    expect(find.text("Today's message"), findsNothing);
  });

  testWidgets(
      '320dp with 3x text: onboarding, paywall, home tabs and every lesson fit',
      (tester) async {
    final store = MemoryStore();
    await start(tester, store, width: 320, scale: 3);
    await tap(tester, 'Get Started');
    await tap(tester, 'Next');
    await tap(tester, 'Next');
    await tap(tester, 'Begin');
    await tap(tester, AppConstants.annualStart);
    await capture(tester, 'small-large-text-today');
    await tap(tester, 'Profile');
    await tap(tester, 'Journey');
    expect(tester.takeException(), isNull);
    for (final lesson in lessons) {
      await start(tester, MemoryStore(),
          width: 320, scale: 3, screen: LessonScreen(lesson: lesson));
      await tester.ensureVisible(find.text("Complete today's message"));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Lesson ${lesson.day}');
    }
    await capture(tester, 'small-large-text-lesson');
  });

  testWidgets('resume and tab changes refresh midnight without counting twice',
      (tester) async {
    var now = DateTime(2026, 10, 29, 23, 59);
    final store = MemoryStore({
      'progress_onboarding_complete': true,
      'paywall_lifetime_unlocked': true,
    });
    await tester.pumpWidget(ProviderScope(overrides: [
      localStoreProvider.overrideWithValue(store),
      localClockProvider.overrideWithValue(() => now),
    ], child: const HolyHerApp()));
    await tester.pumpAndSettle();
    now = DateTime(2026, 10, 30, 0, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('2 day streak'), findsOneWidget);
    await tap(tester, 'Profile');
    expect(find.text('2 days'), findsNWidgets(2));
    await tap(tester, 'Today');
    expect(find.text('2 day streak'), findsOneWidget);
  });

  testWidgets('rapid landing taps push one onboarding route', (tester) async {
    await start(tester, MemoryStore());
    await tester.tap(find.text('Get Started'));
    await tester.tap(find.text('Get Started'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('HOLYHER'), findsOneWidget);
  });
}
