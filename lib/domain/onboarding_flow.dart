/// Onboarding version 3: answers are stored as stable IDs, never as the text
/// shown on screen, so wording can change without breaking saved drafts.
///
/// The steps were reordered and grew from ten to eleven without a new flow
/// version: the saved answers are the same ones, and a draft resumes by the
/// name of its step, never by its number. Every ID below is one the
/// Firestore rules already allow.
library;

const onboardingFlowVersion = 3;

const onboardingStepIds = [
  'name',
  'birthday',
  'heart',
  'season',
  // A short conversation: how well he knows the Bible, then what gets in
  // the way. Both answers are saved under their own keys.
  'familiarity',
  // His first seven days, shown.
  'routinePreview',
  // A short conversation about his daily note.
  'reminder',
  'building',
  'letter',
  // Day 1, shown.
  'dailyRhythm',
  'offer',
];

/// Steps after the profile has been durably saved. The router keeps people
/// in onboarding while their draft sits on one of these, so a relaunch
/// returns to the letter or the offer instead of skipping it.
const onboardingClosingSteps = {
  'building',
  'letter',
  'offer',
  // Version 2 equivalents.
  'saving',
  'lifetimeAccess',
};

/// Whether [draft] sits on a step that comes after the save. 'dailyRhythm'
/// counts only in this version: version 2 used that name for a step in the
/// middle of its flow.
bool onboardingIsClosing(Map<String, dynamic> draft) {
  final stepId = draft['stepId'];
  if (stepId == 'dailyRhythm') {
    return (draft['flowVersion'] as num?)?.toInt() == onboardingFlowVersion;
  }
  return onboardingClosingSteps.contains(stepId);
}

/// Written when someone leaves the offer for Day 1.
const onboardingDoneStepId = 'complete';

class Choice {
  final String id, label;
  final String? detail;

  /// Set beside the label on the welcome's cards and in its replies.
  final String? emoji;
  const Choice(this.id, this.label, {this.detail, this.emoji});
}

const heartChoices = [
  Choice('strength', 'Strength', detail: 'For hard days', emoji: '🛡️'),
  Choice('purpose', 'Purpose', detail: 'Why I am here', emoji: '🧭'),
  Choice('peace', 'Peace', detail: 'A calm mind', emoji: '🕊️'),
  Choice('discipline', 'Discipline', detail: 'Build good habits', emoji: '⏱️'),
  Choice('wisdom', 'Wisdom', detail: 'Make good calls', emoji: '📖'),
  Choice('courage', 'Courage', detail: 'Face my fears', emoji: '🦁'),
];

const seasonChoices = [
  Choice('full', 'My days are packed', emoji: '🗓️'),
  Choice('change', 'Life is changing fast', emoji: '🌊'),
  Choice('hurting', 'Something is hard right now', emoji: '⛰️'),
  Choice('waiting', 'I am waiting on something', emoji: '⏳'),
  Choice('growing', 'I want to grow', emoji: '🌱'),
  Choice('steady', 'Things are steady', emoji: '⚓'),
];

const familiarityChoices = [
  Choice('new', 'I am new to the Bible', emoji: '🌱'),
  Choice('some', 'I know a few stories', emoji: '📖'),
  Choice('returning', 'I am coming back to it', emoji: '🏡'),
  Choice('daily', 'I read it most days', emoji: '☀️'),
];

const obstacleChoices = [
  Choice('busy', 'I run out of time', emoji: '⏰'),
  Choice('understanding', 'It is hard to understand', emoji: '🤔'),
  Choice('forgetting', 'I forget to come back', emoji: '🔔'),
  Choice('starting', 'Starting feels hard', emoji: '🚪'),
  Choice('none', 'Nothing really', emoji: '✨'),
];

/// Reminder answers are 'off' or a 24-hour 'HH:MM'.
const reminderPresets = [
  Choice('07:00', 'Morning', detail: '7:00 AM', emoji: '🌅'),
  Choice('12:30', 'Midday', detail: '12:30 PM', emoji: '☀️'),
  Choice('20:30', 'Evening', detail: '8:30 PM', emoji: '🌙'),
];

/// The emoji for an answer, if it has one.
String? emojiFor(List<Choice> choices, Object? id) {
  for (final c in choices) {
    if (c.id == id) return c.emoji;
  }
  return null;
}

int? reminderMinutesFor(String? answer) {
  if (answer == null) return null;
  final m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(answer);
  if (m == null) return null;
  final h = int.parse(m[1]!), min = int.parse(m[2]!);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

String reminderAnswerFor(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

String? labelFor(List<Choice> choices, Object? id) {
  for (final c in choices) {
    if (c.id == id) return c.label;
  }
  return id is String && id.isNotEmpty ? id : null;
}

// Version 2 stored display text. Map it to the version 3 IDs.
const _legacyObstacles = {
  'My days are full': 'busy',
  'Understanding Scripture is hard': 'understanding',
  'I forget to return': 'forgetting',
  'Beginning feels hard': 'starting',
  'No particular obstacle': 'none',
};
const _legacyReminders = {
  'Morning · 7 AM': '07:00',
  'Midday · 12 PM': '12:00',
  'Evening · 8 PM': '20:00',
  'No reminders': 'off',
};
const _legacyHearts = {
  'Peace': 'peace',
  'Confidence': 'strength',
  'Courage': 'strength',
  'Strength': 'strength',
  'Hope': 'hope',
  'Guidance': 'guidance',
  'Rest': 'rest',
  'Joy': 'joy',
};

String? normalizedObstacle(Object? value) =>
    value is! String ? null : (_legacyObstacles[value] ?? value);
String? normalizedReminder(Object? value) =>
    value is! String ? null : (_legacyReminders[value] ?? value);
List<String> normalizedHearts(List<String> hearts) => {
      for (final h in hearts) _legacyHearts[h] ?? h.toLowerCase(),
    }.take(3).toList();

/// What a person has already answered, read from the profile and draft.
class OnboardingAnswers {
  final bool hasName;
  final List<String> hearts;
  final String? season, familiarity, obstacle, reminder;
  const OnboardingAnswers(
      {required this.hasName,
      this.hearts = const [],
      this.season,
      this.familiarity,
      this.obstacle,
      this.reminder});

  factory OnboardingAnswers.read(Map<String, dynamic> draft,
          {required String name, required List<String> hearts}) =>
      OnboardingAnswers(
          hasName: name.trim().isNotEmpty,
          hearts: hearts,
          season: draft['lifeSeason'] as String?,
          familiarity:
              (draft['familiarity'] ?? draft['faithRoutine']) as String?,
          obstacle: normalizedObstacle(draft['obstacle']),
          reminder: normalizedReminder(draft['reminder']));

  /// The first step whose required answer is missing, or the number of
  /// steps when nothing required is missing. Birthday is optional.
  int get firstMissing {
    if (!hasName) return 0;
    if (hearts.isEmpty) return onboardingStepIds.indexOf('heart');
    if (season == null) return onboardingStepIds.indexOf('season');
    if (familiarity == null || obstacle == null) {
      return onboardingStepIds.indexOf('familiarity');
    }
    if (reminder == null) return onboardingStepIds.indexOf('reminder');
    return onboardingStepIds.length;
  }
}

/// Where to resume. Returns the step a person asked to be on, unless an
/// earlier required answer is missing. Older numeric positions referred to a
/// different order, so a version 2 draft resumes at its first gap instead.
int resumeOnboardingStep(
    Map<String, dynamic> draft, OnboardingAnswers answers) {
  final version = (draft['flowVersion'] as num?)?.toInt();
  final stepId = draft['stepId'];
  var requested = 0;
  if (version == onboardingFlowVersion) {
    if (stepId == 'birthday' && answers.reminder != null) {
      // Birthday used to come after the reminder. A draft left there has
      // answered everything, so it goes on to be saved.
      requested = onboardingStepIds.indexOf('building');
    } else {
      // 'obstacle' was a step of its own before the two questions became
      // one conversation.
      final id = stepId == 'obstacle' ? 'familiarity' : '$stepId';
      requested =
          onboardingStepIds.indexOf(id).clamp(0, onboardingStepIds.length - 1);
    }
  } else if (stepId == 'saving' || stepId == 'lifetimeAccess') {
    // A version 2 profile that was already saved goes to the letter.
    requested = onboardingStepIds.indexOf('letter');
  } else if (draft.isNotEmpty) {
    // Any other version 2 position resumes at its first unanswered step.
    requested = onboardingStepIds.indexOf('building');
  }
  final missing = answers.firstMissing;
  var step = requested < missing ? requested : missing;
  // A name supplied by Apple or Google is never asked for again.
  if (step == 0 && answers.hasName) step = 1;
  return step;
}
