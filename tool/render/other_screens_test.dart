// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renders the screens outside the home tabs for review: welcome, onboarding,
// offer, lesson. Run: flutter test tool/render/other_screens_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/domain/onboarding_flow.dart';
import 'package:holyhim/features/lesson/lesson_screen.dart';
import 'package:holyhim/features/onboarding/onboarding_screen.dart';
import 'package:holyhim/features/paywall/paywall_screen.dart';
import 'package:holyhim/features/welcome/welcome_screen.dart';
import 'package:holyhim/services/billing.dart';
import 'package:holyhim/services/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'fixtures.dart';
import 'harness.dart';

const out = 'build/render/other';

Map<String, dynamic> _draft(String stepId) => {
      'flowVersion': onboardingFlowVersion,
      'stepId': stepId,
      'lifeSeason': 'full',
      'familiarity': 'returning',
      'obstacle': 'busy',
      'reminder': '07:00',
    };

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    SharedPreferences.setMockInitialValues({});
    HolySounds.player = (String _, {double gain = 1}) async {};
    await loadFonts();
  });

  Future<void> shot(WidgetTester tester, String id, Widget screen, WalkState walk,
      {bool owned = false}) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    await capture(tester, '$out/$id.png', screen,
        phone: Phone.max,
        pixelRatio: 2,
        wrap: (app) => scope(app,
            walk: walk,
            user: id == 'welcome' ? null : null,
            billing: LifetimeState(loading: false, purchased: owned, product: product)));
    final error = tester.takeException();
    if (error != null) debugPrint('!! $id: $error');
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets('other screens', (tester) async {
    await shot(tester, 'welcome', const WelcomeScreen(),
        WalkState(profile: profile(onboarded: false)));
    for (final step in ['heart', 'season', 'reminder', 'letter']) {
      await shot(tester, 'onboarding-$step', const OnboardingScreen(),
          WalkState(profile: profile(draft: _draft(step), onboarded: step == 'letter')));
    }
    await shot(tester, 'offer', OfferScreen(onboarding: true, onContinue: () {}),
        WalkState(profile: profile(), completed: history(0)));
    await shot(tester, 'lesson', const LessonScreen(day: 3),
        WalkState(profile: profile(), completed: history(2)), owned: true);
  });
}
