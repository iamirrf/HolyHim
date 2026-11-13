import 'calendar.dart';
import 'lesson.dart';

/// Local civil dates, independent of progress and of elapsed DST hours.
int dailyVerseDay(DateTime now, String timeZone, {int count = 365}) {
  assert(count > 0);
  final date = localNow(now, timeZone);
  final ordinal = DateTime.utc(date.year, date.month, date.day)
      .difference(DateTime.utc(2026, 1, 1))
      .inDays;
  return ordinal % count + 1;
}

Lesson dailyVerse(List<Lesson> lessons, DateTime now, String timeZone) =>
    lessons[dailyVerseDay(now, timeZone, count: lessons.length) - 1];
