import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/data/teaching.dart';
import 'package:holyher/dev/design_studies.dart';
import 'package:holyher/features/auth/auth_screen.dart';
import 'package:holyher/features/home/home_shell.dart';
import 'package:holyher/features/home/progress_calendar.dart';
import 'package:holyher/features/home/saved_tab.dart';
import 'package:holyher/features/landing/landing_screen.dart';
import 'package:holyher/features/lesson/lesson_screen.dart';
import 'package:holyher/features/onboarding/checkpoint.dart';
import 'package:holyher/features/onboarding/onboarding_screen.dart';
import 'package:holyher/features/settings/settings_screen.dart';
import 'package:holyher/features/settings/profile_editors.dart';
import 'package:holyher/features/settings/data_screens.dart';
import 'package:holyher/features/splash/splash_screen.dart';
import 'package:holyher/features/support/support_screens.dart';
import 'package:holyher/features/support/contact_screen.dart';
import 'package:holyher/models/learning.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/accessibility_service.dart';
import 'package:holyher/services/learning_service.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/profile_service.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/reminder_service.dart';
import 'package:holyher/services/streak_service.dart';

/// Standalone, local-only QA fixtures. This entry point never initializes
/// Firebase and never reads a real account or its on-device database.
class PreviewFixture {
  final String route;
  final String theme;
  PreviewFixture(this.route, {this.theme = 'pearl'});
  final store = PreviewStore();
  UserProfile get profile => UserProfile(
      name: 'Amira',
      theme: theme,
      familiarity: 'new',
      focus: 'peace',
      obstacle: 'busy',
      sounds: false,
      haptics: false,
      loaded: true,
      onboardingComplete: !route.startsWith('onboarding'),
      onboardingStep: route.startsWith('onboarding:')
          ? OnboardingStages.ids.indexOf(route.split(':')[1])
          : 0,
      onboardingAnswered: const {
        'name',
        'moment',
        'starting-point',
        'barrier',
        'focus'
      },
      suggestedReminderMinutes: 480,
      reminderDecision: route.contains('denied')
          ? 'denied'
          : route.startsWith('onboarding:reminder')
              ? 'pending'
              : 'declined',
      guidedExampleAnswer: route.contains('answered') ? 'day-001-q1-b' : null);
  List<Override> get overrides => [
        authProvider.overrideWith(() => _Auth(route)),
        profileProvider.overrideWith(() =>
            _Profile(profile, failSave: route == 'onboarding:save:failure')),
        progressProvider.overrideWith(() => _Progress(route)),
        streakProvider.overrideWith(() => _Streak(route)),
        localStoreProvider.overrideWithValue(store),
        learningGatewayProvider.overrideWithValue(null),
        journeyGatewayProvider.overrideWithValue(null),
        reminderEnabledProvider.overrideWith((ref) async => false),
        localClockProvider
            .overrideWithValue(() => DateTime.utc(2026, 11, 1, 17)),
        reduceTransparencyProvider
            .overrideWith(() => _Transparency(route.contains('opaque'))),
      ];
  Widget build() {
    if (route.startsWith('contact:')) {
      return ContactScreen(submit: (email, message, feedback) async {
        await Future<void>.delayed(
            Duration(milliseconds: route.endsWith('sending') ? 10000 : 350));
        if (route.endsWith('network')) {
          throw StateError(
              'Your message has not been sent. Check your connection and retry.');
        }
        if (route.endsWith('rate')) {
          throw StateError(
              'Please wait a little before sending another message.');
        }
      });
    }
    if (route == 'learn:late') {
      store.values['card_position_fixture_148'] = 2;
    }
    if (route == 'learn:resume') {
      final t = teachingCatalog[1]!;
      store.values['lesson_resume_1'] = jsonEncode(LessonResume(
              stepId: 'understand',
              attempt:
                  LearningAttempt.create(1, 1, teachingVersion, t.questions))
          .toJson());
    }
    if (route == 'long:verse') {
      return LessonScreen(
          lesson: lessons.reduce(
              (a, b) => a.verseText.length > b.verseText.length ? a : b));
    }
    if (route == 'motion:welcome') return const LandingScreen();
    if (route == 'motion:tabs') return const HomeShell();
    if (route == 'motion:onboarding') {
      return const OnboardingScreen(initialStage: 'name');
    }
    if (route == 'motion:lesson') return LessonScreen(lesson: lessons.first);
    if (route == 'recovery') {
      return HolyRecovery(
          message:
              'Your saved journey could not be loaded. Check your connection, then retry.',
          onRetry: () {},
          onSignOut: () {});
    }
    if (route.startsWith('welcome')) return const LandingScreen();
    if (route == 'auth:email-loading') return const AuthScreen();
    if (route == 'auth:create-loading') {
      return const AuthScreen(initialCreateAccount: true);
    }
    if (route == 'auth:create-error') {
      return const AuthScreen(initialCreateAccount: true);
    }
    if (route == 'lesson:resume-failure') {
      store.values['lesson_resume_1'] = 'corrupt fixture';
      return LessonScreen(lesson: lessons.first);
    }
    if (RegExp(r'^[ABC]-').hasMatch(route)) {
      return DesignStudy(treatment: route[0], screen: route.substring(2));
    }
    if (route.startsWith('onboarding:')) {
      return OnboardingScreen(initialStage: route.split(':')[1]);
    }
    if (route.startsWith('reading:')) {
      const kinds = ['scripture', 'meaning', 'encouragement', 'hope', 'prayer'];
      final part = route.split(':')[1];
      final index = part == 'complete' ? 4 : kinds.indexOf(part).clamp(0, 4);
      store.values['reading_checkpoint_1'] = jsonEncode({
        'version': 'walk-v1',
        'day': 1,
        'journeyRevision': 1,
        'sessionId': 'isolated-reading-preview',
        'checkpointId': 'isolated-reading-place',
        'cardIndex': index,
        'visited': List.generate(index + 1, (i) => i),
        'cloudRevision': 0,
        'dirty': true,
      });
      if (part == 'error') store.failWrites = true;
      return LessonScreen(lesson: lessons.first);
    }
    if (route.startsWith('lesson:')) {
      final step = semanticSteps.indexOf(route.split(':')[1]).clamp(0, 8),
          teaching = teachingCatalog[1]!;
      var attempt =
          LearningAttempt.create(1, 1, teachingVersion, teaching.questions);
      for (var i = 0; i < 2; i++) {
        if (step > (i == 0 ? 3 : 6) ||
            route.contains('answered') ||
            route.contains('correct') ||
            route.contains('wrong')) {
          final q = teaching.questions[i];
          attempt = attempt.answer(
              q.id,
              route.contains('wrong')
                  ? q.options.firstWhere((o) => o.id != q.correctOptionId).id
                  : q.correctOptionId);
        }
      }
      store.values['lesson_resume_1'] = jsonEncode(
          LessonResume(stepId: semanticSteps[step], attempt: attempt).toJson());
      if (route.contains('failure')) store.failWrites = true;
      return LessonScreen(lesson: lessons.first);
    }
    if (route.startsWith('existing:')) {
      final i = ['verse', 'confidence', 'reason', 'hope', 'carry']
          .indexOf(route.split(':')[1]);
      store.values['card_position_fixture_6'] = i;
      return LessonScreen(lesson: lessons[5]);
    }
    if (route.startsWith('saved:populated') ||
        route == 'saved:detail' ||
        route == 'saved:search-empty' ||
        route == 'saved:removed' ||
        route == 'saved:undo' ||
        route == 'saved:undo-failure') {
      store.values['saved_lessons'] = jsonEncode({
        'schemaVersion': 2,
        'days': {'1': 1793500000000, '3': 1793500100000, '5': 1793500200000},
        'pending': {},
        'operationIds': {}
      });
    }
    if (route == 'saved:error') {
      store.values['saved_lessons'] = 'unreadable fixture';
    }
    switch (route) {
      case 'welcome':
      case 'welcome:0':
      case 'welcome:1':
      case 'welcome:2':
        return const LandingScreen();
      case 'auth:create':
        return const AuthScreen(initialCreateAccount: true);
      case 'auth':
      case 'auth:error':
      case 'auth:invalid':
      case 'auth:visible':
      case 'auth:keyboard':
        return const AuthScreen();
      case 'reset:sent':
      case 'reset':
        return const PasswordResetScreen(initialEmail: 'reader@example.com');
      case 'learn:late':
      case 'learn:resume':
      case 'learn:search':
      case 'learn:search-empty':
      case 'learn:list':
      case 'learn:unit':
      case 'learn:future':
      case 'learn':
      case 'learn:caught-up':
      case 'learn:complete':
        return const HomeShell();
      case 'saved:removed':
      case 'saved:undo-failure':
      case 'saved:undo':
      case 'saved:search-empty':
      case 'saved:empty':
      case 'saved:populated':
      case 'saved:error':
        return const HomeShell(initialTab: 1);
      case 'saved:detail':
        return _SheetFixture(
            open: (context) => showSavedVerseDetail(context, lessons.first));
      case 'profile':
        return const HomeShell(initialTab: 2);
      case 'calendar':
        return const ProgressCalendar();
      case 'settings':
        return const SettingsScreen();
      case 'name':
        return const NameEditorScreen();
      case 'rhythm':
        return const RhythmScreen();
      case 'reminder':
        return const ReminderSettingsScreen();
      case 'export':
        return const ExportDataScreen();
      case 'password':
        return const ChangePasswordScreen();
      case 'reset-progress':
        return const ResetProgressScreen();
      case 'help':
        return const HelpScreen();
      case 'about':
        return const AboutScreen();
      case 'privacy':
        return const PrivacyScreen();
      case 'terms':
        return const TermsScreen();
      case 'contact':
        return const ContactScreen();
      case 'feedback':
        return const ContactScreen(feedback: true);
      case 'splash':
        return const SplashScreen();
      case 'font':
        return const HolyScaffold(
            body: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('A moment with God.\nHolyHer 0123456789',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w400)),
                      SizedBox(height: 32),
                      Text('A moment with God.\nHolyHer 0123456789',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w600))
                    ])));
      default:
        return const HomeShell();
    }
  }
}

class PreviewStore implements LocalStore {
  final values = <String, Object>{};
  bool failWrites = false;
  @override
  Future<Object?> read(String key) async => values[key];
  @override
  Future<bool> write(String key, Object value) async {
    if (failWrites) return false;
    values[key] = value;
    return true;
  }

  Future<void> clear() async => values.clear();
}

class _Auth extends AuthNotifier {
  final String route;
  _Auth(this.route);
  @override
  Future<void> resetPassword(String email) async {
    state = const AuthState();
  }

  @override
  AuthState build() => AuthState(
      user: route.startsWith('auth') ||
              route.startsWith('welcome') ||
              route == 'reset'
          ? null
          : const AuthUser(uid: 'fixture', email: 'amira@example.com'),
      loading: route.endsWith('loading'),
      action: route.contains('google-loading')
          ? AuthAction.google
          : route.contains('apple-loading')
              ? AuthAction.apple
              : route == 'auth:email-loading'
                  ? AuthAction.email
                  : route == 'auth:create-loading'
                      ? AuthAction.createAccount
                      : null,
      error: route == 'auth:error'
          ? 'You appear to be offline. Please reconnect and try again.'
          : route == 'auth:create-error'
              ? 'There is already an account with this email. Try signing in.'
              : null);
}

class _Profile extends ProfileNotifier {
  final UserProfile initial;
  final bool failSave;
  _Profile(this.initial, {this.failSave = false});
  @override
  UserProfile build() => initial;
  @override
  Future<void> save(UserProfile value) async {
    if (failSave) throw StateError('Local fixture account save failure');
    state = value;
  }

  @override
  Future<void> saveDraft(UserProfile value) async {
    state = value;
  }

  @override
  Future<void> flushDraft() async {}
}

class _Progress extends ProgressNotifier {
  final String route;
  _Progress(this.route);
  @override
  ProgressState build() => ProgressState(
          journeyStarted: true,
          unlockedThrough: route == 'learn:complete' || route == 'long:verse'
              ? 365
              : route == 'learn:late'
                  ? 148
                  : 8,
          earnedBadges: route == 'learn:complete'
              ? {1, 7, 30, 90, 180, 365}
              : route == 'learn:late'
                  ? {1, 7, 30, 90}
                  : route == 'calendar' || route == 'learn:caught-up'
                      ? {1, 7}
                      : route.startsWith('lesson:') ||
                              route.startsWith('reading:') ||
                              route == 'learn' ||
                              route == 'learn:resume' ||
                              route.startsWith('existing:')
                          ? {}
                          : {1},
          startDate: route == 'learn:late' ? '2026-06-07' : '2026-10-25',
          timeZone: 'America/New_York',
          completedDays: route == 'learn:late'
              ? Set.from(List.generate(147, (i) => i + 1))
              : route == 'learn:complete'
                  ? Set.from(List.generate(365, (i) => i + 1))
                  : route == 'learn:caught-up' || route == 'calendar'
                      ? {1, 2, 3, 4, 5, 6, 7, 8}
                      : route.startsWith('lesson:') ||
                              route.startsWith('reading:') ||
                              route == 'motion:lesson' ||
                              route.startsWith('existing:') ||
                              route == 'learn' ||
                              route == 'learn:resume'
                          ? {}
                          : {1, 2, 3},
          completionDates: {
            for (var i = 1;
                i <=
                    (route == 'calendar' || route == 'learn:caught-up'
                        ? 8
                        : route == 'learn' ||
                                route == 'learn:resume' ||
                                route.startsWith('lesson:') ||
                                route.startsWith('reading:') ||
                                route == 'motion:lesson' ||
                                route.startsWith('existing:')
                            ? 0
                            : 3);
                i++)
              i: i < 8 ? '2026-10-${24 + i}' : '2026-11-01'
          });
  @override
  Future<void> initialize() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> startJourney() async {}
}

class _Streak extends StreakNotifier {
  final String route;
  _Streak(this.route);
  @override
  StreakState build() => StreakState(
      current: route == 'calendar' ? 8 : 3,
      longest: route == 'calendar' ? 8 : 7,
      activeDays: {'2026-10-30', '2026-10-31', '2026-11-01'});
}

class _Transparency extends TransparencyPreference {
  final bool opaque;
  _Transparency(this.opaque);
  @override
  bool build() => opaque;
}

class _SheetFixture extends StatefulWidget {
  final void Function(BuildContext) open;
  const _SheetFixture({required this.open});
  @override
  State<_SheetFixture> createState() => _SheetFixtureState();
}

class _SheetFixtureState extends State<_SheetFixture> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.open(context);
    });
  }

  @override
  Widget build(BuildContext context) => const HomeShell(initialTab: 1);
}
