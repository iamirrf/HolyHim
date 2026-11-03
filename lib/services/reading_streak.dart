import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/streak_logic.dart';
import 'package:holyher/services/journey_clock.dart';

/// Visit activity remains stored separately by StreakNotifier for legacy data.
/// Every visible reading streak is derived only from actual reading dates.
final readingStreakProvider = Provider<StreakState>((ref) {
  final progress = ref.watch(progressProvider);
  final today =
      accountCalendarTime(ref.watch(localClockProvider)(), progress.timeZone);
  final dates = {...progress.readingDates, ...progress.completionDates.values}
      .where((d) =>
          parseLocalDay(d) != null && d.compareTo(localDayKey(today)) <= 0)
      .toSet();
  final restored = restoreStreak(dates.toList(), 0);
  final yesterday =
      localDayKey(DateTime(today.year, today.month, today.day - 1));
  return restored.copyWith(
      current: dates.contains(localDayKey(today)) || dates.contains(yesterday)
          ? restored.current
          : 0);
});
