import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/data/readings.dart';
import 'package:holyher/models/learning.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/durable_store.dart';
import 'package:holyher/services/learning_service.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/features/home/lesson_presentation.dart';

const readingBadgeThresholds = [1, 7, 30, 90, 180, 365];

/// All reading writes are serialized per account and atomically committed with
/// the journey cache before the UI can report local acceptance.
class ReadingSyncState {
  final List<Map<String, dynamic>> pending;
  final String? error;
  final Set<int> pendingCheckpoints;
  const ReadingSyncState(
      {this.pending = const [],
      this.pendingCheckpoints = const {},
      this.error});
}

class ReadingSync extends Notifier<ReadingSyncState> {
  Future<void> _tail = Future.value();
  Future<void>? _loading, _syncing;
  int _generation = 0;
  String? _uid;
  final Set<int> _dirtyDays = {};
  bool _syncAgain = false;
  final Map<int, int> _cloudRevisions = {};
  final Map<int, Future<void>> _checkpointSends = {};
  @override
  ReadingSyncState build() {
    _uid = ref.watch(authProvider.select((s) => s.user?.uid));
    ref.watch(localStoreProvider);
    ref.watch(learningGatewayProvider);
    final generation = ++_generation;
    _tail = Future.value();
    _loading = null;
    _syncing = null;
    _dirtyDays.clear();
    _syncAgain = false;
    _cloudRevisions.clear();
    _checkpointSends.clear();
    ref.onDispose(() => _generation++);
    Future.microtask(() {
      if (generation == _generation) {
        unawaited(initialize().catchError((Object _) {}));
      }
    });
    return const ReadingSyncState();
  }

  Future<void> initialize() => _loading ??= _load();
  Future<void> _load() async {
    final generation = _generation;
    final store = ref.read(localStoreProvider);
    final raw = await store.read('reading_outbox_v1');
    final dirtyRaw = await store.read('reading_dirty_days');
    if (dirtyRaw != null && dirtyRaw is! List) {
      throw StateError('Reading places could not be read.');
    }
    if (generation != _generation) return;
    _dirtyDays.addAll((dirtyRaw as List? ?? const [])
        .whereType<String>()
        .map(int.tryParse)
        .whereType<int>()
        .where((d) => d >= 1 && d <= 365));
    if (generation != _generation) return;
    if (raw != null && raw is! String) {
      throw StateError('Reading outbox cannot be read.');
    }
    final list = raw == null ? <dynamic>[] : jsonDecode(raw as String);
    if (list is! List) throw StateError('Reading outbox cannot be read.');
    state = ReadingSyncState(
        pendingCheckpoints: Set.unmodifiable(_dirtyDays),
        pending: list.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    unawaited(sync());
  }

  Future<Map<String, dynamic>> open(int day, {bool scripture = false}) async {
    await initialize();
    final generation = _generation,
        revision = ref.read(progressProvider).revision;
    final store = ref.read(localStoreProvider);
    final raw = await store.read('reading_checkpoint_$day');
    Map<String, dynamic>? value;
    var cloudRevision = 0;
    if (raw is String && raw.isNotEmpty) {
      final parsed = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      cloudRevision = parsed['cloudRevision'] as int? ?? 0;
      if (parsed['journeyRevision'] == revision &&
          parsed['completed'] != true) {
        value = parsed;
      }
    }
    final gateway = ref.read(learningGatewayProvider);
    if (gateway != null && !(value?['dirty'] == true)) {
      try {
        final remote = await gateway.read('readingResumes/day-$day');
        if (remote != null && remote['journeyRevision'] == revision) {
          cloudRevision = remote['checkpointRevision'] as int? ?? 0;
          if (remote['cleared'] != true) {
            value = {
              ...Map<String, dynamic>.from(remote['checkpoint'] as Map),
              'cloudRevision': remote['checkpointRevision'],
              'dirty': false
            };
          } else {
            value = null;
          }
        }
      } catch (_) {
        /* Previously unlocked local readings remain available offline. */
      }
    }
    if (generation != _generation) throw StateError('Account changed.');
    // Legacy semantic resumes map to the new five cards. Their original bytes
    // remain available for the old outbox and account export.
    if (value == null) {
      var index = 0;
      final old = await store.read('lesson_resume_$day');
      if (old is String && old.isNotEmpty) {
        final legacy = jsonDecode(old) as Map;
        if ((legacy['attempt'] as Map?)?['journeyRevision'] == revision) {
          index = legacyReadingIndex(legacy['stepId'] as String?);
        }
      } else {
        final semantic = await store
            .read('card_position_${_uid ?? 'local'}_${day}_semantic');
        final numeric =
            await store.read('card_position_${_uid ?? 'local'}_$day');
        if (semantic is String) {
          index = legacyReadingIndex(
              (jsonDecode(semantic) as Map)['stepId'] as String?);
        } else if (numeric is int) {
          index = numeric.clamp(0, 4);
        }
      }
      value = {
        'version': readingContentVersion,
        'day': day,
        'journeyRevision': revision,
        'sessionId': newOperationId(),
        'checkpointId': newOperationId(),
        'cardIndex': index,
        'visited': List.generate(index + 1, (i) => i),
        'cloudRevision': cloudRevision,
        'dirty': true
      };
    }
    if (scripture) {
      value = {
        ...value,
        'cardIndex': 0,
        'visited': {...List<int>.from(value['visited'] as List), 0}.toList()
      };
    }
    _cloudRevisions[day] = value['cloudRevision'] as int? ?? 0;
    await checkpoint(value);
    return value;
  }

  Future<void> checkpoint(Map<String, dynamic> checkpoint) {
    final generation = _generation;
    return _tail = _tail.catchError((Object _) {}).then((_) async {
      if (generation != _generation) throw StateError('Account changed.');
      final value = {
        ...checkpoint,
        'checkpointId': newOperationId(),
        'dirty': true,
        'cloudRevision': _cloudRevisions[checkpoint['day']] ??
            checkpoint['cloudRevision'] ??
            0
      };
      final dirty = {..._dirtyDays, value['day'] as int};
      if (!await writeLocalBatch(ref.read(localStoreProvider), {
        'reading_checkpoint_${value['day']}': jsonEncode(value),
        'reading_dirty_days': dirty.map((d) => '$d').toList()
      })) {
        throw LocalStorageUnavailable();
      }
      if (generation != _generation) return;
      _dirtyDays.add(value['day'] as int);
      state = ReadingSyncState(
          pendingCheckpoints: Set.unmodifiable(_dirtyDays),
          pending: state.pending,
          error: state.error);
      if (generation != _generation) return;
      ref.read(readingPositionRevisionProvider.notifier).state++;
      // Local save is immediate; network checkpoints can be retried separately.
      unawaited(_scheduleCheckpoint(value['day'] as int, generation)
          .catchError((Object _) {}));
    });
  }

  Future<void> _scheduleCheckpoint(int day, int generation) {
    final existing = _checkpointSends[day];
    if (existing != null) return existing;
    final sending = _drainCheckpoint(day, generation).whenComplete(() {
      if (generation == _generation) _checkpointSends.remove(day);
    });
    _checkpointSends[day] = sending;
    return sending;
  }

  Future<void> _drainCheckpoint(int day, int generation) async {
    final gateway = ref.read(learningGatewayProvider);
    if (gateway == null) return;
    final store = ref.read(localStoreProvider);
    while (generation == _generation) {
      final raw = await store.read('reading_checkpoint_$day');
      if (generation != _generation || raw is! String) return;
      final value = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (value['dirty'] != true ||
          value['completed'] == true ||
          value['conflict'] == true) {
        return;
      }
      final result = await gateway.call('saveReadingCheckpoint', {
        'expectedRevision': _cloudRevisions[day] ?? value['cloudRevision'] ?? 0,
        'checkpoint': {...value}
          ..remove('dirty')
          ..remove('cloudRevision')
          ..remove('conflict')
      });
      if (generation != _generation) return;
      final accepted = result['accepted'] == true;
      if (accepted) _cloudRevisions[day] = result['checkpointRevision'] as int;
      await (_tail = _tail.catchError((Object _) {}).then((_) async {
        if (generation != _generation) return;
        final latestRaw = await store.read('reading_checkpoint_$day');
        if (latestRaw is! String || generation != _generation) return;
        final latest = Map<String, dynamic>.from(jsonDecode(latestRaw) as Map);
        if (latest['sessionId'] != value['sessionId']) return;
        if (accepted) {
          final isDirty = latest['checkpointId'] != value['checkpointId'] &&
              latest['completed'] != true;
          final dirty = {..._dirtyDays};
          if (!isDirty) dirty.remove(day);
          if (!await writeLocalBatch(store, {
            'reading_checkpoint_$day': jsonEncode({
              ...latest,
              'cloudRevision': _cloudRevisions[day],
              'dirty': isDirty
            }),
            'reading_dirty_days': dirty.map((d) => '$d').toList()
          })) {
            throw LocalStorageUnavailable();
          }
          if (generation != _generation) return;
          _dirtyDays
            ..clear()
            ..addAll(dirty);
          state = ReadingSyncState(
              pendingCheckpoints: Set.unmodifiable(_dirtyDays),
              pending: state.pending,
              error: state.error?.contains('another device') == true
                  ? state.error
                  : null);
        } else if (result['reason'] == 'conflict') {
          await store.write('reading_checkpoint_$day',
              jsonEncode({...latest, 'conflict': true}));
          if (generation != _generation) return;
          state = ReadingSyncState(
              pendingCheckpoints: Set.unmodifiable(_dirtyDays),
              pending: state.pending,
              error:
                  'This reading changed on another device. Choose which saved place to use.');
        }
      }));
      if (!accepted) return;
    }
  }

  Future<void> resolveCheckpoint(int day, {required bool useCloud}) async {
    final generation = _generation,
        gateway = ref.read(learningGatewayProvider),
        store = ref.read(localStoreProvider);
    if (gateway == null) throw StateError('Reconnect to resolve this reading.');
    final remote = await gateway.read('readingResumes/day-$day');
    final raw = await store.read('reading_checkpoint_$day');
    if (generation != _generation || raw is! String) {
      throw StateError('Account changed.');
    }
    final local = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    // Both choices are retained in the account export before the resolution.
    await store.write('reading_conflict_archive_$day',
        jsonEncode({'local': local, 'remote': remote}));
    if (generation != _generation) throw StateError('Account changed.');
    _cloudRevisions[day] = remote?['checkpointRevision'] as int? ?? 0;
    final chosen =
        useCloud && remote?['cleared'] != true && remote?['checkpoint'] is Map
            ? Map<String, dynamic>.from(remote!['checkpoint'] as Map)
            : local;
    await checkpoint(
        {...chosen, 'cloudRevision': _cloudRevisions[day], 'conflict': false});
    if (generation != _generation) throw StateError('Account changed.');
    state = ReadingSyncState(
        pendingCheckpoints: Set.unmodifiable(_dirtyDays),
        pending: state.pending);
  }

  Future<void> complete(Map<String, dynamic> checkpoint) {
    final generation = _generation;
    return _tail = _tail.catchError((Object _) {}).then((_) async {
      await initialize();
      if (generation != _generation) throw StateError('Account changed.');
      final day = checkpoint['day'] as int,
          progress = ref.read(progressProvider);
      final visited = Set<int>.from(checkpoint['visited'] as List);
      if (!progress.isUnlocked(day) ||
          checkpoint['journeyRevision'] != progress.revision ||
          !visited.containsAll([0, 1, 2, 3, 4])) {
        throw StateError('Visit all five cards before finishing.');
      }
      final date = ref.read(progressProvider.notifier).completionDateNow();
      final operation = {
        'operationId': newOperationId(),
        'sessionId': checkpoint['sessionId'],
        'day': day,
        'readDate': date,
        'contentVersion': readingContentVersion,
        'journeyRevision': progress.revision,
        'visited': [0, 1, 2, 3, 4]
      };
      final pending = [...state.pending, operation];
      final encoded =
          ref.read(progressProvider.notifier).journeyWithCompletion(day, date);
      final journey = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
      journey['readingDates'] = {...progress.readingDates, date}.toList();
      journey['earnedBadges'] = {
        ...progress.earnedBadges,
        ...readingBadgeThresholds
            .where((n) => {...progress.completedDays, day}.length >= n)
      }.toList();
      if (!await writeLocalBatch(ref.read(localStoreProvider), {
        'reading_outbox_v1': jsonEncode(pending),
        'reading_dirty_days':
            _dirtyDays.where((d) => d != day).map((d) => '$d').toList(),
        'journey_cache': jsonEncode(journey),
        'reading_checkpoint_$day':
            jsonEncode({...checkpoint, 'completed': true, 'dirty': false})
      })) {
        throw LocalStorageUnavailable();
      }
      if (generation != _generation) return;
      _dirtyDays.remove(day);
      state = ReadingSyncState(
          pendingCheckpoints: Set.unmodifiable(_dirtyDays), pending: pending);
      await ref.read(progressProvider.notifier).applyAttemptResult(journey);
      unawaited(sync());
    });
  }

  Future<void> reconcileReset(int revision) {
    final generation = _generation;
    return _tail = _tail.catchError((Object _) {}).then((_) async {
      await initialize();
      if (generation != _generation) return;
      final retained = state.pending
          .where((o) => (o['journeyRevision'] as int) >= revision)
          .toList();
      final archived = state.pending
          .where((o) => (o['journeyRevision'] as int) < revision)
          .toList();
      final dirty = <int>{};
      final store = ref.read(localStoreProvider);
      for (final day in _dirtyDays.toList()) {
        final raw = await store.read('reading_checkpoint_$day');
        if (generation != _generation) return;
        if (raw is String &&
            raw.isNotEmpty &&
            ((jsonDecode(raw) as Map)['journeyRevision'] as int? ?? 0) >=
                revision) {
          dirty.add(day);
        }
      }
      if (!await writeLocalBatch(ref.read(localStoreProvider), {
        'reading_dirty_days': dirty.map((d) => '$d').toList(),
        'reading_outbox_v1': jsonEncode(retained),
        if (archived.isNotEmpty)
          'reading_outbox_before_reset_$revision': jsonEncode(archived)
      })) {
        throw LocalStorageUnavailable();
      }
      if (generation == _generation) {
        _dirtyDays
          ..clear()
          ..addAll(dirty);
        state = ReadingSyncState(
            pendingCheckpoints: Set.unmodifiable(_dirtyDays),
            pending: retained);
      }
    });
  }

  Future<void> sync() {
    final existing = _syncing;
    if (existing != null) {
      _syncAgain = true;
      return existing;
    }
    final generation = _generation;
    return _syncing = _sync(generation).whenComplete(() {
      if (generation != _generation) return;
      _syncing = null;
      if (_syncAgain) {
        _syncAgain = false;
        unawaited(sync());
      }
    });
  }

  Future<void> _sync(int generation) async {
    // Initialization may invoke sync; wait for its state rather than recursively
    // awaiting initialization inside the initialization future.
    final gateway = ref.read(learningGatewayProvider);
    if (gateway == null) return;
    try {
      while (generation == _generation && state.pending.isNotEmpty) {
        final operation = state.pending.first;
        if (operation['journeyRevision'] !=
            ref.read(progressProvider).revision) {
          state = ReadingSyncState(
              pendingCheckpoints: Set.unmodifiable(_dirtyDays),
              pending: state.pending,
              error:
                  'A reading from before a progress reset is retained for export. Reopen the lesson to continue.');
          return;
        }
        final result = await gateway.call('completeReading', operation);
        if (generation != _generation) return;
        // Queue acknowledgement behind local acceptance: no delayed response
        // can overwrite a completion that was just committed offline.
        await (_tail = _tail.catchError((Object _) {}).then((_) async {
          if (generation != _generation) return;
          final remaining = state.pending
              .where((o) => o['operationId'] != operation['operationId'])
              .toList();
          if (!await ref
              .read(localStoreProvider)
              .write('reading_outbox_v1', jsonEncode(remaining))) {
            throw LocalStorageUnavailable();
          }
          if (generation != _generation) return;
          state = ReadingSyncState(
              pendingCheckpoints: Set.unmodifiable(_dirtyDays),
              pending: remaining);
          await ref.read(progressProvider.notifier).applyAttemptResult(result);
        }));
      }
      for (final day in _dirtyDays.toList()) {
        if (generation != _generation) return;
        await _scheduleCheckpoint(day, generation);
      }
    } catch (_) {
      if (generation == _generation) {
        state = ReadingSyncState(
            pendingCheckpoints: Set.unmodifiable(_dirtyDays),
            pending: state.pending,
            error: 'Saved on this device. Reconnect to sync your reading.');
      }
    }
  }
}

int legacyReadingIndex(String? id) => switch (id) {
      'opening' || 'verse' => 0,
      'understand' || 'reason' => 1,
      'question-1' || 'confidence' => 2,
      'hope' || 'question-2' => 3,
      'carry' || 'closing' => 4,
      _ => 0
    };
final readingSyncProvider =
    NotifierProvider<ReadingSync, ReadingSyncState>(ReadingSync.new);
