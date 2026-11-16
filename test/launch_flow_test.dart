import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:holyhim/data/lessons.g.dart';
import 'package:holyhim/domain/access.dart';
import 'package:holyhim/domain/lesson_position.dart';
import 'package:holyhim/domain/onboarding_flow.dart';
import 'package:holyhim/features/welcome/welcome_screen.dart';

OnboardingAnswers _answers(Map<String, dynamic> draft,
        {String name = 'Mira', List<String> hearts = const []}) =>
    OnboardingAnswers.read(draft, name: name, hearts: hearts);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('onboarding version 3 resume', () {
    test('a known name skips the name step; an unknown one starts there', () {
      expect(resumeOnboardingStep(const {}, _answers(const {})), 1);
      expect(resumeOnboardingStep(const {}, _answers(const {}, name: '')), 0);
      expect(resumeOnboardingStep(const {}, _answers(const {}, name: '  ')), 0);
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
      expect(resumeOnboardingStep(draft, _answers(draft)),
          onboardingStepIds.indexOf('heart'));
      // Going back to review an earlier answer is respected.
      final back = {...draft, 'stepId': 'season'};
      expect(resumeOnboardingStep(back, _answers(back, hearts: ['peace'])),
          onboardingStepIds.indexOf('season'));
    });

    test('the two conversations resume until both of their answers are given',
        () {
      final chat = onboardingStepIds.indexOf('familiarity');
      final half = {
        'flowVersion': onboardingFlowVersion,
        'stepId': 'routinePreview',
        'lifeSeason': 'full',
        'familiarity': 'new',
      };
      // The obstacle was never answered: back into the conversation.
      expect(
          resumeOnboardingStep(half, _answers(half, hearts: ['peace'])), chat);
      final both = {...half, 'obstacle': 'busy'};
      expect(resumeOnboardingStep(both, _answers(both, hearts: ['peace'])),
          onboardingStepIds.indexOf('routinePreview'));
    });

    test('drafts saved in the earlier step order land on the right step', () {
      final answered = {
        'flowVersion': onboardingFlowVersion,
        'lifeSeason': 'full',
        'familiarity': 'new',
        'obstacle': 'busy',
      };
      // 'obstacle' was a step of its own; it is now part of a conversation.
      final obstacle = {...answered, 'stepId': 'obstacle', 'step': 4}
        ..remove('obstacle');
      expect(
          resumeOnboardingStep(obstacle, _answers(obstacle, hearts: ['rest'])),
          onboardingStepIds.indexOf('familiarity'));
      // Birthday used to be the last question, after the reminder.
      final birthday = {
        ...answered,
        'stepId': 'birthday',
        'step': 6,
        'reminder': '07:00'
      };
      expect(
          resumeOnboardingStep(birthday, _answers(birthday, hearts: ['rest'])),
          onboardingStepIds.indexOf('building'));
      // In the present order birthday comes second, before any answer.
      final fresh = {
        'flowVersion': onboardingFlowVersion,
        'stepId': 'birthday'
      };
      expect(resumeOnboardingStep(fresh, _answers(fresh)),
          onboardingStepIds.indexOf('birthday'));
    });

    test('the steps after the save keep her in the welcome on relaunch', () {
      for (final id in ['building', 'letter', 'dailyRhythm', 'offer']) {
        expect(
            onboardingIsClosing(
                {'flowVersion': onboardingFlowVersion, 'stepId': id}),
            isTrue,
            reason: id);
      }
      for (final id in ['name', 'reminder', 'routinePreview', 'complete']) {
        expect(
            onboardingIsClosing(
                {'flowVersion': onboardingFlowVersion, 'stepId': id}),
            isFalse,
            reason: id);
      }
      // Version 2 used 'dailyRhythm' for a step in the middle of its flow.
      expect(onboardingIsClosing({'flowVersion': 2, 'stepId': 'dailyRhythm'}),
          isFalse);
      expect(
          onboardingIsClosing({'flowVersion': 2, 'stepId': 'lifetimeAccess'}),
          isTrue);
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
      expect(
          resumeOnboardingStep(v2, a), onboardingStepIds.indexOf('building'));
      final saved = {...v2, 'stepId': 'lifetimeAccess', 'step': 10};
      expect(resumeOnboardingStep(saved, _answers(saved, hearts: ['peace'])),
          onboardingStepIds.indexOf('letter'));
      final partial = {'flowVersion': 2, 'stepId': 'lifeSeason', 'step': 2};
      expect(
          resumeOnboardingStep(partial, _answers(partial, hearts: ['peace'])),
          onboardingStepIds.indexOf('season'));
    });

    test('reminder answers round-trip through minutes', () {
      expect(reminderMinutesFor('07:00'), 420);
      expect(reminderMinutesFor('20:30'), 1230);
      expect(reminderMinutesFor('off'), isNull);
      expect(reminderMinutesFor('25:00'), isNull);
      expect(reminderAnswerFor(1230), '20:30');
      expect(reminderAnswerFor(5), '00:05');
    });

    test('every step ID and position is one the Firestore rules allow', () {
      // Read from the deployed rules file: the welcome cannot ask for a
      // rules change, so it must fit what is already there.
      final rules = File('firestore.rules').readAsStringSync();
      final list =
          RegExp(r"get\('stepId',''\) in \[([^\]]*)\]").firstMatch(rules)![1]!;
      final allowed =
          RegExp(r"'([^']*)'").allMatches(list).map((m) => m[1]!).toSet();
      for (final id in [...onboardingStepIds, onboardingDoneStepId]) {
        expect(allowed, contains(id));
      }
      final maxStep =
          int.parse(RegExp(r"get\('step',0\) <= (\d+)").firstMatch(rules)![1]!);
      expect(onboardingStepIds.length - 1, lessThanOrEqualTo(maxStep));
      final maxVersion = int.parse(
          RegExp(r"get\('flowVersion',0\) <= (\d+)").firstMatch(rules)![1]!);
      expect(onboardingFlowVersion, lessThanOrEqualTo(maxVersion));
      expect(onboardingStepIds.toSet().length, onboardingStepIds.length);
    });
  });

  test('the welcome shows its night scenes from seven until five', () {
    for (final hour in [19, 22, 0, 4]) {
      expect(WelcomeScreen.isNight(DateTime(2026, 11, 14, hour)), isTrue,
          reason: '$hour');
    }
    for (final hour in [5, 9, 12, 18]) {
      expect(WelcomeScreen.isNight(DateTime(2026, 11, 14, hour)), isFalse,
          reason: '$hour');
    }
    // Every scene it can show is a photograph in the bundle.
    for (final path in [
      ...WelcomeScreen.scenes,
      ...WelcomeScreen.nightScenes
    ]) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  group('access', () {
    test('nothing is free: every lesson needs membership or the unlock', () {
      for (final day in [1, 7, 8, 365]) {
        expect(canOpenLesson(day, owned: false, completed: const {}), isFalse,
            reason: 'Day $day');
        expect(canOpenLesson(day, owned: true, completed: const {}), isTrue,
            reason: 'Day $day');
      }
    });

    test('a completed lesson stays readable', () {
      expect(canOpenLesson(9, owned: false, completed: const {9: '2026-11-01'}),
          isTrue);
      expect(lessonAccess(9, owned: false, completed: const {9: '2026-11-01'}),
          LessonAccess.completed);
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
