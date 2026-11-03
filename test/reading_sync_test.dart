import 'dart:convert';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/durable_store.dart';
import 'package:holyher/services/learning_service.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/reading_service.dart';
import 'package:holyher/services/reading_streak.dart';
import 'package:holyher/services/journey_clock.dart';

class _Store implements TransactionalLocalStore {
  final values = <String, Object>{};
  bool fail = false;
  Completer<void>? block;
  @override
  Future<Object?> read(String key) async => values[key];
  @override
  Future<bool> write(String key, Object value) => writeBatch({key: value});
  @override
  Future<bool> writeBatch(Map<String, Object> batch) async {
    if (block != null) await block!.future;
    if (fail) return false;
    values.addAll(batch);
    return true;
  }
}

class _Gateway implements LearningGateway {
  bool offline = true;
  int attempts = 0;
  Map<String, dynamic>? last;
  @override
  Future<Map<String, dynamic>> call(
      String name, Map<String, dynamic> data) async {
    if (name != 'saveReadingCheckpoint') {
      throw StateError('Unexpected operation');
    }
    attempts++;
    if (offline) throw StateError('Offline');
    last = data;
    return {'accepted': true, 'checkpointRevision': 1};
  }

  @override
  Future<Map<String, dynamic>?> read(String path) async => null;
}

class _Auth extends AuthNotifier {
  void change(String uid) {
    state = AuthState(user: AuthUser(uid: uid));
  }

  @override
  AuthState build() => const AuthState(user: AuthUser(uid: 'reading-test'));
}

class _Progress extends ProgressNotifier {
  @override
  ProgressState build() => const ProgressState(
      journeyStarted: true,
      unlockedThrough: 7,
      startDate: '2026-10-27',
      timeZone: 'America/New_York');
  @override
  Future<void> initialize() async {}
  @override
  Future<void> refresh() async {}
}

Map<String, dynamic> checkpoint({List<int> visited = const [0, 1, 2, 3, 4]}) =>
    {
      'version': 'walk-v1',
      'day': 1,
      'cardIndex': 4,
      'visited': visited,
      'sessionId': 'reading-session-test-0001',
      'journeyRevision': 1
    };
ProviderContainer _container(_Store store) => ProviderContainer(overrides: [
      authProvider.overrideWith(_Auth.new),
      progressProvider.overrideWith(_Progress.new),
      localStoreProvider.overrideWithValue(store),
      learningGatewayProvider.overrideWithValue(null),
      localClockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 2, 17))
    ]);
void main() {
  test(
      'offline acceptance atomically persists an answer-free retry and completion-derived streak',
      () async {
    final store = _Store();
    final scope = _container(store);
    addTearDown(scope.dispose);
    final reading = scope.read(readingSyncProvider.notifier);
    await reading.initialize();
    await reading.complete(checkpoint());
    expect(scope.read(progressProvider).completedDays, {1});
    expect(scope.read(progressProvider).earnedBadges, {1});
    expect(scope.read(readingStreakProvider).current, 1);
    final outbox =
        jsonDecode(store.values['reading_outbox_v1'] as String) as List;
    expect(outbox.length, 1);
    expect((outbox.single as Map).containsKey('selectedOptionIds'), isFalse);
    expect(
        (jsonDecode(store.values['journey_cache'] as String)
            as Map)['readingDates'],
        ['2026-11-02']);
  });
  test('incomplete cards and failed transactions cannot accept progress',
      () async {
    final store = _Store();
    final c = _container(store);
    addTearDown(c.dispose);
    final reading = c.read(readingSyncProvider.notifier);
    await reading.initialize();
    await expectLater(
        reading.complete(checkpoint(visited: [0, 1, 2, 3])), throwsStateError);
    store.fail = true;
    await expectLater(reading.complete(checkpoint()), throwsStateError);
    expect(store.values['reading_outbox_v1'], isNull);
    expect(c.read(progressProvider).completedDays, isEmpty);
    store.fail = false;
    await reading.complete(checkpoint());
    expect(c.read(progressProvider).completedDays, {1});
  });
  test('rereads do not inflate distinct lesson progress or same-day streaks',
      () async {
    final store = _Store();
    final scope = _container(store);
    addTearDown(scope.dispose);
    final reading = scope.read(readingSyncProvider.notifier);
    await reading.initialize();
    await reading.complete(checkpoint());
    await reading.complete(checkpoint());
    expect(scope.read(progressProvider).completedCount, 1);
    expect(scope.read(readingStreakProvider).current, 1);
    expect(scope.read(progressProvider).earnedBadges, {1});
    await reading.reconcileReset(2);
    expect(scope.read(readingSyncProvider).pending, isEmpty);
    expect(store.values['reading_outbox_before_reset_2'], isNotNull);
  });
  test('an in-flight old-account checkpoint cannot mark the next account dirty',
      () async {
    final a = _Store(), b = _Store();
    final c = ProviderContainer(overrides: [
      authProvider.overrideWith(_Auth.new),
      progressProvider.overrideWith(_Progress.new),
      learningGatewayProvider.overrideWithValue(null),
      localStoreProvider.overrideWith(
          (ref) => ref.watch(authProvider).user?.uid == 'reading-test' ? a : b)
    ]);
    addTearDown(c.dispose);
    final reading = c.read(readingSyncProvider.notifier);
    await reading.initialize();
    a.block = Completer<void>();
    final pending = reading.checkpoint(checkpoint());
    await Future<void>.delayed(Duration.zero);
    (c.read(authProvider.notifier) as _Auth).change('next-account');
    c.read(readingSyncProvider);
    a.block!.complete();
    await pending;
    await Future<void>.delayed(Duration.zero);
    expect(c.read(readingSyncProvider).pendingCheckpoints, isEmpty);
    expect(b.values['reading_checkpoint_1'], isNull);
  });
  test(
      'a persisted offline position retries on resume without reopening the reading',
      () async {
    final store = _Store();
    store.values['reading_dirty_days'] = ['1'];
    store.values['reading_checkpoint_1'] = jsonEncode({
      ...checkpoint(visited: [0, 1]),
      'cardIndex': 1,
      'checkpointId': 'offline-position-0001',
      'dirty': true,
      'cloudRevision': 0,
    });
    final gateway = _Gateway();
    final scope = ProviderContainer(overrides: [
      authProvider.overrideWith(_Auth.new),
      progressProvider.overrideWith(_Progress.new),
      localStoreProvider.overrideWithValue(store),
      learningGatewayProvider.overrideWithValue(gateway),
    ]);
    addTearDown(scope.dispose);
    final reading = scope.read(readingSyncProvider.notifier);
    await reading.initialize();
    await reading.sync();
    await Future<void>.delayed(Duration.zero);
    expect(scope.read(readingSyncProvider).pendingCheckpoints, {1});
    expect(scope.read(progressProvider).completedDays, isEmpty);
    gateway.offline = false;
    await reading.sync();
    await Future<void>.delayed(Duration.zero);
    expect(gateway.last?['checkpoint']['cardIndex'], 1);
    expect(scope.read(readingSyncProvider).pendingCheckpoints, isEmpty);
    final saved = jsonDecode(store.values['reading_checkpoint_1'] as String);
    expect(saved['dirty'], false);
    expect(saved['cloudRevision'], 1);
    expect(store.values['reading_dirty_days'], isEmpty);
  });
}
