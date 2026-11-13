import 'streak.dart';
import 'calendar.dart';

class WalkBadge {
  final String id, title, description;
  final int progress, goal;
  const WalkBadge(
      {required this.id,
      required this.title,
      required this.description,
      required this.progress,
      required this.goal});
  bool get earned => progress >= goal;
  double get fraction => (progress / goal).clamp(0, 1);
}

const dayBadgeTitles = <int, String>{
  1: 'A Beautiful Beginning',
  3: 'Small Faithful Steps',
  7: 'A Faithful Week',
  14: 'Roots of Trust',
  21: 'A Growing Heart',
  30: 'A Month of Grace',
  50: 'Quiet Strength',
  75: 'A Steady Light',
  100: 'One Hundred Mornings',
  150: 'Deepening Roots',
  200: 'Living Hope',
  250: 'An Open Heart',
  300: 'A Faithful Season',
  365: 'A Year with God'
};

List<WalkBadge> badgesFor(
    {required Map<int, String> completed,
    required Map<int, DateTime> saved,
    required Streak streak,
    DateTime? promiseStartedAt,
    String timeZone = 'UTC'}) {
  final promiseRead = promiseStartedAt == null
      ? 0
      : completed.values
          .toSet()
          .where((date) =>
              date.compareTo(dateKey(localNow(promiseStartedAt, timeZone))) >=
              0)
          .length;
  final dates = completed.values.toSet().toList()..sort();
  final returned = List.generate(
      dates.length > 1 ? dates.length - 1 : 0,
      (i) => calendarDate(dates[i + 1])
          .difference(calendarDate(dates[i]))
          .inDays).any((gap) => gap > 1);
  return [
    for (final entry in dayBadgeTitles.entries)
      WalkBadge(
          id: 'days-${entry.key}',
          title: entry.value,
          description:
              'Spend ${entry.key} ${entry.key == 1 ? 'day' : 'days'} in Scripture.',
          progress: completed.length,
          goal: entry.key),
    for (final goal in [7, 30, 100])
      WalkBadge(
          id: 'streak-$goal',
          title: '$goal Days of Faithfulness',
          description: 'Grow a $goal-reading streak.',
          progress: streak.longest,
          goal: goal),
    WalkBadge(
        id: 'first-saved',
        title: 'Words to Keep',
        description: 'Save your first verse.',
        progress: saved.isEmpty ? 0 : 1,
        goal: 1),
    WalkBadge(
        id: 'promise',
        title: promiseRead >= 7 ? 'Your Promise Kept' : 'Returning with Grace',
        description: promiseRead >= 7
            ? 'Your seven-day promise, remembered.'
            : 'Return to your walk after a missed day.',
        progress: promiseRead >= 7 || returned ? 1 : 0,
        goal: 1),
  ];
}
