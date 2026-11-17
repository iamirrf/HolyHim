import '../../domain/onboarding_flow.dart';
import 'chat/chat_script.dart';

/// Every word of the welcome, in one place.
///
/// The voice is the one in content/STYLE.md: a warm friend, plain words,
/// short sentences, spoken to "you". Nothing here promises an outcome, and
/// nothing assumes what her life looks like. Each title ends with one emoji,
/// and each step has one small line under its button.
abstract final class OnboardingCopy {
  static const continueLabel = 'Continue';
  static const skip = 'Skip';
  static const tryAgain = 'Try again';

  /// Shown once when a relaunch returns her to the step she left.
  static const resumed = 'Welcome back. Picked up where you left off.';

  static const nameTitle = 'What should we call you? 🌸';
  static const nameSubtitle = 'Your first name is enough.';
  static const nameField = 'First name';
  static const nameError = 'Tell us what to call you.';
  static const nameLine = 'Only your first name. You can change it any time.';

  static const birthdayTitle = 'When is your birthday? 🎂';
  static const birthdaySubtitle =
      'So we can send a blessing on your day. This is optional.';
  static const birthdaySave = 'Save my birthday';
  static const birthdayLine =
      'Used for one thing only: a blessing on your day.';

  static String heartTitle(String name) => name.isEmpty
      ? 'What does your heart need? 💗'
      : 'Hi $name. What does your heart need? 💗';
  static const heartSubtitle =
      'Choose up to three. We will shape your walk around them.';
  static String heartCount(int chosen) => switch (chosen) {
        0 => 'Choose up to three.',
        3 => '3 of 3 chosen. Tap one to change it.',
        _ => '$chosen of 3 chosen',
      };
  static const chatHint = 'Tap one of your answers to change it.';
  static const chatLine = 'Just tap a reply. There is nothing to type.';

  static const seasonTitle = 'What season are you in? 🍃';
  static const seasonSubtitle = 'There is no wrong answer.';
  static const seasonLine = 'Your answer changes the words in your letter.';

  static const showFirstWeek = 'Show me my first week';
  static String firstWeekTitle(String name) => name.isEmpty
      ? 'Here is your first week 🌅'
      : '$name, here is your first week 🌅';
  static const firstWeekSubtitle = 'Seven short lessons, one for each day.';
  static const firstWeekLabel = 'YOUR FIRST 7 DAYS';
  static const firstWeekLine = 'About five minutes a day. Four short cards.';

  /// One emoji for each of the first seven lessons, in order.
  static const firstWeekEmoji = ['👣', '🫶', '🛡️', '🙌', '🌅', '🕊️', '🦅'];

  /// Her own words, said back to her: what she told us gets in the way, and
  /// what the walk does about it. Null when she said nothing gets in the way.
  static String? echo(String? obstacle, {required bool reminderOn}) =>
      switch (obstacle) {
        'busy' =>
          'You said time gets in the way. Each day is four short cards, about five minutes.',
        'understanding' =>
          'You said the Bible can be hard to understand. Every verse comes with plain words.',
        'forgetting' => reminderOn
            ? 'You said you forget to come back. Your daily note will bring today’s word to you.'
            : 'You said you forget to come back. Your place is always saved for you.',
        'starting' =>
          'You said starting feels hard. Day 1 is small on purpose.',
        _ => null,
      };

  static const buildWalk = 'Build my walk';
  static String buildingTitle(String name) =>
      name.isEmpty ? 'Building your walk ✨' : 'Building your walk, $name ✨';
  static const medallionCaption = 'Finish Day 1 and this is yours';
  static const medallionName = 'A Beautiful Beginning';
  static const saveError =
      'We could not save your walk on this phone. Please try again.';

  static String letterTitle(String name) =>
      name.isEmpty ? 'Your walk is ready 💌' : 'Your walk is ready, $name 💌';
  static const letterLine = 'Your answers are saved to your account.';

  static const dayOneLabel = 'DAY 1';
  static const dayOneTitle = 'Here is where you begin 🕊️';
  static const dayOneLine =
      'Four short cards and a prayer. About five minutes.';

  // The conversation about the Bible.

  static String _hello(String name) => name.isEmpty
      ? 'Hi. I am so glad you are here. 🤍'
      : 'Hi $name. I am so glad you are here. 🤍';

  static ChatScript bibleChat({required String Function() name}) => ChatScript(
      opening: () => [
            _hello(name()),
            'Can I ask you two quick things? They help me choose the right words for you.',
          ],
      questions: [
        ChatQuestion(
            id: 'familiarity',
            ask: () => const ['How well do you know the Bible? 📖'],
            replies: () => [
                  for (final c in familiarityChoices)
                    ChatReply(c.id, c.label, emoji: c.emoji)
                ],
            react: (id) => switch (id) {
                  'new' =>
                    'That is a good place to start. Every lesson explains the verse in plain words.',
                  'some' => 'Good. We will build on the stories you know.',
                  'returning' =>
                    'Welcome back. We will take it one day at a time.',
                  'daily' =>
                    'Lovely. You may see a verse you know in a new light.',
                  _ => null,
                }),
        ChatQuestion(
            id: 'obstacle',
            ask: () => const ['What usually gets in the way?'],
            replies: () => [
                  for (final c in obstacleChoices)
                    ChatReply(c.id, c.label, emoji: c.emoji)
                ],
            react: (id) => switch (id) {
                  'busy' => 'I hear you. Each lesson is just four short cards.',
                  'understanding' =>
                    'You are not alone in that. We explain each verse in plain words.',
                  'forgetting' =>
                    'That happens to all of us. A gentle note each day can help.',
                  'starting' =>
                    'Starting is the hard part. You have already begun.',
                  'none' => 'Good. Then let us begin.',
                  _ => null,
                }),
      ],
      closing: () => [
            name().isEmpty
                ? 'Thank you. I have what I need. 🌷'
                : 'Thank you, ${name()}. I have what I need. 🌷'
          ]);

  // The conversation about her daily note.

  static const noteCustom = 'custom';
  static const noteOff = 'off';
  static const noteKeep = 'keep';
  static const noteCustomLabel = 'Choose another time';
  static const noteOffLabel = 'Not now';
  static const noteKeepLabel = 'Keep it as it is';
  static const noteCustomEmoji = '🕰️';
  static const noteOffEmoji = '🌿';
  static const noteKeepEmoji = '👍';

  /// [keep] is offered in place of "Not now" when she is retaking the
  /// welcome with a reminder already on: declining must not switch it off.
  /// [react] is asked after the answer is stored, because what to say
  /// depends on what iOS allowed.
  static ChatScript noteChat(
          {required String Function() name,
          required bool keep,
          required String? Function(String answerId) react}) =>
      ChatScript(
          opening: () => [
                name().isEmpty
                    ? 'One more thing.'
                    : 'One more thing, ${name()}.'
              ],
          questions: [
            ChatQuestion(
                id: 'reminder',
                ask: () => const [
                      'A short note each day can help you come back. When should today’s word arrive? 🔔'
                    ],
                replies: () => [
                      for (final p in reminderPresets)
                        ChatReply(p.id, '${p.label} · ${p.detail}',
                            emoji: p.emoji),
                      const ChatReply(noteCustom, noteCustomLabel,
                          deferred: true, emoji: noteCustomEmoji),
                      keep
                          ? const ChatReply(noteKeep, noteKeepLabel,
                              emoji: noteKeepEmoji)
                          : const ChatReply(noteOff, noteOffLabel,
                              emoji: noteOffEmoji),
                    ],
                react: react),
          ],
          closing: () => const []);

  static String noteSet(String time) =>
      'Done. One note a day at $time. You can change it anytime. 🌤️';
  static const noteDenied =
      'That is all right. You can turn notes on later in Profile.';
  static const noteDeclined =
      'That is all right. Your walk will be here whenever you come.';
  static const noteKept = 'Good. Your note stays just as it is.';

  /// "7:00 AM" for minutes after midnight.
  static String clock(int minutes) {
    final h = minutes ~/ 60, m = minutes % 60;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
  }
}
