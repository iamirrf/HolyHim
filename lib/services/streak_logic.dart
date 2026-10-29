/// Pure local-calendar streak rules. No storage, Flutter, timers, or I/O.
class StreakState {
  final int current;
  final int longest;
  final Set<String> activeDays;

  const StreakState({
    this.current = 0,
    this.longest = 0,
    this.activeDays = const {},
  });

  StreakState copyWith({int? current, int? longest, Set<String>? activeDays}) =>
      StreakState(
        current: current ?? this.current,
        longest: longest ?? this.longest,
        activeDays: activeDays ?? this.activeDays,
      );
}

String localDayKey(DateTime day) => '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

DateTime? parseLocalDay(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final day = DateTime.tryParse(value);
  return day != null && localDayKey(day) == value ? day : null;
}

String _previousDay(String key) {
  final day = parseLocalDay(key);
  if (day == null) return '';
  return localDayKey(DateTime(day.year, day.month, day.day - 1));
}

/// History is authoritative; legacy counters are recoverable projections.
StreakState restoreStreak(Object? history, Object? best) {
  if (history is! List || history.any((day) => day is! String)) {
    return const StreakState();
  }
  final days = history.cast<String>().toSet().toList()..sort();
  if (days.any((day) => parseLocalDay(day) == null) || days.isEmpty) {
    return const StreakState();
  }
  var run = 0;
  var longest = best is int && best >= 0 ? best : 0;
  String? previous;
  for (final day in days) {
    run = previous == _previousDay(day) ? run + 1 : 1;
    if (run > longest) longest = run;
    previous = day;
  }
  return StreakState(
    current: run,
    longest: longest,
    activeDays: Set.unmodifiable(days),
  );
}

StreakState advanceStreak(StreakState state, DateTime now) {
  final today = localDayKey(now);
  if (state.activeDays.contains(today)) return state;
  final days = state.activeDays.toList()..sort();
  if (days.isNotEmpty && today.compareTo(days.last) < 0) return state;
  final current =
      state.activeDays.contains(_previousDay(today)) ? state.current + 1 : 1;
  return StreakState(
    current: current,
    longest: current > state.longest ? current : state.longest,
    activeDays: Set.unmodifiable({...state.activeDays, today}),
  );
}
