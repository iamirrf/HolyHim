import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/streak_logic.dart';
export 'package:holyher/services/streak_logic.dart' show StreakState;

/// FUTURE SEAM: SharedPreferences today; Firebase storage at ship time.
/// Preserve initialize(), checkAndUpdateStreak(), markTodayActive(), dayKey(),
/// and streakProvider's immediately available StreakState. Pure rules stay in
/// streak_logic.dart; screens never know which backend persists their state.
class StreakNotifier extends Notifier<StreakState> {
  static const _kCurrent = 'streak_current';
  static const _kLongest = 'streak_longest';
  static const _kActiveDays = 'streak_active_days';
  Future<void>? _loaded;
  Future<void>? _inFlight;
  bool _alive = true;

  static String dayKey(DateTime date) => localDayKey(date);

  @override
  StreakState build() {
    ref.onDispose(() => _alive = false);
    return const StreakState();
  }

  Future<void> _load() async {
    final store = ref.read(localStoreProvider);
    final history = await store.read(_kActiveDays);
    final best = await store.read(_kLongest);
    if (_alive) state = restoreStreak(history, best);
  }

  Future<void> initialize() => checkAndUpdateStreak();
  Future<void> markTodayActive() => checkAndUpdateStreak();

  Future<void> checkAndUpdateStreak() =>
      _inFlight ??= _update().whenComplete(() => _inFlight = null);

  Future<void> _update() async {
    final store = ref.read(localStoreProvider);
    final clock = ref.read(localClockProvider);
    await (_loaded ??= _load());
    if (!_alive) return;
    final next = advanceStreak(state, clock());
    if (identical(next, state)) return;
    // Save authoritative history first. A killed process can reconstruct both
    // counters from the last saved history, even between projection writes.
    // SharedPreferences does not promise fsync durability or multi-key batches.
    final saved =
        await store.write(_kActiveDays, next.activeDays.toList()..sort());
    if (saved) {
      await store.write(_kCurrent, next.current);
      await store.write(_kLongest, next.longest);
    }
    // Failed persistence still leaves a coherent, usable session.
    if (_alive) state = next;
  }
}

final localClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final streakProvider =
    NotifierProvider<StreakNotifier, StreakState>(StreakNotifier.new);
