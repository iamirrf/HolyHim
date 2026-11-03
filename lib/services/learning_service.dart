import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/models/learning.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/durable_store.dart';
import 'package:holyher/services/progress_service.dart';

abstract interface class LearningGateway {
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data);
  Future<Map<String, dynamic>?> read(String path);
}

class FirebaseLearningGateway implements LearningGateway {
  final Ref ref;
  final String uid;
  FirebaseLearningGateway(this.ref, this.uid);
  void _check() {
    if (ref.read(authProvider).user?.uid != uid) {
      throw StateError('Account changed.');
    }
  }

  @override
  Future<Map<String, dynamic>> call(
      String name, Map<String, dynamic> data) async {
    _check();
    final result = await FirebaseFunctions.instance
        .httpsCallable(name)
        .call<Map<String, dynamic>>(data)
        .timeout(const Duration(seconds: 15));
    _check();
    return result.data;
  }

  @override
  Future<Map<String, dynamic>?> read(String path) async {
    _check();
    final result = await FirebaseFirestore.instance
        .doc('users/$uid/$path')
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 8));
    _check();
    return result.data();
  }
}

final learningGatewayProvider = Provider<LearningGateway?>((ref) {
  final uid = ref.watch(authProvider.select((s) => s.user?.uid));
  return uid == null || Firebase.apps.isEmpty
      ? null
      : FirebaseLearningGateway(ref, uid);
});

class AttemptSyncState {
  final List<LearningAttempt> pending;
  final String? _error;
  String? get error =>
      _error ??
      (rejected.isEmpty
          ? null
          : 'A saved attempt needs attention. Reopen the lesson or export your data for support.');
  final bool recoveryRequired;
  final Map<String, String> rejected;
  const AttemptSyncState(
      {this.pending = const [],
      String? error,
      this.recoveryRequired = false,
      this.rejected = const {}})
      : _error = error;
}

class AttemptSync extends Notifier<AttemptSyncState> {
  int _generation = 0;
  Future<void> _tail = Future.value();
  Future<void>? _loading, _syncing;
  @override
  AttemptSyncState build() {
    ref.watch(authProvider.select((s) => s.user?.uid));
    ref.watch(localStoreProvider);
    ref.watch(learningGatewayProvider);
    _generation++;
    _loading = null;
    _syncing = null;
    _tail = Future.value();
    ref.onDispose(() => _generation++);
    return const AttemptSyncState();
  }

  Future<void> initialize() => _loading ??= _load(_generation);
  Future<void> _load(int generation) async {
    try {
      final raw = await ref.read(localStoreProvider).read('attempt_outbox');
      if (generation != _generation) return;
      if (raw == null) return;
      if (raw is! String) throw const FormatException();
      final decoded = jsonDecode(raw);
      final rows = decoded is List ? decoded : decoded['attempts'];
      if (decoded is! List && decoded['schemaVersion'] != 2) {
        throw const FormatException();
      }
      final pending = [
        for (final row in rows)
          LearningAttempt.fromJson(Map<String, dynamic>.from(row))
      ];
      if (pending.map((a) => a.id).toSet().length != pending.length) {
        throw const FormatException();
      }
      state = AttemptSyncState(
          pending: pending,
          rejected: decoded is List
              ? const {}
              : Map<String, String>.from(decoded['rejected'] ?? {}));
      for (final attempt in pending) {
        if (attempt.journeyRevision == ref.read(progressProvider).revision) {
          ref.read(progressProvider.notifier).acceptAttemptLocally(attempt.day);
        }
      }
    } catch (error) {
      if (generation != _generation) return;
      state = AttemptSyncState(
          recoveryRequired: true,
          error: error is LocalStorageUnavailable
              ? 'Device storage is unavailable. Retry before changing learning data.'
              : 'Saved attempts could not be read. Retry or contact support before changing learning data.');
    }
  }

  Future<void> retryLoad() async {
    if (!state.recoveryRequired) return sync();
    _loading = null;
    await initialize();
  }

  String _encode(List<LearningAttempt> pending, Map<String, String> rejected) =>
      jsonEncode({
        'schemaVersion': 2,
        'attempts': pending.map((a) => a.toJson()).toList(),
        'rejected': rejected
      });
  Future<bool> _persist(LocalStore store, List<LearningAttempt> pending,
          Map<String, String> rejected) =>
      store.write('attempt_outbox', _encode(pending, rejected));

  Future<void> accept(LearningAttempt attempt) {
    final generation = _generation;
    return _tail = _tail.catchError((Object _) {}).then((_) async {
      await initialize();
      if (generation != _generation) throw StateError('Account changed.');
      if (state.recoveryRequired) throw StateError(state.error!);
      if (attempt.journeyRevision != ref.read(progressProvider).revision) {
        throw StateError('Your journey was reset. Reopen this lesson.');
      }
      final pending = [
        ...state.pending.where((a) => a.id != attempt.id),
        attempt
      ];
      final store = ref.read(localStoreProvider);
      final encoded = _encode(pending, state.rejected);
      final progress = ref.read(progressProvider.notifier),
          date = ref.read(progressProvider.notifier).completionDateNow();
      final saved = store is TransactionalLocalStore
          ? await store.writeBatch({
              'attempt_outbox': encoded,
              'lesson_resume_${attempt.day}': '',
              'journey_cache': progress.journeyWithCompletion(attempt.day, date)
            })
          : await store.write('attempt_outbox', encoded);
      if (!saved) {
        throw StateError('Your lesson could not be saved on this device.');
      }
      if (generation != _generation) return;
      state = AttemptSyncState(pending: pending, rejected: state.rejected);
      ref
          .read(progressProvider.notifier)
          .acceptAttemptLocally(attempt.day, date: date);
      unawaited(sync());
    });
  }

  Future<void> reconcileReset(int revision) {
    final generation = _generation, store = ref.read(localStoreProvider);
    return _tail = _tail.catchError((Object _) {}).then((_) async {
      await initialize();
      if (generation != _generation) throw StateError('Account changed.');
      if (state.recoveryRequired) throw StateError(state.error!);
      final pending =
          state.pending.where((a) => a.journeyRevision >= revision).toList();
      final rejected = Map<String, String>.from(state.rejected)
        ..removeWhere((id, _) => !pending.any((a) => a.id == id));
      if (!await _persist(store, pending, rejected)) {
        throw StateError('Reset cleanup could not be saved.');
      }
      if (generation != _generation) return;
      state = AttemptSyncState(pending: pending, rejected: rejected);
    });
  }

  Future<void> sync() {
    final generation = _generation;
    return _syncing ??= _sync(generation).whenComplete(() {
      if (generation == _generation) _syncing = null;
    });
  }

  Future<void> _sync(int generation) async {
    await initialize();
    if (generation != _generation || state.recoveryRequired) return;
    final gateway = ref.read(learningGatewayProvider),
        store = ref.read(localStoreProvider);
    if (gateway == null) return;
    while (generation == _generation) {
      final eligible = state.pending.where((a) =>
          a.journeyRevision == ref.read(progressProvider).revision &&
          !state.rejected.containsKey(a.id));
      if (eligible.isEmpty) return;
      final attempt = eligible.first;
      if (attempt.journeyRevision == ref.read(progressProvider).revision) {
        ref.read(progressProvider.notifier).acceptAttemptLocally(attempt.day);
      }
      // Stale work is retained for recovery/export but never sent to the new journey.
      if (attempt.journeyRevision != ref.read(progressProvider).revision) {
        continue;
      }
      try {
        final result =
            await gateway.call('completeLessonAttempt', attempt.toJson());
        if (generation != _generation) return;
        await ref.read(progressProvider.notifier).applyAttemptResult(result);
        if (generation != _generation) return;
        final previous = _tail;
        _tail = previous.catchError((Object _) {}).then((_) async {
          if (generation != _generation) return;
          final pending =
              state.pending.where((a) => a.id != attempt.id).toList();
          if (!await _persist(store, pending, state.rejected)) {
            throw StateError('Local acknowledgment failed.');
          }
          if (generation == _generation) {
            state =
                AttemptSyncState(pending: pending, rejected: state.rejected);
          }
        });
        await _tail;
      } catch (error) {
        if (generation != _generation) return;
        final code = error is FirebaseFunctionsException ? error.code : null;
        final permanent = const {
          'invalid-argument',
          'failed-precondition',
          'already-exists',
          'permission-denied',
          'not-found',
          'unimplemented'
        }.contains(code);
        if (permanent) {
          _tail = _tail.catchError((Object _) {}).then((_) async {
            if (generation != _generation) return;
            final rejected = {...state.rejected, attempt.id: code!};
            if (!await _persist(store, state.pending, rejected)) {
              throw StateError('Rejection could not be saved.');
            }
            if (generation != _generation) return;
            state = AttemptSyncState(
                pending: state.pending,
                rejected: rejected,
                error:
                    'A saved attempt needs attention. Reopen the lesson or export your data for support.');
          });
          try {
            await _tail;
          } catch (_) {
            return;
          }
          continue;
        }
        state = AttemptSyncState(
            pending: state.pending,
            rejected: state.rejected,
            error: code == 'unauthenticated'
                ? 'Saved on this device. Sign in again to synchronize your lessons.'
                : 'Saved on this device. Reconnect and retry synchronization.');
        return;
      }
    }
  }
}

final attemptSyncProvider =
    NotifierProvider<AttemptSync, AttemptSyncState>(AttemptSync.new);
