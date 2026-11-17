import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/domain/lesson.dart';
import 'package:holyhim/main.dart';
import 'package:holyhim/services/auth_service.dart';
import 'package:holyhim/services/billing.dart';
import 'package:holyhim/services/notifications.dart';
import 'package:holyhim/services/repository.dart';
import 'package:holyhim/services/widget_bridge.dart';
import 'package:timezone/data/latest.dart' as tzdata;

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(user: AuthUser(uid: 'first'));
  void change(String? uid) =>
      state = AuthState(user: uid == null ? null : AuthUser(uid: uid));
}

class _VerifiedAccess extends AccessController {
  @override
  AccessState build() =>
      const AccessState(loading: false, purchased: true, verified: true);
}

class _Repository extends WalkRepository {
  @override
  WalkState build() {
    final uid = ref.watch(authProvider.select((auth) => auth.user?.uid));
    return WalkState(
        profile: AppProfile(
            name: uid ?? '',
            timeZone: 'UTC',
            haptics: false,
            sounds: false,
            onboardedAt: uid == null ? null : DateTime.now()));
  }

  @override
  void updateProfile(AppProfile profile) =>
      state = state.copyWith(profile: profile);
}

class _Notifications extends NotificationService {
  @override
  Future<void> initialize() async {}
  final zones = <Completer<String>>[];
  @override
  Future<String> deviceTimeZone() {
    final zone = Completer<String>();
    zones.add(zone);
    return zone.future;
  }

  @override
  void reconcile(
      {required String uid,
      required AppProfile profile,
      required Map<int, String> completed,
      required List<Lesson> lessons}) {}
  @override
  Future<void> cancel() async {}
}

class _WidgetBridge extends WidgetBridge {
  final refreshed = <AppProfile>[];
  int clears = 0;
  @override
  Future<void> refresh(
      {required AppProfile profile,
      required Map<int, String> completed,
      required List<Lesson> lessons}) async {
    refreshed.add(profile);
  }

  @override
  Future<void> clear() async {
    clears++;
  }
}

void main() {
  setUpAll(tzdata.initializeTimeZones);
  testWidgets(
      'travel lookups cannot edit a different account and widget data clears on sign-out',
      (tester) async {
    HolySounds.player = (String _, {double gain = 1}) async {};
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final notifications = _Notifications(), bridge = _WidgetBridge();
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_Auth.new),
      accessProvider.overrideWith(_VerifiedAccess.new),
      repositoryProvider.overrideWith(_Repository.new),
      notificationServiceProvider.overrideWithValue(notifications),
      widgetBridgeProvider.overrideWithValue(bridge)
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const HolyHimApp()));
    await tester.pump();
    expect(notifications.zones.length, 1);
    (container.read(authProvider.notifier) as _Auth).change('second');
    await tester.pump();
    expect(notifications.zones.length, 2);
    notifications.zones.first.complete('Asia/Tokyo');
    await tester.pump();
    await tester.pump();
    expect(container.read(repositoryProvider).profile.name, 'second');
    expect(container.read(repositoryProvider).profile.timeZone, 'UTC');
    notifications.zones[1].complete('America/New_York');
    await tester.pump();
    await tester.pump();
    expect(container.read(repositoryProvider).profile.timeZone,
        'America/New_York');
    expect(bridge.refreshed.last.name, 'second');
    expect(bridge.clears, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(notifications.zones.length, 3);
    (container.read(authProvider.notifier) as _Auth).change(null);
    await tester.pump();
    notifications.zones[2].complete('Europe/London');
    await tester.pump();
    await tester.pump();
    expect(container.read(repositoryProvider).profile.name, isEmpty);
    expect(container.read(repositoryProvider).profile.timeZone, 'UTC');
    expect(bridge.clears, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    notifications.dispose();
  });
}
