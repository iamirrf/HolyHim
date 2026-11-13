import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:holyhim/data/lessons.g.dart';
import 'package:holyhim/domain/access.dart';
import 'package:holyhim/domain/lesson_position.dart';
import 'package:holyhim/domain/onboarding_flow.dart';

OnboardingAnswers _answers(Map<String, dynamic> draft,
        {String name = 'Mira', List<String> hearts = const []}) =>
    OnboardingAnswers.read(draft, name: name, hearts: hearts);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('onboarding version 3 resume', () {
    test('a known name skips the name step; an unknown one starts there', () {
      expect(resumeOnboardingStep(const {}, _answers(const {})), 1);
      expect(resumeOnboardingStep(const {}, _answers(const {}, name: '')), 0);
      expect(
          resumeOnboardingStep(const {}, _answers(const {}, name: '  ')), 0);
    });

    test('resumes at the step she was on, never past a missing answer', () {
      final draft = {
        'flowVersion': onboardingFlowVersion,
        'stepId': 'reminder',
        'lifeSeason': 'full',
        'familiarity': 'new',
        'obstacle': 'busy',
      };
      expect(resumeOnboardingStep(draft, _answers(draft, hearts: ['peace'])),
          onboardingStepIds.indexOf('reminder'));
      // Hearts were never saved: go back for them.
      expect(resumeOnboardingStep(draft, _answers(draft)), 1);
      // Going back to review an earlier answer is respected.
      final back = {...draft, 'stepId': 'season'};
      expect(resumeOnboardingStep(back, _answers(back, hearts: ['peace'])), 2);
    });

    test('birthday is optional; closing steps resume where they were', () {
      final draft = {
        'flowVersion': onboardingFlowVersion,
        'stepId': 'letter',
        'lifeSeason': 'full',
        'familiarity': 'new',
        'obstacle': 'busy',
        'reminder': 'off',
      };
      expect(resumeOnboardingStep(draft, _answers(draft, hearts: ['hope'])),
          onboardingStepIds.indexOf('letter'));
      final offer = {...draft, 'stepId': 'offer'};
      expect(resumeOnboardingStep(offer, _answers(offer, hearts: ['hope'])),
          onboardingStepIds.indexOf('offer'));
    });

    test('version 2 drafts map their display text to stable IDs', () {
      final v2 = {
        'flowVersion': 2,
        'stepId': 'dailyRhythm',
        'step': 6,
        'lifeSeason': 'A time of change',
        'faithRoutine': 'I read regularly',
        'obstacle': 'My days are full',
        'reminder': 'Morning · 7 AM',
      };
      final a = _answers(v2, hearts: normalizedHearts(['Peace', 'Courage']));
      expect(a.obstacle, 'busy');
      expect(a.reminder, '07:00');
      expect(a.hearts, ['peace', 'strength']);
      // Everything required is answered: go to the optional birthday.
      expect(resumeOnboardingStep(v2, a), onboardingStepIds.indexOf('building'));
      final saved = {...v2, 'stepId': 'lifetimeAccess', 'step': 10};
      expect(resumeOnboardingStep(saved, _answers(saved, hearts: ['peace'])),
          onboardingStepIds.indexOf('letter'));
      final partial = {'flowVersion': 2, 'stepId': 'lifeSeason', 'step': 2};
      expect(resumeOnboardingStep(partial, _answers(partial, hearts: ['peace'])),
          2);
    });

    test('reminder answers round-trip through minutes', () {
      expect(reminderMinutesFor('07:00'), 420);
      expect(reminderMinutesFor('20:30'), 1230);
      expect(reminderMinutesFor('off'), isNull);
      expect(reminderMinutesFor('25:00'), isNull);
      expect(reminderAnswerFor(1230), '20:30');
      expect(reminderAnswerFor(5), '00:05');
    });

    test('every step ID fits the Firestore rules list', () {
      for (final id in onboardingStepIds) {
        expect(id.length, lessThan(40));
      }
      expect(onboardingStepIds.toSet().length, onboardingStepIds.length);
    });
  });

  group('access', () {
    test('the first week is free and later days need the unlock', () {
      for (var day = 1; day <= freeDays; day++) {
        expect(canOpenLesson(day, owned: false, completed: const {}), isTrue);
      }
      expect(canOpenLesson(8, owned: false, completed: const {}), isFalse);
      expect(canOpenLesson(8, owned: true, completed: const {}), isTrue);
      expect(canOpenLesson(365, owned: true, completed: const {}), isTrue);
    });

    test('a completed lesson stays open forever', () {
      expect(canOpenLesson(9, owned: false, completed: const {9: '2026-11-01'}),
          isTrue);
      expect(lessonAccess(9, owned: false, completed: const {9: '2026-11-01'}),
          LessonAccess.completed);
    });

    test('free days left counts unfinished free lessons', () {
      expect(freeDaysLeft(const {}), 7);
      expect(freeDaysLeft(const {1: 'a', 2: 'b', 9: 'c'}), 5);
      expect(freeDaysLeft({for (var d = 1; d <= 7; d++) d: 'x'}), 0);
    });
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
