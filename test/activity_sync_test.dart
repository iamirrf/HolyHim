import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/streak_service.dart';
import 'support.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(user: AuthUser(uid: 'alice'));
}

class _Progress extends ProgressNotifier {
  @override
  ProgressState build() => const ProgressState(
        journeyStarted: true,
        unlockedThrough: 3,
        startDate: '2026-10-29',
        timeZone: 'America/New_York',
      );
  @override
  Future<void> initialize() async {}
}

class _Activity implements ActivityGateway {
  bool offline = true;
  final server = <String>{};
  final submissions = <List<String>>[];
  @override
  Future<List<String>> merge(String uid, List<String> days) async {
    expect(uid, 'alice');
    submissions.add([...days]);
    if (offline) throw StateError('Offline');
    server.addAll(days);
    return server.toList()..sort();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer create(
      MemoryStore store, DateTime Function() clock, _Activity gateway) {
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_Auth.new),
      progressProvider.overrideWith(_Progress.new),
      localStoreProvider.overrideWithValue(store),
      localClockProvider.overrideWithValue(clock),
      activityGatewayProvider.overrideWithValue(gateway),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('offline streak uses account dates and survives restart before merging',
      () async {
    // UTC/device date is already Oct30, but New York is still Oct29.
    var now = DateTime.utc(2026, 10, 30, 3, 30);
    final gateway = _Activity();
    final store = MemoryStore();
    final first = create(store, () => now, gateway);
    await first.read(streakProvider.notifier).initialize();
    expect(first.read(streakProvider).activeDays, {'2026-10-29'});
    expect(store.values['streak_pending_days'], ['2026-10-29']);
    now = DateTime.utc(2026, 10, 31, 3);
    await first.read(streakProvider.notifier).markTodayActive();
    expect(first.read(streakProvider).current, 2);
    expect(store.values['streak_pending_days'], ['2026-10-29', '2026-10-30']);

    now = DateTime.utc(2026, 11, 1, 3);
    gateway.offline = false;
    final restartedStore = MemoryStore(store.values);
    final restarted = create(restartedStore, () => now, gateway);
    await restarted.read(streakProvider.notifier).initialize();
    expect(
        gateway.submissions.last, ['2026-10-29', '2026-10-30', '2026-10-31']);
    expect(gateway.server, {'2026-10-29', '2026-10-30', '2026-10-31'});
    expect(restarted.read(streakProvider).current, 3);
    expect(restartedStore.values['streak_pending_days'], isEmpty);
    await restarted.read(streakProvider.notifier).markTodayActive();
    expect(gateway.submissions.last, isEmpty);
    expect(restarted.read(streakProvider).current, 3);
  });

  test('a saved activity outbox recovers history interrupted before its write',
      () async {
    final store = MemoryStore({
      'streak_active_days': ['2026-10-29'],
      'streak_pending_days': ['2026-10-29', '2026-10-30'],
    });
    final container =
        create(store, () => DateTime.utc(2026, 11, 1, 3), _Activity());
    await container.read(streakProvider.notifier).initialize();
    expect(container.read(streakProvider).current, 3);
    expect(container.read(streakProvider).activeDays,
        {'2026-10-29', '2026-10-30', '2026-10-31'});
  });

  test('account calendar remains correct through repeated DST hours', () {
    final before = accountCalendarTime(
        DateTime.utc(2026, 11, 1, 5, 30), 'America/New_York');
    final repeated = accountCalendarTime(
        DateTime.utc(2026, 11, 1, 6, 30), 'America/New_York');
    final late = accountCalendarTime(
        DateTime.utc(2026, 11, 2, 4, 30), 'America/New_York');
    final next = accountCalendarTime(
        DateTime.utc(2026, 11, 2, 5, 1), 'America/New_York');
    expect(before.hour, 1);
    expect(repeated.hour, 1);
    expect(StreakNotifier.dayKey(before), '2026-11-01');
    expect(StreakNotifier.dayKey(repeated), '2026-11-01');
    expect(StreakNotifier.dayKey(late), '2026-11-01');
    expect(StreakNotifier.dayKey(next), '2026-11-02');
  });

  test(
      'pending activity dates reject future and invalid entries and stay bounded',
      () {
    final days = {
      for (var index = 0; index < 500; index++)
        StreakNotifier.dayKey(DateTime(2025, 1, 1 + index)),
      'not a date',
      '2025-02-30',
      '2099-01-01',
    };
    final outbox =
        activityDaysForSync(days, today: '2026-05-15', startDate: '2025-02-01');
    expect(outbox.length, 366);
    expect(outbox.every((day) => day.compareTo('2026-05-15') <= 0), isTrue);
    expect(outbox.contains('2025-01-01'), isFalse);
    expect(outbox.contains('2025-02-30'), isFalse);
    expect(outbox.contains('2099-01-01'), isFalse);
  });
}
