import 'dart:convert';
import 'package:timezone/timezone.dart' as tz;
import 'calendar.dart';
import 'lesson.dart';
import 'pacing.dart';
import 'daily_verse.dart';
import 'milestones.dart';
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
  final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (clean.length <= limit) return clean;
  var cut = clean.substring(0, limit - 1);
  final space = cut.lastIndexOf(' ');
  if (space > 0) cut = cut.substring(0, space);
  return '${cut.trimRight()}…';
}

/// A verse as a note shows it: whole when it fits, otherwise cut at a word,
/// always inside its quotation marks.
String noteVerse(String verse, {int limit = 220}) {
  var text = verse.replaceAll(RegExp(r'\s+'), ' ').trim();
  // A verse that is one quoted saying keeps only the outer marks.
  if (text.startsWith('‘') &&
      text.endsWith('’') &&
      '‘'.allMatches(text).length == 1) {
    text = text.substring(1, text.length - 1);
  }
  return quoteVerse(teaserExcerpt(text, limit: limit));
}

/// A lesson note's body: the day's verse, then where it is from, so the
/// note is worth reading even if she never opens it.
String lessonNoteBody(Lesson lesson) =>
    '${noteVerse(lesson.verse)}\n— ${lesson.reference}';

/// A verse note: the verse of the day, whole whenever it fits.
String verseNoteBody(Lesson verse) => noteVerse(verse.verse, limit: 240);

String _first(String name) {
  final part = name.trim().split(RegExp(r'\s+')).first;
  return part.length > 18 ? '' : part;
}

/// The waiting lesson's note: a medallion one morning away, then a habit
/// worth keeping, then a plain greeting. A new reader always gets the greeting she
/// saw previewed in onboarding.
String _lessonTitle(int hour, String name, int read, int walk) {
  final first = _first(name);
  final milestone = nextMilestone(read);
  if (read >= 1 && milestone != null && milestone.remaining == 1) {
    return _fit(first, '🏅 $first, a medallion is one morning away',
        '🏅 A medallion is one morning away');
  }
  if (walk >= 2) {
    return _fit(first, '🔥 Your $walk-day habit continues, $first',
        '🔥 Your $walk-day habit continues');
  }
  return lessonNoteTitle(hour, name);
}

/// Titles stay short enough to read whole on the Lock Screen.
String _fit(String first, String personal, String plain) =>
    first.isEmpty || personal.length > 40 ? plain : personal;

/// Verse notes change their opening line so they never blur into noise.
String _verseTitle(bool firstNote, DateTime at, String first) {
  final titles = [
    first.isEmpty ? '📖 Today’s word' : '📖 Today’s word for you, $first',
    '🌸 A promise for your morning',
    '🕊️ Something to hold today',
    _fit(first, '✨ $first, a verse for you', '✨ A verse for you'),
  ];
  if (firstNote) return titles.first;
  final dayOfYear = at.difference(DateTime(at.year)).inDays;
  return titles[dayOfYear % titles.length];
}

/// The title of a lesson note at [hour], shared with the onboarding preview
/// so the picture she approves is the note she gets.
String lessonNoteTitle(int hour, String name) {
  final greeting = hour < 12
      ? '🌅 Good morning'
      : hour < 17
          ? '☀️ Good afternoon'
          : '🌙 Good evening';
  final first = _first(name);
  return first.isEmpty ? greeting : '$greeting, $first';
}

/// The notes HolyHim sends, all about Scripture and her daily habit, never about
/// buying anything:
///
/// * a personal daily note at her chosen time: the next lesson's teaser when
///   one is waiting, otherwise the verse of the day;
/// * an evening note at 8 PM, only today, only if a habit of two or more
///   days would otherwise lapse;
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
  final lastRead =
      completed.isEmpty ? null : (completed.values.toList()..sort()).last;
  final born = birthday == null ? null : DateTime.tryParse(birthday);
  final walk = streakFor(completed, now, timeZone).current;
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
      final blessing = lessons.firstWhere(
          (l) => l.reference == 'Numbers 6:24-26',
          orElse: () => verse);
      result.add(PlannedNotification(
          id: id,
          day: blessing.day,
          at: at,
          title:
              first.isEmpty ? '🎂 Happy birthday' : '🎂 Happy birthday, $first',
          subtitle: 'A blessing for your day',
          body:
              '${noteVerse(blessing.verse, limit: 240)}\n— ${blessing.reference}',
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
          title:
              quiet == 3 ? '🕊️ Your place is saved' : '🤍 Still here for you',
          subtitle: next == null
              ? verse.reference
              : 'Day ${next.day} · ${next.title}',
          body: quiet == 3
              ? 'No catching up needed. Day ${pacing.currentDay} is right where you left it.'
              : 'God has not gone anywhere. Five quiet minutes starts your habit again.',
          kind: NotificationKind.comeback));
      continue;
    }
    // The very next note can point at the lesson she will actually open.
    final lessonDay = !pacing.finished &&
            (pacing.canBegin ||
                (pacing.nextUnlock != null && !pacing.nextUnlock!.isAfter(at)))
        ? pacing.currentDay
        : null;
    final next = result.isEmpty ? lessonFor(lessonDay ?? 0) : null;
    if (next != null) {
      result.add(PlannedNotification(
          id: id,
          day: next.day,
          at: at,
          title: _lessonTitle(at.hour, name, completed.length, walk),
          subtitle: 'Day ${next.day} · ${next.title}',
          body: lessonNoteBody(next),
          kind: NotificationKind.daily));
    } else {
      result.add(PlannedNotification(
          id: id,
          day: verse.day,
          at: at,
          title: _verseTitle(result.isEmpty, at, first),
          subtitle: '${verse.reference} · WEB',
          body: verseNoteBody(verse),
          kind: NotificationKind.daily));
    }
  }

  // Tonight only: keep a habit of two or more days from lapsing.
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
          title: '🌙 Keep your $streak-day habit going',
          subtitle: 'Day ${next.day} · ${next.title}',
          body: 'Five quiet minutes before bed keeps your habit alive.',
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
