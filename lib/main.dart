import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'design/design.dart';
import 'firebase_options.dart';
import 'features/splash/splash_screen.dart';
import 'services/app_router.dart';
import 'services/auth_service.dart';
import 'services/repository.dart';
import 'services/account_cache.dart';
import 'services/billing.dart';
import 'services/notifications.dart';
import 'services/navigation_state.dart';
import 'services/firebase_runtime.dart';
import 'services/widget_bridge.dart';
import 'services/url_strategy_stub.dart'
    if (dart.library.js_interop) 'services/url_strategy_web.dart';
import 'data/lessons.g.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in const [
      ('Cormorant Garamond', 'CormorantGaramond-OFL.txt'),
      ('Lora', 'Lora-OFL.txt'),
      ('Manrope', 'manrope-OFL.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks(
          [family], await rootBundle.loadString('assets/fonts/$file'));
    }
  });
  configureBrowserRoutes();
  tzdata.initializeTimeZones();
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  final Future<void> Function()? initializeFirebase;
  final Future<void> Function()? initializeCache;
  final WidgetBuilder? appBuilder;
  const Bootstrap(
      {super.key,
      this.initializeFirebase,
      this.initializeCache,
      this.appBuilder});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late final ProviderContainer container;
  bool ready = false;
  final cache = AccountCache(durable: true);
  @override
  void initState() {
    super.initState();
    container = ProviderContainer(overrides: [
      firebaseReadyProvider.overrideWith((ref) => false),
      accountCacheProvider.overrideWithValue(cache)
    ]);
    unawaited(start());
  }

  Future<void> initializeFirebase() async {
    final options = kIsWeb
        ? HolyHimFirebaseOptions.web
        : defaultTargetPlatform == TargetPlatform.iOS
            ? HolyHimFirebaseOptions.ios
            : null;
    await Firebase.initializeApp(options: options);
  }

  Future<void> start() async {
    // Long enough for the wordmark to register, short enough not to wait.
    final minimum = Future<void>.delayed(const Duration(milliseconds: 650));
    // Keep observing the original future after the splash's three-second guard.
    // A late native initialization must activate auth and local snapshots too.
    final initialization =
        Future<void>.sync(widget.initializeFirebase ?? initializeFirebase)
            .then((_) {
      if (!mounted) return;
      try {
        configureFirestoreCache();
      } catch (_) {/* Auth can recover even if a cache is unavailable. */}
      container.read(firebaseReadyProvider.notifier).state = true;
    }).catchError((Object _) {
      /* The welcome flow can explain unavailable sign-in. */
    });
    final guard = Completer<void>();
    final timer = Timer(const Duration(seconds: 3), () => guard.complete());
    try {
      await Future.wait([
        minimum,
        widget.initializeCache?.call() ?? cache.initialize(),
        Future.any([initialization, guard.future])
      ]);
    } finally {
      timer.cancel();
    }
    if (mounted) setState(() => ready = true);
  }

  @override
  void dispose() {
    container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ready
      ? UncontrolledProviderScope(
          container: container,
          child: widget.appBuilder == null
              ? const HolyHimApp()
              : Builder(builder: widget.appBuilder!))
      : const Directionality(
          textDirection: TextDirection.ltr, child: SplashScreen());
}

class HolyHimApp extends ConsumerStatefulWidget {
  const HolyHimApp({super.key});
  @override
  ConsumerState<HolyHimApp> createState() => _HolyHimAppState();
}

class _HolyHimAppState extends ConsumerState<HolyHimApp>
    with WidgetsBindingObserver {
  static const accessibility = MethodChannel('holyhim/accessibility');
  bool reduceTransparency = false;
  String? checkingZoneFor;
  int zoneGeneration = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      accessibility.invokeMethod<bool>('reduceTransparency').then((v) {
        if (mounted) setState(() => reduceTransparency = v ?? false);
      }).catchError((Object _) {});
      accessibility.setMethodCallHandler((call) async {
        if (call.method == 'transparencyChanged' && mounted) {
          setState(() => reduceTransparency = call.arguments == true);
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref
          .read(notificationServiceProvider)
          .initialize()
          .catchError((Object _) {}));
      refreshTimeZone();
      reconcile();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    accessibility.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(repositoryProvider.notifier).retrySync();
      refreshTimeZone();
      reconcile();
      unawaited(ref.read(accessProvider.notifier).load());
    }
  }

  void refreshTimeZone() {
    final uid = ref.read(authProvider).user?.uid;
    if (uid == null ||
        checkingZoneFor == uid ||
        !ref.read(repositoryProvider).ready) {
      return;
    }
    checkingZoneFor = uid;
    final generation = ++zoneGeneration;
    unawaited(() async {
      try {
        final zone = await ref
            .read(notificationServiceProvider)
            .deviceTimeZone()
            .timeout(const Duration(seconds: 2),
                onTimeout: () => tz.local.name);
        if (!mounted ||
            ref.read(authProvider).user?.uid != uid ||
            generation != zoneGeneration) {
          return;
        }
        final location = tz.getLocation(zone);
        tz.setLocalLocation(location);
        final profile = ref.read(repositoryProvider).profile;
        if (profile.timeZone != zone) {
          ref
              .read(repositoryProvider.notifier)
              .updateProfile(profile.copyWith(timeZone: zone));
        }
      } catch (_) {
        /* A failed zone lookup keeps the previously saved calendar. */
      } finally {
        if (generation == zoneGeneration) checkingZoneFor = null;
      }
    }());
  }

  void reconcile() {
    final uid = ref.read(authProvider).user?.uid;
    if (uid == null) return;
    final state = ref.read(repositoryProvider);
    if (!state.ready) return;
    // Reminders and widgets work for everyone, unlocked or not.
    ref.read(notificationServiceProvider).reconcile(
        uid: uid,
        profile: state.profile,
        completed: state.completed,
        lessons: lessons);
    unawaited(ref.read(widgetBridgeProvider).refresh(
        profile: state.profile, completed: state.completed, lessons: lessons));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(repositoryProvider);
    final theme = HolyThemes.byId(state.profile.theme);
    HolyHaptics.enabled = state.profile.haptics;
    HolySounds.enabled = state.profile.sounds;
    ref.listen(repositoryProvider, (before, after) {
      if (before?.ready != true && after.ready) refreshTimeZone();
      reconcile();
    });
    ref.listen(authProvider, (before, after) {
      if (before?.user?.uid != after.user?.uid) {
        ++zoneGeneration;
        checkingZoneFor = null;
        if (before?.user != null) {
          ref.read(pendingDestinationProvider.notifier).state = null;
          unawaited(ref.read(notificationServiceProvider).cancel());
        }
        if (after.user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
            }
          });
        }
        unawaited(ref.read(widgetBridgeProvider).clear());
        refreshTimeZone();
        reconcile();
      }
    });
    ref.listen(notificationTapProvider, (_, tap) {
      if (tap == null) return;
      final uid = ref.read(authProvider).user?.uid;
      if (tap.account != uid) return;
      ref.read(appRouterProvider).go(tap.verseOnly
          ? '/verse/${tap.day}'
          : '/lesson/${tap.day}?continuation=1');
    });
    return MaterialApp.router(
        title: 'HolyHim',
        debugShowCheckedModeBanner: false,
        theme: HolyThemeData.build(theme),
        routerConfig: ref.watch(appRouterProvider),
        builder: (context, child) => ThemeHost(
            theme: theme,
            reduceTransparency: reduceTransparency,
            child: child!));
  }
}
