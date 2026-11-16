// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renders every composed screen and state to build/render/screens.
// Run: flutter test tool/render/screens_test.dart [--plain-name <id>]
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/domain/onboarding_flow.dart';
import 'package:holyhim/features/auth/email_screen.dart';
import 'package:holyhim/features/celebration/celebration_screen.dart';
import 'package:holyhim/features/lesson/lesson_screen.dart';
import 'package:holyhim/features/onboarding/onboarding_screen.dart';
import 'package:holyhim/features/paywall/paywall_screen.dart';
import 'package:holyhim/features/shell/home_shell.dart';
import 'package:holyhim/features/welcome/welcome_screen.dart';
import 'package:holyhim/features/growth/growth_screen.dart';
import 'package:holyhim/features/profile/profile_screen.dart';
import 'package:holyhim/features/profile/app_icon_screen.dart';
import 'package:holyhim/data/lessons.g.dart';
import 'package:holyhim/features/share/share_sheet.dart';
import 'package:holyhim/services/share_card.dart';
import 'package:holyhim/features/profile/theme_screen.dart';
import 'package:holyhim/features/saved/saved_screen.dart';
import 'package:holyhim/features/support/support_screen.dart';
import 'package:holyhim/services/app_router.dart';
import 'package:holyhim/services/billing.dart';
import 'package:holyhim/services/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'fixtures.dart';
import 'harness.dart';

const out = 'build/render/screens';

/// A draft resting on [stepId] with every earlier answer given. [open]
/// leaves that step's own question unanswered.
Map<String, dynamic> draftAt(String stepId, {bool open = false}) {
  final at = onboardingStepIds.indexOf(stepId);
  bool has(String id) {
    final index = onboardingStepIds.indexOf(id);
    return open ? at > index : at >= index;
  }

  return {
    'flowVersion': onboardingFlowVersion,
    'stepId': stepId,
    'step': at,
    if (has('season')) 'lifeSeason': 'full',
    if (has('familiarity')) ...{'familiarity': 'returning', 'obstacle': 'busy'},
    if (has('reminder')) 'reminder': '07:00',
  };
}

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    SharedPreferences.setMockInitialValues({});
    HolySounds.player = (String _, {double gain = 1}) async {};
    OnboardingScreen.resumeToast = false;
    await loadFonts(emoji: true);
  });

  Future<void> shot(WidgetTester tester, String id, Widget screen,
      {WalkState? walk,
      AccessState? billing,
      Phone phone = Phone.pro,
      HolyTheme theme = HolyThemes.blush,
      double textScale = 1,
      double keyboard = 0,
      Future<void> Function()? action}) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    await capture(tester, '$out/$id-${phone.id}.png', screen,
        phone: phone,
        theme: theme,
        textScale: textScale,
        keyboard: keyboard,
        pixelRatio: 1.5,
        action: action,
        wrap: (app) => scope(app, walk: walk, billing: billing ?? offerState));
    final error = tester.takeException();
    if (error != null) debugPrint('!! $id-${phone.id}: $error');
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  }

  final phones = [Phone.se, Phone.pro];

  testWidgets('welcome and email', (tester) async {
    for (final p in phones) {
      await shot(
          tester, 'welcome', WelcomeScreen(now: DateTime(2026, 11, 14, 9)),
          phone: p);
      await shot(tester, 'welcome-night',
          WelcomeScreen(now: DateTime(2026, 11, 14, 22)),
          phone: p);
      await shot(tester, 'email', const EmailScreen(), phone: p);
      await shot(tester, 'email-keyboard', const EmailScreen(),
          phone: p, keyboard: p == Phone.se ? 260 : 336);
    }
  });

  testWidgets('onboarding', (tester) async {
    const closing = {'building', 'letter', 'dailyRhythm', 'offer'};
    for (final p in phones) {
      for (final step in onboardingStepIds.where((id) => id != 'building')) {
        await shot(tester, 'onboarding-$step', const OnboardingScreen(),
            phone: p,
            walk: WalkState(
                profile: profile(
                    name: step == 'name' ? '' : 'Mira Rose',
                    onboarded: closing.contains(step),
                    hearts: step == 'heart' ? const ['peace'] : const ['peace'],
                    draft: draftAt(step, open: step == 'season'))));
      }
      // The two conversations with their replies on offer.
      for (final step in ['familiarity', 'reminder']) {
        await shot(tester, 'onboarding-$step-open', const OnboardingScreen(),
            phone: p,
            walk: WalkState(
                profile: profile(
                    onboarded: false,
                    hearts: const ['peace'],
                    draft: draftAt(step, open: true))));
      }
      await shot(tester, 'onboarding-name-keyboard', const OnboardingScreen(),
          phone: p,
          keyboard: p == Phone.se ? 260 : 336,
          walk: WalkState(
              profile:
                  profile(name: '', onboarded: false, draft: draftAt('name'))));
    }
  });

  testWidgets('offer', (tester) async {
    for (final p in phones) {
      await shot(tester, 'offer-gate', const OfferScreen(locked: true),
          phone: p);
      await shot(tester, 'offer-no-trial', const OfferScreen(locked: true),
          phone: p,
          billing: const AccessState(
              loading: false,
              trialPlan: trialPlan,
              plainPlan: plainPlan,
              trialEligible: false));
      await shot(tester, 'offer-welcomed', const OfferScreen(locked: true),
          phone: p, billing: memberState);
      await shot(tester, 'offer-unavailable', const OfferScreen(locked: true),
          phone: p,
          billing: const AccessState(
              loading: false,
              error:
                  'We could not connect to the App Store. Try again shortly.'));
    }
  });

  testWidgets('today and journey', (tester) async {
    for (final p in phones) {
      await shot(tester, 'today-begin', const HomeShell(),
          phone: p, walk: WalkState(profile: profile(), completed: history(2)));
      await shot(tester, 'today-done', const HomeShell(),
          phone: p,
          walk: WalkState(
              profile: profile(), completed: history(2, today: true)));
      await shot(tester, 'today-locked', const HomeShell(),
          phone: p, walk: WalkState(profile: profile(), completed: history(7)));
      await shot(tester, 'walk', const HomeShell(initialTab: 1),
          phone: p, walk: WalkState(profile: profile(), completed: history(2)));
    }
    await shot(tester, 'today-begin-dark', const HomeShell(),
        theme: HolyThemes.midnightRose,
        walk: WalkState(
            profile: profile(theme: 'midnight-rose'), completed: history(2)));
    await shot(tester, 'today-begin-large', const HomeShell(),
        textScale: 1.3,
        walk: WalkState(profile: profile(), completed: history(2)));
    // Themes reach the Walk's stones and path, not just the paper.
    await shot(tester, 'walk-sunrise', const HomeShell(initialTab: 1),
        theme: HolyThemes.sunrise,
        walk: WalkState(
            profile: profile(theme: 'sunrise'), completed: history(9)));
  });

  testWidgets('lesson, celebration, verse', (tester) async {
    for (final p in phones) {
      for (var card = 0; card < 4; card++) {
        await shot(tester, 'lesson-$card', const LessonScreen(day: 3),
            phone: p,
            walk: WalkState(profile: profile(), completed: history(2)),
            action: () async {
          for (var i = 0; i < card; i++) {
            await tester.tap(find.byTooltip('Next card'));
            await tester.pump(const Duration(milliseconds: 600));
          }
        });
      }
      await shot(tester, 'celebration', const CelebrationScreen(day: 3),
          phone: p,
          walk: WalkState(
              profile: profile(), completed: history(2, today: true)));
      await shot(tester, 'verse', const VerseScreen(day: 3), phone: p);
    }
  });

  testWidgets('saved, growth, profile', (tester) async {
    Widget tab(Widget child) => MediaQuery(
        data: const MediaQueryData(),
        child: Builder(
            builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    padding: MediaQuery.paddingOf(context).copyWith(
                        bottom: MediaQuery.paddingOf(context).bottom + 84)),
                child: Scaffold(body: child))));
    final saved = WalkState(
        profile: profile(),
        completed: history(9),
        saved: {1: DateTime(2026, 11, 3), 3: DateTime(2026, 11, 5)});
    for (final p in phones) {
      await shot(tester, 'saved', tab(const SavedScreen()),
          phone: p, walk: saved);
      await shot(tester, 'saved-empty', tab(const SavedScreen()),
          phone: p, walk: WalkState(profile: profile()));
      await shot(tester, 'growth', tab(const GrowthScreen()),
          phone: p, walk: saved);
      await shot(tester, 'profile', tab(const ProfileScreen()),
          phone: p, walk: saved);
      await shot(tester, 'profile-owned', tab(const ProfileScreen()),
          phone: p,
          walk: saved,
          billing: const AccessState(loading: false, purchased: true));
    }
    await shot(tester, 'settings-reminders', const RemindersScreen(),
        walk: saved);
    await shot(tester, 'settings-theme', const ThemeScreen(), walk: saved);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('holyhim/app-icon'),
        (call) async => switch (call.method) {
              'supported' => true,
              'current' => 'AppIcon-Lily',
              _ => null,
            });
    await shot(tester, 'settings-app-icon', const AppIconScreen(), walk: saved);
    await shot(tester, 'settings-reading', const ReadingScreen(), walk: saved);
    await shot(tester, 'settings-account', const AccountScreen(), walk: saved);
    await shot(tester, 'support', const SupportScreen(), walk: saved);
    // The share sheet in each look; the preview is the picture that is sent.
    Widget sheet(KeepsakeLook look, KeepsakeStyle style) => Scaffold(
        backgroundColor: const Color(0xFF6B5A60),
        body: Align(
            alignment: Alignment.bottomCenter,
            child: ShareSheet(
                lesson: lessons[2], initialLook: look, initialStyle: style)));
    await shot(
        tester, 'share-photo', sheet(KeepsakeLook.photo, KeepsakeStyle.story),
        walk: saved);
    await shot(
        tester, 'share-paper', sheet(KeepsakeLook.paper, KeepsakeStyle.story),
        walk: saved);
    await shot(tester, 'share-night-post',
        sheet(KeepsakeLook.night, KeepsakeStyle.square),
        walk: saved);
    await shot(tester, 'growth-dark', tab(const GrowthScreen()),
        theme: HolyThemes.starlight, walk: saved);
    await shot(tester, 'profile-lavender', tab(const ProfileScreen()),
        theme: HolyThemes.lavender,
        walk: WalkState(
            profile: profile(theme: 'lavender'),
            completed: history(9),
            saved: saved.saved));
  });
}
