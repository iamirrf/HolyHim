import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;
import 'package:holyher/services/reminder_service.dart';

void main() {
  setUpAll(data.initializeTimeZones);
  test(
      '60 one-shot quotes keep device wall time across DST and journey eligibility across zones',
      () {
    final device = tz.getLocation('America/New_York');
    final queue = buildQuoteReminderQueue(
        now: tz.TZDateTime(device, 2026, 3, 7, 9),
        minutes: 480,
        startDate: '2026-03-01',
        journeyTimeZone: 'America/Los_Angeles');
    expect(queue.length, 60);
    expect(queue.map((r) => r.id).toSet().length, 60);
    for (final reminder in queue) {
      expect(reminder.scheduledDate.hour, 8);
      expect(reminder.scheduledDate.minute, 0);
    }
    expect(queue.first.scheduledDate.day, 8);
    expect(queue.first.scheduledDate.timeZoneOffset, const Duration(hours: -4));
    final dates = queue
        .map((r) =>
            '${r.scheduledDate.year}-${r.scheduledDate.month}-${r.scheduledDate.day}')
        .toSet();
    expect(dates.length, 60);
  });
  test('delivery and lesson calendars may fall on different dates', () {
    final queue = buildQuoteReminderQueue(
        now: tz.TZDateTime(tz.getLocation('Asia/Tokyo'), 2026, 11, 2, 7),
        minutes: 480,
        startDate: '2026-11-01',
        journeyTimeZone: 'America/New_York',
        count: 1);
    expect(queue.single.day, 1);
    expect(queue.single.scheduledDate.day, 2);
  });
  test('year-end reminders keep valid lesson 365 destinations', () {
    final queue = buildQuoteReminderQueue(
        now: tz.TZDateTime.utc(2027, 11, 3),
        minutes: 480,
        startDate: '2026-11-02',
        journeyTimeZone: 'UTC');
    expect(queue.every((r) => r.day == 365), isTrue);
  });
}
