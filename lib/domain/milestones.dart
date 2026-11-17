import 'badges.dart';

/// The next day medallion and how close she is to it. Progress shown as a
/// short distance to a named goal keeps a habit moving (the goal-gradient
/// effect); it never shames a missed day.
class Milestone {
  final int goal, remaining;
  final String title;

  /// 0 to 1, from the previous medallion to this one.
  final double progress;
  const Milestone(
      {required this.goal,
      required this.remaining,
      required this.title,
      required this.progress});

  String get distance =>
      '$remaining more ${remaining == 1 ? 'morning' : 'mornings'} to $title';
}

Milestone? nextMilestone(int lessonsRead) {
  var previous = 0;
  for (final entry in dayBadgeTitles.entries) {
    if (entry.key > lessonsRead) {
      return Milestone(
          goal: entry.key,
          remaining: entry.key - lessonsRead,
          title: entry.value,
          progress: (lessonsRead - previous) / (entry.key - previous));
    }
    previous = entry.key;
  }
  return null;
}

/// Who she is becoming, said once at each day medallion. Identity outlasts
/// rewards; these are affirmations, never promises.
String? identityFor(int lessonsRead) => const {
      1: 'Every faithful story begins with one morning.',
      3: 'You keep showing up. That is faith, lived.',
      7: 'A week with God. This is who you are becoming.',
      14: 'Your roots are going deeper.',
      21: 'This is more than a habit now. It is a home.',
      30: 'A month of mornings. You are a woman of the Word.',
      50: 'Fifty mornings. Your quiet strength is showing.',
      75: 'A steady light, morning after morning.',
      100: 'One hundred mornings with God.',
      150: 'Deep roots grow quietly. Yours have.',
      200: 'Two hundred mornings of hope.',
      250: 'An open heart, and it shows.',
      300: 'A faithful season, held in His hands.',
      365: 'A whole year of mornings with God.',
    }[lessonsRead];
