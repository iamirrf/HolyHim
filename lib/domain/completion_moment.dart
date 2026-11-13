import 'badges.dart';
import 'streak.dart';

/// An immutable receipt for one completion. It is never persisted as an award.
class CompletionMoment {
  final int day, previousStreak, streak;
  final List<WalkBadge> newlyEarned;
  const CompletionMoment(
      {required this.day,
      required this.previousStreak,
      required this.streak,
      required this.newlyEarned});

  factory CompletionMoment.fromProgress(
      {required int day,
      required Map<int, String> beforeCompleted,
      required Map<int, String> completed,
      required Map<int, DateTime> beforeSaved,
      required Map<int, DateTime> saved,
      required String timeZone,
      DateTime? promiseStartedAt,
      required DateTime now}) {
    final previous = streakFor(beforeCompleted, now, timeZone);
    final current = streakFor(completed, now, timeZone);
    final previousBadges = badgesFor(
            completed: beforeCompleted,
            saved: beforeSaved,
            streak: previous,
            promiseStartedAt: promiseStartedAt,
            timeZone: timeZone)
        .where((badge) => badge.earned)
        .map((badge) => badge.id)
        .toSet();
    final earned = badgesFor(
            completed: completed,
            saved: saved,
            streak: current,
            promiseStartedAt: promiseStartedAt,
            timeZone: timeZone)
        .where((badge) => badge.earned && !previousBadges.contains(badge.id));
    return CompletionMoment(
        day: day,
        previousStreak: previous.current,
        streak: current.current,
        newlyEarned: List.unmodifiable(earned));
  }
}
