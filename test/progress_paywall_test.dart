import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/paywall_service.dart';
import 'support.dart';

void main() {
  ProviderContainer create(MemoryStore store) {
    final container = ProviderContainer(
        overrides: [localStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    return container;
  }

  test('valid progress survives corruption, invalid day numbers do not count',
      () async {
    final store = MemoryStore({
      'progress_completed_days': ['1', 'invalid', '3', '-1', '999'],
      'progress_onboarding_complete': 'yes',
      'paywall_lifetime_unlocked': 'yes',
    });
    final container = create(store);
    final service = container.read(progressProvider.notifier);
    await service.initialize();
    await container.read(paywallProvider.notifier).initialize();
    expect(container.read(progressProvider).completedDays, {1, 3});
    expect(container.read(progressProvider).todayDay, 2);
    expect(container.read(progressProvider).onboardingComplete, false);
    expect(container.read(paywallProvider), false);
    await Future.wait([
      service.completeDay(2),
      service.completeDay(4),
      service.completeDay(2)
    ]);
    expect(container.read(progressProvider).completedDays, {1, 2, 3, 4});
    final before = store.writes.length;
    await service.completeDay(999);
    expect(store.writes.length, before);
  });

  test('all-complete, reread completion and persisted restart are stable',
      () async {
    final store = MemoryStore();
    final container = create(store);
    final progress = container.read(progressProvider.notifier);
    for (final lesson in lessons) {
      await progress.completeDay(lesson.day);
    }
    await progress.finishOnboarding();
    await container.read(paywallProvider.notifier).unlock();
    expect(container.read(progressProvider).allComplete, true);
    expect(container.read(progressProvider).fraction, 1);
    final before = store.writes.length;
    await progress.completeDay(1);
    expect(store.writes.length, before);
    final restarted = create(MemoryStore(store.values));
    await restarted.read(progressProvider.notifier).initialize();
    await restarted.read(paywallProvider.notifier).initialize();
    expect(restarted.read(progressProvider).completedCount, lessons.length);
    expect(restarted.read(progressProvider).onboardingComplete, true);
    expect(restarted.read(paywallProvider), true);
  });

  test('storage outage allows local session without pretending to persist',
      () async {
    final store = MemoryStore()..writesAllowed = 0;
    final container = create(store);
    await container.read(progressProvider.notifier).finishOnboarding();
    await container.read(progressProvider.notifier).completeDay(1);
    await container.read(paywallProvider.notifier).unlock();
    expect(container.read(progressProvider).completedCount, 1);
    expect(container.read(paywallProvider), true);
    final restarted = create(MemoryStore(store.values));
    await restarted.read(paywallProvider.notifier).initialize();
    expect(restarted.read(paywallProvider), false);
  });

  test('365-entry catalogs need no progress or screen limit change', () {
    final catalog = List.generate(
        365,
        (i) => DailyLesson(
              day: i + 1,
              title: 'Synthetic test entry',
              verseReference: '',
              verseText: '',
              confidence: '',
              reason: '',
              hope: '',
              reflection: '',
            ));
    final partial = ProgressState(
        catalog: catalog,
        completedDays: {for (var day = 1; day <= 364; day++) day});
    expect(partial.todayDay, 365);
    expect(partial.fraction, 364 / 365);
    expect(
        partial.copyWith(completedDays: {
          for (var day = 1; day <= 365; day++) day
        }).allComplete,
        true);
    expect(const ProgressState(catalog: []).fraction, 0);
  });
}
