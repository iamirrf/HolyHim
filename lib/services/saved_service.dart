import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/models/learning.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/learning_service.dart';

class SavedState {
  final Map<int, int> days;
  final Map<int, bool> pending;
  final Map<int, String> operationIds;
  final bool loading, recoveryRequired;
  final String? error;
  const SavedState(
      {this.days = const {},
      this.pending = const {},
      this.operationIds = const {},
      this.loading = true,
      this.recoveryRequired = false,
      this.error});
}

class SavedNotifier extends Notifier<SavedState> {
  int _generation = 0;
  Future<void>? _loading, _syncing;
  Future<void> _tail = Future.value();
  @override
  SavedState build() {
    ref.watch(authProvider.select((s) => s.user?.uid));
    ref.watch(localStoreProvider);
    ref.watch(learningGatewayProvider);
    final generation = ++_generation;
    _loading = null;
    _syncing = null;
    _tail = Future.value();
    ref.onDispose(() => _generation++);
    Future.microtask(() {
      if (generation == _generation) initialize();
    });
    return const SavedState();
  }

  Future<void> initialize() => _loading ??= _load(_generation);
  Future<void> _load(int generation) async {
    try {
      final raw = await ref.read(localStoreProvider).read('saved_lessons');
      if (generation != _generation) return;
      if (raw != null && raw is! String) throw const FormatException();
      final data =
          raw == null ? <String, dynamic>{} : jsonDecode(raw as String);
      if (data is! Map || (data['schemaVersion'] ?? 1) > 2) {
        throw const FormatException();
      }
      final days = (data['days'] as Map? ?? {})
          .map((k, v) => MapEntry(int.parse(k), v as int));
      final pending = (data['pending'] as Map? ?? {})
          .map((k, v) => MapEntry(int.parse(k), v as bool));
      final ids = (data['operationIds'] as Map? ?? {})
          .map((k, v) => MapEntry(int.parse(k), v as String));
      if ([...days.keys, ...pending.keys].any((day) => day < 1 || day > 365)) {
        throw const FormatException();
      }
      // Version 1 mutations receive durable identities before any network send.
      for (final day in pending.keys) {
        ids.putIfAbsent(day, newOperationId);
      }
      if (pending.isNotEmpty &&
          !await _persist(ref.read(localStoreProvider), days, pending, ids)) {
        throw LocalStorageUnavailable();
      }
      if (generation != _generation) return;
      state = SavedState(
          days: days, pending: pending, operationIds: ids, loading: false);
      unawaited(sync());
    } catch (error) {
      if (generation != _generation) return;
      // Keep the original bytes untouched. An ordinary edit must never replace
      // an unreadable outbox with an empty one.
      state = SavedState(
          loading: false,
          recoveryRequired: true,
          error: error is LocalStorageUnavailable
              ? 'Device storage is unavailable. Retry before changing saved items.'
              : 'Saved lessons could not be read. Retry or contact support before changing saved items.');
    }
  }

  Future<void> retryLoad() async {
    if (!state.recoveryRequired) return sync();
    _loading = null;
    await initialize();
  }

  Future<bool> _persist(LocalStore store, Map<int, int> days,
          Map<int, bool> pending, Map<int, String> ids) =>
      store.write(
          'saved_lessons',
          jsonEncode({
            'schemaVersion': 2,
            'days': days.map((k, v) => MapEntry('$k', v)),
            'pending': pending.map((k, v) => MapEntry('$k', v)),
            'operationIds': ids.map((k, v) => MapEntry('$k', v))
          }));

  Future<void> setSaved(int day, bool saved) {
    final generation = _generation;
    final store = ref.read(localStoreProvider);
    return _tail = _tail.catchError((Object _) {}).then((_) async {
      await initialize();
      if (generation != _generation) throw StateError('Account changed.');
      if (state.recoveryRequired) throw StateError(state.error!);
      if (day < 1 || day > 365) throw ArgumentError.value(day, 'day');
      final days = {...state.days}, pending = {...state.pending, day: saved};
      final ids = {...state.operationIds, day: newOperationId()};
      if (saved) {
        days[day] = DateTime.now().millisecondsSinceEpoch;
      } else {
        days.remove(day);
      }
      if (!await _persist(store, days, pending, ids)) {
        throw StateError('This change could not be saved. Please retry.');
      }
      if (generation != _generation) throw StateError('Account changed.');
      state = SavedState(
          days: days, pending: pending, operationIds: ids, loading: false);
      unawaited(sync());
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
    try {
      final remote = await gateway.read('private/savedCatalog');
      if (generation != _generation) return;
      // Merge and persistence share the local edit queue. No stale snapshot can
      // overwrite an edit that was accepted while the read was in flight.
      _tail = _tail.catchError((Object _) {}).then((_) async {
        if (generation != _generation) return;
        final merged = {...state.days};
        for (final entry in (remote?['days'] as Map? ?? {}).entries) {
          final day = int.tryParse(entry.key);
          if (day == null ||
              day < 1 ||
              day > 365 ||
              state.pending.containsKey(day)) {
            continue;
          }
          if (entry.value is int) {
            merged[day] = entry.value;
          } else {
            merged.remove(day);
          }
        }
        if (!await _persist(store, merged, state.pending, state.operationIds)) {
          throw StateError('Refresh could not be saved.');
        }
        if (generation != _generation) return;
        state = SavedState(
            days: merged,
            pending: state.pending,
            operationIds: state.operationIds,
            loading: false);
      });
      await _tail;
      while (generation == _generation && state.pending.isNotEmpty) {
        final day = state.pending.keys.first;
        final saved = state.pending[day]!;
        final id = state.operationIds[day]!;
        final result = await gateway.call(
            'setSavedLesson', {'day': day, 'saved': saved, 'operationId': id});
        if (generation != _generation) return;
        _tail = _tail.catchError((Object _) {}).then((_) async {
          if (generation != _generation) return;
          final pending = {...state.pending},
              ids = {...state.operationIds},
              days = {...state.days};
          // Boolean equality is insufficient for save → remove → save.
          if (ids[day] == id) {
            pending.remove(day);
            ids.remove(day);
            if (saved && result['savedAt'] is int) {
              days[day] = result['savedAt'];
            }
          }
          if (!await _persist(store, days, pending, ids)) {
            throw StateError('Acknowledgment failed.');
          }
          if (generation != _generation) return;
          state = SavedState(
              days: days, pending: pending, operationIds: ids, loading: false);
        });
        await _tail;
      }
    } catch (_) {
      if (generation == _generation) {
        state = SavedState(
            days: state.days,
            pending: state.pending,
            operationIds: state.operationIds,
            loading: false,
            error:
                'Your saved lessons are here. Reconnect and retry synchronization.');
      }
    }
  }
}

final savedProvider =
    NotifierProvider<SavedNotifier, SavedState>(SavedNotifier.new);
