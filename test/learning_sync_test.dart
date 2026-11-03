import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/data/teaching.dart';
import 'package:holyher/models/learning.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/learning_service.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/saved_service.dart';
import 'support.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(user: AuthUser(uid: 'alice'));
  void switchTo(String uid) {
    state = AuthState(user: AuthUser(uid: uid));
  }
}

class _Progress extends ProgressNotifier {
  @override
  ProgressState build() {
    ref.watch(authProvider.select((s) => s.user?.uid));
    return const ProgressState(journeyStarted: true, unlockedThrough: 5);
  }

  @override
  Future<void> initialize() async {}
}

class _Gateway implements LearningGateway {
  final calls = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? response;
  @override
  Future<Map<String, dynamic>?> read(String path) async => null;
  @override
  Future<Map<String, dynamic>> call(
      String name, Map<String, dynamic> data) async {
    calls.add({'name': name, ...data});
    if (response != null) return await response!.future;
    return {
      'started': true,
      'revision': 1,
      'unlockedThrough': 5,
      'completedDays': [1]
    };
  }
}

class _ControlledGateway implements LearningGateway {
  final calls = <Map<String, dynamic>>[];
  Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)? onCall;
  Future<Map<String, dynamic>?> Function()? onRead;
  @override
  Future<Map<String, dynamic>?> read(String path) async =>
      onRead == null ? null : await onRead!();
  @override
  Future<Map<String, dynamic>> call(
      String name, Map<String, dynamic> data) async {
    calls.add({'name': name, ...data});
    return onCall == null ? <String, dynamic>{} : await onCall!(name, data);
  }
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

LearningAttempt attempt([int day = 1]) {
  var value = LearningAttempt.create(
      day, 1, teachingVersion, teachingCatalog[day]!.questions);
  for (final q in teachingCatalog[day]!.questions) {
    value = value.answer(q.id, q.options[1].id);
  }
  return value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ProviderContainer setup(MemoryStore store, {LearningGateway? gateway}) =>
      ProviderContainer(overrides: [
        authProvider.overrideWith(_Auth.new),
        progressProvider.overrideWith(_Progress.new),
        localStoreProvider.overrideWithValue(store),
        learningGatewayProvider.overrideWithValue(gateway)
      ]);
  test(
      'answer IDs and shuffled option order roundtrip and first selection locks',
      () {
    final original = attempt();
    final restored = LearningAttempt.fromJson(original.toJson());
    expect(restored.optionOrder, original.optionOrder);
    expect(restored.selected, original.selected);
    final q = teachingCatalog[1]!.questions.first;
    expect(restored.answer(q.id, q.options.first.id).selected[q.id],
        q.options[1].id);
  });
  test('a failed local write never announces a completed lesson', () async {
    final store = MemoryStore()..writesAllowed = 0;
    final container = setup(store);
    addTearDown(container.dispose);
    await expectLater(
        container.read(attemptSyncProvider.notifier).accept(attempt()),
        throwsStateError);
    expect(container.read(progressProvider).completedDays, isEmpty);
    expect(container.read(attemptSyncProvider).pending, isEmpty);
  });
  test('accepted offline attempts survive a new service instance and sync once',
      () async {
    final store = MemoryStore();
    final first = setup(store);
    final value = attempt();
    await first.read(attemptSyncProvider.notifier).accept(value);
    expect(first.read(progressProvider).completedDays, {1});
    first.dispose();
    final gateway = _Gateway(), second = setup(store, gateway: gateway);
    addTearDown(second.dispose);
    await second.read(attemptSyncProvider.notifier).sync();
    expect(gateway.calls.single['attemptId'], value.id);
    expect(second.read(attemptSyncProvider).pending, isEmpty);
    expect(second.read(progressProvider).completedDays, {1});
    await second.read(attemptSyncProvider.notifier).sync();
    expect(gateway.calls.length, 1);
  });
  test('a late attempt acknowledgment cannot enter a different account',
      () async {
    final stores = {'alice': MemoryStore(), 'bob': MemoryStore()},
        gateway = _Gateway()..response = Completer();
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_Auth.new),
      progressProvider.overrideWith(_Progress.new),
      localStoreProvider
          .overrideWith((ref) => stores[ref.watch(authProvider).user!.uid]!),
      learningGatewayProvider.overrideWithValue(gateway)
    ]);
    addTearDown(container.dispose);
    await container.read(attemptSyncProvider.notifier).accept(attempt());
    await Future<void>.delayed(Duration.zero);
    (container.read(authProvider.notifier) as _Auth).switchTo('bob');
    expect(container.read(attemptSyncProvider).pending, isEmpty);
    expect(container.read(progressProvider).completedDays, isEmpty);
    gateway.response!.complete({
      'started': true,
      'revision': 1,
      'unlockedThrough': 5,
      'completedDays': [1]
    });
    await Future<void>.delayed(Duration.zero);
    expect(container.read(progressProvider).completedDays, isEmpty);
    expect(stores['bob']!.values['attempt_outbox'], isNull);
  });
  test('offline bookmark additions and removals survive restart as tombstones',
      () async {
    final store = MemoryStore(), first = setup(MemoryStore());
    first.dispose();
    final a = setup(store);
    await a.read(savedProvider.notifier).setSaved(1, true);
    await a.read(savedProvider.notifier).setSaved(2, true);
    await a.read(savedProvider.notifier).setSaved(1, false);
    a.dispose();
    final b = setup(store);
    addTearDown(b.dispose);
    await b.read(savedProvider.notifier).initialize();
    expect(b.read(savedProvider).days.keys, {2});
    expect(b.read(savedProvider).pending, {1: false, 2: true});
  });
  test('work added during synchronization drains and retains local completions',
      () async {
    final response = Completer<Map<String, dynamic>>();
    final gateway = _ControlledGateway();
    gateway.onCall = (_, data) async => gateway.calls.length == 1
        ? await response.future
        : {
            'started': true,
            'revision': 1,
            'unlockedThrough': 5,
            'completedDays': [1, 2]
          };
    final container = setup(MemoryStore(), gateway: gateway);
    addTearDown(container.dispose);
    final service = container.read(attemptSyncProvider.notifier);
    await service.accept(attempt());
    await settle();
    await service.accept(attempt(2));
    await container.read(progressProvider.notifier).applyAttemptResult({
      'started': true,
      'revision': 1,
      'unlockedThrough': 5,
      'completedDays': [1]
    });
    expect(container.read(progressProvider).completedDays, {1, 2});
    response.complete({
      'started': true,
      'revision': 1,
      'unlockedThrough': 5,
      'completedDays': [1]
    });
    await service.sync();
    expect(gateway.calls.map((call) => call['day']), [1, 2]);
    expect(container.read(attemptSyncProvider).pending, isEmpty);
  });

  test('lost local acknowledgment retries the same accepted attempt ID',
      () async {
    final store = MemoryStore();
    final gateway = _ControlledGateway();
    gateway.onCall = (_, data) async {
      store.writesAllowed = 0;
      return {
        'started': true,
        'revision': 1,
        'unlockedThrough': 5,
        'completedDays': [1]
      };
    };
    final container = setup(store, gateway: gateway);
    addTearDown(container.dispose);
    final service = container.read(attemptSyncProvider.notifier),
        value = attempt();
    await service.accept(value);
    await service.sync();
    expect(container.read(attemptSyncProvider).pending.single.id, value.id);
    store.writesAllowed = null;
    gateway.onCall = (_, data) async => {
          'started': true,
          'revision': 1,
          'unlockedThrough': 5,
          'completedDays': [1]
        };
    await service.sync();
    expect(
        gateway.calls.map((call) => call['attemptId']), [value.id, value.id]);
    expect(container.read(attemptSyncProvider).pending, isEmpty);
  });

  test('permanent rejection is retained for export without blocking other work',
      () async {
    final gateway = _ControlledGateway();
    gateway.onCall = (_, data) async {
      if (data['day'] == 1) {
        throw FirebaseFunctionsException(
            code: 'invalid-argument', message: 'content-version');
      }
      return {
        'started': true,
        'revision': 1,
        'unlockedThrough': 5,
        'completedDays': [2]
      };
    };
    final store = MemoryStore(), container = setup(store, gateway: gateway);
    addTearDown(container.dispose);
    final service = container.read(attemptSyncProvider.notifier),
        value = attempt();
    await service.accept(value);
    await service.sync();
    await service.accept(attempt(2));
    await service.sync();
    expect(container.read(attemptSyncProvider).pending.single.id, value.id);
    expect(container.read(attemptSyncProvider).rejected[value.id],
        'invalid-argument');
    await service.sync();
    expect(gateway.calls.length, 2);
    expect(
        jsonDecode(store.values['attempt_outbox'] as String)['rejected']
            [value.id],
        'invalid-argument');
  });

  test(
      'corrupt records cannot be overwritten by local edits or synchronization',
      () async {
    for (final raw in ['broken-json', '{"schemaVersion":99}', 42]) {
      final store = MemoryStore({'attempt_outbox': raw, 'saved_lessons': raw});
      final gateway = _ControlledGateway(),
          container = setup(store, gateway: gateway);
      final attempts = container.read(attemptSyncProvider.notifier),
          saved = container.read(savedProvider.notifier);
      await attempts.initialize();
      await saved.initialize();
      await expectLater(attempts.accept(attempt()), throwsStateError);
      await expectLater(saved.setSaved(1, true), throwsStateError);
      await attempts.sync();
      await saved.sync();
      expect(store.values['attempt_outbox'], raw);
      expect(store.values['saved_lessons'], raw);
      expect(gateway.calls, isEmpty);
      expect(container.read(attemptSyncProvider).recoveryRequired, true);
      expect(container.read(savedProvider).recoveryRequired, true);
      container.dispose();
    }
  });

  test('save remove save acknowledges its exact operation and drains new work',
      () async {
    final first = Completer<Map<String, dynamic>>();
    final gateway = _ControlledGateway();
    gateway.onCall = (_, data) async =>
        gateway.calls.length == 1 ? await first.future : {'savedAt': 123456};
    final store = MemoryStore(), container = setup(store, gateway: gateway);
    addTearDown(container.dispose);
    final service = container.read(savedProvider.notifier);
    await service.setSaved(1, true);
    await settle();
    final firstId = gateway.calls.single['operationId'];
    await service.setSaved(1, false);
    await service.setSaved(1, true);
    final latestId = container.read(savedProvider).operationIds[1];
    expect(latestId, isNot(firstId));
    first.complete({'savedAt': 1});
    await service.sync();
    expect(gateway.calls.length, 2);
    expect(gateway.calls.last['operationId'], latestId);
    expect(container.read(savedProvider).pending, isEmpty);
    expect(container.read(savedProvider).days[1], 123456);
    final restored = setup(store);
    addTearDown(restored.dispose);
    await restored.read(savedProvider.notifier).initialize();
    expect(restored.read(savedProvider).days[1], 123456);
  });

  test('a delayed bookmark read preserves a newly accepted local mutation',
      () async {
    final read = Completer<Map<String, dynamic>?>();
    final gateway = _ControlledGateway()..onRead = () => read.future;
    gateway.onCall = (_, data) async => {'savedAt': 77};
    final container = setup(MemoryStore(), gateway: gateway);
    addTearDown(container.dispose);
    final service = container.read(savedProvider.notifier);
    await service.initialize();
    await settle();
    await service.setSaved(2, true);
    read.complete({
      'days': {'1': 22, '2': null}
    });
    await service.sync();
    expect(container.read(savedProvider).days, {1: 22, 2: 77});
  });

  test('a stale server response cannot restore progress after a reset',
      () async {
    final container = setup(MemoryStore());
    addTearDown(container.dispose);
    await container.read(progressProvider.notifier).applyAttemptResult({
      'started': true,
      'revision': 2,
      'unlockedThrough': 5,
      'completedDays': <int>[]
    });
    await container.read(progressProvider.notifier).applyAttemptResult({
      'started': true,
      'revision': 1,
      'unlockedThrough': 5,
      'completedDays': [1]
    });
    expect(container.read(progressProvider).revision, 2);
    expect(container.read(progressProvider).completedDays, isEmpty);
  });
  test(
      'resume reconciliation uses server revisions across practice attempts and preserves offline answers',
      () {
    final value = attempt();
    final local = LessonResume(
        stepId: 'question-2',
        renderedPart: 2,
        attempt: value,
        checkpointId: 'local-checkpoint-000001',
        checkpointRevision: 4,
        pending: true);
    final remote = LessonResume(
        stepId: 'verse',
        attempt: attempt(),
        checkpointId: 'remote-checkpoint-000001',
        checkpointRevision: 5);
    expect(selectLessonResume(local, remote, serverRevision: 4), same(local));
    expect(selectLessonResume(local, remote, serverRevision: 5), same(remote));
    expect(selectLessonResume(local, null, serverRevision: 5, cleared: true),
        isNull);
    final restored = LessonResume.fromJson(local.toJson());
    expect(restored.attempt.optionOrder, value.optionOrder);
    expect(restored.attempt.selected, value.selected);
    expect(restored.renderedPart, 2);
    expect(restored.checkpointId, local.checkpointId);
    expect(restored.pending, true);
  });
}
