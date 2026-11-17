import 'badges.dart';

/// The next day medallion and how close he is to it. Progress shown as a
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

/// Who he is becoming, said once at each day medallion. Identity outlasts
/// rewards; these are affirmations, never promises. Plain words, no
/// swagger: never "warrior", "alpha" or "real men" (content/STYLE.md).
String? identityFor(int lessonsRead) => const {
      1: 'Every road starts with one step. You took it.',
      3: 'Three mornings. You keep showing up. That is faith, lived.',
      7: 'A week in the Word. This is who you are becoming.',
      14: 'Two weeks strong. Your roots are going deeper.',
      21: 'This is more than a habit now. It is how your day starts.',
      30: 'A month standing. You are a man of the Word.',
      50: 'Fifty mornings. Steady strength is showing.',
      75: 'A lamp to your feet, morning after morning.',
      100: 'One hundred mornings in the Word.',
      150: 'Deep roots grow quietly. Yours have.',
      200: 'Two hundred mornings of living hope.',
      250: 'A faithful heart, and it shows.',
      300: 'Three hundred mornings, faithful in the small things.',
      365: 'The whole road. A year of mornings with God.',
    }[lessonsRead];
