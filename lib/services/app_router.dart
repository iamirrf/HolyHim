import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/lessons.g.dart';
import '../design/design.dart';
import '../domain/access.dart';
import '../domain/onboarding_flow.dart';
import '../domain/pacing.dart';
import '../domain/routes.dart';
import '../features/common.dart';
import '../features/welcome/welcome_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/shell/home_shell.dart';
import '../features/lesson/lesson_screen.dart';
import '../features/celebration/celebration_screen.dart';
import '../features/journey/journey_screen.dart';
import '../features/paywall/paywall_screen.dart';
import '../features/community/community_screen.dart';
import '../features/saved/saved_screen.dart';
import '../design/art_catalog.dart';
import '../features/support/support_screen.dart';
import '../services/share_card.dart';
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

const _pushed = [
  'lesson', 'verse', 'celebration', 'journey', 'offer', 'paywall', 'saved', 'post'
];

/// Full-screen routes sit above the retained tab route, so the Today card
/// can fly into the lesson as a shared element.
Page<void> appRoutePage(BuildContext context, GoRouterState state) {
  final parts = Uri.parse(appPath(state.uri)).pathSegments;
  final pushed = parts.isNotEmpty && _pushed.contains(parts.first);
  final child = AppGate(uri: state.uri);
  if (!pushed) {
    return NoTransitionPage<void>(
        key: const ValueKey('holyhim-root'), child: child);
  }
  final reduced = MediaQuery.disableAnimationsOf(context);
  final rising = parts.first == 'offer' || parts.first == 'paywall';
  return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration:
          reduced ? Duration.zero : const Duration(milliseconds: 520),
      reverseTransitionDuration:
          reduced ? Duration.zero : const Duration(milliseconds: 360),
      transitionsBuilder: (context, animation, secondary, child) {
        final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic);
        return FadeTransition(
            opacity: curve,
            child: rising
                ? SlideTransition(
                    position:
                        Tween(begin: const Offset(0, .06), end: Offset.zero)
                            .animate(curve),
                    child: child)
                : child);
      });
}

class AppGate extends ConsumerWidget {
  final Uri uri;
  const AppGate({super.key, required this.uri});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider), state = ref.watch(repositoryProvider);
    if (auth.user == null) return const WelcomeScreen();
    if (!state.ready) {
      return state.syncError == null
          ? const Scaffold(body: BrandLoader())
          : StatusScreen(
              title: 'Your walk could not load',
              message:
                  'Check your connection, then try again. Nothing you have read is lost.',
              action: 'Try again',
              onAction: () => ref.invalidate(repositoryProvider));
    }
    final requested = appPath(uri);
    final redo = uri.queryParameters['redo'] == '1';
    final stepId = state.profile.onboardingDraft['stepId'];
    final closing = onboardingClosingSteps.contains(stepId);
    if (!state.profile.onboarded ||
        closing ||
        (requested == '/onboarding' && redo)) {
      if (requested != '/' && requested != '/onboarding') {
        scheduleMicrotask(() => ref
            .read(pendingDestinationProvider.notifier)
            .state = uri.toString());
      }
      return const OnboardingScreen();
    }
    if (requested == '/onboarding') {
      scheduleMicrotask(() => context.go('/'));
      return const HomeShell();
    }
    final owned = ref.watch(lifetimeProvider.select((a) => a.active));
    if (requested == '/offer' || requested == '/paywall') {
      final day = int.tryParse(uri.queryParameters['day'] ?? '');
      return OfferScreen(
          lockedDay: day,
          onContinue: () {
            final pending = ref.read(pendingDestinationProvider);
            ref.read(pendingDestinationProvider.notifier).state = null;
            if (pending != null && owned) {
              context.go(pending);
            } else if (day != null && ref.read(lifetimeProvider).active) {
              context.pushReplacement('/lesson/$day');
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          });
    }
    if (requested == '/journey') return const JourneyScreen();
    if (requested == '/saved') {
      return const Scaffold(body: SavedScreen(standalone: true));
    }
    if (requested == '/support') return const SupportScreen();
    if (requested == '/legal') {
      return LegalScreen(document: uri.queryParameters['document'] ?? 'terms');
    }
    final normalized =
        Uri(path: appPath(uri), query: uri.hasQuery ? uri.query : null);
    final parts = normalized.pathSegments;
    final pacing =
        pacingFor(state.completed, DateTime.now(), state.profile.timeZone);
    if (parts.length == 2 && parts.first == 'lesson') {
      final day =
          parts[1] == 'today' ? pacing.displayDay : int.tryParse(parts[1]);
      if (day != null && pacing.canRead(day, state.completed)) {
        if (!canOpenLesson(day, owned: owned, completed: state.completed)) {
          return OfferScreen(lockedDay: day);
        }
        return LessonScreen(
            key: ValueKey('lesson-$day'),
            day: day,
            continuation: uri.queryParameters['continuation'] == '1');
      }
      return const StatusScreen(
          title: 'Not quite yet',
          message:
              'This lesson is still ahead of you. One a day is plenty; today’s is waiting on Today.',
          action: 'Back to Today');
    }
    if (parts.length == 2 && parts.first == 'post') {
      return PostScreen(key: ValueKey('post-${parts[1]}'), id: parts[1]);
    }
    if (parts.length == 2 && parts.first == 'verse') {
      final day = int.tryParse(parts[1]);
      if (day != null && day >= 1 && day <= 365) return VerseScreen(day: day);
    }
    if (parts.length == 2 && parts.first == 'celebration') {
      final day = int.tryParse(parts[1]);
      if (day != null && state.completed.containsKey(day)) {
        return CelebrationScreen(day: day);
      }
    }
    const tabs = {
      '/': 0,
      '/brothers': 1,
      '/ranks': 2,
      '/growth': 3,
      '/profile': 4,
      '/account': 4
    };
    final tab = tabs[normalized.path];
    if (tab == null) {
      return const StatusScreen(
          title: 'That page is not here',
          message: 'It may have moved. Your walk is right where you left it.',
          action: 'Back to Today');
    }
    return HomeShell(
        initialTab: tab,
        onMood: (value) => ref.read(meshMoodProvider).value = value);
  }
}

/// Verse of the day, full screen on its chapter photograph.
class VerseScreen extends StatelessWidget {
  final int day;
  const VerseScreen({super.key, required this.day});
  @override
  Widget build(BuildContext context) {
    final lesson = lessons[day - 1];
    final media = MediaQuery.of(context);
    return Scaffold(
        backgroundColor: HolyTheme.photoShade,
        body: PhotoStage(
            images: [HolyArtCatalog.assetForDay(day)],
            alignment: const Alignment(0, -.3),
            topVeil: .45,
            bottomVeil: .85,
            child: Padding(
                padding: EdgeInsets.fromLTRB(HolySpace.gutter,
                    media.padding.top + 6, HolySpace.gutter, media.padding.bottom + 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        IconControl(
                            icon: CupertinoIcons.xmark,
                            label: 'Close verse',
                            onPhoto: true,
                            onPressed: () => context.canPop()
                                ? context.pop()
                                : context.go('/')),
                        const Spacer(),
                        IconControl(
                            icon: CupertinoIcons.square_arrow_up,
                            label: 'Share verse',
                            onPhoto: true,
                            onPressed: () => shareVerseCard(context, lesson)),
                      ]),
                      const Spacer(),
                      const Eyebrow('Verse of the day',
                          color: Color(0xFFF2D7A6)),
                      const SizedBox(height: 14),
                      Rise(
                          child: Text('“${lesson.verse}”',
                              style: HolyTypography.verse.copyWith(
                                  color: HolyTheme.photoInk,
                                  fontSize: lesson.verse.length > 220 ? 26 : 32,
                                  shadows: const [
                                    Shadow(
                                        color: Color(0x88000000),
                                        blurRadius: 20)
                                  ]))),
                      const SizedBox(height: 14),
                      Text('${lesson.reference} · World English Bible',
                          style: HolyTypography.label.copyWith(
                              color: HolyTheme.photoInk.withValues(alpha: .85))),
                      const SizedBox(height: 28),
                      HolyButton('Open today’s lesson',
                          style: HolyButtonStyle.photoPrimary,
                          onPressed: () => context.go('/lesson/today')),
                    ]))));
  }
}
