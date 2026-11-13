/// Onboarding version 3: answers are stored as stable IDs, never as the text
/// shown on screen, so wording can change without breaking saved drafts.
library;

const onboardingFlowVersion = 3;

const onboardingStepIds = [
  'name',
  'heart',
  'season',
  'familiarity',
  'obstacle',
  'reminder',
  'birthday',
  'building',
  'letter',
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

/// Written when someone leaves the offer for Day 1.
const onboardingDoneStepId = 'complete';

class Choice {
  final String id, label;
  final String? detail;
  const Choice(this.id, this.label, [this.detail]);
}

const heartChoices = [
  Choice('peace', 'Peace', 'Quiet for a busy mind'),
  Choice('strength', 'Strength', 'For a hard season'),
  Choice('hope', 'Hope', 'Something good to hold'),
  Choice('guidance', 'Guidance', 'Help with a choice'),
  Choice('rest', 'Rest', 'Room to breathe'),
  Choice('joy', 'Joy', 'Gladness again'),
];

const seasonChoices = [
  Choice('full', 'My days are full'),
  Choice('change', 'Things are changing'),
  Choice('hurting', 'I am hurting'),
  Choice('waiting', 'I am waiting on something'),
  Choice('growing', 'I want to grow'),
  Choice('steady', 'Life feels steady'),
];

const familiarityChoices = [
  Choice('new', 'I am new to the Bible'),
  Choice('some', 'I know a few stories'),
  Choice('returning', 'I am coming back to it'),
  Choice('daily', 'I read it most days'),
];

const obstacleChoices = [
  Choice('busy', 'I run out of time'),
  Choice('understanding', 'It is hard to understand'),
  Choice('forgetting', 'I forget to come back'),
  Choice('starting', 'Starting feels hard'),
  Choice('none', 'Nothing really'),
];

/// Reminder answers are 'off' or a 24-hour 'HH:MM'.
const reminderPresets = [
  Choice('07:00', 'Morning', '7:00 AM'),
  Choice('12:30', 'Midday', '12:30 PM'),
  Choice('20:30', 'Evening', '8:30 PM'),
];

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
    if (hearts.isEmpty) return 1;
    if (season == null) return 2;
    if (familiarity == null) return 3;
    if (obstacle == null) return 4;
    if (reminder == null) return 5;
    return onboardingStepIds.length;
  }
}

/// Where to resume. Returns the step a person asked to be on, unless an
/// earlier required answer is missing. Older numeric positions referred to a
/// different order, so a version 2 draft resumes at its first gap instead.
int resumeOnboardingStep(Map<String, dynamic> draft, OnboardingAnswers answers) {
  final version = (draft['flowVersion'] as num?)?.toInt();
  final stepId = draft['stepId'];
  var requested = 0;
  if (version == onboardingFlowVersion) {
    requested = onboardingStepIds.indexOf('$stepId').clamp(0, 9);
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
