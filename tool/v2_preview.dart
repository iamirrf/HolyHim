// Explicit visual-QA entrypoint. It never initializes Firebase or an account.
// Native builds use the HolyHimVisualQA scheme. Switch real widgets with:
// Use devicectl with the verified wireless iPhone; never create a simulator.
// Query options: theme, text (OS text scale), reading, card (1..4), step (0..10),
// scroll (pixels), empty=1, done=1, sheet=email|badge. Automated callbacks below
// select screenshot states; behavioral correctness is verified by widget tests.
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:holyhim/design/design.dart';
import 'package:holyhim/domain/calendar.dart';
import 'package:holyhim/domain/lesson.dart';
import 'package:holyhim/features/auth/email_sheet.dart';
import 'package:holyhim/features/celebration/celebration_screen.dart';
import 'package:holyhim/features/common.dart';
import 'package:holyhim/features/lesson/lesson_screen.dart';
import 'package:holyhim/features/onboarding/onboarding_screen.dart';
import 'package:holyhim/features/profile/profile_screen.dart';
import 'package:holyhim/features/splash/splash_screen.dart';
import 'package:holyhim/features/support/support_screen.dart';
import 'package:holyhim/features/welcome/welcome_screen.dart';
import 'package:holyhim/main.dart';
import 'package:holyhim/services/app_router.dart';
import 'package:holyhim/services/auth_service.dart';
import 'package:holyhim/services/notifications.dart';
import 'package:holyhim/services/repository.dart';

const _screen = String.fromEnvironment('V2_SCREEN', defaultValue: 'walk');
const _theme = String.fromEnvironment('V2_THEME', defaultValue: 'blush');
const _qa = MethodChannel('holyhim/visual-qa');
final _timings = <FrameTiming>[];
final _qaEvents = <Map<String, Object?>>[];
Future<void> _record(Map<String, Object?> event) async {
  _qaEvents.add(event);
  if (_qaEvents.length > 300) _qaEvents.removeAt(0);
  try {
    await _qa.invokeMethod<void>('record', {
      'at': DateTime.now().toUtc().toIso8601String(),
      ...event,
    });
  } catch (_) {/* The same fixture also runs without native QA telemetry. */}
}

class _PreviewAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
      user: AuthUser(
          uid: 'visual-fixture',
          displayName: 'Mira',
          email: 'mira@example.test'));
}

class _PreviewRepository extends WalkRepository {
  WalkState fixture(
      {String theme = _theme,
      bool empty = false,
      bool done = false,
      double reading = 1}) {
    final now = DateTime.now(),
        today = dateKey(localNow(DateTime.now(), 'America/New_York'));
    return WalkState(
        profile: AppProfile(
            name: 'Mira',
            hearts: ['Peace', 'Hope'],
            theme: theme,
            timeZone: 'America/New_York',
            reminderEnabled: true,
            readingScale: reading,
            haptics: false,
            sounds: false,
            promiseStartedAt: now.subtract(const Duration(days: 6)),
            onboardedAt: now.subtract(const Duration(days: 6))),
        completed: {
          for (var day = 1; day <= 6; day++) day: shiftDate(today, day - 7),
          if (done) 7: today
        },
        saved: empty
            ? {}
            : {
                1: now.subtract(const Duration(days: 5)),
                3: now.subtract(const Duration(days: 3)),
                6: now.subtract(const Duration(days: 1))
              });
  }

  @override
  WalkState build() => fixture();
  void reset(Uri uri) {
    state = fixture(
        theme: uri.queryParameters['theme'] ?? _theme,
        empty: uri.queryParameters['empty'] == '1',
        done: uri.queryParameters['done'] == '1',
        reading: (double.tryParse(uri.queryParameters['reading'] ?? '') ?? 1)
            .clamp(1, 2));
    if (uri.path.endsWith('/onboarding')) {
      state = state.copyWith(
          profile: state.profile.copyWith(
              onboardedAt: null,
              birthday: '1998-05-16',
              onboardingDraft: {
            'step': (int.tryParse(uri.queryParameters['step'] ?? '') ?? 0)
                .clamp(0, 10),
            'firstName': 'Mira',
            'lifeSeason': 'A time of change',
            'faithRoutine': 'I’m finding a steady rhythm',
            'termsAccepted': true
          }));
    }
  }

  @override
  void updateProfile(AppProfile profile) =>
      state = state.copyWith(profile: profile);
  @override
  void finishOnboarding([AppProfile? profile]) => updateProfile(
      (profile ?? state.profile).copyWith(onboardedAt: DateTime.now()));
}

class _PreviewNotifications extends NotificationService {
  @override
  Future<void> initialize() async {}
  @override
  Future<String> deviceTimeZone() async => 'America/New_York';
  @override
  Future<bool> requestPermission() async => true;
  @override
  void reconcile(
      {required String uid,
      required AppProfile profile,
      required Map<int, String> completed,
      required List<Lesson> lessons}) {}
  @override
  Future<void> cancel() async {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/New_York'));
  // ignore: invalid_use_of_visible_for_testing_member
  HolySounds.player = (String _, {double gain = 1}) async {};
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(_record({
      'event': 'flutter-error',
      'message': details.exceptionAsString(),
      'stack': '${details.stack}'
    }));
  };
  SchedulerBinding.instance.addTimingsCallback((frames) {
    _timings.addAll(frames);
    if (_timings.length > 600) _timings.removeRange(0, _timings.length - 600);
  });
  var initial = '/preview/$_screen';
  try {
    final args = await _qa
        .invokeListMethod<String>('launchArguments')
        .timeout(const Duration(seconds: 2));
    for (final arg in args ?? <String>[]) {
      if (arg.startsWith('--v2-route=')) {
        initial = arg.substring('--v2-route='.length);
      }
    }
  } catch (_) {}
  final router = GoRouter(initialLocation: initial, routes: [
    GoRoute(
        path: '/:location(.*)',
        pageBuilder: (context, state) => NoTransitionPage<void>(
            key: ValueKey(state.uri.toString()),
            child: _PreviewGate(uri: state.uri)))
  ]);
  // Debug-only control for the standalone fixture app. Local VM requests
  // select real widget routes and collect readiness/errors without UI alerts.
  registerExtension('ext.holyhim.preview', (method, parameters) async {
    final route = parameters['route'];
    if (route != null && route.startsWith('/')) router.go(route);
    return ServiceExtensionResponse.result(jsonEncode({
      'route': router.routeInformationProvider.value.uri.toString(),
      'events': _qaEvents,
    }));
  });
  runApp(ProviderScope(overrides: [
    authProvider.overrideWith(_PreviewAuth.new),
    repositoryProvider.overrideWith(_PreviewRepository.new),
    notificationServiceProvider.overrideWith((ref) => _PreviewNotifications()),
    appRouterProvider.overrideWithValue(router)
  ], child: const HolyHimApp()));
}

class _PreviewGate extends ConsumerStatefulWidget {
  final Uri uri;
  const _PreviewGate({required this.uri});
  @override
  ConsumerState<_PreviewGate> createState() => _PreviewGateState();
}

class _PreviewGateState extends ConsumerState<_PreviewGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  List<Element> _elements() {
    final result = <Element>[];
    void visit(Element element) {
      result.add(element);
      element.visitChildElements(visit);
    }

    (context as Element).visitChildElements(visit);
    return result;
  }

  String _text(Element element) {
    final parts = <String>[];
    void visit(Element current) {
      if (current.widget case Text(:final data)) {
        if (data != null) parts.add(data);
      }
      current.visitChildElements(visit);
    }

    visit(element);
    return parts.join(' ');
  }

  bool _press(String label) {
    for (final element in _elements()) {
      final widget = element.widget;
      if (widget is ActionButton &&
          widget.label == label &&
          widget.onPressed != null) {
        widget.onPressed!();
        return true;
      }
      if (widget is CircleControl && widget.label == label) {
        widget.onPressed();
        return true;
      }
      if (widget is TextButton &&
          _text(element) == label &&
          widget.onPressed != null) {
        widget.onPressed!();
        return true;
      }
      if (widget is HoldButton && widget.label == label && widget.enabled) {
        widget.onComplete();
        return true;
      }
    }
    return false;
  }

  Future<void> _prepare() async {
    (ref.read(repositoryProvider.notifier) as _PreviewRepository)
        .reset(widget.uri);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    final query = widget.uri.queryParameters;
    final screen = widget.uri.pathSegments.lastOrNull ?? 'walk';
    if (screen == 'lesson') {
      final card = (int.tryParse(query['card'] ?? '') ?? 1).clamp(1, 4);
      for (var i = 1; i < card && mounted; i++) {
        _press('Next card');
        await Future<void>.delayed(const Duration(milliseconds: 550));
      }
    }
    if (!mounted) return;
    final scroll = double.tryParse(query['scroll'] ?? '');
    if (scroll != null) {
      final view = MediaQuery.sizeOf(context);
      for (final element in _elements()) {
        if (element is StatefulElement && element.state is ScrollableState) {
          final state = element.state as ScrollableState;
          if (state.position.axis != Axis.vertical ||
              !state.position.hasContentDimensions) {
            continue;
          }
          final render = element.findRenderObject();
          if (render is! RenderBox || !render.hasSize) continue;
          final rect = render.localToGlobal(Offset.zero) & render.size;
          if (!rect.overlaps(Offset.zero & view)) continue;
          state.position
              .jumpTo(scroll.clamp(0, state.position.maxScrollExtent));
          break;
        }
      }
    }
    if (query['sheet'] == 'email') {
      unawaited(Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const EmailSheet())));
    } else if (query['sheet'] == 'badge') {
      unawaited(showBadgeReveal(context,
          title: 'A Beautiful Beginning',
          description: 'Your first quiet moment with God.',
          earned: true,
          progress: '1 / 1',
          icon: Icons.auto_awesome));
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final size = MediaQuery.sizeOf(context);
    final sample = _timings
        .map((frame) => frame.totalSpan.inMicroseconds / 1000)
        .toList()
      ..sort();
    await _record({
      'event': 'ready',
      'route': widget.uri.toString(),
      'width': size.width,
      'height': size.height,
      'textScale': MediaQuery.textScalerOf(context).scale(1),
      'frameCount': sample.length,
      if (sample.isNotEmpty)
        'debugFrameP90Ms':
            sample[(sample.length * .9).floor().clamp(0, sample.length - 1)],
      'verification':
          'real widgets with local fixtures; debug timings are not device profile FPS'
    });
    debugPrint('V2_QA_READY ${widget.uri}');
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(repositoryProvider);
    final parts = widget.uri.pathSegments;
    final screen = parts.isEmpty ? 'walk' : parts.last;
    Widget child;
    if (parts.length >= 2 && parts.first != 'preview') {
      child = AppGate(uri: widget.uri);
    } else if (screen == 'welcome') {
      child = const WelcomeScreen();
    } else if (screen == 'onboarding') {
      child = OnboardingScreen(
          key: ValueKey(
              'onboarding-${snapshot.profile.onboardingDraft['step']}'));
    } else if (screen == 'lesson') {
      child = const LessonScreen(day: 7);
    } else if (screen == 'celebration') {
      child = const CelebrationScreen(day: 6);
    } else if (screen == 'splash') {
      child = const SplashScreen();
    } else if (screen == 'guide') {
      child = const WidgetGuideScreen();
    } else if (screen == 'support') {
      child = const SupportScreen();
    } else if (screen == 'verse') {
      child = AppGate(uri: Uri.parse('/verse/6'));
    } else {
      final paths = {
        'walk': '/',
        'saved': '/saved',
        'growth': '/growth',
        'profile': '/profile'
      };
      child = AppGate(uri: Uri.parse(paths[screen] ?? widget.uri.path));
    }
    final scale =
        (double.tryParse(widget.uri.queryParameters['text'] ?? '') ?? 1.0)
            .clamp(1, 2);
    var data = MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(scale.toDouble()));
    if (widget.uri.queryParameters['compact'] == '1') {
      data = data.copyWith(
          size: const Size(375, 667),
          padding: const EdgeInsets.only(top: 20),
          viewPadding: const EdgeInsets.only(top: 20),
          viewInsets: EdgeInsets.zero);
      return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
              width: 375,
              height: 667,
              child: MediaQuery(data: data, child: child)));
    }
    return MediaQuery(data: data, child: child);
  }
}
