import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/streak_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'real preferences adapter handles raw corrupt types without typed getter casts',
      () async {
    SharedPreferences.setMockInitialValues({
      'signed-out:streak_active_days': 'wrong type',
      'signed-out:streak_longest': -10,
      'progress_completed_days': 42,
      'progress_onboarding_complete': 'true',
      'paywall_lifetime_unlocked': 1,
    });
    final container = ProviderContainer(overrides: [
      localStoreProvider
          .overrideWithValue(PreferencesStore(prefix: 'signed-out:')),
      localClockProvider.overrideWithValue(() => DateTime(2026, 10, 29)),
    ]);
    addTearDown(container.dispose);
    await container.read(streakProvider.notifier).initialize();
    await container.read(progressProvider.notifier).initialize();
    expect(container.read(streakProvider).current, 1);
    expect(container.read(streakProvider).longest, 1);
    expect(container.read(progressProvider).completedDays, isEmpty);
    expect(container.read(progressProvider).onboardingComplete, false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.get('signed-out:streak_active_days'), ['2026-10-29']);
  });

  test('preferences adapter roundtrips booleans, counters and day lists',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferencesStore();
    expect(await store.read('missing'), isNull);
    expect(await store.write('access', true), true);
    expect(await store.write('counter', 2), true);
    expect(await store.write('days', <String>['2026-10-29']), true);
    expect(await store.read('access'), true);
    expect(await store.read('counter'), 2);
    expect(await store.read('days'), ['2026-10-29']);
    expect(await store.write('unsupported', <int>[1]), false);
  });
}
