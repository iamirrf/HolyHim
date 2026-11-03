import 'dart:math';

String newOperationId() {
  final random = Random.secure();
  return '${DateTime.now().microsecondsSinceEpoch}-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}

const semanticSteps = [
  'opening',
  'verse',
  'understand',
  'question-1',
  'confidence',
  'hope',
  'question-2',
  'carry',
  'closing'
];

class EditionAccess {
  final String edition;
  final bool eligible, retainedGrant, genuinePurchase;
  const EditionAccess(
      {required this.edition,
      required this.eligible,
      required this.retainedGrant,
      required this.genuinePurchase});
  factory EditionAccess.fromJson(Map<String, dynamic> value) => EditionAccess(
      edition: value['edition'] as String,
      eligible: value['eligible'] == true,
      retainedGrant: value['retainedGrant'] == true,
      genuinePurchase: value['genuinePurchase'] == true);
}

class LessonStep {
  final String id, title, body;
  const LessonStep(this.id, this.title, this.body);
}

class QuestionOption {
  final String id, text;
  const QuestionOption(this.id, this.text);
}

class LessonQuestion {
  final String id, prompt, correctOptionId, explanation, teachingSource;
  final List<QuestionOption> options;
  const LessonQuestion(
      {required this.id,
      required this.prompt,
      required this.correctOptionId,
      required this.explanation,
      required this.teachingSource,
      required this.options});
  factory LessonQuestion.fromJson(Map<String, dynamic> data) => LessonQuestion(
          id: data['id'],
          prompt: data['prompt'],
          correctOptionId: data['correctOptionId'],
          explanation: data['explanation'],
          teachingSource: data['teachingSource'],
          options: [
            for (final option in data['options'])
              QuestionOption(option['id'], option['text'])
          ]);
}

class LearningAttempt {
  final String id, contentVersion;
  final int day, journeyRevision;
  final Map<String, List<String>> optionOrder;
  final Map<String, String> selected;
  const LearningAttempt(
      {required this.id,
      required this.day,
      required this.contentVersion,
      required this.journeyRevision,
      required this.optionOrder,
      required this.selected});
  factory LearningAttempt.create(
      int day, int revision, String version, List<LessonQuestion> questions) {
    final random = Random.secure();
    final id =
        '${DateTime.now().microsecondsSinceEpoch}-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    final order = <String, List<String>>{};
    for (final question in questions) {
      order[question.id] = question.options.map((o) => o.id).toList()
        ..shuffle(random);
    }
    return LearningAttempt(
        id: id,
        day: day,
        contentVersion: version,
        journeyRevision: revision,
        optionOrder: order,
        selected: {});
  }
  LearningAttempt answer(String questionId, String optionId) => LearningAttempt(
      id: id,
      day: day,
      contentVersion: contentVersion,
      journeyRevision: journeyRevision,
      optionOrder: optionOrder,
      selected: {...selected, questionId: selected[questionId] ?? optionId});
  bool validFor(List<LessonQuestion> questions) {
    if (!RegExp(r'^[a-zA-Z0-9-]{16,100}$').hasMatch(id) ||
        day < 1 ||
        day > 365 ||
        journeyRevision < 1 ||
        optionOrder.length != questions.length) {
      return false;
    }
    for (final question in questions) {
      final order = optionOrder[question.id];
      if (order == null ||
          order.toSet().length != 4 ||
          !order.every((id) => question.options.any((o) => o.id == id))) {
        return false;
      }
    }
    return selected.entries.every((entry) => questions.any(
        (q) => q.id == entry.key && q.options.any((o) => o.id == entry.value)));
  }

  Map<String, dynamic> toJson() => {
        'attemptId': id,
        'day': day,
        'contentVersion': contentVersion,
        'journeyRevision': journeyRevision,
        'optionOrder': optionOrder,
        'selectedOptionIds': selected
      };
  factory LearningAttempt.fromJson(Map<String, dynamic> data) =>
      LearningAttempt(
          id: data['attemptId'],
          day: data['day'],
          contentVersion: data['contentVersion'],
          journeyRevision: data['journeyRevision'],
          optionOrder: (data['optionOrder'] as Map)
              .map((k, v) => MapEntry(k as String, List<String>.from(v))),
          selected: Map<String, String>.from(data['selectedOptionIds']));
}

class LessonResume {
  final String stepId, checkpointId;
  final int renderedPart, checkpointRevision, readingOffset;
  final bool pending;
  final LearningAttempt attempt;
  const LessonResume(
      {required this.stepId,
      this.renderedPart = 0,
      this.readingOffset = 0,
      required this.attempt,
      this.checkpointId = '',
      this.checkpointRevision = 0,
      this.pending = false});
  LessonResume withSync({required int revision, required bool pending}) =>
      LessonResume(
          stepId: stepId,
          renderedPart: renderedPart,
          readingOffset: readingOffset,
          attempt: attempt,
          checkpointId: checkpointId,
          checkpointRevision: revision,
          pending: pending);
  Map<String, dynamic> toJson() => {
        'stepId': stepId,
        'renderedPart': renderedPart,
        'readingOffset': readingOffset,
        'attempt': attempt.toJson(),
        'checkpointId': checkpointId,
        'checkpointRevision': checkpointRevision,
        'pending': pending
      };
  factory LessonResume.fromJson(Map<String, dynamic> value) => LessonResume(
      stepId: value['stepId'],
      renderedPart: value['renderedPart'] ?? 0,
      readingOffset:
          value['readingOffset'] is int && value['readingOffset'] >= 0
              ? value['readingOffset'] as int
              : 0,
      checkpointId: value['checkpointId'] ?? '',
      checkpointRevision: value['checkpointRevision'] ?? 0,
      pending: value['pending'] == true,
      attempt: LearningAttempt.fromJson(
          Map<String, dynamic>.from(value['attempt'])));
}

/// A pending local edit wins only while its server base has not changed.
/// A newer server revision (including a completion tombstone) wins on opening.
LessonResume? selectLessonResume(LessonResume? local, LessonResume? remote,
    {required int serverRevision, bool cleared = false}) {
  if (local == null) return cleared ? null : remote;
  if (local.pending && local.checkpointRevision >= serverRevision) return local;
  if (serverRevision > local.checkpointRevision || remote != null) {
    return cleared ? null : remote;
  }
  return cleared ? null : local;
}

class SavedLesson {
  final int day;
  final DateTime savedAt;
  const SavedLesson(this.day, this.savedAt);
}

class AppPreferences {
  final bool sounds, haptics, tips, largerText;
  const AppPreferences(
      {this.sounds = true,
      this.haptics = true,
      this.tips = true,
      this.largerText = false});
}
