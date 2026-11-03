import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:holyher/services/journey_clock.dart';
export 'package:holyher/services/journey_clock.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/streak_logic.dart';
export 'package:holyher/services/streak_logic.dart' show StreakState;

final accountClockProvider = Provider<DateTime Function()>((ref) {
  final clock = ref.watch(localClockProvider);
  final timeZone =
      ref.watch(progressProvider.select((state) => state.timeZone));
  return () => accountCalendarTime(clock(), timeZone);
});

/// Keep a bounded outbox of real, nonfuture account-calendar dates.
Set<String> activityDaysForSync(Iterable<String> days,
    {required String today, String? startDate}) {
  final valid = days
      .where((day) =>
          parseLocalDay(day) != null &&
          day.compareTo(today) <= 0 &&
          (startDate == null || day.compareTo(startDate) >= 0))
      .toSet()
      .toList()
    ..sort();
  return valid.skip(valid.length > 366 ? valid.length - 366 : 0).toSet();
}

abstract interface class ActivityGateway {
  Future<List<String>> merge(String uid, List<String> days);
}

class _FirebaseActivityGateway implements ActivityGateway {
  final Ref ref;
  _FirebaseActivityGateway(this.ref);
  @override
  Future<List<String>> merge(String uid, List<String> days) async {
    if (ref.read(authProvider).user?.uid != uid) {
      throw StateError('The signed-in account changed.');
    }
    final result = await FirebaseFunctions.instance
        .httpsCallable('markActive')
        .call<Map<String, dynamic>>({'days': days}).timeout(
            const Duration(seconds: 15));
    if (ref.read(authProvider).user?.uid != uid) {
      throw StateError('The signed-in account changed.');
    }
    final history = result.data['activeDays'];
    if (history is! List ||
        history.any((day) => day is! String || parseLocalDay(day) == null)) {
      throw StateError('Invalid activity response.');
    }
    return history.cast<String>();
  }
}

final activityGatewayProvider = Provider<ActivityGateway?>(
    (ref) => Firebase.apps.isEmpty ? null : _FirebaseActivityGateway(ref));

class StreakNotifier extends Notifier<StreakState> {
  static const _kCurrent = 'streak_current';
  static const _kLongest = 'streak_longest';
  static const _kActiveDays = 'streak_active_days';
  static const _kPendingDays = 'streak_pending_days';
  Future<void>? _loaded;
  Future<void>? _inFlight;
  bool _alive = true;
  int _generation = 0;
  Set<String> _pendingDays = {}, _persistedPending = {};

  static String dayKey(DateTime date) => localDayKey(date);

  @override
  StreakState build() {
    ref.watch(authProvider.select((state) => state.user?.uid));
    ref.watch(localStoreProvider);
    ref.watch(activityGatewayProvider);
    _generation++;
    _alive = true;
    _loaded = null;
    _inFlight = null;
    _pendingDays = {};
    _persistedPending = {};
    ref.onDispose(() {
      _alive = false;
      _generation++;
    });
    return const StreakState();
  }

  Future<void> _load() async {
    final generation = _generation;
    final store = ref.read(localStoreProvider);
    final history = await store.read(_kActiveDays);
    final best = await store.read(_kLongest);
    final pending = await store.read(_kPendingDays);
    if (_alive && generation == _generation) {
      state = restoreStreak(history, best);
      _pendingDays = pending is List
          ? pending
              .whereType<String>()
              .where((day) => parseLocalDay(day) != null)
              .toSet()
          : state.activeDays.toSet();
      _persistedPending = pending is List ? _pendingDays.toSet() : {};
    }
  }

  Future<void> initialize() => checkAndUpdateStreak();
  Future<void> markTodayActive() => checkAndUpdateStreak();

  Future<void> checkAndUpdateStreak() {
    final generation = _generation;
    return _inFlight ??= _update().whenComplete(() {
      if (_generation == generation) _inFlight = null;
    });
  }

  bool _current(int generation) => _alive && _generation == generation;

  Future<void> _savePending(LocalStore store, int generation) async {
    if (_pendingDays.length == _persistedPending.length &&
        _pendingDays.containsAll(_persistedPending)) {
      return;
    }
    final snapshot = _pendingDays.toSet();
    if (await store.write(_kPendingDays, snapshot.toList()..sort())) {
      if (_current(generation)) _persistedPending = snapshot;
    }
  }

  Future<void> _update() async {
    final generation = _generation;
    final store = ref.read(localStoreProvider);
    await (_loaded ??= _load());
    await ref.read(progressProvider.notifier).initialize();
    if (!_current(generation)) return;
    final now = ref.read(accountClockProvider)();
    final today = localDayKey(now);
    final journey = ref.read(progressProvider);
    final knownDays = {...state.activeDays, ..._pendingDays}
        .where((day) =>
            parseLocalDay(day) != null &&
            day.compareTo(today) <= 0 &&
            (journey.startDate == null ||
                day.compareTo(journey.startDate!) >= 0))
        .toSet();
    final sameHistory = knownDays.length == state.activeDays.length &&
        knownDays.containsAll(state.activeDays);
    final base =
        sameHistory ? state : restoreStreak(knownDays.toList(), state.longest);
    var next = advanceStreak(base, now);
    _pendingDays = activityDaysForSync({
      ..._pendingDays,
      if (!base.activeDays.contains(today)) today,
    }, today: today, startDate: journey.startDate);
    await _savePending(store, generation);
    if (!_current(generation)) return;

    final uid = ref.read(authProvider).user?.uid;
    final gateway = ref.read(activityGatewayProvider);
    if (uid != null && gateway != null && journey.journeyStarted) {
      final submitted = _pendingDays.toList()..sort();
      try {
        final history = await gateway.merge(uid, submitted);
        if (!_current(generation)) return;
        final validHistory = history.where((day) =>
            parseLocalDay(day) != null &&
            day.compareTo(today) <= 0 &&
            (journey.startDate == null ||
                day.compareTo(journey.startDate!) >= 0));
        next = restoreStreak(
            {...next.activeDays, ...validHistory}.toList(), next.longest);
        _pendingDays.removeAll(submitted);
        await _savePending(store, generation);
        if (!_current(generation)) return;
      } catch (_) {
        // Persisted dates remain in the outbox until a successful merge.
      }
    }
    if (identical(next, state)) return;
    final saved =
        await store.write(_kActiveDays, next.activeDays.toList()..sort());
    if (saved) {
      await store.write(_kCurrent, next.current);
      await store.write(_kLongest, next.longest);
    }
    if (_current(generation)) state = next;
  }
}

final streakProvider =
    NotifierProvider<StreakNotifier, StreakState>(StreakNotifier.new);
