/// Semantic positions survive presentation changes and avoid replaying newly
/// inserted interludes when an older checkpoint resumes.
abstract final class OnboardingStages {
  static const v3 = [
    'name',
    'moment',
    'starting-point',
    'barrier',
    'guided-example',
    'daily-rhythm',
    'focus',
    'reminder',
    'summary',
    'save',
    'day-one',
    'arrival'
  ];
  static const v2 = [
    'name',
    'starting-point',
    'focus',
    'barrier',
    'suggested-rhythm',
    'reminder',
    'learning-preview',
    'summary',
    'save',
    'day-one'
  ];
  static const v1ToV2 = [0, 1, 2, 3, 5, 7, 9];
  static const renamed = {
    'suggested-rhythm': 'daily-rhythm',
    'learning-preview': 'guided-example'
  };
  static const ids = ['name', 'focus', 'reminder', 'day-one'];
  static int migrate(Map<String, dynamic> data) {
    final id = data['onboardingStepId'];
    if (data['onboardingVersion'] == 4) {
      return ids.contains(id)
          ? ids.indexOf(id as String)
          : (data['onboardingStep'] as int? ?? 0).clamp(0, 3);
    }
    final numeric =
        data['onboardingStep'] is int ? data['onboardingStep'] as int : 0;
    final oldId = id is String
        ? id
        : data['onboardingVersion'] == 3
            ? v3[numeric.clamp(0, 11)]
            : v2[(data['onboardingVersion'] == 2
                ? numeric.clamp(0, 9)
                : v1ToV2[numeric.clamp(0, 6)])];
    return switch (oldId) {
      'name' || 'moment' || 'starting-point' => 0,
      'focus' || 'barrier' || 'guided-example' || 'learning-preview' => 1,
      'reminder' || 'suggested-rhythm' || 'daily-rhythm' => 2,
      _ => 3,
    };
  }

  static Set<String> answered(Map<String, dynamic> data) {
    final previous = data['onboardingAnswered'];
    if ((data['onboardingVersion'] == 3 || data['onboardingVersion'] == 4) &&
        previous is List) {
      return previous
          .whereType<String>()
          .where((id) => v3.contains(id) || ids.contains(id))
          .toSet();
    }
    return {
      if (previous is List)
        ...previous
            .whereType<String>()
            .where((id) => v3.contains(id) || ids.contains(id)),
      if (data['name'] is String && (data['name'] as String).isNotEmpty) 'name',
      if (data['familiarity'] is String) 'starting-point',
      if (data['focus'] is String) 'focus',
      if (data['obstacle'] is String) 'barrier',
      if (data['reminderMinutes'] is int) 'reminder',
    };
  }
}
