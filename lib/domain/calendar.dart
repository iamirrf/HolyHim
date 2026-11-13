import 'package:timezone/timezone.dart' as tz;

String dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Calendar arithmetic uses UTC ordinals, never elapsed local 24-hour periods.
DateTime calendarDate(String value) {
  final date = DateTime.tryParse('${value}T00:00:00Z');
  if (date == null || dateKey(date) != value) {
    throw FormatException('Invalid date', value);
  }
  return date;
}

int calendarDistance(String from, String to) =>
    calendarDate(to).difference(calendarDate(from)).inDays;

String shiftDate(String value, int days) =>
    dateKey(calendarDate(value).add(Duration(days: days)));

tz.Location locationFor(String name) {
  try {
    return tz.getLocation(name);
  } catch (_) {
    return tz.UTC;
  }
}

tz.TZDateTime localNow(DateTime now, String timeZone) =>
    tz.TZDateTime.from(now, locationFor(timeZone));

class WalkStats {
  final int daysRead, minutesWithGod, versesKept;
  const WalkStats(
      {required this.daysRead,
      required this.minutesWithGod,
      required this.versesKept});
  factory WalkStats.from(
          Map<int, String> completed, Map<int, DateTime> saved) =>
      WalkStats(
          daysRead: completed.length,
          minutesWithGod: completed.length,
          versesKept: saved.length);
}

/// Nulls are the leading empty cells in a Monday-first month grid.
List<DateTime?> monthCalendar(int year, int month) {
  final first = DateTime.utc(year, month);
  final count = DateTime.utc(year, month + 1, 0).day;
  return [
    for (var i = 1; i < first.weekday; i++) null,
    for (var day = 1; day <= count; day++) DateTime.utc(year, month, day)
  ];
}
