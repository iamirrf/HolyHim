import 'package:holyher/services/profile_service.dart';

String focusLabel(String id) =>
    const {
      'peace': 'Peace',
      'confidence': 'Confidence',
      'hope': 'Hope',
      'guidance': 'Guidance',
      'rest': 'Rest'
    }[id] ??
    'Daily faith';
String familiarityLabel(String id) =>
    const {
      'new': 'New to the Bible',
      'returning': 'Returning to the Bible',
      'regular': 'A regular reader'
    }[id] ??
    'Your own pace';
String rhythmTip(String obstacle) => switch (obstacle) {
      'busy' =>
        'Leave a little room, rather than waiting for a perfect morning. Your place in the cards is saved.',
      'forget' =>
        'Let one familiar moment be your cue: a morning drink, lunch, or settling in for the evening.',
      'language' =>
        'Read the verse slowly, then turn to Reason for a plain-language explanation of its message.',
      'apply' =>
        'Stay with one small action on the Carry card. You do not need to change everything today.',
      _ => 'One verse, five short cards, and something to carry into your day.',
    };
String reminderLabel(int? minutes) {
  if (minutes == null) return 'No daily reminder';
  final hour = minutes ~/ 60;
  return '${hour % 12 == 0 ? 12 : hour % 12}:${(minutes % 60).toString().padLeft(2, '0')} ${hour < 12 ? 'AM' : 'PM'}';
}

String focusQuestion(UserProfile profile, int day) {
  const questions = <String, List<String>>{
    'peace': [
      'What worry can you name honestly as you reflect on this verse?',
      'Where could you pause before reacting today?',
      'Which words in this passage invite you to slow down?',
      'What can you entrust to God while taking your next practical step?',
      'How could today’s reflection change the way you enter a difficult conversation?',
      'What would a quiet minute with this passage look like today?',
      'Which part of today’s message will you return to when your thoughts feel crowded?'
    ],
    'confidence': [
      'What small, faithful action can you take with today’s verse in mind?',
      'Which words in this passage help you remember where your worth rests?',
      'Where can you practice courage without pretending you are not afraid?',
      'What would it mean to receive today’s encouragement rather than earn it?',
      'How could this verse help you speak with honesty and kindness?',
      'Which part of today’s reflection can steady you before a hard task?',
      'What is one thing you can do today while trusting God with the outcome?'
    ],
    'hope': [
      'Where does today’s passage give you a reason to keep going?',
      'What small sign of goodness can you notice today?',
      'Which words in this verse would you like to remember while you wait?',
      'How could you make room for hope without denying what is difficult?',
      'Who could receive a little encouragement from you today?',
      'What unfinished part of life can you bring to God in prayer?',
      'Which thought from today’s message can accompany you into tomorrow?'
    ],
    'guidance': [
      'What next step becomes clearer as you consider this passage?',
      'Where could you seek wise counsel before making a decision?',
      'How can today’s verse shape one choice you already need to make?',
      'Which words in this passage invite closer attention?',
      'What would an honest and gentle next step look like today?',
      'Where might you need patience rather than an immediate answer?',
      'What can you practice from this passage before trying to understand everything?'
    ],
    'rest': [
      'What burden can you name before God without solving it first?',
      'Where could you make a little room to breathe today?',
      'Which words in today’s passage invite you to receive rather than strive?',
      'What can wait while you take a necessary moment of rest?',
      'How could today’s reflection change the way you speak to yourself?',
      'What would accepting help look like in one ordinary moment?',
      'What can you set down tonight while remembering this passage?'
    ],
  };
  final list = questions[profile.focus];
  return list == null
      ? 'What is one small way you can carry today’s verse into your life?'
      : list[(day - 1).clamp(0, 364) % list.length];
}
