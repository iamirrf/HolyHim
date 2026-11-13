/// Who may open what. Pure and synchronous so the router, Today, Journey and
/// notifications all agree.
///
/// The rule is deliberately small: the first [freeDays] lessons are free for
/// everyone, every later lesson needs the one-time lifetime unlock, and a
/// lesson someone has already completed stays open forever. Nothing else in
/// the app is ever locked: Today, Saved, Growth, Profile, reminders and
/// widgets work for everyone.
library;

const freeDays = 7;

enum LessonAccess {
  /// Inside the free week.
  free,

  /// Owned through the lifetime unlock.
  owned,

  /// Completed before; always readable.
  completed,

  /// Needs the lifetime unlock.
  locked,
}

LessonAccess lessonAccess(int day,
    {required bool owned, required Map<int, String> completed}) {
  if (completed.containsKey(day)) return LessonAccess.completed;
  if (day <= freeDays) return LessonAccess.free;
  return owned ? LessonAccess.owned : LessonAccess.locked;
}

bool canOpenLesson(int day,
        {required bool owned, required Map<int, String> completed}) =>
    lessonAccess(day, owned: owned, completed: completed) !=
    LessonAccess.locked;

/// How many free lessons remain for someone who has not unlocked.
int freeDaysLeft(Map<int, String> completed) {
  var left = 0;
  for (var day = 1; day <= freeDays; day++) {
    if (!completed.containsKey(day)) left++;
  }
  return left;
}
