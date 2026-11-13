import 'dart:convert';
import 'package:timezone/timezone.dart' as tz;
import 'calendar.dart';
import 'lesson.dart';
import 'pacing.dart';
import 'daily_verse.dart';
import 'streak.dart';

enum NotificationKind { daily, streakSaver, comeback, birthday }

class PlannedNotification {
  final int id, day;
  final tz.TZDateTime at;
  final String title, subtitle, body;
  final NotificationKind kind;

  /// Lesson notes open the lesson; verse and blessing notes open the verse.
  bool get opensLesson =>
      kind == NotificationKind.streakSaver ||
      kind == NotificationKind.comeback ||
      (kind == NotificationKind.daily && subtitle.startsWith('Day '));
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
        'card': opensLesson ? 'lesson' : 'verse',
        'continuation': body
      });
}

String teaserExcerpt(String text, {int limit = 90}) {
  final clean = text
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (clean.length <= limit) return clean;
  var cut = clean.substring(0, limit - 1);
  final space = cut.lastIndexOf(' ');
  if (space > 0) cut = cut.substring(0, space);
  return '${cut.trimRight()}…';
}

String _first(String name) {
  final part = name.trim().split(RegExp(r'\s+')).first;
  return part.length > 18 ? '' : part;
}

/// The title of a lesson note at [hour], shared with the onboarding preview
/// so the picture she approves is the note she gets.
String lessonNoteTitle(int hour, String name) {
  final greeting =
      hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
  final first = _first(name);
  return first.isEmpty ? greeting : '$greeting, $first';
}

/// The notes HolyHim sends, all about Scripture and her walk, never about
/// buying anything:
///
/// * a personal daily note at her chosen time: the next lesson's teaser when
///   one is waiting, otherwise the verse of the day;
/// * an evening note at 8 PM, only today, only if a walk of two or more days
///   would otherwise lapse;
/// * a quiet "your place is saved" note three and seven days after her last
///   reading, in place of that day's daily note;
/// * a blessing on her birthday, in place of that day's daily note.
///
/// The queue is rebuilt whenever the app opens or progress changes, so
/// completing today's lesson removes the evening note.
List<PlannedNotification> notificationPlan(
    {required DateTime now,
    required String timeZone,
    required int minutes,
    required String name,
    required List<String> hearts,
    required Map<int, String> completed,
    required List<Lesson> lessons,
    String? birthday,
    bool enabled = true}) {
  if (!enabled || minutes < 0 || minutes >= 1440 || lessons.isEmpty) return [];
  final local = localNow(now, timeZone);
  final first = _first(name);
  final pacing = pacingFor(completed, now, timeZone);
  final today = dateKey(local);
  final readToday = completed.values.contains(today);
  final lastRead = completed.isEmpty
      ? null
      : (completed.values.toList()..sort()).last;
  final born = birthday == null ? null : DateTime.tryParse(birthday);
  final result = <PlannedNotification>[];
  Lesson? lessonFor(int day) =>
      day >= 1 && day <= lessons.length ? lessons[day - 1] : null;

  for (var offset = 0; result.length < 29; offset++) {
    final at = tz.TZDateTime(local.location, local.year, local.month,
        local.day + offset, minutes ~/ 60, minutes % 60);
    if (!at.isAfter(local)) continue;
    final key = dateKey(at);
    final id = 2000 + result.length;
    final verse = dailyVerse(lessons, at, timeZone);
    if (born != null && born.month == at.month && born.day == at.day) {
      final blessing = lessons.firstWhere((l) => l.reference == 'Numbers 6:24-26',
          orElse: () => verse);
      result.add(PlannedNotification(
          id: id,
          day: blessing.day,
          at: at,
          title: first.isEmpty ? 'Happy birthday' : 'Happy birthday, $first',
          subtitle: 'A blessing for your day',
          body: 'The Lord bless you, and keep you. The Lord make his face to shine on you.',
          kind: NotificationKind.birthday));
      continue;
    }
    final quiet = lastRead == null ? 0 : calendarDistance(lastRead, key);
    if (lastRead != null && !pacing.finished && (quiet == 3 || quiet == 7)) {
      final next = lessonFor(pacing.currentDay);
      result.add(PlannedNotification(
          id: id,
          day: next?.day ?? verse.day,
          at: at,
          title: quiet == 3 ? 'Your place is saved' : 'Still here for you',
          subtitle: next == null ? verse.reference : 'Day ${next.day} · ${next.title}',
          body: quiet == 3
              ? 'No catching up needed. Day ${pacing.currentDay} is right where you left it.'
              : 'God has not gone anywhere, and neither has your walk. Five quiet minutes?',
          kind: NotificationKind.comeback));
      continue;
    }
    // The very next note can point at the lesson she will actually open.
    final lessonDay = !pacing.finished &&
            (pacing.canBegin || (pacing.nextUnlock != null && !pacing.nextUnlock!.isAfter(at)))
        ? pacing.currentDay
        : null;
    final next = result.isEmpty ? lessonFor(lessonDay ?? 0) : null;
    if (next != null) {
      result.add(PlannedNotification(
          id: id,
          day: next.day,
          at: at,
          title: lessonNoteTitle(at.hour, name),
          subtitle: 'Day ${next.day} · ${next.title}',
          body: teaserExcerpt(next.teaser),
          kind: NotificationKind.daily));
    } else {
      result.add(PlannedNotification(
          id: id,
          day: verse.day,
          at: at,
          title: first.isEmpty ? 'Today’s word' : 'Today’s word for you, $first',
          subtitle: '${verse.reference} · WEB',
          body: teaserExcerpt(verse.verse),
          kind: NotificationKind.daily));
    }
  }

  // Tonight only: keep a walk of two or more days from lapsing.
  final streak = streakFor(completed, now, timeZone).current;
  final evening =
      tz.TZDateTime(local.location, local.year, local.month, local.day, 20);
  if (!readToday && streak >= 2 && pacing.canBegin && evening.isAfter(local)) {
    final next = lessonFor(pacing.currentDay);
    if (next != null) {
      result.add(PlannedNotification(
          id: 2090,
          day: next.day,
          at: evening,
          title: 'Your $streak-day walk',
          subtitle: 'Day ${next.day} · ${next.title}',
          body: 'Five quiet minutes before bed keeps it going.',
          kind: NotificationKind.streakSaver));
    }
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
