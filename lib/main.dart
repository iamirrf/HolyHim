import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/url_strategy_stub.dart'
    if (dart.library.js_interop) 'package:holyher/services/url_strategy_web.dart';
import 'package:holyher/services/app_router.dart';
import 'package:holyher/services/reading_service.dart';
import 'package:holyher/services/reading_destination.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:holyher/dev/preview_bootstrap.dart' as visual_qa;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/constants/app_constants.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/features/home/home_shell.dart';
import 'package:holyher/features/landing/landing_screen.dart';
import 'package:holyher/features/onboarding/onboarding_screen.dart';
import 'package:holyher/features/splash/splash_screen.dart';
import 'package:holyher/firebase_options.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/profile_service.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/streak_service.dart';
import 'package:holyher/services/reminder_service.dart';
import 'package:holyher/services/learning_service.dart';
import 'package:holyher/services/saved_service.dart';
import 'package:holyher/features/lesson/lesson_screen.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/core/widgets/holy_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureBrowserRoutes();
  // Developer-invoked screen states use the real widgets on a physical device.
  // This branch is removed from release builds and never initializes an account.
  if (!kIsWeb && !kReleaseMode && defaultTargetPlatform == TargetPlatform.iOS) {
    final arguments = await HolyTypography.channel
            .invokeListMethod<String>('previewArguments') ??
        [];
    if (arguments.any((value) => value.startsWith('--holyher-preview='))) {
      await visual_qa.runPreview(entrypoint: 'lib/main.dart');
      return;
    }
  }
  try {
    await HolyTypography.initialize();
    await HolyMark.prepare();
  } catch (_) {
    runApp(ProviderScope(
        child: MaterialApp(
            theme: buildAppTheme(),
            home: const HolyRecovery(
                message: 'We could not prepare HolyHer. Please retry.',
                onRetry: main))));
    return;
  }
  try {
    await Firebase.initializeApp(
            options: kIsWeb
                ? HolyHerFirebaseOptions.web
                : HolyHerFirebaseOptions.ios)
        .timeout(const Duration(seconds: 20));
  } catch (_) {
    runApp(ProviderScope(
        child: MaterialApp(
            theme: buildAppTheme(),
            home: const HolyRecovery(
                message: 'We could not initialize HolyHer. Please retry.',
                onRetry: main))));
    return;
  }
  runApp(const ProviderScope(child: HolyHerApp()));
}

class HolyHerApp extends ConsumerWidget {
  const HolyHerApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(authProvider.select((s) => s.user?.uid),
        (previous, next) {
      if (previous != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
        });
      }
    });
    return MaterialApp.router(
        title: AppConstants.appName,
        theme: buildAppTheme(
            theme: ref.watch(profileProvider.select((p) => p.theme))),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: ref
                        .watch(profileProvider.select((p) => p.largerText))
                    ? TextScaler.linear(
                        MediaQuery.textScalerOf(context).scale(16) / 16 * 1.15)
                    : MediaQuery.textScalerOf(context)),
            child: BlushBackdrop(child: child!)),
        routerConfig: ref.watch(appRouterProvider));
  }
}

class AppRoot extends ConsumerWidget {
  final int initialTab;
  final int? requestedDay;
  final bool requestedScripture;
  const AppRoot(
      {super.key,
      this.initialTab = 0,
      this.requestedDay,
      this.requestedScripture = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth.user == null) return const LandingScreen();
    return _SignedInRoot(
        key: ValueKey(auth.user!.uid),
        initialTab: initialTab,
        requestedDay: requestedDay,
        requestedScripture: requestedScripture);
  }
}

class _SignedInRoot extends ConsumerStatefulWidget {
  final int initialTab;
  final int? requestedDay;
  final bool requestedScripture;
  const _SignedInRoot(
      {super.key,
      this.initialTab = 0,
      this.requestedDay,
      this.requestedScripture = false});
  @override
  ConsumerState<_SignedInRoot> createState() => _SignedInRootState();
}

class _SignedInRootState extends ConsumerState<_SignedInRoot>
    with WidgetsBindingObserver {
  bool _booted = false, _openingDestination = false;
  int _destinationEpoch = 0;
  String? _error;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  Future<void> _bootstrap() async {
    if (mounted) {
      setState(() {
        _error = null;
        _booted = false;
      });
    }
    try {
      await ref.read(profileProvider.notifier).initialize();
      if (!mounted) return;
      await ref.read(progressProvider.notifier).initialize();
      if (!mounted) return;
      await ref.read(progressProvider.notifier).refresh();
      if (!mounted) return;
      unawaited(ref.read(attemptSyncProvider.notifier).sync());
      unawaited(ref.read(readingSyncProvider.notifier).initialize());
      unawaited(ref
          .read(reminderServiceProvider)
          .reconcile(ref.read(profileProvider).reminderMinutes));
      unawaited(ref.read(streakProvider.notifier).initialize());
      if (mounted) {
        if (widget.requestedDay != null &&
            (!ref.read(profileProvider).onboardingComplete ||
                !ref.read(progressProvider).journeyStarted)) {
          ref.read(readingDestinationProvider.notifier).state =
              ReadingDestination(widget.requestedDay!,
                  scripture: widget.requestedScripture);
        }
        setState(() => _booted = true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is LocalStorageUnavailable
            ? error.message.toString()
            : 'We could not load your saved journey. Check your connection, then try again.');
      }
    }
  }

  void _refresh() {
    if (!mounted || !_booted) return;
    unawaited(ref.read(savedProvider.notifier).sync());
    unawaited(ref.read(readingSyncProvider.notifier).sync());
    unawaited(ref
        .read(progressProvider.notifier)
        .refresh()
        .then((_) => ref.read(attemptSyncProvider.notifier).sync()));
    unawaited(ref
        .read(reminderServiceProvider)
        .reconcile(ref.read(profileProvider).reminderMinutes)
        .then((_) {
      if (mounted) ref.invalidate(reminderEnabledProvider);
    }).catchError((Object _) {}));
    unawaited(ref.read(streakProvider.notifier).checkAndUpdateStreak());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return HolyRecovery(
          message: _error!,
          onRetry: () {
            ref.invalidate(profileProvider);
            _bootstrap();
          },
          onSignOut: () => ref.read(authProvider.notifier).signOut());
    }
    if (!_booted) return const SplashScreen();
    final profile = ref.watch(profileProvider);
    if (!profile.onboardingComplete) return const OnboardingScreen();
    if (!ref.watch(progressProvider).journeyStarted) {
      return const BeginJourneyScreen();
    }
    final destination = ref.watch(readingDestinationProvider);
    if (destination != null && !_openingDestination) {
      _openingDestination = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(readingDestinationProvider.notifier).state = null;
        _openingDestination = false;
        setState(() => _destinationEpoch++);
        final from = widget.initialTab == 1
            ? 'saved'
            : widget.initialTab == 2
                ? 'profile'
                : 'walk';
        ref.read(appRouterProvider).go(
            '/reading/${destination.day}?from=$from${destination.scripture ? '&card=scripture' : ''}');
      });
    }
    final day = widget.requestedDay,
        lesson = day == null ? null : lessonForDay(day);
    void close() => ref.read(appRouterProvider).go(widget.initialTab == 1
        ? '/saved'
        : widget.initialTab == 2
            ? '/profile'
            : '/');
    return Stack(fit: StackFit.expand, children: [
      TickerMode(
          enabled: day == null,
          child: ExcludeFocus(
              excluding: day != null,
              child: Offstage(
                  offstage: day != null,
                  child: HomeShell(initialTab: widget.initialTab)))),
      if (lesson != null)
        LessonScreen(
            key: ValueKey(
                'reading-${lesson.day}-${widget.requestedScripture}-$_destinationEpoch'),
            lesson: lesson,
            openScripture: widget.requestedScripture,
            onClose: close),
      if (day != null && lesson == null)
        HolyRecovery(
            message: 'That reading is not part of your 365-day walk.',
            onRetry: close),
    ]);
  }
}

class BeginJourneyScreen extends ConsumerStatefulWidget {
  const BeginJourneyScreen({super.key});
  @override
  ConsumerState<BeginJourneyScreen> createState() => _BeginJourneyState();
}

class _BeginJourneyState extends ConsumerState<BeginJourneyScreen> {
  bool _busy = false;
  String? _error;
  @override
  Widget build(BuildContext context) => HolyScaffold(
      body: Center(
          child: ReadingWidth(
              maxWidth: 560,
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const HolyMark(size: 80),
                    const SizedBox(height: 24),
                    Text('Your setup is ready.',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 16),
                    const Text(
                        'Begin your free 365-lesson journey. One more lesson opens each calendar day. Connect once to confirm your start date.'),
                    if (_error != null) InlineMessage(_error!, error: true),
                    const SizedBox(height: 24),
                    HolyButton(
                        label: 'Begin my journey',
                        busy: _busy,
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() {
                                  _busy = true;
                                  _error = null;
                                });
                                if (ref.read(readingDestinationProvider) ==
                                    null) {
                                  ref
                                      .read(readingDestinationProvider.notifier)
                                      .state = const ReadingDestination(1);
                                }
                                try {
                                  await ref
                                      .read(progressProvider.notifier)
                                      .startJourney();
                                } catch (_) {
                                  if (mounted) {
                                    setState(() => _error =
                                        'Your setup is saved. Reconnect and try again to begin.');
                                  }
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              })
                  ])))));
}
