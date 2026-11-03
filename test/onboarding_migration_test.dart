import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/features/onboarding/checkpoint.dart';
import 'package:holyher/services/profile_service.dart';

void main() {
  test('all v1 and v2 numeric positions migrate through their semantic meaning',
      () {
    const v1 = [
      'name',
      'name',
      'focus',
      'focus',
      'reminder',
      'day-one',
      'day-one'
    ];
    for (var i = 0; i < v1.length; i++) {
      expect(
          UserProfile.fromJson({'onboardingStep': i}).onboardingStepId, v1[i]);
    }
    const v2 = [
      'name',
      'name',
      'focus',
      'focus',
      'reminder',
      'reminder',
      'focus',
      'day-one',
      'day-one',
      'day-one'
    ];
    for (var i = 0; i < v2.length; i++) {
      expect(
          UserProfile.fromJson({'onboardingVersion': 2, 'onboardingStep': i})
              .onboardingStepId,
          v2[i]);
    }
  });
  test('v4 semantic ID wins over numeric position and survives termination',
      () {
    for (final id in OnboardingStages.ids) {
      final profile = UserProfile.fromJson({
        'onboardingVersion': 4,
        'onboardingStep': 0,
        'onboardingStepId': id,
        'onboardingAnswered': ['name', 'starting-point'],
        'suggestedReminderMinutes': 759,
        'reminderDecision': 'denied',
        'guidedExampleAnswer': 'day-001-q1-b',
        'guidedExampleRevealed': true
      });
      expect(profile.onboardingStepId, id);
      final restored = UserProfile.fromJson(profile.toJson());
      expect(restored.onboardingStepId, id);
      expect(restored.suggestedReminderMinutes, 759);
      expect(restored.reminderMinutes, isNull);
      expect(restored.reminderDecision, 'denied');
      expect(restored.guidedExampleAnswer, 'day-001-q1-b');
      expect(restored.onboardingAnswered, {'name', 'starting-point'});
    }
  });
  test('completed older accounts keep their answers and enabled reminder', () {
    final p = UserProfile.fromJson({
      'onboardingComplete': true,
      'onboardingStep': 6,
      'name': 'Amira',
      'familiarity': 'regular',
      'focus': 'rest',
      'obstacle': 'forget',
      'reminderMinutes': 540
    });
    expect(p.onboardingComplete, isTrue);
    expect(p.reminderMinutes, 540);
    expect(p.suggestedReminderMinutes, 540);
    expect(p.reminderDecision, 'enabled');
    expect(p.focus, 'rest');
  });
  test(
      'invalid stage identifiers fall back safely and settings defaults survive',
      () {
    expect(
        UserProfile.fromJson({
          'onboardingVersion': 3,
          'onboardingStepId': 'bogus',
          'onboardingStep': 40
        }).onboardingStepId,
        'day-one');
    final p = UserProfile.fromJson({});
    expect(p.haptics, isTrue);
    expect(p.sounds, isTrue);
    expect(p.tips, isTrue);
    expect(p.reminderMinutes, isNull);
    final muted = UserProfile.fromJson(
        {'sounds': false, 'haptics': true, 'largerText': true});
    expect(muted.sounds, isFalse);
    expect(muted.haptics, isTrue);
    expect(muted.largerText, isTrue);
  });
}
