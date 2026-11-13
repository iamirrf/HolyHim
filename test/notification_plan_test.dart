import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:holyhim/domain/lesson.dart';
import 'package:holyhim/domain/notification_plan.dart';

const lesson = Lesson(
    day: 3,
    title: 'A place to bring trouble',
    reference: 'Psalm 46:1',
    theme: 'Refuge',
    verse: 'God is our refuge and strength, a very present help in trouble.',
    meaning: 'Meaning',
    heart: 'Heart',
    holdOn: 'You have somewhere to bring this day.',
    prayer: 'God, be near. Amen.',
    teaser: 'God is our refuge and strength, a very present help in trouble.');
void main() {
  setUpAll(tzdata.initializeTimeZones);
  List<PlannedNotification> plan(
          {Map<int, String>? completed, bool enabled = true}) =>
      notificationPlan(
          now: DateTime.utc(2026, 11, 3, 10),
          timeZone: 'America/New_York',
          minutes: 420,
          name: 'A very very very long name that needs to fit',
          hearts: ['Peace'],
          completed: completed ?? {1: '2026-11-01', 2: '2026-11-02'},
          lessons: [lesson],
          enabled: enabled);
  test('queue stays below iOS cap, titles fit and days are real', () {
    final queue = plan();
    expect(queue.length, 30);
    expect(queue.map((n) => n.id).toSet().length, queue.length);
    expect(queue.every((n) => n.day == 3 && n.title.length <= 40), isTrue);
    expect(
        queue.where((n) => n.kind == NotificationKind.streakSaver).length, 0);
    expect(queue.where((n) => n.kind == NotificationKind.comeback).length, 0);
    expect(queue.every((n) => n.at.isAfter(DateTime.utc(2026, 11, 3, 10))),
        isTrue);
  });
  test('completion does not change the independent daily verse queue', () {
    final queue =
        plan(completed: {1: '2026-11-01', 2: '2026-11-02', 3: '2026-11-03'});
    expect(queue.any((n) => n.at.day == 3), isTrue);
    expect(queue.any((n) => n.kind == NotificationKind.streakSaver), isFalse);
    expect(plan(enabled: false), isEmpty);
  });
  test('DST keeps the chosen wall time and switches UTC offset', () {
    final queue = notificationPlan(
        now: DateTime.utc(2026, 10, 30),
        timeZone: 'America/New_York',
        minutes: 420,
        name: 'Eve',
        hearts: [],
        completed: {},
        lessons: [lesson]);
    expect(queue.every((n) => n.at.hour == 7), isTrue);
    expect(queue.first.at.timeZoneOffset.inHours, -4);
    expect(queue.last.at.timeZoneOffset.inHours, -5);
  });
  test('word-boundary teaser always ends in an ellipsis', () {
    final excerpt = teaserExcerpt(
        'A long verse with many words that should be cut gently on a word boundary, with no chopped word.',
        limit: 45);
    expect(excerpt.length, lessThanOrEqualTo(45));
    expect(excerpt.endsWith('…'), isTrue);
    expect(teaserExcerpt('God is near.'), 'God is near.');
  });
  NotificationTap? tap(String payload) => parseNotificationTap(payload,
      account: 'owner',
      completed: {1: '2026-11-01', 2: '2026-11-02'},
      now: DateTime.utc(2026, 11, 3),
      timeZone: 'UTC');
  test(
      'warm and cold payloads route next lesson, stale teasers go to verse sheet',
      () {
    final payload = plan().first.payload('owner');
    expect(tap(payload)!.day, 3);
    expect(tap(payload)!.verseOnly, isTrue);
    final old = jsonEncode({
      'version': 2,
      'account': 'owner',
      'day': 1,
      'continuation': 'God is near…'
    });
    expect(tap(old)!.verseOnly, isTrue);
    expect(tap(old)!.continuation, 'God is near…');
  });
  test('another account, malformed payload and out-of-range days are ignored',
      () {
    for (final payload in [
      'broken',
      jsonEncode({'version': 2, 'account': 'other', 'day': 3}),
      jsonEncode({'version': 2, 'account': 'owner', 'day': 366}),
      jsonEncode({'version': 1, 'account': 'owner', 'day': 3})
    ]) {
      expect(tap(payload), isNull);
    }
  });
}
