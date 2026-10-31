import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/constants/app_constants.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/features/home/home_shell.dart';
import 'package:holyher/features/landing/landing_screen.dart';
import 'package:holyher/features/onboarding/onboarding_screen.dart';
import 'package:holyher/features/paywall/paywall_screen.dart';
import 'package:holyher/features/splash/splash_screen.dart';
import 'package:holyher/firebase_options.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/paywall_service.dart';
import 'package:holyher/services/profile_service.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/streak_service.dart';
import 'package:holyher/services/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: HolyHerFirebaseOptions.ios);
  } catch (_) {/* Authentication shows a recoverable connection message. */}
  runApp(const ProviderScope(child: HolyHerApp()));
}

class HolyHerApp extends ConsumerWidget {
  const HolyHerApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
      key: ValueKey(
          ref.watch(authProvider.select((state) => state.user?.uid)) ??
              'signed-out'),
      title: AppConstants.appName,
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: const AppRoot());
}

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth.user == null) return const LandingScreen();
    return _SignedInRoot(key: ValueKey(auth.user!.uid));
  }
}

class _SignedInRoot extends ConsumerStatefulWidget {
  const _SignedInRoot({super.key});
  @override
  ConsumerState<_SignedInRoot> createState() => _SignedInRootState();
}

class _SignedInRootState extends ConsumerState<_SignedInRoot>
    with WidgetsBindingObserver {
  bool _booted = false;
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
      await ref.read(paywallProvider.notifier).initialize();
      if (!mounted) return;
      unawaited(ref.read(streakProvider.notifier).initialize());
      if (mounted) setState(() => _booted = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'We could not load your saved journey. Check your connection, then try again.');
      }
    }
  }

  void _refresh() {
    if (!mounted || !_booted) return;
    unawaited(ref.read(progressProvider.notifier).refresh());
    unawaited(ref.read(paywallProvider.notifier).refresh());
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
      return Scaffold(
          body: SafeArea(
              child: Center(
                  child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        FilledButton(
                            onPressed: () {
                              ref.invalidate(profileProvider);
                              _bootstrap();
                            },
                            child: const Text('Try again')),
                        TextButton(
                            onPressed: () =>
                                ref.read(authProvider.notifier).signOut(),
                            child: const Text('Sign out'))
                      ])))));
    }
    if (!_booted) return const SplashScreen();
    final profile = ref.watch(profileProvider);
    if (!profile.onboardingComplete) return const OnboardingScreen();
    if (!ref.watch(paywallProvider)) return const PaywallScreen();
    return const HomeShell();
  }
}
