import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:holyhim/domain/calendar.dart';
import 'package:holyhim/domain/pacing.dart';
import 'package:holyhim/domain/streak.dart';
import 'package:holyhim/domain/badges.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);
  group('calendar pacing', () {
    test('a missed week makes no backlog and completed lessons remain readable',
        () {
      final pacing = pacingFor(
          {1: '2026-10-20'}, DateTime.utc(2026, 11, 3, 15), 'America/New_York');
      expect(pacing.currentDay, 2);
      expect(pacing.canBegin, isTrue);
      expect(pacing.canRead(1, {1: '2026-10-20'}), isTrue);
      expect(pacing.canRead(3, {1: '2026-10-20'}), isFalse);
    });
    test('midnight opens the next lesson, including DST fall back', () {
      final completed = {1: '2026-11-01'};
      final before = pacingFor(
          completed, DateTime.utc(2026, 11, 2, 4, 59), 'America/New_York');
      expect(before.canBegin, isFalse);
      expect(before.nextUnlock!.toUtc(), DateTime.utc(2026, 11, 2, 5));
      final after = pacingFor(
          completed, DateTime.utc(2026, 11, 2, 5), 'America/New_York');
      expect(after.canBegin, isTrue);
    });
    test('spring forward uses a 23-hour calendar day', () {
      final now = DateTime.utc(2026, 3, 8, 5);
      final pacing = pacingFor({1: '2026-03-08'}, now, 'America/New_York');
      expect(pacing.nextUnlock!.difference(now).inHours, 23);
      expect(
          pacingFor({1: '2026-03-08'}, DateTime.utc(2026, 3, 9, 4),
                  'America/New_York')
              .canBegin,
          isTrue);
    });
    test('travel changes calendar without requiring 24 elapsed hours', () {
      final completed = {1: '2026-11-03'}, now = DateTime.utc(2026, 11, 4, 1);
      expect(pacingFor(completed, now, 'America/New_York').canBegin, isFalse);
      expect(pacingFor(completed, now, 'Asia/Tokyo').canBegin, isTrue);
      expect(pacingFor(completed, now, 'Pacific/Honolulu').currentDay, 2);
    });
    test('all 365 complete is finished', () {
      final pacing = pacingFor({for (var d = 1; d <= 365; d++) d: '2026-11-03'},
          DateTime.utc(2026, 11, 4), 'UTC');
      expect(pacing.finished, isTrue);
      expect(pacing.canBegin, isFalse);
      expect(pacing.currentDay, 365);
    });
    test('calendar rejects impossible dates and handles leap February', () {
      expect(() => calendarDate('2026-02-30'), throwsFormatException);
      expect(calendarDistance('2026-03-08', '2026-03-09'), 1);
      expect(monthCalendar(2028, 2).whereType<DateTime>().length, 29);
      expect(monthCalendar(2026, 11).take(6).every((d) => d == null), isTrue);
    });
  });
  group('derived grace and streak', () {
    Map<int, String> run(int count) =>
        {for (var d = 1; d <= count; d++) d: shiftDate('2026-10-01', d - 1)};
    test('seven actual readings earn one grace', () {
      final streak = streakFor(run(7), DateTime.utc(2026, 10, 7, 12), 'UTC');
      expect(streak.current, 7);
      expect(streak.graceDays, 1);
    });
    test('grace bridges one missed day without inventing a reading', () {
      final completed = {...run(7), 8: '2026-10-09'};
      final streak = streakFor(completed, DateTime.utc(2026, 10, 9, 12), 'UTC');
      expect(streak.current, 8);
      expect(streak.graceDays, 0);
      expect(streak.graceDates, {'2026-10-08'});
      expect(completed.length, 8);
    });
    test('grace balance caps at two and cannot bridge three quiet days', () {
      final streak = streakFor(run(21), DateTime.utc(2026, 10, 25, 12), 'UTC');
      expect(streak.current, 0);
      expect(streak.longest, 21);
      expect(streak.graceDays, 0);
      expect(streak.graceDates, {'2026-10-22', '2026-10-23'});
    });
    test('today is available until midnight and does not spend a grace', () {
      final streak =
          streakFor(run(7), DateTime.utc(2026, 10, 8, 23, 59), 'UTC');
      expect(streak.current, 7);
      expect(streak.graceDays, 1);
      expect(streakFor(run(7), DateTime.utc(2026, 10, 9), 'UTC').graceDays, 0);
    });
    test('duplicate date readings cannot earn extra streak or grace', () {
      final streak = streakFor(
          {1: '2026-10-01', 2: '2026-10-01'}, DateTime.utc(2026, 10, 1), 'UTC');
      expect(streak.current, 1);
      expect(streak.longest, 1);
    });
    test('badge progress, first save and promise are derived', () {
      final completed = run(7), saved = {1: DateTime.utc(2026, 10, 1)};
      final badges = badgesFor(
          completed: completed,
          saved: saved,
          streak: streakFor(completed, DateTime.utc(2026, 10, 7), 'UTC'),
          promiseStartedAt: DateTime.utc(2026, 10, 1));
      expect(badges.length, 19);
      expect(badges.singleWhere((b) => b.id == 'days-7').earned, isTrue);
      expect(badges.singleWhere((b) => b.id == 'days-14').fraction, 0.5);
      expect(badges.singleWhere((b) => b.id == 'first-saved').earned, isTrue);
      expect(badges.singleWhere((b) => b.id == 'promise').earned, isTrue);
      expect(WalkStats.from(completed, saved).minutesWithGod, 7);
    });
    test('streak works across spring DST and current device time zone', () {
      final completed = {1: '2026-03-07', 2: '2026-03-08', 3: '2026-03-09'};
      expect(
          streakFor(completed, DateTime.utc(2026, 3, 10, 3, 59),
                  'America/New_York')
              .current,
          3);
      expect(
          streakFor(completed, DateTime.utc(2026, 3, 11, 3, 59),
                  'America/New_York')
              .current,
          3);
      expect(
          streakFor(completed, DateTime.utc(2026, 3, 11, 4), 'America/New_York')
              .current,
          0);
      expect(tz.getLocation('America/New_York').name, 'America/New_York');
    });
  });
  test('promise badge compares the timestamp in the saved calendar time zone',
      () {
    final completed = {
      for (var day = 1; day <= 7; day++)
        day: '2026-11-${day.toString().padLeft(2, '0')}'
    };
    final streak =
        streakFor(completed, DateTime.utc(2026, 11, 7, 20), 'America/New_York');
    final newYork = badgesFor(
        completed: completed,
        saved: {},
        streak: streak,
        promiseStartedAt: DateTime.utc(2026, 11, 2, 1, 30),
        timeZone: 'America/New_York');
    expect(
        newYork.singleWhere((badge) => badge.id == 'promise').earned, isTrue);
    final tokyo = badgesFor(
        completed: completed,
        saved: {},
        streak: streak,
        promiseStartedAt: DateTime.utc(2026, 11, 1, 17),
        timeZone: 'Asia/Tokyo');
    expect(tokyo.singleWhere((badge) => badge.id == 'promise').progress, 0);
    expect(tokyo.singleWhere((badge) => badge.id == 'promise').earned, isFalse);
  });
}
