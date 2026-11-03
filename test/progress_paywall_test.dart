import 'dart:convert';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/journey_clock.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/profile_service.dart';
import 'package:holyher/services/auth_service.dart';
import 'support.dart';

class _SavedProfile extends ProfileNotifier {
  @override
  UserProfile build() =>
      const UserProfile(loaded: true, onboardingComplete: true);
}

class _EditingProfile extends ProfileNotifier {
  @override
  UserProfile build() => const UserProfile(loaded: true);
  @override
  Future<void> save(UserProfile value) async {
    state = value;
  }
}

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthState(user: AuthUser(uid: 'alice'));
}

class _Journey implements JourneyGateway {
  final loadResponse = Completer<Map<String, dynamic>>();
  final completed = <int>[];
  Map<String, dynamic> server = {};
  @override
  Stream<Map<String, dynamic>> watch(String uid) => const Stream.empty();
  @override
  Future<Map<String, dynamic>> load(String uid) => loadResponse.future;
  @override
  Future<Map<String, dynamic>> start(String uid, String timeZone) async =>
      server;
  @override
  Future<Map<String, dynamic>> complete(String uid, int day) async {
    completed.add(day);
    server = {
      ...server,
      'completedDays': {...(server['completedDays'] as List<int>), day}.toList()
    };
    return server;
  }
}

class _DelayedJourney extends _Journey {
  final firstStarted = Completer<void>();
  final firstResponse = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> complete(String uid, int day) async {
    if (day == 1 && !firstStarted.isCompleted) {
      completed.add(day);
      firstStarted.complete();
      return firstResponse.future;
    }
    return super.complete(uid, day);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String, Object> journey(
          {int unlocked = 3, List<int> completed = const []}) =>
      {
        'journey_cache': jsonEncode({
          'started': true,
          'startDate': '2026-10-29',
          'timeZone': 'America/New_York',
          'unlockedThrough': unlocked,
          'completedDays': completed
        })
      };
  ProviderContainer create(MemoryStore store, {JourneyGateway? gateway}) {
    final container = ProviderContainer(overrides: [
      localStoreProvider.overrideWithValue(store),
      profileProvider.overrideWith(_SavedProfile.new),
      if (gateway != null) ...[
        authProvider.overrideWith(_SignedIn.new),
        journeyGatewayProvider.overrideWithValue(gateway),
      ]
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test(
      'finishing setup preserves the enrolled journey without restarting progress',
      () async {
    final store = MemoryStore(journey());
    final c = ProviderContainer(overrides: [
      localStoreProvider.overrideWithValue(store),
      profileProvider.overrideWith(_EditingProfile.new)
    ]);
    addTearDown(c.dispose);
    final service = c.read(progressProvider.notifier);
    await service.initialize();
    expect(c.read(progressProvider).journeyStarted, isTrue);
    await c
        .read(profileProvider.notifier)
        .save(c.read(profileProvider).copyWith(onboardingComplete: true));
    expect(identical(service, c.read(progressProvider.notifier)), isTrue);
    expect(c.read(progressProvider).journeyStarted, isTrue);
    expect(c.read(progressProvider).unlockedThrough, 3);
    expect(c.read(progressProvider).onboardingComplete, isTrue);
  });
  test(
      'completion dates use the journey calendar, survive restart, and are never inferred for old lessons',
      () async {
    final store = MemoryStore(journey(completed: [1]));
    final container = ProviderContainer(overrides: [
      localStoreProvider.overrideWithValue(store),
      profileProvider.overrideWith(_SavedProfile.new),
      localClockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 2, 2))
    ]);
    addTearDown(container.dispose);
    await container.read(progressProvider.notifier).initialize();
    expect(container.read(progressProvider).completionDates, isEmpty);
    await container.read(progressProvider.notifier).completeDay(2);
    expect(container.read(progressProvider).completionDates, {2: '2026-11-01'});
    final restarted = create(MemoryStore(store.values));
    await restarted.read(progressProvider.notifier).initialize();
    expect(restarted.read(progressProvider).completionDates, {2: '2026-11-01'});
    expect(restarted.read(progressProvider).completedDays, {1, 2});
  });
  test('calendar state separates daily release, catch-up and year completion',
      () {
    const state = ProgressState(
        journeyStarted: true, unlockedThrough: 8, completedDays: {1, 2, 3});
    expect(state.todayLesson?.day, 8);
    expect(state.nextLesson?.day, 4);
    expect(state.isUnlocked(8), true);
    expect(state.isUnlocked(9), false);
    expect(state.allComplete, false);
    expect(state.caughtUp, false);
    final caughtUp =
        state.copyWith(completedDays: {for (var d = 1; d <= 8; d++) d});
    expect(caughtUp.caughtUp, true);
    expect(caughtUp.allComplete, false);
    expect(
        state.copyWith(
            unlockedThrough: 365,
            completedDays: {for (var d = 1; d <= 365; d++) d}).allComplete,
        true);
    expect(const ProgressState(catalog: []).fraction, 0);
  });
  test('future lessons stay locked and queued completion survives restart',
      () async {
    final store = MemoryStore(journey());
    final container = create(store);
    final service = container.read(progressProvider.notifier);
    await service.initialize();
    await service.completeDay(1);
    await service.completeDay(3);
    await service.completeDay(4);
    expect(container.read(progressProvider).completedDays, {1, 3});
    expect(container.read(progressProvider).pendingDays, {1, 3});
    final before = store.writes.length;
    await service.completeDay(1);
    expect(store.writes.length, before);
    final restarted = create(MemoryStore(store.values));
    await restarted.read(progressProvider.notifier).initialize();
    expect(restarted.read(progressProvider).completedDays, {1, 3});
    expect(restarted.read(progressProvider).nextLesson?.day, 2);
  });
  test('failed persistence does not complete and does not poison next retry',
      () async {
    final store = MemoryStore(journey())..writesAllowed = 0;
    final container = create(store);
    final service = container.read(progressProvider.notifier);
    await service.initialize();
    await expectLater(service.completeDay(1), throwsStateError);
    expect(container.read(progressProvider).completedDays, isEmpty);
    store.writesAllowed = null;
    await service.completeDay(1);
    expect(container.read(progressProvider).completedDays, {1});
  });
  test(
      'corrupt cache and the old development unlock do not start a paid journey',
      () async {
    final store = MemoryStore({
      'journey_cache': 'bad JSON',
      'paywall_lifetime_unlocked': true,
      'progress_completed_days': ['1', '2']
    });
    final container = create(store);
    await container.read(progressProvider.notifier).initialize();
    expect(container.read(progressProvider).journeyStarted, false);
    expect(container.read(progressProvider).completedDays, isEmpty);
    await container.read(progressProvider.notifier).completeDay(1);
    expect(container.read(progressProvider).completedDays, isEmpty);
  });
  test('all 365 real lessons participate in release and progress calculations',
      () {
    expect(lessons.length, 365);
    final almost = ProgressState(
        journeyStarted: true,
        unlockedThrough: 365,
        completedDays: {for (var d = 1; d < 365; d++) d});
    expect(almost.nextLesson?.day, 365);
    expect(almost.fraction, 364 / 365);
    expect(
        almost.copyWith(
            completedDays: {for (var d = 1; d <= 365; d++) d}).allComplete,
        true);
  });

  for (final corrupt in [false, true]) {
    test(
        'completion outbox survives ${corrupt ? 'corrupt' : 'missing'} journey '
        'cache and validates against server release', () async {
      final store = MemoryStore({
        if (corrupt) 'journey_cache': 'not valid JSON',
        'pending_completions': ['1', '3', '365', 'bad', '0']
      });
      final gateway = _Journey();
      final container = create(store, gateway: gateway);
      final service = container.read(progressProvider.notifier);
      await service.initialize();
      expect(container.read(progressProvider).pendingDays, {1, 3, 365});
      expect(container.read(progressProvider).completedDays, isEmpty);
      expect(container.read(progressProvider).journeyStarted, isFalse);
      gateway.server = {
        'started': true,
        'startDate': '2026-10-29',
        'timeZone': 'America/New_York',
        'unlockedThrough': 3,
        'completedDays': <int>[]
      };
      gateway.loadResponse.complete(gateway.server);
      await service.refresh();
      expect(gateway.completed, [1, 3]);
      expect(container.read(progressProvider).completedDays, {1, 3});
      expect(container.read(progressProvider).pendingDays, isEmpty);
      expect(container.read(progressProvider).isUnlocked(365), isFalse);
      expect(store.values['pending_completions'], isEmpty);
    });
  }
  test(
      'legacy completions added during a request drain without overwriting their outbox',
      () async {
    final store = MemoryStore(journey());
    final gateway = _DelayedJourney();
    gateway.server = {
      'started': true,
      'revision': 1,
      'unlockedThrough': 3,
      'startDate': '2026-10-29',
      'timeZone': 'America/New_York',
      'completedDays': <int>[]
    };
    final container = create(store, gateway: gateway);
    final service = container.read(progressProvider.notifier);
    await service.initialize();
    await service.completeDay(1);
    gateway.loadResponse.complete(gateway.server);
    await gateway.firstStarted.future;
    await service.completeDay(2);
    expect(container.read(progressProvider).pendingDays, {1, 2});
    gateway.firstResponse.complete({
      ...gateway.server,
      'completedDays': [1]
    });
    await service.refresh();
    expect(gateway.completed, [1, 2]);
    expect(container.read(progressProvider).completedDays, {1, 2});
    expect(container.read(progressProvider).pendingDays, isEmpty);
    expect(store.values['pending_completions'], isEmpty);
  });
}
