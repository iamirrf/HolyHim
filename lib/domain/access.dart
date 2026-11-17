/// Who may open what. Pure and synchronous so the router, Today, the Walk
/// and notifications all agree.
///
/// The rule is small: membership (in its free week or paid), the lifetime
/// unlock sold before membership, or access kept from the free edition opens
/// every lesson. Without one of those the app shows the offer, and nothing
/// is free. A lesson he completed stays readable whenever he is let in.
library;

enum LessonAccess {
  /// Open through membership, the lifetime unlock or a kept grant.
  owned,

  /// Completed before; always readable.
  completed,

  /// Needs membership.
  locked,
}

LessonAccess lessonAccess(int day,
    {required bool owned, required Map<int, String> completed}) {
  if (completed.containsKey(day)) return LessonAccess.completed;
  return owned ? LessonAccess.owned : LessonAccess.locked;
}

bool canOpenLesson(int day,
        {required bool owned, required Map<int, String> completed}) =>
    lessonAccess(day, owned: owned, completed: completed) !=
    LessonAccess.locked;
