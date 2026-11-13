/// Daily activity and completion streak logic ported directly from Cognein.
///
/// A day is the user's local calendar day (YYYY-MM-DD), midnight to midnight.
/// Streak increments on consecutive calendar days of app activity or lesson completion,
/// preserves longest streak, and tracks active dates.
library;

import 'calendar.dart';

String dayKey(DateTime local) {
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-$month-$day';
}

final RegExp _dayKeyPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

int? dayNumber(String? key) {
  if (key == null) return null;
  final match = _dayKeyPattern.firstMatch(key);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime.utc(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}

String keyForDayNumber(int number) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    number * Duration.millisecondsPerDay,
    isUtc: true,
  );
  return dayKey(date);
}

DateTime? dateOfDayKey(String? key) {
  final number = dayNumber(key);
  if (number == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(
    number * Duration.millisecondsPerDay,
    isUtc: true,
  );
}

const int streakHistoryDays = 90;

class StreakRecord {
  const StreakRecord({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastActivityDate,
    required this.activeDays,
  });

  final int currentStreak;
  final int longestStreak;
  final String lastActivityDate;
  final List<String> activeDays;

  Map<String, Object> toFields() => {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastActivityDate': lastActivityDate,
        'activeDays': activeDays,
      };
}

int? _asInt(Object? value) => value is num ? value.toInt() : null;

List<String> _cleanDays(Object? raw) {
  if (raw is! Iterable) return const [];
  final keys = <String>{
    for (final item in raw)
      if (item is String && dayNumber(item) != null) item,
  };
  return keys.toList()..sort();
}

StreakRecord? planStreakUpdate(
    Map<String, dynamic>? stored, DateTime nowLocal,
    {Iterable<String> additionalDates = const []}) {
  final todayKey = dayKey(nowLocal);
  final today = dayNumber(todayKey)!;

  final storedCurrent = _asInt(stored?['currentStreak']) ?? 0;
  final storedLongest = _asInt(stored?['longestStreak']) ?? 0;
  final storedLast = stored?['lastActivityDate'];
  final last = dayNumber(storedLast is String ? storedLast : null);

  var current = storedCurrent < 0 ? 0 : storedCurrent;

  if (last == null) {
    current = 1;
  } else {
    final diff = today - last;
    if (diff <= 0) {
      current = current < 1 ? 1 : current;
    } else if (diff == 1) {
      current += 1;
    } else {
      current = 1;
    }
  }
  final longest = storedLongest > current ? storedLongest : current;

  final earliest = today - (streakHistoryDays - 1);
  final allClean = <String>{
    for (final key in _cleanDays(stored?['activeDays']))
      if (dayNumber(key)! >= earliest && dayNumber(key)! <= today) key,
    for (final key in additionalDates)
      if (dayNumber(key) != null &&
          dayNumber(key)! >= earliest &&
          dayNumber(key)! <= today)
        key,
    todayKey,
  };
  final days = allClean.toList()..sort();

  final next = StreakRecord(
    currentStreak: current,
    longestStreak: longest,
    lastActivityDate: todayKey,
    activeDays: days,
  );

  return next;
}

class StreakBoardData {
  const StreakBoardData({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActivityDate,
    this.activeKeys = const <String>{},
  });

  static const StreakBoardData empty = StreakBoardData();

  factory StreakBoardData.fromDocument(Map<String, dynamic>? data) {
    if (data == null) return empty;
    final last = data['lastActivityDate'];
    return StreakBoardData(
      currentStreak: (_asInt(data['currentStreak']) ?? 0).clamp(0, 1 << 30),
      longestStreak: (_asInt(data['longestStreak']) ?? 0).clamp(0, 1 << 30),
      lastActivityDate: last is String && dayNumber(last) != null ? last : null,
      activeKeys: _cleanDays(data['activeDays']).toSet(),
    );
  }

  final int currentStreak;
  final int longestStreak;
  final String? lastActivityDate;
  final Set<String> activeKeys;

  List<bool> litDays(String todayKey, {int days = 7}) {
    final count = days.clamp(0, 365);
    final today = dayNumber(todayKey);
    if (today == null) return List<bool>.filled(count, false);
    final last = dayNumber(lastActivityDate);
    return [
      for (var i = count - 1; i >= 0; i--)
        () {
          final day = today - i;
          final key = keyForDayNumber(day);
          if (activeKeys.contains(key)) return true;
          return last != null &&
              currentStreak > 0 &&
              day <= last &&
              day > last - currentStreak;
        }(),
    ];
  }
}

class Streak {
  final int current, longest, graceDays;
  final Set<String> graceDates;
  final Set<String> activeDates;
  const Streak({
    required this.current,
    required this.longest,
    required this.graceDays,
    required this.graceDates,
    this.activeDates = const {},
  });
}

Streak streakFor(
  Map<int, String> completed,
  DateTime now,
  String timeZone, {
  Iterable<String> additionalActiveDates = const [],
  bool includeTodayAsActive = false,
}) {
  final local = localNow(now, timeZone);
  final today = dateKey(local);

  final datesSet = <String>{
    ...completed.values,
    ...additionalActiveDates,
    if (includeTodayAsActive) today,
  }.where((date) {
    try {
      calendarDate(date);
      return date.compareTo(today) <= 0;
    } catch (_) {
      return false;
    }
  }).toSet();

  final dates = datesSet.toList()..sort();
  if (dates.isEmpty) {
    return const Streak(
        current: 0, longest: 0, graceDays: 0, graceDates: {}, activeDates: {});
  }

  var current = 0, longest = 0, grace = 0, consecutiveRead = 0;
  final used = <String>{};
  String? previous;
  for (final date in dates) {
    if (previous != null) {
      final missed = calendarDistance(previous, date) - 1;
      if (missed > 0) {
        consecutiveRead = 0;
        final spend = missed < grace ? missed : grace;
        for (var d = 1; d <= spend; d++) {
          used.add(shiftDate(previous, d));
        }
        grace -= spend;
        if (spend < missed) current = 0;
      }
    }
    current++;
    consecutiveRead++;
    if (consecutiveRead % 7 == 0) grace = (grace + 1).clamp(0, 2);
    if (current > longest) longest = current;
    previous = date;
  }

  final quiet = calendarDistance(dates.last, today) - 1;
  if (quiet > 0) {
    final spend = quiet < grace ? quiet : grace;
    for (var d = 1; d <= spend; d++) {
      used.add(shiftDate(dates.last, d));
    }
    grace -= spend;
    if (spend < quiet) current = 0;
  }

  return Streak(
    current: current,
    longest: longest,
    graceDays: grace,
    graceDates: Set.unmodifiable(used),
    activeDates: Set.unmodifiable(datesSet),
  );
}
