// Every composed screen fits one viewport from iPhone SE to the largest
// Pro Max at normal text size, and never overflows at 130% text. With the
// keyboard up, the focused field and the primary button stay above it.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:holyhim/design/design.dart';
import 'package:holyhim/domain/onboarding_flow.dart';
import 'package:holyhim/features/auth/email_screen.dart';
import 'package:holyhim/features/celebration/celebration_screen.dart';
import 'package:holyhim/features/journey/journey_screen.dart';
import 'package:holyhim/features/lesson/lesson_screen.dart';
import 'package:holyhim/features/onboarding/onboarding_screen.dart';
import 'package:holyhim/features/paywall/paywall_screen.dart';
import 'package:holyhim/features/profile/profile_screen.dart';
import 'package:holyhim/features/profile/theme_screen.dart';
import 'package:holyhim/features/shell/home_shell.dart';
import 'package:holyhim/features/saved/saved_screen.dart';
import 'package:holyhim/features/support/support_screen.dart';
import 'package:holyhim/features/welcome/welcome_screen.dart';
import 'package:holyhim/services/repository.dart';
import '../tool/render/fixtures.dart';
import '../tool/render/harness.dart' show loadFonts;

const sizes = [Size(375, 667), Size(393, 852), Size(430, 932), Size(440, 956)];

Map<String, dynamic> _draft(String stepId) => {
      'flowVersion': onboardingFlowVersion,
      'stepId': stepId,
      'lifeSeason': 'full',
      'familiarity': 'returning',
      'obstacle': 'busy',
      'reminder': '07:00',
    };

WalkState _walk({Map<String, dynamic> draft = const {}, bool onboarded = true}) =>
    WalkState(
        profile: profile(draft: draft, onboarded: onboarded),
        completed: history(2),
        saved: {1: DateTime(2026, 11, 3)});

final screens = <String, (Widget, WalkState)>{
  'welcome': (const WelcomeScreen(), _walk()),
  'email': (const EmailScreen(), _walk()),
  for (final step in ['heart', 'season', 'familiarity', 'obstacle', 'reminder',
      'birthday', 'letter'])
    'onboarding-$step': (
      const OnboardingScreen(),
      _walk(draft: _draft(step), onboarded: step == 'letter')
    ),
  'offer': (OfferScreen(onboarding: true, onContinue: () {}), _walk()),
  'offer-locked': (const OfferScreen(lockedDay: 8), _walk()),
  'walk': (const HomeShell(), _walk()),
  'brothers': (const HomeShell(initialTab: 1), _walk()),
  'ranks': (const HomeShell(initialTab: 2), _walk()),
  'growth': (const HomeShell(initialTab: 3), _walk()),
  'profile': (const HomeShell(initialTab: 4), _walk()),
  'saved': (const SavedScreen(standalone: true), _walk()),
  'journey': (const JourneyScreen(), _walk()),
  'lesson': (const LessonScreen(day: 3), _walk()),
  'celebration': (const CelebrationScreen(day: 2), _walk()),
  'reminders': (const RemindersScreen(), _walk()),
  'reading': (const ReadingScreen(), _walk()),
  'account': (const AccountScreen(), _walk()),
  'support': (const SupportScreen(), _walk()),
  'theme': (const ThemeScreen(), _walk()),
};

Future<void> _pump(WidgetTester tester, Widget screen, WalkState walk,
    {required Size size, double scale = 1, double keyboard = 0}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  final top = size.height < 700 ? 20.0 : 59.0;
  final bottom = size.height < 700 ? 0.0 : 34.0;
  await tester.pumpWidget(scope(
      MaterialApp(
          theme: HolyThemeData.build(HolyThemes.blush),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  padding: EdgeInsets.only(top: top, bottom: bottom),
                  viewPadding: EdgeInsets.only(top: top, bottom: bottom),
                  viewInsets: EdgeInsets.only(bottom: keyboard),
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true),
              child: HolyThemeScope(theme: HolyThemes.blush, child: child!)),
          home: screen),
      walk: walk));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(() async {
    await loadFonts();
    tz.initializeTimeZones();
    HolySounds.player = (String _, {double gain = 1}) async {};
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  for (final entry in screens.entries) {
    testWidgets('${entry.key} fits one viewport and never overflows',
        (tester) async {
      addTearDown(tester.view.reset);
      for (final size in sizes) {
        for (final scale in [1.0, 1.3]) {
          await _pump(tester, entry.value.$1, entry.value.$2,
              size: size, scale: scale);
          expect(tester.takeException(), isNull,
              reason: '${entry.key} at ${size.width}x${size.height} ×$scale');
          if (scale == 1) {
            for (final fit in find.byType(FitColumn).evaluate()) {
              final scrollable = find
                  .descendant(
                      of: find.byWidget(fit.widget),
                      matching: find.byType(Scrollable))
                  .first;
              final position =
                  tester.state<ScrollableState>(scrollable).position;
              expect(position.maxScrollExtent, lessThanOrEqualTo(.5),
                  reason:
                      '${entry.key} scrolls at ${size.width}x${size.height}');
            }
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    });
  }

  testWidgets('email keeps the password field and Sign in above the keyboard',
      (tester) async {
    addTearDown(tester.view.reset);
    for (final size in sizes) {
      final keyboard = size.height < 700 ? 260.0 : 336.0;
      await _pump(tester, const EmailScreen(), _walk(),
          size: size, keyboard: keyboard);
      final limit = size.height - keyboard;
      final button = tester.getRect(find.text('Sign in').last);
      final field = tester.getRect(find.text('Password'));
      expect(button.bottom, lessThanOrEqualTo(limit), reason: '$size');
      expect(field.bottom, lessThan(button.top), reason: '$size');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('the first-name step keeps its field and button above the keyboard',
      (tester) async {
    addTearDown(tester.view.reset);
    for (final size in sizes) {
      final keyboard = size.height < 700 ? 260.0 : 336.0;
      await _pump(
          tester,
          const OnboardingScreen(),
          WalkState(profile: profile(name: '', onboarded: false)),
          size: size,
          keyboard: keyboard);
      final limit = size.height - keyboard;
      expect(tester.getRect(find.text('Continue')).bottom,
          lessThanOrEqualTo(limit),
          reason: '$size');
      expect(tester.getRect(find.byType(TextField)).bottom,
          lessThan(tester.getRect(find.text('Continue')).top));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
