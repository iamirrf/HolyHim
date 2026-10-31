import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/local_store.dart';
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
  Future<Map<String, dynamic>> complete(String uid, int day) =>
      _call(uid, 'completeLesson', {'day': day});
}

final journeyGatewayProvider = Provider<JourneyGateway?>(
    (ref) => Firebase.apps.isEmpty ? null : _FirebaseJourneyGateway(ref));

class ProgressState {
  final Set<int> completedDays, pendingDays;
  final bool onboardingComplete, journeyStarted, loading;
  final int unlockedThrough;
  final String? startDate, timeZone, syncError;
  final List<DailyLesson> catalog;
  const ProgressState(
      {this.completedDays = const {},
      this.pendingDays = const {},
      this.onboardingComplete = false,
      this.journeyStarted = false,
      this.loading = false,
      this.unlockedThrough = 0,
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
          Set<int>? pendingDays,
          bool? onboardingComplete,
          bool? journeyStarted,
          bool? loading,
          int? unlockedThrough,
          String? startDate,
          String? timeZone,
          String? syncError}) =>
      ProgressState(
          completedDays: completedDays ?? this.completedDays,
          pendingDays: pendingDays ?? this.pendingDays,
          onboardingComplete: onboardingComplete ?? this.onboardingComplete,
          journeyStarted: journeyStarted ?? this.journeyStarted,
          loading: loading ?? this.loading,
          unlockedThrough: unlockedThrough ?? this.unlockedThrough,
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
    final onboarded =
        ref.watch(profileProvider.select((p) => p.onboardingComplete));
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
      if (_generation == generation) initialize();
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
    if (_generation != generation) return;
    final valid = pending is List
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
        final completed = (data['completedDays'] as List? ?? [])
            .whereType<int>()
            .where(state.isUnlocked)
            .toSet();
        state = state.copyWith(completedDays: {
          ...completed,
          ...state.pendingDays.where(state.isUnlocked)
        });
        if (state.journeyStarted) unawaited(_cache(store));
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
    final pending = authoritative
        ? state.pendingDays.where((day) => day <= unlocked).toSet()
        : state.pendingDays;
    state = state.copyWith(
        journeyStarted: true,
        unlockedThrough: unlocked,
        startDate: data['startDate'] as String?,
        timeZone: data['timeZone'] as String?,
        pendingDays: pending,
        completedDays: {...completed, ...pending.where((d) => d <= unlocked)},
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
        await store.write('pending_completions',
            state.pendingDays.map((day) => '$day').toList());
        for (final day in state.pendingDays.toList()..sort()) {
          final response = await gateway.complete(uid, day);
          if (_generation != generation) return;
          final pending = {...state.pendingDays}..remove(day);
          state = state.copyWith(pendingDays: pending);
          _apply(response, authoritative: true);
          await store.write(
              'pending_completions', pending.map((d) => '$d').toList());
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
    if (_generation != generation) return;
    _apply(result, authoritative: true);
    await _cache(ref.read(localStoreProvider));
  }

  Future<void> _cache(LocalStore store) => store
      .write(
          'journey_cache',
          jsonEncode({
            'started': state.journeyStarted,
            'startDate': state.startDate,
            'timeZone': state.timeZone,
            'unlockedThrough': state.unlockedThrough,
            'completedDays': state.completedDays.toList()
          }))
      .then((_) {});
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
      if (!await store.write(
          'pending_completions', pending.map((day) => '$day').toList())) {
        throw StateError('Your progress could not be saved. Please try again.');
      }
      if (_generation != generation) return;
      state = state.copyWith(
          completedDays: {...state.completedDays, day}, pendingDays: pending);
      await _cache(store);
      if (_generation == generation) unawaited(refresh());
    });
  }

  Future<void> finishOnboarding() => ref
      .read(profileProvider.notifier)
      .save(ref.read(profileProvider).copyWith(onboardingComplete: true));
}

final progressProvider =
    NotifierProvider<ProgressNotifier, ProgressState>(ProgressNotifier.new);
