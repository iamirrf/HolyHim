import 'package:timezone/timezone.dart' as tz;
import 'calendar.dart';

class Pacing {
  /// The first unfinished lesson, or 365 after the whole walk is complete.
  final int currentDay;
  final DateTime? nextUnlock;
  final bool completedToday, finished;
  const Pacing(
      {required this.currentDay,
      required this.completedToday,
      required this.finished,
      this.nextUnlock});
  bool get canBegin => !finished && nextUnlock == null;
  int get displayDay =>
      nextUnlock != null ? (currentDay - 1).clamp(1, 365) : currentDay;
  bool canRead(int day, Map<int, String> completed) =>
      day >= 1 &&
      day <= 365 &&
      (completed.containsKey(day) || (day == currentDay && canBegin));
}

Pacing pacingFor(Map<int, String> completed, DateTime now, String timeZone) {
  final local = localNow(now, timeZone), today = dateKey(local);
  var next = 1;
  while (next <= 365 && completed.containsKey(next)) {
    next++;
  }
  final complete = next > 365;
  final readToday = completed.values.contains(today);
  // Completing a previous lesson is what starts the next calendar-day wait.
  final previousDate = completed[next - 1];
  DateTime? unlock;
  if (!complete && previousDate != null && previousDate.compareTo(today) >= 0) {
    final previous = calendarDate(previousDate);
    unlock = tz.TZDateTime(
        local.location, previous.year, previous.month, previous.day + 1);
  }
  return Pacing(
      currentDay: next.clamp(1, 365),
      completedToday: readToday,
      finished: complete,
      nextUnlock: unlock);
}
