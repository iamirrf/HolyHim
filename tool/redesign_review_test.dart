// ignore_for_file: invalid_use_of_visible_for_testing_member
// Raster layout review only. This does not replace wireless iPhone verification.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:holyhim/features/shell/home_shell.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/services/repository.dart';
import 'package:holyhim/domain/calendar.dart';
import 'package:holyhim/services/auth_service.dart';
import 'package:holyhim/services/billing.dart';
import 'package:holyhim/domain/onboarding_flow.dart';
import 'package:holyhim/features/welcome/welcome_screen.dart';
import 'package:holyhim/features/auth/email_sheet.dart';
import 'package:holyhim/features/onboarding/onboarding_screen.dart';
import 'package:holyhim/features/lesson/lesson_screen.dart';
import 'package:holyhim/features/celebration/celebration_screen.dart';
import 'package:holyhim/features/saved/saved_screen.dart';
import 'package:holyhim/features/growth/growth_screen.dart';
import 'package:holyhim/features/profile/profile_screen.dart';
import 'package:holyhim/features/profile/theme_screen.dart';
import 'package:holyhim/features/profile/edit_profile_screen.dart';
import 'package:holyhim/features/paywall/paywall_screen.dart';
import 'package:holyhim/features/support/support_screen.dart';
import 'package:holyhim/features/common.dart';
import 'package:timezone/data/latest.dart' as tz;

class ReviewBundle extends CachingAssetBundle {
  late final manifest = const StandardMessageCodec().encodeMessage({
    for (final file
        in Directory('assets/art').listSync(recursive: true).whereType<File>())
      file.path: [
        {'asset': file.path, 'dpr': 1.0}
      ]
  })!;
  @override
  Future<ByteData> load(String key) {
    if (key == 'AssetManifest.bin') return SynchronousFuture(manifest);
    final file = File(key);
    return file.existsSync()
        ? SynchronousFuture(ByteData.sublistView(file.readAsBytesSync()))
        : rootBundle.load(key);
  }
}

final reviewBundle = ReviewBundle();

class ReviewAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
      user: AuthUser(uid: 'layout-review', email: 'mira@example.test'));
}

class ReviewRepository extends WalkRepository {
  final AppProfile profile;
  final bool empty, completedToday;
  ReviewRepository(this.profile,
      {this.empty = false, this.completedToday = false});
  @override
  WalkState build() => WalkState(
      profile: profile,
      completed: empty
          ? {}
          : completedToday
              ? {1: dateKey(localNow(DateTime.now(), 'America/New_York'))}
              : {for (var d = 1; d <= 14; d++) d: '2026-10-${d + 10}'},
      saved:
          empty ? {} : {1: DateTime(2026, 10, 11), 3: DateTime(2026, 10, 13)});
  @override
  void updateProfile(AppProfile value) =>
      state = state.copyWith(profile: value);
  @override
  void finishOnboarding([AppProfile? value]) => updateProfile(
      (value ?? state.profile).copyWith(onboardedAt: DateTime(2026, 11, 4)));
}

class ReviewBilling extends LifetimeController {
  @override
  LifetimeState build() => const LifetimeState(
      loading: false,
      error:
          'The lifetime purchase is unavailable right now. Try again shortly.');
}

class ReviewHome extends StatefulWidget {
  const ReviewHome({super.key});
  @override
  State<ReviewHome> createState() => _ReviewHomeState();
}

class _ReviewHomeState extends State<ReviewHome> {
  late final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeShell())
  ]);
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 59, bottom: 34),
              disableAnimations: true),
          child: child!));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    tz.initializeTimeZones();
    await HolyArtAssets.contains(
        reviewBundle, 'assets/art/library/cross-hill.webp');
    HolySounds.player = (String _, {double gain = 1}) async {};
    final icons = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(rootBundle
          .load('packages/cupertino_icons/assets/CupertinoIcons.ttf'));
    await icons.load();
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    for (final font in [
      'DancingScript',
      'Manrope',
      'PlayfairDisplay',
      'Lora',
      'PinyonScript'
    ]) {
      final loader = FontLoader(font)
        ..addFont(rootBundle.load(font == 'Manrope'
            ? 'assets/fonts/Manrope[wght].ttf'
            : 'assets/fonts/$font.ttf'));
      await loader.load();
    }
  });
  testWidgets('capture all adapted screen layouts', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final output = Directory('store/launch-redesign/screens')
      ..createSync(recursive: true);
    Future<void> capture(String id, Widget screen,
        {int? step,
        bool guideUnanswered = false,
        bool empty = false,
        Future<void> Function()? action}) async {
      debugPrint('Capturing $id');
      final profile = AppProfile(
          name: 'Mira',
          username: 'Mira Rose',
          haptics: false,
          sounds: false,
          timeZone: 'America/New_York',
          birthday: '1998-05-16',
          hearts: step != null && step >= 6 ? const ['Peace'] : const [],
          onboardedAt: step == null ? DateTime(2026, 11, 4) : null,
          onboardingDraft: {
            'step': step ?? 0,
            'stepId': onboardingStepIds[step ?? 0],
            'flowVersion': onboardingFlowVersion,
            'firstName': 'Mira',
            'lastName': 'Rose',
            'lifeSeason': 'A time of change',
            'faithRoutine': 'I’m returning after some time',
            if (!guideUnanswered || step != 4) 'obstacle': 'My days are full',
            if (!guideUnanswered || step != 6) ...{
              'pace': 'One minute',
              'reminder': 'No reminders',
            },
            'termsAccepted': true,
          });
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith(ReviewAuth.new),
        repositoryProvider.overrideWith(() => ReviewRepository(profile,
            empty: empty, completedToday: id == 'completion')),
        lifetimeProvider.overrideWith(ReviewBilling.new)
      ]);
      if (id == 'completion') {
        container.read(completionMomentProvider.notifier).state =
            completionMomentBetween(
                day: 1,
                before: WalkState(profile: profile),
                after: container.read(repositoryProvider),
                now: DateTime.now());
      }
      final key = GlobalKey();
      await tester.pumpWidget(DefaultAssetBundle(
          bundle: reviewBundle,
          child: UncontrolledProviderScope(
              container: container,
              child: RepaintBoundary(
                  key: key,
                  child: MaterialApp(
                      debugShowCheckedModeBanner: false,
                      theme: HolyThemeData.build(HolyThemes.charcoal),
                      builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                              padding:
                                  const EdgeInsets.only(top: 59, bottom: 34),
                              disableAnimations: true),
                          child: Atmosphere(
                              theme: HolyThemes.charcoal, child: child!)),
                      home: screen)))));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      if (action != null) {
        await action();
        await tester.pump();
      }
      for (var frame = 0; frame < 3; frame++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        });
        await tester.pump();
      }
      expect(tester.takeException(), isNull, reason: id);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final bitmap = await boundary.toImage(pixelRatio: 2);
        final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
        bitmap.dispose();
        await File('${output.path}/$id.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      container.dispose();
    }

    await capture('welcome', const WelcomeScreen());

    await capture('email-signin', const EmailSheet());
    await capture('email-signup', const EmailSheet(), action: () async {
      await tester.tap(find.text('Sign up'));
      await tester.pump();
    });
    for (var step = 0; step <= 9; step++) {
      await capture('onboarding-${step + 1}', const OnboardingScreen(),
          step: step);
    }
    await capture('onboarding-5-choices', const OnboardingScreen(),
        step: 4, guideUnanswered: true);
    await capture('onboarding-7-choices', const OnboardingScreen(),
        step: 6, guideUnanswered: true);
    await capture('paywall-unavailable', const PaywallScreen());
    await capture('scripture', const LessonScreen(day: 1));
    for (var card = 1; card <= 3; card++) {
      await capture(['scripture', 'meaning', 'reflection', 'prayer'][card],
          const LessonScreen(day: 1), action: () async {
        for (var i = 0; i < card; i++) {
          await tester.tap(find.byTooltip('Next card'));
          await tester.pump();
        }
      });
    }
    await capture('completion', const CelebrationScreen(day: 1));
    await capture('saved', const SavedScreen());
    await capture('saved-empty', const SavedScreen(), empty: true);
    await capture('growth', const GrowthScreen());
    await capture('growth-empty', const GrowthScreen(), empty: true);
    await capture('walk', const ReviewHome());
    await capture('walk-journey', const ReviewHome(), action: () async {
      await tester.drag(
          find.byType(CustomScrollView).first, const Offset(0, -1150));
      await tester.pump(const Duration(milliseconds: 700));
    });
    await capture('profile', const ProfileScreen());
    await capture('edit-profile', const EditProfileScreen());
    await capture('themes', const ThemeScreen());
    await capture('support', const SupportScreen());
    await capture('privacy', const LegalScreen(document: 'privacy'));
  });
}
