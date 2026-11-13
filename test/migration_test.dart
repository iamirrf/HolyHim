import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/services/migration.dart';
import 'package:holyhim/services/repository.dart';

void main() {
  test(
      'v4 maps profile, exact completion dates, saved timestamps, and tombstones',
      () {
    final now = DateTime.utc(2026, 11, 3);
    final mapped = mapLegacyAccount(profile: {
      'name': 'Mira',
      'focus': 'peace',
      'reminderMinutes': 420,
      'onboardingComplete': true,
      'theme': 'midnight',
      'readingScale': 1.5
    }, journey: {
      'completionDates': {
        '1': '2026-10-30',
        '2': '2026-11-01',
        '366': '2026-11-02',
        '3': '2026-02-30'
      },
      'timeZone': 'America/New_York'
    }, saved: {
      'days': {'1': 1793664000000, '2': null}
    }, now: now);
    expect(mapped.profile.name, 'Mira');
    expect(mapped.profile.hearts, ['Peace']);
    expect(mapped.profile.reminderEnabled, isTrue);
    expect(mapped.profile.reminderMinutes, 420);
    expect(mapped.profile.onboarded, isTrue);
    expect(mapped.profile.readingScale, 1.5);
    expect(mapped.profile.timeZone, 'America/New_York');
    expect(mapped.profile.migratedAt, now);
    expect(mapped.completed, {1: '2026-10-30', 2: '2026-11-01'});
    expect(mapped.saved.keys, [1]);
    expect(mapped.saved[1]!.millisecondsSinceEpoch, 1793664000000);
  });
  test('v6 serialization matches the rules payload and optional nulls', () {
    final profile = AppProfile(
        name: 'Mira', hearts: ['Peace', 'Rest'], timeZone: 'America/New_York');
    final payload = profile.toFirestore();
    expect(payload['schema'], 6);
    expect(payload['reminder'], {'enabled': false, 'minutes': 420});
    expect(payload['promise'], {'startedAt': null});
    expect(payload['onboardedAt'], null);
    expect(AppProfile.fromFirestore(payload).hearts, ['Peace', 'Rest']);
    expect(profile.copyWith(onboardedAt: DateTime.utc(2026, 11, 3)).onboarded,
        isTrue);
  });
  test(
      'unknown optional theme does not lose settings and future keys are ignored',
      () {
    final mapped = mapLegacyAccount(profile: {
      'theme': 'a-future-theme',
      'haptics': false,
      'sounds': true,
      'hearts': ['Hope', 'Joy', 'Rest', 'Peace'],
      'readingScale': 5
    }, journey: {});
    expect(mapped.profile.theme, 'a-future-theme');
    expect(mapped.profile.hearts.length, 3);
    expect(mapped.profile.readingScale, 2);
    expect(mapped.profile.haptics, isFalse);
    expect(mapped.profile.sounds, isTrue);
    expect(mapped.profile.onboarded, isFalse);
  });
}
