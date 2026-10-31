import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/streak_logic.dart';
import 'package:holyher/services/streak_service.dart';
import 'support.dart';

void main() {
  ProviderContainer create(MemoryStore store, DateTime Function() clock) {
    final container = ProviderContainer(overrides: [
      localStoreProvider.overrideWithValue(store),
      localClockProvider.overrideWithValue(clock),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('fresh, concurrent, same-day, consecutive, and missed-day opens',
      () async {
    var now = DateTime(2026, 10, 27);
    final store = MemoryStore();
    final container = create(store, () => now);
    final service = container.read(streakProvider.notifier);
    await Future.wait(List.generate(3, (_) => service.initialize()));
    expect(container.read(streakProvider).current, 1);
    expect(store.writes.where((key) => key == 'streak_active_days').length, 1);
    var events = 0;
    container.listen(streakProvider, (previous, next) => events++);
    final writes = store.writes.length;
    await service.markTodayActive();
    expect(events, 0);
    expect(store.writes.length, writes);
    now = DateTime(2026, 10, 28, 23, 59);
    await service.markTodayActive();
    expect(container.read(streakProvider).current, 2);
    now = DateTime(2026, 10, 29, 0, 1);
    await service.markTodayActive();
    expect(container.read(streakProvider).current, 3);
    now = DateTime(2026, 11, 1);
    await service.markTodayActive();
    final state = container.read(streakProvider);
    expect(state.current, 1);
    expect(state.longest, 3);
    expect(state.activeDays.length, 4);
    StreakState? latest;
    container.listen(streakProvider, (_, next) => latest = next,
        fireImmediately: true);
    expect(latest, same(state));
  });

  test('backwards clock and duplicate dates leave state untouched', () {
    final state = restoreStreak(['2026-10-27', '2026-10-28'], 7);
    expect(advanceStreak(state, DateTime(2026, 10, 26)), same(state));
    expect(advanceStreak(state, DateTime(2026, 10, 28)), same(state));
    expect(advanceStreak(state, DateTime(2026, 11, 5)).longest, 7);
  });

  test('both DST boundaries use calendar yesterday, including late evening',
      () {
    for (final pair in [
      [DateTime(2026, 3, 7, 23, 30), DateTime(2026, 3, 8, 23, 30)],
      [DateTime(2026, 11, 1, 0, 30), DateTime(2026, 11, 2, 0, 15)],
    ]) {
      final first = advanceStreak(const StreakState(), pair[0]);
      expect(advanceStreak(first, pair[1]).current, 2);
    }
  });

  test('timezone-style repeated/skipped/backwards local dates remain sane', () {
    final first = advanceStreak(const StreakState(), DateTime(2026, 10, 29));
    expect(advanceStreak(first, DateTime(2026, 10, 29, 23)), same(first));
    expect(advanceStreak(first, DateTime(2026, 10, 28)), same(first));
    expect(advanceStreak(first, DateTime(2026, 10, 31)).current, 1);
  });

  test('invalid history resets; malformed counters are reconstructed', () {
    for (final invalid in [
      null,
      '',
      3,
      ['2026-02-30'],
      [''],
      [3],
      ['2026-1-01']
    ]) {
      final state = restoreStreak(invalid, 99);
      expect(state.current, 0);
      expect(state.longest, 0);
      expect(state.activeDays, isEmpty);
    }
    final state =
        restoreStreak(['2026-10-28', '2026-10-27', '2026-10-28'], 'bad');
    expect(state.current, 2);
    expect(state.longest, 2);
  });

  for (final boundary in [1, 2, 3]) {
    test('restart reconstructs counters after write boundary $boundary',
        () async {
      final store = MemoryStore({
        'streak_active_days': ['2026-10-27', '2026-10-28'],
        'streak_current': -99,
        'streak_longest': 2,
      })
        ..writesAllowed = boundary;
      final first = create(store, () => DateTime(2026, 10, 29));
      await first.read(streakProvider.notifier).initialize();
      final restarted =
          create(MemoryStore(store.values), () => DateTime(2026, 10, 29));
      await restarted.read(streakProvider.notifier).initialize();
      expect(restarted.read(streakProvider).current, 3);
      expect(restarted.read(streakProvider).longest, 3);
    });
  }

  test('failed history write keeps session coherent, does not write counters',
      () async {
    final store = MemoryStore()..writesAllowed = 0;
    final container = create(store, () => DateTime(2026, 10, 29));
    await container.read(streakProvider.notifier).initialize();
    expect(container.read(streakProvider).current, 1);
    expect(store.writes, ['streak_pending_days', 'streak_active_days']);
    final restarted =
        create(MemoryStore(store.values), () => DateTime(2026, 10, 29));
    await restarted.read(streakProvider.notifier).initialize();
    expect(restarted.read(streakProvider).current, 1);
  });
}
