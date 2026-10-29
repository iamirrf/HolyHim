import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/constants/app_constants.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/features/home/home_shell.dart';
import 'package:holyher/features/landing/landing_screen.dart';
import 'package:holyher/features/paywall/paywall_screen.dart';
import 'package:holyher/services/paywall_service.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/streak_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: HolyHerApp()));
}

class HolyHerApp extends StatelessWidget {
  const HolyHerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: const AppRoot(),
    );
  }
}

/// Decides the first screen from stored state:
/// landing (first run) -> paywall (not unlocked) -> home shell.
class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> with WidgetsBindingObserver {
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        ref.read(streakProvider.notifier).initialize(),
        ref.read(progressProvider.notifier).initialize(),
        ref.read(paywallProvider.notifier).initialize(),
      ]);
      if (mounted) {
        setState(() => _booted = true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(streakProvider.notifier).checkAndUpdateStreak();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_booted) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }
    final onboardingComplete = ref.watch(progressProvider).onboardingComplete;
    final unlocked = ref.watch(paywallProvider);
    if (!onboardingComplete) {
      return const LandingScreen();
    }
    if (!unlocked) {
      return const PaywallScreen();
    }
    return const HomeShell();
  }
}
