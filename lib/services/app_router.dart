import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/lessons.g.dart';
import '../design/design.dart';
import '../domain/pacing.dart';
import '../domain/routes.dart';
import '../features/common.dart';
import '../features/welcome/welcome_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/shell/home_shell.dart';
import '../features/lesson/lesson_screen.dart';
import '../features/celebration/celebration_screen.dart';
import '../features/paywall/paywall_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/support/support_screen.dart';
import 'billing.dart';
import 'navigation_state.dart';
import '../main.dart' show meshMoodProvider;
import 'auth_service.dart';
import 'repository.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
      navigatorKey: appNavigatorKey,
      routes: [GoRoute(path: '/:location(.*)', pageBuilder: appRoutePage)]);
  ref.onDispose(router.dispose);
  return router;
});

/// Full-screen reading routes sit above the retained tab route. A pushed Today
/// card can therefore fly to the lesson's background through Navigator's Hero.
Page<void> appRoutePage(BuildContext context, GoRouterState state) {
  final parts = Uri.parse(appPath(state.uri)).pathSegments;
  final reading = parts.length == 2 &&
      ['lesson', 'verse', 'celebration'].contains(parts.first);
  final child = AppGate(uri: state.uri);
  if (!reading) {
    return NoTransitionPage<void>(
        key: const ValueKey('holyhim-root'), child: child);
  }
  final reduced = MediaQuery.disableAnimationsOf(context);
  return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration:
          reduced ? Duration.zero : const Duration(milliseconds: 420),
      reverseTransitionDuration:
          reduced ? Duration.zero : const Duration(milliseconds: 360),
      transitionsBuilder: (context, animation, secondary, child) =>
          FadeTransition(
              opacity: CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic),
              child: child));
}

class AppGate extends ConsumerWidget {
  final Uri uri;
  const AppGate({super.key, required this.uri});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider), state = ref.watch(repositoryProvider);
    if (auth.user == null) return const WelcomeScreen();
    if (!state.ready) {
      return Scaffold(
          body: Center(
              child: state.syncError == null
                  ? const CupertinoActivityIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text(
                            'Your profile could not load. Check your connection and try again.',
                            textAlign: TextAlign.center),
                        TextButton(
                            onPressed: () => ref.invalidate(repositoryProvider),
                            child: const Text('Try again')),
                      ]))));
    }
    final requested = appPath(uri);
    final redoOnboarding = uri.queryParameters['redo'] == '1';
    final stepId = state.profile.onboardingDraft['stepId'];
    final inOnboardingFlow = stepId == 'saving' || stepId == 'lifetimeAccess';
    if (!state.profile.onboarded ||
        inOnboardingFlow ||
        (requested == '/onboarding' && redoOnboarding)) {
      if (requested != '/' && requested != '/onboarding') {
        scheduleMicrotask(() => ref
            .read(pendingDestinationProvider.notifier)
            .state = uri.toString());
      }
      return const OnboardingScreen();
    }
    if (requested == '/onboarding') {
      // User has already completed onboarding. Redirect gracefully to home.
      scheduleMicrotask(() => context.go('/'));
      return const HomeShell();
    }
    if (requested == '/paywall') {
      return PaywallScreen(onContinue: () {
        final pending = ref.read(pendingDestinationProvider);
        ref.read(pendingDestinationProvider.notifier).state = null;
        context.go(pending ?? '/');
      });
    }
    if (!testingPaywallExit &&
        !['/support', '/account', '/legal'].contains(requested)) {
      final access = ref.watch(lifetimeProvider);
      if (access.loading) {
        return const Scaffold(
            body: Center(child: CupertinoActivityIndicator()));
      }
      if (!access.active) {
        scheduleMicrotask(() => ref
            .read(pendingDestinationProvider.notifier)
            .state = uri.toString());
        return const PaywallScreen();
      }
    }
    if (requested == '/account') return const ProfileScreen();
    if (requested == '/support') return const SupportScreen();
    if (requested == '/legal') {
      return LegalScreen(document: uri.queryParameters['document'] ?? 'terms');
    }
    final normalized =
        Uri(path: appPath(uri), query: uri.hasQuery ? uri.query : null);
    final parts = normalized.pathSegments,
        pacing =
            pacingFor(state.completed, DateTime.now(), state.profile.timeZone);
    if (parts.length == 2 && parts.first == 'lesson') {
      final day =
          parts[1] == 'today' ? pacing.displayDay : int.tryParse(parts[1]);
      if (day != null && pacing.canRead(day, state.completed)) {
        return LessonScreen(
            key: ValueKey('lesson-$day'),
            day: day,
            continuation: uri.queryParameters['continuation'] == '1');
      }
      return const _Recovery(
          message: 'This little moment is still ahead of you.');
    }
    if (parts.length == 2 && parts.first == 'verse') {
      final day = int.tryParse(parts[1]);
      if (day != null && day >= 1 && day <= 365) return _VerseScreen(day: day);
    }
    if (parts.length == 2 && parts.first == 'celebration') {
      final day = int.tryParse(parts[1]);
      if (day != null && state.completed.containsKey(day)) {
        return CelebrationScreen(day: day);
      }
    }
    final tabs = {'/': 0, '/saved': 1, '/growth': 2, '/profile': 3};
    final tab = tabs[normalized.path];
    if (tab == null) {
      return const _Recovery(message: 'That page is not part of your walk.');
    }
    return HomeShell(
        initialTab: tab,
        onMood: (value) => ref.read(meshMoodProvider).value = value);
  }
}

class _VerseScreen extends ConsumerWidget {
  final int day;
  const _VerseScreen({required this.day});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = lessons[day - 1];
    return Scaffold(
        appBar: GlassTopBar(
            leading: CircleControl(
                icon: CupertinoIcons.xmark,
                onPressed: () => context.go('/'),
                label: 'Close verse'),
            title: const Text('Verse of the Day')),
        body: SafeArea(
            child: PageBody(padding: const EdgeInsets.all(26), children: [
          const SizedBox(height: 30),
          Glass(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Eyebrow('Verse of the Day'),
                const SizedBox(height: 24),
                Text(lesson.verse, style: HolyTypography.verse),
                const SizedBox(height: 22),
                Text('${lesson.reference} · WEB', style: muted(context))
              ])),
          const SizedBox(height: 26),
          ActionButton("Today's lesson",
              onPressed: () => context.go('/lesson/today'))
        ])));
  }
}

class _Recovery extends StatelessWidget {
  final String message;
  const _Recovery({required this.message});
  @override
  Widget build(BuildContext context) => Scaffold(
          body: SafeArea(
              child: PageBody(children: [
        const SizedBox(height: 100),
        Text(message, style: HolyTypography.title),
        const SizedBox(height: 28),
        ActionButton('Back to my walk', onPressed: () => context.go('/'))
      ])));
}
