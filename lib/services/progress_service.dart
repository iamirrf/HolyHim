import 'dart:async';
import 'dart:convert';
import 'package:holyher/services/journey_clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/durable_store.dart';
import 'package:holyher/services/profile_service.dart';

abstract interface class JourneyGateway {
  Stream<Map<String, dynamic>> watch(String uid);
  Future<Map<String, dynamic>> load(String uid);
  Future<Map<String, dynamic>> start(String uid, String timeZone);
  Future<Map<String, dynamic>> complete(String uid, int day);
}

class _FirebaseJourneyGateway implements JourneyGateway {
  final Ref ref;
  _FirebaseJourneyGateway(this.ref);
  void _checkUser(String uid) {
    if (ref.read(authProvider).user?.uid != uid) {
      throw StateError('The signed-in account changed.');
    }
  }

  Future<Map<String, dynamic>> _call(String uid, String name,
      [Map<String, dynamic>? data]) async {
    _checkUser(uid);
    final response = await FirebaseFunctions.instance
        .httpsCallable(name)
        .call<Map<String, dynamic>>(data)
        .timeout(const Duration(seconds: 15));
    _checkUser(uid);
    return response.data;
  }

  @override
  Stream<Map<String, dynamic>> watch(String uid) {
    _checkUser(uid);
    return FirebaseFirestore.instance
        .doc('users/$uid/private/journey')
        .snapshots()
        .where((snapshot) => snapshot.exists)
        .map((snapshot) => snapshot.data()!);
  }

  @override
  Future<Map<String, dynamic>> load(String uid) => _call(uid, 'getJourney');
  @override
  Future<Map<String, dynamic>> start(String uid, String timeZone) =>
      _call(uid, 'startJourney', {'timeZone': timeZone});
  @override
  Future<Map<String, dynamic>> complete(String uid, int day) => _call(
      uid,
      'completeLesson',
      {'day': day, 'journeyRevision': ref.read(progressProvider).revision});
}

final journeyGatewayProvider = Provider<JourneyGateway?>(
    (ref) => Firebase.apps.isEmpty ? null : _FirebaseJourneyGateway(ref));

class ProgressState {
  final Set<int> completedDays, pendingDays, earnedBadges;
  final Set<String> readingDates;
  final Map<int, String> completionDates;
  final bool onboardingComplete, journeyStarted, loading;
  final int unlockedThrough, revision;
  final String? startDate, timeZone, syncError;
  final List<DailyLesson> catalog;
  const ProgressState(
      {this.completedDays = const {},
      this.earnedBadges = const {},
      this.readingDates = const {},
      this.completionDates = const {},
      this.pendingDays = const {},
      this.onboardingComplete = false,
      this.journeyStarted = false,
      this.loading = false,
      this.unlockedThrough = 0,
      this.revision = 1,
      this.startDate,
      this.timeZone,
      this.syncError,
      this.catalog = lessons});
  bool isUnlocked(int day) =>
      journeyStarted &&
      day >= 1 &&
      day <= unlockedThrough &&
      catalog.any((l) => l.day == day);
  DailyLesson? get nextLesson {
    for (final lesson in catalog) {
      if (isUnlocked(lesson.day) && !completedDays.contains(lesson.day)) {
        return lesson;
      }
    }
    return null;
  }

  DailyLesson? get todayLesson {
    for (final lesson in catalog) {
      if (lesson.day == unlockedThrough && isUnlocked(lesson.day)) {
        return lesson;
      }
    }
    return null;
  }

  int get todayDay => unlockedThrough;
  int get completedCount =>
      catalog.where((l) => completedDays.contains(l.day)).length;
  bool get allComplete =>
      catalog.isNotEmpty && completedCount == catalog.length;
  bool get caughtUp => journeyStarted && nextLesson == null;
  double get fraction => catalog.isEmpty ? 0 : completedCount / catalog.length;
  ProgressState copyWith(
          {Set<int>? completedDays,
          Set<int>? earnedBadges,
          Set<String>? readingDates,
          Map<int, String>? completionDates,
          Set<int>? pendingDays,
          bool? onboardingComplete,
          bool? journeyStarted,
          bool? loading,
          int? unlockedThrough,
          int? revision,
          String? startDate,
          String? timeZone,
          String? syncError}) =>
      ProgressState(
          completedDays: completedDays ?? this.completedDays,
          earnedBadges: earnedBadges ?? this.earnedBadges,
          readingDates: readingDates ?? this.readingDates,
          completionDates: completionDates ?? this.completionDates,
          pendingDays: pendingDays ?? this.pendingDays,
          onboardingComplete: onboardingComplete ?? this.onboardingComplete,
          journeyStarted: journeyStarted ?? this.journeyStarted,
          loading: loading ?? this.loading,
          unlockedThrough: unlockedThrough ?? this.unlockedThrough,
          revision: revision ?? this.revision,
          startDate: startDate ?? this.startDate,
          timeZone: timeZone ?? this.timeZone,
          syncError: syncError,
          catalog: catalog);
}

class ProgressNotifier extends Notifier<ProgressState> {
  Future<void>? _loaded, _refreshing;
  Future<void> _pending = Future.value();
  StreamSubscription<Map<String, dynamic>>? _subscription;
  int _generation = 0;
  String? _uid;
  @override
  ProgressState build() {
    _uid = ref.watch(authProvider.select((s) => s.user?.uid));
    ref.watch(localStoreProvider);
    ref.watch(journeyGatewayProvider);
    final onboarded = ref.read(profileProvider).onboardingComplete;
    ref.listen(profileProvider.select((p) => p.onboardingComplete), (_, value) {
      if (state.onboardingComplete != value) {
        state = state.copyWith(onboardingComplete: value);
      }
    });
    final generation = ++_generation;
    _loaded = null;
    _refreshing = null;
    _pending = Future.value();
    _subscription?.cancel();
    ref.onDispose(() {
      _generation++;
      _subscription?.cancel();
    });
    Future.microtask(() {
      if (_generation == generation) {
        unawaited(initialize().catchError((Object _) {}));
      }
    });
    return ProgressState(onboardingComplete: onboarded);
  }

  Future<void> initialize() => _loaded ??= _load(_generation);
  Future<void> _load(int generation) async {
    final store = ref.read(localStoreProvider);
    final raw = await store.read('journey_cache');
    if (_generation != generation) return;
    if (raw is String) {
      try {
        _apply(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {}
    }
    final pending = await store.read('pending_completions');
    final pendingRevision =
        await store.read('pending_completion_revision') ?? 1;
    if (_generation != generation) return;
    final valid = pendingRevision == state.revision && pending is List
        ? pending
            .whereType<String>()
            .map(int.tryParse)
            .whereType<int>()
            .where((day) => day >= 1 && day <= lessons.length)
            .toSet()
        : <int>{};
    state = state.copyWith(pendingDays: valid, completedDays: {
      ...state.completedDays,
      ...valid.where(state.isUnlocked)
    });
    final uid = _uid;
    final gateway = ref.read(journeyGatewayProvider);
    if (uid != null && gateway != null) {
      _subscription = gateway.watch(uid).listen((data) {
        if (_generation != generation) return;
        final revision = data['revision'] as int? ?? 1;
        if (revision < state.revision) return;
        if (revision > state.revision) {
          state = state
              .copyWith(revision: revision, pendingDays: {}, completedDays: {});
          unawaited(store.write('pending_completions', <String>[]));
        }
        final completed = (data['completedDays'] as List? ?? [])
            .whereType<int>()
            .where(state.isUnlocked)
            .toSet();
        state = state.copyWith(completionDates: {
          ...state.completionDates,
          if (data['completionDates'] is Map)
            for (final e in (data['completionDates'] as Map).entries)
              if (int.tryParse('${e.key}') != null && e.value is String)
                int.parse('${e.key}'): e.value as String
        }, readingDates: {
          ...state.readingDates,
          ...((data['readingDates'] as List?)?.whereType<String>() ??
              const <String>[])
        }, earnedBadges: {
          ...state.earnedBadges,
          ...((data['earnedBadges'] as List?)?.whereType<int>() ??
              const <int>[])
        }, completedDays: {
          ...state.completedDays,
          ...completed,
          ...state.pendingDays.where(state.isUnlocked)
        });
        if (state.journeyStarted) {
          unawaited(_cache(store).catchError((Object _) {}));
        }
      }, onError: (Object _) {});
      unawaited(refresh());
    }
  }

  void _apply(Map<String, dynamic> data, {bool authoritative = false}) {
    if (data['started'] != true) return;
    final unlocked = data['unlockedThrough'];
    if (unlocked is! int || unlocked < 1 || unlocked > lessons.length) return;
    final completed = (data['completedDays'] as List? ?? [])
        .whereType<int>()
        .where((d) => d >= 1 && d <= unlocked)
        .toSet();
    final revision = data['revision'] as int? ?? 1;
    if (revision < state.revision) return;
    final pending = revision > state.revision
        ? <int>{}
        : authoritative
            ? state.pendingDays.where((day) => day <= unlocked).toSet()
            : state.pendingDays;
    state = state.copyWith(
        journeyStarted: true,
        readingDates: {
          ...state.readingDates,
          ...((data['readingDates'] as List?)?.whereType<String>() ??
              const <String>[])
        },
        earnedBadges: {
          ...state.earnedBadges,
          ...((data['earnedBadges'] as List?)?.whereType<int>() ??
              const <int>[]),
          ...[1, 7, 30, 90, 180, 365].where((n) => completed.length >= n)
        },
        completionDates: {
          if (revision == state.revision) ...state.completionDates,
          if (data['completionDates'] is Map)
            for (final entry in (data['completionDates'] as Map).entries)
              if (int.tryParse('${entry.key}') != null &&
                  completed.contains(int.tryParse('${entry.key}')) &&
                  entry.value is String &&
                  RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(entry.value))
                int.parse('${entry.key}'): entry.value as String,
        },
        revision: revision,
        unlockedThrough: unlocked,
        startDate: data['startDate'] as String?,
        timeZone: data['timeZone'] as String?,
        pendingDays: pending,
        completedDays: {
          if (revision == state.revision) ...state.completedDays,
          ...completed,
          ...pending.where((d) => d <= unlocked)
        },
        loading: false);
  }

  Future<void> refresh() {
    final generation = _generation;
    return _refreshing ??= _refresh().whenComplete(() {
      if (_generation == generation) _refreshing = null;
    });
  }

  Future<void> _refresh() async {
    final generation = _generation;
    await initialize();
    if (_generation != generation) return;
    final uid = _uid;
    final gateway = ref.read(journeyGatewayProvider);
    if (uid == null || gateway == null) return;
    final store = ref.read(localStoreProvider);
    try {
      final result = await gateway.load(uid);
      if (_generation != generation) return;
      _apply(result, authoritative: true);
      if (state.journeyStarted) {
        // Use the same queue as local completion acceptance. A delayed refresh
        // or acknowledgment cannot overwrite work added during the request.
        _pending = _pending.catchError((Object _) {}).then((_) async {
          if (_generation != generation) return;
          await _persistProgress(store);
        });
        await _pending;
        while (_generation == generation && state.pendingDays.isNotEmpty) {
          final day = (state.pendingDays.toList()..sort()).first;
          final revision = state.revision;
          final response = await gateway.complete(uid, day);
          if (_generation != generation) return;
          _pending = _pending.catchError((Object _) {}).then((_) async {
            if (_generation != generation || state.revision != revision) return;
            final pending = {...state.pendingDays}..remove(day);
            state = state.copyWith(pendingDays: pending);
            _apply(response, authoritative: true);
            try {
              await _persistProgress(store);
            } catch (_) {
              if (_generation == generation && state.revision == revision) {
                state =
                    state.copyWith(pendingDays: {...state.pendingDays, day});
              }
              rethrow;
            }
          });
          await _pending;
        }
        await _cache(store);
      }
      if (_generation == generation) state = state.copyWith(loading: false);
    } catch (_) {
      if (_generation == generation) {
        state = state.copyWith(
            loading: false,
            syncError:
                'Your saved lessons are here. Reconnect to sync your progress and unlock new days.');
      }
    }
  }

  Future<void> startJourney() async {
    await initialize();
    final generation = _generation;
    final uid = _uid;
    final gateway = ref.read(journeyGatewayProvider);
    if (uid == null || gateway == null) {
      throw StateError('Please reconnect to start your journey.');
    }
    final zone = (await FlutterTimezone.getLocalTimezone()).identifier;
    if (_generation != generation) return;
    final result = await gateway.start(uid, zone);
    if (_generation != generation) throw StateError('Account changed.');
    if (result['started'] != true) {
      throw StateError('The server did not confirm your journey.');
    }
    _apply(result, authoritative: true);
    await _cache(ref.read(localStoreProvider));
  }

  String _encodedJourney() => jsonEncode({
        'started': state.journeyStarted,
        'revision': state.revision,
        'startDate': state.startDate,
        'timeZone': state.timeZone,
        'unlockedThrough': state.unlockedThrough,
        'completionDates':
            state.completionDates.map((k, v) => MapEntry('$k', v)),
        'readingDates': state.readingDates.toList(),
        'earnedBadges': state.earnedBadges.toList(),
        'completedDays': state.completedDays.toList()
      });
  Future<void> _cache(LocalStore store) async {
    if (!await store.write('journey_cache', _encodedJourney())) {
      throw StateError('Your progress cache could not be saved.');
    }
  }

  Future<void> _persistProgress(LocalStore store) async {
    if (!await writeLocalBatch(store, {
      'journey_cache': _encodedJourney(),
      'pending_completions': state.pendingDays.map((day) => '$day').toList(),
      'pending_completion_revision': state.revision
    })) {
      throw StateError('Your progress could not be saved.');
    }
  }

  String completionDateNow() {
    final now =
        accountCalendarTime(ref.read(localClockProvider)(), state.timeZone);
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String journeyWithCompletion(int day, String date) {
    final value = Map<String, dynamic>.from(jsonDecode(_encodedJourney()));
    value['completedDays'] = {...state.completedDays, day}.toList();
    value['completionDates'] = {
      ...state.completionDates.map((k, v) => MapEntry('$k', v)),
      if (!state.completedDays.contains(day)) '$day': date
    };
    return jsonEncode(value);
  }

  Future<void> completeDay(int day) {
    final generation = _generation;
    return _pending = _pending.catchError((Object _) {}).then((_) async {
      if (_generation != generation) return;
      await initialize();
      if (_generation != generation ||
          !state.isUnlocked(day) ||
          state.completedDays.contains(day)) {
        return;
      }
      final store = ref.read(localStoreProvider);
      final pending = {...state.pendingDays, day};
      final date = completionDateNow();
      if (!await writeLocalBatch(store, {
        'pending_completion_revision': state.revision,
        'pending_completions': pending.map((day) => '$day').toList(),
        'journey_cache': journeyWithCompletion(day, date)
      })) {
        throw StateError('Your progress could not be saved. Please try again.');
      }
      if (_generation != generation) return;
      state = state.copyWith(
          completedDays: {...state.completedDays, day},
          pendingDays: pending,
          completionDates: {...state.completionDates, day: date});
      if (_generation == generation) unawaited(refresh());
    });
  }

  void acceptAttemptLocally(int day, {String? date}) {
    if (state.isUnlocked(day)) {
      state = state.copyWith(completionDates: {
        ...state.completionDates,
        if (!state.completedDays.contains(day) && date != null) day: date
      }, completedDays: {
        ...state.completedDays,
        day
      });
    }
  }

  Future<void> applyAttemptResult(Map<String, dynamic> result) async {
    _apply(result, authoritative: true);
    await _cache(ref.read(localStoreProvider));
  }

  Future<void> finishOnboarding() => ref
      .read(profileProvider.notifier)
      .save(ref.read(profileProvider).copyWith(onboardingComplete: true));
}

final progressProvider =
    NotifierProvider<ProgressNotifier, ProgressState>(ProgressNotifier.new);
