import 'dart:convert';
import 'package:timezone/timezone.dart' as tz;
import 'calendar.dart';
import 'lesson.dart';
import 'pacing.dart';
import 'daily_verse.dart';

enum NotificationKind { daily, streakSaver, comeback }

class PlannedNotification {
  final int id, day;
  final tz.TZDateTime at;
  final String title, subtitle, body;
  final NotificationKind kind;
  const PlannedNotification(
      {required this.id,
      required this.day,
      required this.at,
      required this.title,
      required this.subtitle,
      required this.body,
      required this.kind});
  String payload(String uid) => jsonEncode({
        'version': 3,
        'account': uid,
        'day': day,
        'card': 'verse',
        'continuation': body
      });
}

String teaserExcerpt(String text, {int limit = 90}) {
  final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (clean.length <= limit) return clean;
  var cut = clean.substring(0, limit - 1);
  final space = cut.lastIndexOf(' ');
  if (space > 0) cut = cut.substring(0, space);
  return '${cut.trimRight()}…';
}

/// One actual Scripture excerpt per local calendar day. It continues after the
/// journey is complete, and never changes because a lesson was completed.
List<PlannedNotification> notificationPlan(
    {required DateTime now,
    required String timeZone,
    required int minutes,
    required String name,
    required List<String> hearts,
    required Map<int, String> completed,
    required List<Lesson> lessons,
    bool enabled = true}) {
  if (!enabled || minutes < 0 || minutes >= 1440 || lessons.isEmpty) return [];
  final local = localNow(now, timeZone);
  final result = <PlannedNotification>[];
  for (var offset = 0; result.length < 30; offset++) {
    final at = tz.TZDateTime(local.location, local.year, local.month,
        local.day + offset, minutes ~/ 60, minutes % 60);
    if (!at.isAfter(local)) continue;
    final verse = dailyVerse(lessons, at, timeZone);
    result.add(PlannedNotification(
        id: 2000 + result.length,
        day: verse.day,
        at: at,
        title: 'Be Strong in the Word',
        subtitle: '${verse.reference} · WEB',
        body: teaserExcerpt(verse.verse),
        kind: NotificationKind.daily));
  }
  return result;
}

class NotificationTap {
  final String account, continuation;
  final int day;
  final bool verseOnly;
  const NotificationTap(
      {required this.account,
      required this.day,
      this.verseOnly = false,
      this.continuation = ''});
}

NotificationTap? parseNotificationTap(String? payload,
    {required String? account,
    required Map<int, String> completed,
    required DateTime now,
    required String timeZone}) {
  if (payload == null || account == null) return null;
  try {
    final value = jsonDecode(payload);
    if (value is! Map ||
        ![2, 3].contains(value['version']) ||
        value['account'] != account ||
        value['day'] is! int ||
        value['day'] < 1 ||
        value['day'] > 365) {
      return null;
    }
    final pacing = pacingFor(completed, now, timeZone);
    final day = value['day'] as int;
    return NotificationTap(
        account: account,
        day: day,
        verseOnly: value['card'] == 'verse' ||
            day != pacing.currentDay ||
            !pacing.canBegin,
        continuation:
            value['continuation'] is String ? value['continuation'] : '');
  } catch (_) {
    return null;
  }
}
