const onboardingFlowVersion = 2;
const onboardingStepIds = [
  'name',
  'birthday',
  'lifeSeason',
  'scriptureRoutine',
  'guideObstacle',
  'intentions',
  'dailyRhythm',
  'routinePreview',
  'profileSetup',
  'saving',
  'lifetimeAccess'
];
// The previous eleven-screen flow placed preview before intentions and rhythm.
const legacyOnboardingStepIds = [
  'name',
  'birthday',
  'lifeSeason',
  'scriptureRoutine',
  'guideObstacle',
  'routinePreview',
  'intentions',
  'dailyRhythm',
  'profileSetup',
  'saving',
  'lifetimeAccess',
];

/// Old numeric positions referred to a different order. Revisit the first
/// missing input; never interpret an old number as the new screen index.
int resumeOnboardingStep(
  Map<String, dynamic> draft, {
  required bool hasBirthday,
  required bool hasIntentions,
}) {
  final version = (draft['flowVersion'] as num?)?.toInt();
  final requested = () {
    if (version == onboardingFlowVersion) {
      final index = onboardingStepIds.indexOf(draft['stepId']);
      if (index >= 0) return index;
    }
    final old = draft['step'];
    if (old is int && old >= 0 && old < legacyOnboardingStepIds.length) {
      return onboardingStepIds.indexOf(legacyOnboardingStepIds[old]);
    }
    return 0;
  }();
  final missing = () {
    if ((draft['firstName'] as String? ?? '').trim().isEmpty) return 0;
    if (!hasBirthday) return 1;
    if (draft['lifeSeason'] == null) return 2;
    if (draft['faithRoutine'] == null) return 3;
    if (draft['obstacle'] == null) return 4;
    if (!hasIntentions) return 5;
    if (draft['pace'] == null || draft['reminder'] == null) return 6;
    if (draft['termsAccepted'] != true) return 8;
    return 9;
  }();
  // Entering the offer records that the local save already succeeded.
  if (requested == 10 && missing == 9 && draft['stepId'] == 'lifetimeAccess') {
    return 10;
  }
  return requested < missing ? requested : missing;
}
