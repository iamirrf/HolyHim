import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:holyhim/domain/lesson.dart';
import 'package:holyhim/domain/notification_plan.dart';

Lesson _lesson(int day, {String reference = 'Psalm 46:1'}) => Lesson(
    day: day,
    title: 'Lesson $day',
    reference: reference,
    theme: 'Refuge',
    verse: 'God is our refuge and strength, a very present help in trouble.',
    meaning: 'Meaning',
    heart: 'Heart',
    holdOn: 'You have somewhere to bring this day.',
    prayer: 'God, be near. Amen.',
    teaser: 'A safe place that does not wait for the storm to pass.');

final lessons = [
  for (var d = 1; d <= 40; d++)
    _lesson(d, reference: d == 29 ? 'Numbers 6:24-26' : 'Psalm 46:$d')
];

void main() {
  setUpAll(tzdata.initializeTimeZones);
  // 10:00 UTC is 5:00 AM in New York on November 3, 2026.
  List<PlannedNotification> plan(
          {Map<int, String>? completed,
          bool enabled = true,
          String? birthday,
          DateTime? now,
          String name = 'Mira Rose'}) =>
      notificationPlan(
          now: now ?? DateTime.utc(2026, 11, 3, 10),
          timeZone: 'America/New_York',
          minutes: 420,
          name: name,
          hearts: ['peace'],
          completed: completed ?? {1: '2026-11-01', 2: '2026-11-02'},
          lessons: lessons,
          birthday: birthday,
          enabled: enabled);

  test('queue stays below the iOS cap with unique IDs, all in the future', () {
    final queue = plan();
    expect(queue.length, lessThanOrEqualTo(30));
    expect(queue.map((n) => n.id).toSet().length, queue.length);
    expect(queue.every((n) => n.title.length <= 40), isTrue);
    expect(queue.every((n) => n.at.isAfter(DateTime.utc(2026, 11, 3, 10))),
        isTrue);
  });

  test('a new reader gets the greeting she saw in onboarding', () {
    final next = plan(completed: {}).first;
    expect(next.title, '🌅 Good morning, Mira');
    expect(next.subtitle, 'Day 1 · Lesson 1');
  });

  test('a medallion one morning away, then a walk, then a greeting', () {
    // Two read: the third earns "Small Faithful Steps".
    expect(plan().first.title, '🏅 Mira, a medallion is one morning away');
    // Four read on consecutive days, two away from the next medallion.
    final walk = plan(completed: {
      1: '2026-10-30',
      2: '2026-10-31',
      3: '2026-11-01',
      4: '2026-11-02'
    });
    expect(walk.first.title, '🔥 Your 4-day habit continues, Mira');
    // A long name falls back to the plain line rather than overflow.
    final long = plan(name: 'Maximiliana Rose', completed: {
      1: '2026-10-30',
      2: '2026-10-31',
      3: '2026-11-01',
      4: '2026-11-02'
    });
    expect(long.first.title.length, lessThanOrEqualTo(40));
  });

  test('later verse notes vary their opening line', () {
    final titles = plan()
        .skip(1)
        .where((n) => n.kind == NotificationKind.daily)
        .map((n) => n.title)
        .toSet();
    expect(titles.length, greaterThan(2));
  });

  test('the next note points at the waiting lesson', () {
    final next = plan().first;
    expect(next.subtitle, 'Day 3 · Lesson 3');
    expect(next.opensLesson, isTrue);
    // The note carries the day's verse, then where it is from.
    expect(next.body, lessonNoteBody(lessons[2]));
    expect(next.body, startsWith('“'));
    expect(next.body, endsWith('\n— ${lessons[2].reference}'));
    // Later notes carry the verse of the day and open the verse.
    expect(plan()[1].opensLesson, isFalse);
  });

  test('an evening note keeps a walk going only on a day not yet read', () {
    final saver =
        plan().where((n) => n.kind == NotificationKind.streakSaver).toList();
    expect(saver, hasLength(1));
    expect(saver.single.at.hour, 20);
    expect(saver.single.title, '🌙 Keep your 2-day habit going');
    final readToday =
        plan(completed: {1: '2026-11-01', 2: '2026-11-02', 3: '2026-11-03'});
    expect(
        readToday.any((n) => n.kind == NotificationKind.streakSaver), isFalse);
    expect(
        plan(completed: {1: '2026-11-02'})
            .any((n) => n.kind == NotificationKind.streakSaver),
        isFalse);
  });

  test('quiet days bring a saved-place note on days three and seven', () {
    final queue = plan(completed: {1: '2026-10-31'});
    final comebacks =
        queue.where((n) => n.kind == NotificationKind.comeback).toList();
    // Last read October 31: notes on November 3 and November 7.
    expect(comebacks.map((n) => n.at.day), [3, 7]);
    expect(comebacks.first.title, '🕊️ Your place is saved');
    expect(comebacks.last.title, '🤝 Still here for you');
    final early = plan(completed: {1: '2026-11-02'})
        .where((n) => n.kind == NotificationKind.comeback)
        .map((n) => n.at.day);
    expect(early, [5, 9]);
  });

  test('a birthday blessing replaces that day\'s note', () {
    final queue = plan(birthday: '1995-11-10');
    final birthday =
        queue.where((n) => n.kind == NotificationKind.birthday).toList();
    expect(birthday, hasLength(1));
    expect(birthday.single.at.day, 10);
    expect(birthday.single.title, '🎂 Happy birthday, Mira');
    // The blessing is the Bible's own words, not a paraphrase.
    expect(birthday.single.body,
        '${noteVerse(lessons[28].verse, limit: 240)}\n— ${lessons[28].reference}');
    expect(birthday.single.day, 29);
    expect(
        queue.where((n) => n.at.day == 10 && n.at.month == 11), hasLength(1));
  });

  test('notes speak of a habit, one emoji opens each title', () {
    for (final n
        in plan(birthday: '1995-11-10', completed: {1: '2026-10-31'})) {
      expect('${n.title} ${n.body}'.toLowerCase().contains('walk'), isFalse,
          reason: n.title);
      expect(n.title.runes.first, greaterThan(0x2000), reason: n.title);
    }
  });

  test('no notes when reminders are off, and nothing mentions buying', () {
    expect(plan(enabled: false), isEmpty);
    for (final n
        in plan(birthday: '1995-11-10', completed: {1: '2026-10-31'})) {
      final text = '${n.title} ${n.subtitle} ${n.body}'.toLowerCase();
      for (final word in ['unlock', 'buy', 'price', 'offer', 'sale', '\$']) {
        expect(text.contains(word), isFalse, reason: text);
      }
    }
  });

  test('DST keeps the chosen wall time and switches UTC offset', () {
    final queue = notificationPlan(
        now: DateTime.utc(2026, 10, 30),
        timeZone: 'America/New_York',
        minutes: 420,
        name: 'Eve',
        hearts: [],
        completed: {},
        lessons: lessons);
    final daily = queue.where((n) => n.kind != NotificationKind.streakSaver);
    expect(daily.every((n) => n.at.hour == 7), isTrue);
    expect(daily.first.at.timeZoneOffset.inHours, -4);
    expect(daily.last.at.timeZoneOffset.inHours, -5);
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
      'lesson notes open the lesson; verse notes and stale days open the verse',
      () {
    final queue = plan();
    expect(tap(queue.first.payload('owner'))!.verseOnly, isFalse);
    expect(tap(queue[1].payload('owner'))!.verseOnly, isTrue);
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
