import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:holyhim/data/lessons.g.dart';
import 'package:holyhim/domain/lesson_position.dart';
import 'package:holyhim/domain/onboarding_flow.dart';
import 'package:holyhim/domain/personalized_plan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy numeric onboarding positions revisit missing semantic answers',
      () {
    final old = <String, dynamic>{
      'step': 8,
      'firstName': 'Mira',
      'lifeSeason': 'A time of change',
      'faithRoutine': 'I’m returning after some time',
      'source': 'The App Store',
      'familiarity': 'I know a little',
      'needs': 'Finding peace',
      'pace': 'Three minutes',
      'reminder': 'No reminders',
      'termsAccepted': true,
    };
    expect(
        resumeOnboardingStep(old, hasBirthday: true, hasIntentions: true), 4);
    old['obstacle'] = 'My days are full';
    expect(
        resumeOnboardingStep(old, hasBirthday: true, hasIntentions: true), 8);
    old['flowVersion'] = onboardingFlowVersion;
    old['stepId'] = 'routinePreview';
    expect(
        resumeOnboardingStep(old, hasBirthday: true, hasIntentions: true), 7);
    old['firstName'] = '';
    expect(
        resumeOnboardingStep(old, hasBirthday: true, hasIntentions: true), 0);
  });

  test('each old numeric position maps to its former semantic screen', () {
    const expected = [0, 1, 2, 3, 4, 7, 5, 6, 8, 9, 9];
    for (var oldStep = 0; oldStep < expected.length; oldStep++) {
      final old = <String, dynamic>{
        'step': oldStep,
        'firstName': 'Mira',
        'lifeSeason': 'A time of change',
        'faithRoutine': 'I read regularly',
        'obstacle': 'No particular obstacle',
        'pace': 'Three minutes',
        'reminder': 'No reminders',
        'termsAccepted': true,
      };
      expect(resumeOnboardingStep(old, hasBirthday: true, hasIntentions: true),
          expected[oldStep],
          reason: 'legacy step $oldStep');
    }
  });

  test('planned totals and reminder text derive from actual choices', () {
    final answers = <String, dynamic>{
      'lifeSeason': 'Caring for others',
      'faithRoutine': 'I’m new to Scripture',
      'obstacle': 'Understanding Scripture is hard',
      'pace': 'Five minutes',
      'reminder': 'Morning · 7 AM',
    };
    final plan =
        PersonalizedPlan.fromAnswers(answers, ['Peace', 'Hope'], false);
    expect(plan.minutes, 5);
    expect(plan.reminder, 'Reminders are off on this device');
    expect(plan.advice, contains('Meaning card'));
    expect(plan.encouragement, 'Peace · Hope');
    answers['pace'] = 'A little longer';
    expect(PersonalizedPlan.fromAnswers(answers, [], true).minutes, isNull);
  });

  test('reading position is account scoped and content changes reset scroll',
      () async {
    SharedPreferences.setMockInitialValues({});
    final lesson = lessons.first;
    final position = LessonPosition(1, LessonStage.reflection, .72,
        LessonPosition.revision(lesson), DateTime.utc(2026, 11, 8));
    await LessonPositionStore.write('reader-a', position);
    expect((await LessonPositionStore.read('reader-a', lesson))!.scrollFraction,
        .72);
    expect(await LessonPositionStore.read('reader-b', lesson), isNull);
    final altered = LessonPosition.parse(
        {...position.toJson(), 'contentRevision': 'older'}, lesson);
    expect(altered!.stage, LessonStage.reflection);
    expect(altered.scrollFraction, 0);
    await LessonPositionStore.clear('reader-a');
    expect(await LessonPositionStore.read('reader-a', lesson), isNull);
  });
}
