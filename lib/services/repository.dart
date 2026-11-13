import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import '../domain/calendar.dart';
import '../domain/pacing.dart';
import 'auth_service.dart';
import 'migration.dart';
import 'firebase_runtime.dart';
import 'account_cache.dart';

const _keep = Object();
const _deviceWriteError =
    'Your changes could not be saved on this device. Please try again.';
const _cloudSyncError =
    'Some changes could not sync. Reopen HolyHim when connected to try again.';
DateTime? profileDate(Object? value) => value is Timestamp
    ? value.toDate()
    : value is DateTime
        ? value
        : value is String
            ? DateTime.tryParse(value)
            : null;

class AppProfile {
  final String name, theme, timeZone, username;
  final String? birthday, avatarUrl;
  final Map<String, dynamic> onboardingDraft;
  final List<String> hearts;
  final bool reminderEnabled, haptics, sounds;
  final int reminderMinutes;
  final double readingScale;
  final DateTime? promiseStartedAt, onboardedAt, migratedAt;
  final DateTime createdAt, updatedAt;
  AppProfile(
      {this.name = '',
      this.username = '',
      this.birthday,
      this.avatarUrl,
      this.onboardingDraft = const {},
      this.hearts = const [],
      this.reminderEnabled = false,
      this.reminderMinutes = 420,
      this.theme = 'blush',
      this.readingScale = 1,
      this.haptics = true,
      this.sounds = false,
      this.promiseStartedAt,
      this.onboardedAt,
      this.timeZone = 'UTC',
      DateTime? createdAt,
      DateTime? updatedAt,
      this.migratedAt})
      : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();
  bool get onboarded => onboardedAt != null;
  AppProfile copyWith(
          {String? name,
          String? username,
          Object? birthday = _keep,
          Object? avatarUrl = _keep,
          Map<String, dynamic>? onboardingDraft,
          List<String>? hearts,
          bool? reminderEnabled,
          int? reminderMinutes,
          String? theme,
          double? readingScale,
          bool? haptics,
          bool? sounds,
          String? timeZone,
          Object? promiseStartedAt = _keep,
          Object? onboardedAt = _keep,
          Object? migratedAt = _keep,
          DateTime? updatedAt}) =>
      AppProfile(
          name: name ?? this.name,
          username: username ?? this.username,
          birthday:
              identical(birthday, _keep) ? this.birthday : birthday as String?,
          avatarUrl: identical(avatarUrl, _keep)
              ? this.avatarUrl
              : avatarUrl as String?,
          onboardingDraft: onboardingDraft ?? this.onboardingDraft,
          hearts: hearts ?? this.hearts,
          reminderEnabled: reminderEnabled ?? this.reminderEnabled,
          reminderMinutes: reminderMinutes ?? this.reminderMinutes,
          theme: theme ?? this.theme,
          readingScale: readingScale ?? this.readingScale,
          haptics: haptics ?? this.haptics,
          sounds: sounds ?? this.sounds,
          timeZone: timeZone ?? this.timeZone,
          promiseStartedAt: identical(promiseStartedAt, _keep)
              ? this.promiseStartedAt
              : promiseStartedAt as DateTime?,
          onboardedAt: identical(onboardedAt, _keep)
              ? this.onboardedAt
              : onboardedAt as DateTime?,
          migratedAt: identical(migratedAt, _keep)
              ? this.migratedAt
              : migratedAt as DateTime?,
          createdAt: createdAt,
          updatedAt: updatedAt ?? DateTime.now());
  Map<String, dynamic> toFirestore() => {
        'schema': 6,
        'username': username,
        'birthday': birthday,
        'avatarUrl': avatarUrl,
        'onboardingDraft': onboardingDraft,
        'name': name.trim(),
        'hearts': hearts.take(3).toList(),
        'reminder': {'enabled': reminderEnabled, 'minutes': reminderMinutes},
        'theme': theme,
        'readingScale': readingScale,
        'haptics': haptics,
        'sounds': sounds,
        'promise': {'startedAt': promiseStartedAt},
        'timeZone': timeZone,
        'onboardedAt': onboardedAt,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        if (migratedAt != null) 'migratedAt': migratedAt
      };
  factory AppProfile.fromFirestore(Map<String, dynamic> data,
      {String name = ''}) {
    final reminder =
        data['reminder'] is Map ? data['reminder'] as Map : const {};
    final promise = data['promise'] is Map ? data['promise'] as Map : const {};
    final focus = data['focus'];
    final hearts = data['hearts'] is List
        ? (data['hearts'] as List).whereType<String>().take(3).toList()
        : focus is String && focus.isNotEmpty
            ? [focus[0].toUpperCase() + focus.substring(1)]
            : <String>[];
    return AppProfile(
        name: data['name'] is String ? data['name'] : name,
        username: data['username'] as String? ?? '',
        birthday: data['birthday'] as String?,
        avatarUrl: data['avatarUrl'] as String?,
        onboardingDraft: data['onboardingDraft'] is Map
            ? Map<String, dynamic>.from(data['onboardingDraft'])
            : const {},
        hearts: hearts,
        reminderEnabled:
            reminder['enabled'] as bool? ?? data['reminderMinutes'] is int,
        reminderMinutes:
            ((reminder['minutes'] ?? data['reminderMinutes']) as num?)
                    ?.toInt()
                    .clamp(0, 1439) ??
                420,
        theme: switch (data['theme']) {
          'midnight' => 'midnight-rose',
          'dawn' => 'sunrise',
          final String value => value,
          _ => 'blush'
        },
        readingScale:
            (data['readingScale'] as num?)?.toDouble().clamp(1, 2) ?? 1,
        haptics: data['haptics'] as bool? ?? true,
        sounds: data['sounds'] as bool? ?? false,
        promiseStartedAt: profileDate(promise['startedAt']),
        onboardedAt: profileDate(data['onboardedAt']) ??
            (data['onboardingComplete'] == true ? DateTime.now() : null),
        createdAt: profileDate(data['createdAt']),
        updatedAt: profileDate(data['updatedAt']),
        migratedAt: profileDate(data['migratedAt']),
        timeZone: data['timeZone'] as String? ?? 'UTC');
  }
}

class WalkState {
  final AppProfile profile;
  final Map<int, String> completed;
  final Map<int, DateTime> saved;
  final bool syncing, ready;
  final String? syncError;
  WalkState(
      {AppProfile? profile,
      this.completed = const {},
      this.saved = const {},
      this.syncing = false,
      this.ready = true,
      this.syncError})
      : profile = profile ?? AppProfile();
  WalkState copyWith(
          {AppProfile? profile,
          Map<int, String>? completed,
          Map<int, DateTime>? saved,
          bool? syncing,
          bool? ready,
          Object? syncError = _keep}) =>
      WalkState(
          profile: profile ?? this.profile,
          completed: completed ?? this.completed,
          saved: saved ?? this.saved,
          syncing: syncing ?? this.syncing,
          ready: ready ?? this.ready,
          syncError: identical(syncError, _keep)
              ? this.syncError
              : syncError as String?);
}

/// Call once after Firebase initialization and before creating any document refs.
/// FlutterFire uses persistentLocalCache + persistentMultipleTabManager on web.
void configureFirestoreCache() {
  if (Firebase.apps.isEmpty) return;
  FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      webPersistentTabManager: WebPersistentMultipleTabManager());
}

/// Injectable SDK boundary lets tests hold real write receipts indefinitely.
final repositoryFirestoreProvider = Provider<FirebaseFirestore?>((ref) {
  final ready = ref.watch(firebaseReadyProvider);
  return ready && Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null;
});

typedef AccountMigration = Future<void> Function(
    FirebaseFirestore db, String uid, Map<String, dynamic> profile);
final accountMigrationProvider =
    Provider<AccountMigration>((ref) => migrateLegacyAccount);

final repositoryProvider =
    NotifierProvider<WalkRepository, WalkState>(WalkRepository.new);

/// Firestore owns the only durable queue. No app flow awaits a server receipt.
class WalkRepository extends Notifier<WalkState> {
  FirebaseFirestore? _db;
  String? _uid;
  int _generation = 0, _pending = 0;
  bool _alive = false, _profileWritten = false, _migrationStarted = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Set<String> _pendingDocuments = {};
  final Map<String, dynamic> _earlyProfileFields = {};
  bool _profileMayCreate = false;
  final Map<String, dynamic> _dirtyProfile = {};
  final Map<int, DateTime?> _dirtySaved = {};
  DateTime? _completedOnboarding;
  bool _hasFailure = false;
  late AccountCache _cache;
  Map<String, dynamic>? _migrationProfile;
  DateTime? _migrationRetryAfter;
  @override
  WalkState build() {
    ref.watch(authProvider.select((value) => value.user?.uid));
    final auth = ref.read(authProvider).user;
    final generation = ++_generation;
    _alive = true;
    _pending = 0;
    _pendingDocuments.clear();
    _profileWritten = false;
    _migrationStarted = false;
    _migrationProfile = null;
    _migrationRetryAfter = null;
    _earlyProfileFields.clear();
    _hasFailure = false;
    _dirtyProfile.clear();
    _dirtySaved.clear();
    _completedOnboarding = null;
    _cache = ref.read(accountCacheProvider);
    _profileMayCreate = auth?.isNewAccount ?? false;
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
    _uid = auth?.uid;
    _db = ref.watch(repositoryFirestoreProvider);
    ref.onDispose(() {
      if (generation != _generation) return;
      _alive = false;
      for (final sub in _subscriptions) {
        unawaited(sub.cancel());
      }
      _subscriptions.clear();
    });
    final cached = _uid == null ? null : _cache.read(_uid!);
    final cachedProfile = cached?['profile'];
    var profile = cachedProfile is Map
        ? AppProfile.fromFirestore(Map<String, dynamic>.from(cachedProfile))
        : AppProfile(name: auth?.displayName ?? '', timeZone: tz.local.name);
    final durableOnboarded = _uid == null ? null : _cache.readOnboardedAt(_uid!);
    final cachedCompleted = completionMap(cached?['completed']);
    if (profile.onboardedAt == null &&
        (durableOnboarded != null || cachedCompleted.isNotEmpty)) {
      profile = profile.copyWith(onboardedAt: durableOnboarded ?? DateTime.now());
    }
    _completedOnboarding = profile.onboardedAt;
    if (cached?['dirtyProfile'] is Map) {
      _dirtyProfile.addAll(
          _datesFromJson(Map<String, dynamic>.from(cached!['dirtyProfile'])));
    }
    if (cached?['dirtySaved'] is Map) {
      for (final e in (cached!['dirtySaved'] as Map).entries) {
        final day = int.tryParse('${e.key}');
        if (day != null) _dirtySaved[day] = profileDate(e.value);
      }
    }
    final initial = WalkState(
        profile: profile,
        completed: completionMap(cached?['completed']),
        saved: savedMap(cached?['saved']),
        syncing: _dirtyProfile.isNotEmpty || _dirtySaved.isNotEmpty,
        ready: cached != null || auth == null || _db == null);
    if (_uid != null && _db != null) {
      scheduleMicrotask(() => _listen(generation));
    }
    return initial;
  }

  bool _valid(int generation) => _alive && generation == _generation;
  DocumentReference<Map<String, dynamic>> get _profile =>
      _db!.doc('users/$_uid');
  DocumentReference<Map<String, dynamic>> _walk(String doc) =>
      _db!.doc('users/$_uid/walk/$doc');

  void _listen(int generation) {
    if (!_valid(generation)) return;
    void metadata(String doc, DocumentSnapshot<Map<String, dynamic>> snapshot) {
      if (snapshot.metadata.hasPendingWrites) {
        _pendingDocuments.add(doc);
      } else {
        _pendingDocuments.remove(doc);
      }
    }

    _subscriptions.add(
        _profile.snapshots(includeMetadataChanges: true).listen((snapshot) {
      if (!_valid(generation)) return;
      metadata('profile', snapshot);
      final data = snapshot.data();
      if (data != null) {
        _profileWritten = true;
        final patch = Map<String, dynamic>.of(_earlyProfileFields);
        _earlyProfileFields.clear();
        if (!snapshot.metadata.hasPendingWrites &&
            !snapshot.metadata.isFromCache) {
          _acknowledgeProfile(data);
        }
        final merged = _mergeProfileFields(
            _mergeProfileFields(data, patch), _dirtyProfile);
        if (_completedOnboarding != null) {
          merged['onboardedAt'] = _completedOnboarding;
        } else if (state.completed.isNotEmpty) {
          _completedOnboarding = DateTime.now();
          merged['onboardedAt'] = _completedOnboarding;
        }
        state = state.copyWith(
            profile: AppProfile.fromFirestore(merged, name: state.profile.name),
            ready: true,
            syncError: _hasFailure ? state.syncError : null);
        _completedOnboarding ??= state.profile.onboardedAt;
        _persist();
        _migrationProfile = merged;
        _startMigration();
        if (patch.isNotEmpty) {
          _write(() => _profile.set(patch, _profileMergeOptions(patch)),
              generation);
        }
      } else if (!_profileWritten &&
          (!snapshot.metadata.isFromCache || _profileMayCreate)) {
        state = state.copyWith(ready: true);
        _profileWritten = true;
        _earlyProfileFields.clear();
        _write(
            () => _profile.set(
                state.profile.toFirestore(), SetOptions(merge: true)),
            generation);
      }
      _syncState();
    }, onError: (Object error) => _syncFailure(generation)));
    _subscriptions.add(_walk('progress')
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
      if (!_valid(generation)) return;
      metadata('progress', snapshot);
      final values = completionMap(snapshot.data()?['completed']);
      // A completion is monotonic. A lagging snapshot cannot undo a local Amen.
      state = state.copyWith(
          completed: {...values, ...state.completed},
          syncError: _hasFailure ? state.syncError : null);
      _persist();
      _syncState();
    }, onError: (Object error) => _syncFailure(generation)));
    _subscriptions.add(_walk('saved')
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
      if (!_valid(generation)) return;
      metadata('saved', snapshot);
      state = state.copyWith(
          saved: _mergeSavedSnapshot(snapshot),
          syncError: _hasFailure ? state.syncError : null);
      _persist();
      _syncState();
    }, onError: (Object error) => _syncFailure(generation)));
  }

  /// A failed initial legacy read can retry on resume; no flow waits for it.
  void retryMigration() => _startMigration(force: true);
  void _startMigration({bool force = false}) {
    final profile = _migrationProfile;
    if (_migrationStarted ||
        _db == null ||
        _uid == null ||
        profile == null ||
        profile['migratedAt'] != null) {
      return;
    }
    if (!force &&
        _migrationRetryAfter != null &&
        DateTime.now().isBefore(_migrationRetryAfter!)) {
      return;
    }
    final generation = _generation, db = _db!, uid = _uid!;
    final run = ref.read(accountMigrationProvider);
    _migrationStarted = true;
    unawaited(Future<void>.sync(() => run(db, uid, profile)).then((_) {
      if (!_valid(generation)) return;
      _migrationStarted = false;
      _migrationProfile = null;
      _migrationRetryAfter = null;
    }, onError: (Object error) {
      if (!_valid(generation)) return;
      _migrationStarted = false;
      _migrationRetryAfter = DateTime.now().add(const Duration(seconds: 30));
      state = state.copyWith(
          syncError: 'Your earlier walk will sync when you reconnect.');
    }));
  }

  void _syncState() {
    if (_alive) {
      state = state.copyWith(
          syncing: _pending > 0 ||
              _pendingDocuments.isNotEmpty ||
              _earlyProfileFields.isNotEmpty ||
              _dirtyProfile.isNotEmpty ||
              _dirtySaved.isNotEmpty);
    }
  }

  void _syncFailure(int generation) {
    if (_valid(generation)) {
      _hasFailure = true;
      state = state.copyWith(syncing: true, syncError: _cloudSyncError);
    }
  }

  void _write(Future<void> Function() action, [int? generation]) {
    if (_db == null || _uid == null) return;
    final owner = generation ?? _generation;
    _pending++;
    _syncState();
    // Calling now enqueues in Firestore before returning. Never serialize on ack.
    try {
      unawaited(action().then((_) {
        if (!_valid(owner)) return;
        _pending--;
        _syncState();
      }, onError: (Object error) {
        if (!_valid(owner)) return;
        _pending--;
        _syncFailure(owner);
      }));
    } catch (_) {
      if (_valid(owner)) {
        _pending--;
        _syncFailure(owner);
      }
    }
  }

  void updateProfile(AppProfile profile) {
    if (_completedOnboarding != null && !profile.onboarded) {
      profile = profile.copyWith(onboardedAt: _completedOnboarding);
    }
    _completedOnboarding ??= profile.onboardedAt;
    final before = state.profile.toFirestore(), after = profile.toFirestore();
    state = state.copyWith(profile: profile);
    final fields = <String, dynamic>{'schema': 6};
    for (final key in after.keys) {
      if (_same(before[key], after[key])) continue;
      if (key == 'onboardingDraft') {
        fields[key] = after[key];
      } else if (before[key] is Map && after[key] is Map) {
        final oldMap = before[key] as Map, newMap = after[key] as Map;
        fields[key] = {
          for (final field in newMap.keys)
            if (!_same(oldMap[field], newMap[field])) field: newMap[field]
        };
      } else {
        fields[key] = after[key];
      }
    }
    _dirtyProfile.addAll(_mergeProfileFields(_dirtyProfile, fields));
    _persist();
    if (!_profileWritten) {
      if (_profileMayCreate) {
        _profileWritten = true;
        _write(() => _profile.set(after, SetOptions(merge: true)));
      } else {
        // An empty cache is not proof that a returning account has no profile.
        // Keep edits optimistic until its first document arrives, then merge
        // only the edited fields rather than replacing cross-device settings.
        final merged = _mergeProfileFields(_earlyProfileFields, fields);
        _earlyProfileFields
          ..clear()
          ..addAll(merged);
        _syncState();
      }
    } else if (fields.isNotEmpty) {
      _write(() => _profile.set(fields, _profileMergeOptions(fields)));
    }
  }

  void finishOnboarding([AppProfile? profile]) => updateProfile(
      (profile ?? state.profile).copyWith(onboardedAt: DateTime.now()));
  bool complete(int day, {DateTime? now}) {
    if (state.completed.containsKey(day)) return false;
    final instant = now ?? DateTime.now();
    final pacing = pacingFor(state.completed, instant, state.profile.timeZone);
    if (day != pacing.currentDay || !pacing.canBegin) return false;
    final date = dateKey(localNow(instant, state.profile.timeZone));
    state = state.copyWith(completed: {...state.completed, day: date});
    _write(() => _walk('progress').set({
          'completed': {'$day': date}
        }, SetOptions(merge: true)));
    _persist();
    return true;
  }

  void toggleSaved(int day, {DateTime? now}) {
    if (day < 1 || day > 365) return;
    final values = {...state.saved};
    final removing = values.containsKey(day);
    final time = now ?? DateTime.now();
    if (removing) {
      values.remove(day);
    } else {
      values[day] = time;
    }
    _dirtySaved[day] = removing ? null : time;
    state = state.copyWith(saved: values);
    _persist();
    _write(() => _walk('saved').set({
          'verses': {
            '$day': removing ? FieldValue.delete() : Timestamp.fromDate(time)
          }
        }, SetOptions(merge: true)));
  }

  void _persist() {
    final uid = _uid;
    if (uid == null) return;
    final owner = _generation;
    unawaited(_cache.write(uid, {
      'profile': _json(state.profile.toFirestore()),
      'completed': {
        for (final e in state.completed.entries) '${e.key}': e.value
      },
      'saved': {
        for (final e in state.saved.entries)
          '${e.key}': e.value.toIso8601String()
      },
      'dirtyProfile': _json(_dirtyProfile),
      'dirtySaved': {
        for (final e in _dirtySaved.entries)
          '${e.key}': e.value?.toIso8601String()
      },
    }).then<void>((_) {
      if (_valid(owner) && state.syncError == _deviceWriteError) {
        state = state.copyWith(syncError: _hasFailure ? _cloudSyncError : null);
      }
    }, onError: (Object _) {
      if (_valid(owner)) state = state.copyWith(syncError: _deviceWriteError);
    }));
  }

  void _acknowledgeProfile(Map<String, dynamic> data) {
    for (final key in _dirtyProfile.keys.toList()) {
      final wanted = _dirtyProfile[key];
      if (key == 'onboardingDraft') {
        if (_same(wanted, data[key])) _dirtyProfile.remove(key);
      } else if (wanted is Map && data[key] is Map) {
        final left = Map<String, dynamic>.from(wanted);
        left.removeWhere((k, v) => _same(v, (data[key] as Map)[k]));
        if (left.isEmpty) {
          _dirtyProfile.remove(key);
        } else {
          _dirtyProfile[key] = left;
        }
      } else if (_same(wanted, data[key])) {
        _dirtyProfile.remove(key);
      }
    }
  }

  Map<int, DateTime> _mergeSavedSnapshot(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final values = savedMap(snapshot.data()?['verses']);
    if (!snapshot.metadata.hasPendingWrites && !snapshot.metadata.isFromCache) {
      _dirtySaved.removeWhere((day, date) => values[day] == date);
    }
    for (final e in _dirtySaved.entries) {
      if (e.value == null) {
        values.remove(e.key);
      } else {
        values[e.key] = e.value!;
      }
    }
    return values;
  }

  Future<bool> completeDurably(int day, {DateTime? now}) async {
    final changed = complete(day, now: now);
    // A failed device write can be retried without awarding this day again.
    if (!changed) _persist();
    await ref.read(accountCacheProvider).flush();
    return changed;
  }

  Future<void> finishOnboardingDurably([AppProfile? profile]) async {
    final at = DateTime.now();
    if (_uid != null) {
      await _cache.markOnboarded(_uid!, at);
    }
    finishOnboarding((profile ?? state.profile).copyWith(onboardedAt: at));
    await ref.read(accountCacheProvider).flush();
  }

  void retrySync() {
    _hasFailure = false;
    if (_uid == null || _db == null || !_profileWritten) return;
    final patch = Map<String, dynamic>.from(_dirtyProfile);
    if (patch.isNotEmpty) {
      _write(() => _profile.set(patch, _profileMergeOptions(patch)));
    }
    if (state.completed.isNotEmpty) {
      _write(() => _walk('progress').set({
            'completed': {
              for (final e in state.completed.entries) '${e.key}': e.value
            }
          }, SetOptions(merge: true)));
    }
    for (final e in _dirtySaved.entries.toList()) {
      _write(() => _walk('saved').set({
            'verses': {
              '${e.key}': e.value == null
                  ? FieldValue.delete()
                  : Timestamp.fromDate(e.value!)
            }
          }, SetOptions(merge: true)));
    }
    retryMigration();
  }

  String exportData() => const JsonEncoder.withIndent('  ').convert({
        'version': 2,
        'exportedAt': DateTime.now().toIso8601String(),
        'profile': state.profile
            .toFirestore()
            .map((key, value) => MapEntry(key, _json(value))),
        'completed': {
          for (final entry in state.completed.entries)
            '${entry.key}': entry.value
        },
        'saved': {
          for (final entry in state.saved.entries)
            '${entry.key}': entry.value.toIso8601String()
        }
      });
}

/// A guided conversation replaces its answer map so editing an earlier answer
/// also clears the later answers. Other nested preferences still merge leaves.
SetOptions _profileMergeOptions(Map<String, dynamic> patch) =>
    SetOptions(mergeFields: [
      for (final entry in patch.entries)
        if (entry.key != 'onboardingDraft' && entry.value is Map)
          for (final leaf in (entry.value as Map).keys)
            FieldPath([entry.key, '$leaf'])
        else
          FieldPath([entry.key]),
    ]);

Map<String, dynamic> _mergeProfileFields(
    Map<String, dynamic> original, Map<String, dynamic> patch) {
  final merged = Map<String, dynamic>.of(original);
  for (final entry in patch.entries) {
    final old = merged[entry.key];
    merged[entry.key] =
        entry.key != 'onboardingDraft' && old is Map && entry.value is Map
            ? _mergeProfileFields(Map<String, dynamic>.from(old),
                Map<String, dynamic>.from(entry.value))
            : entry.value;
  }
  return merged;
}

bool _same(Object? a, Object? b) {
  if ((a is DateTime || a is Timestamp) && (b is DateTime || b is Timestamp)) {
    return profileDate(a)!.microsecondsSinceEpoch ==
        profileDate(b)!.microsecondsSinceEpoch;
  }
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.entries.every((entry) =>
            b.containsKey(entry.key) && _same(entry.value, b[entry.key]));
  }
  if (a is Iterable && b is Iterable) {
    final left = a.iterator, right = b.iterator;
    while (left.moveNext()) {
      if (!right.moveNext() || !_same(left.current, right.current)) {
        return false;
      }
    }
    return !right.moveNext();
  }
  return a == b;
}

Object? _json(Object? value) => value is DateTime
    ? value.toUtc().toIso8601String()
    : value is Timestamp
        ? value.toDate().toUtc().toIso8601String()
        : value is Map
            ? value.map((key, value) => MapEntry(key, _json(value)))
            : value is Iterable
                ? value.map(_json).toList()
                : value;

Map<int, String> completionMap(Object? raw) {
  if (raw is! Map) return {};
  final result = <int, String>{};
  for (final entry in raw.entries) {
    final day = int.tryParse('${entry.key}');
    if (day == null || day < 1 || day > 365 || entry.value is! String) continue;
    try {
      calendarDate(entry.value);
      result[day] = entry.value;
    } catch (_) {}
  }
  return result;
}

Map<int, DateTime> savedMap(Object? raw) {
  if (raw is! Map) return {};
  final result = <int, DateTime>{};
  for (final entry in raw.entries) {
    final day = int.tryParse('${entry.key}'), date = profileDate(entry.value);
    if (day != null && day >= 1 && day <= 365 && date != null) {
      result[day] = date;
    }
  }
  return result;
}

Map<String, dynamic> _datesFromJson(Map<String, dynamic> value) =>
    value.map((key, item) => MapEntry(
        key,
        ['onboardedAt', 'updatedAt', 'createdAt', 'migratedAt', 'startedAt']
                .contains(key)
            ? profileDate(item)
            : item is Map
                ? _datesFromJson(Map<String, dynamic>.from(item))
                : item));
