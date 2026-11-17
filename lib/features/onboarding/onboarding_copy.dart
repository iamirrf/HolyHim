import '../../domain/onboarding_flow.dart';
import 'chat/chat_script.dart';

/// Every word of the welcome, in one place.
///
/// The voice is the one in content/STYLE.md: an older brother, plain and
/// direct, short sentences, spoken to "you". Nothing here promises an
/// outcome, and nothing assumes what his life looks like. Titles and the
/// conversation carry no emoji; his answers and his note do. Each step has
/// one small line under its button.
abstract final class OnboardingCopy {
  static const continueLabel = 'Continue';
  static const skip = 'Skip';
  static const tryAgain = 'Try again';

  /// Shown once when a relaunch returns him to the step he left.
  static const resumed = 'Welcome back. Picked up where you left off.';

  static const nameTitle = 'What should we call you?';
  static const nameSubtitle = 'Your first name is enough.';
  static const nameField = 'First name';
  static const nameError = 'Tell us what to call you.';
  static const nameLine = 'Only your first name. You can change it any time.';

  static const birthdayTitle = 'When is your birthday?';
  static const birthdaySubtitle =
      'So we can send a blessing on your day. This is optional.';
  static const birthdaySave = 'Save my birthday';
  static const birthdayLine =
      'Used for one thing only: a blessing on your day.';

  static String heartTitle(String name) => name.isEmpty
      ? 'What do you need most?'
      : '$name, what do you need most?';
  static const heartSubtitle =
      'Pick up to three. Your lessons will meet you there.';
  static String heartCount(int chosen) => switch (chosen) {
        0 => 'Pick up to three.',
        3 => '3 of 3 picked. Tap one to change it.',
        _ => '$chosen of 3 picked',
      };
  static const chatHint = 'Tap one of your answers to change it.';
  static const chatLine = 'Just tap a reply. There is nothing to type.';

  static const seasonTitle = 'Where are you right now?';
  static const seasonSubtitle = 'There is no wrong answer.';
  static const seasonLine = 'Your answer changes the words in your letter.';

  static const showFirstWeek = 'Show me my first week';
  static String firstWeekTitle(String name) => name.isEmpty
      ? 'Here is your first week'
      : '$name, here is your first week';
  static const firstWeekSubtitle = 'Seven short lessons, one for each day.';
  static const firstWeekLabel = 'YOUR FIRST 7 DAYS';
  static const firstWeekLine = 'About five minutes a day. Four short cards.';

  /// One emoji for each of the first seven lessons, in order: He Goes With
  /// You, A Clean Road, There Is a Way Out, God Looks Deeper, Iron on Iron,
  /// Young Is Not Too Young, Strength That Lasts.
  static const firstWeekEmoji = ['👣', '🛤️', '🚪', '🔍', '⚒️', '🌱', '🦅'];

  /// His own words, said back to him: what he told us gets in the way, and
  /// what the road does about it. Null when he said nothing gets in the way.
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

  static const buildWalk = 'Build my road';
  static String buildingTitle(String name) =>
      name.isEmpty ? 'Building your road' : 'Building your road, $name';

  static const medallionCaption = 'Finish Day 1 and this is yours';
  static const medallionName = 'First Step';
  static const saveError =
      'We could not save your road on this phone. Please try again.';

  static String letterTitle(String name) =>
      name.isEmpty ? 'Your road is ready' : 'Your road is ready, $name';
  static const letterLine = 'Your answers are saved to your account.';

  static const dayOneLabel = 'DAY 1';
  static const dayOneTitle = 'Here is where you start';
  static const dayOneLine =
      'Four short cards and a prayer. About five minutes.';

  // The conversation about the Bible.

  static String _hello(String name) => name.isEmpty
      ? 'Good to have you here.'
      : 'Good to have you here, $name.';

  static ChatScript bibleChat({required String Function() name}) => ChatScript(
      opening: () => [
            _hello(name()),
            'Two quick questions. They help me pick the right words for you.',
          ],
      questions: [
        ChatQuestion(
            id: 'familiarity',
            ask: () => const ['How well do you know the Bible?'],
            replies: () => [
                  for (final c in familiarityChoices)
                    ChatReply(c.id, c.label, emoji: c.emoji)
                ],
            react: (id) => switch (id) {
                  'new' =>
                    'Good place to start. Every lesson explains the verse in plain words.',
                  'some' => 'Good. We will build on the stories you know.',
                  'returning' =>
                    'Welcome back. We will take it one day at a time.',
                  'daily' =>
                    'Good. You may see a verse you know in a new light.',
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
                  'busy' => 'Fair. Each lesson is just four short cards.',
                  'understanding' =>
                    'You are not the only one. We explain each verse in plain words.',
                  'forgetting' =>
                    'That happens to everyone. A short note each day can help.',
                  'starting' =>
                    'Starting is the hard part. You already have.',
                  'none' => 'Good. Then let us start.',
                  _ => null,
                }),
      ],
      closing: () => [
            name().isEmpty
                ? 'Thanks. That is all I need.'
                : 'Thanks, ${name()}. That is all I need.'
          ]);

  // The conversation about his daily note.

  static const noteCustom = 'custom';
  static const noteOff = 'off';
  static const noteKeep = 'keep';
  static const noteCustomLabel = 'Choose another time';
  static const noteOffLabel = 'Not now';
  static const noteKeepLabel = 'Keep it as it is';
  static const noteCustomEmoji = '🕰️';
  static const noteOffEmoji = '⏸️';
  static const noteKeepEmoji = '👍';

  /// [keep] is offered in place of "Not now" when he is retaking the
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
                      'A short note each day helps you come back. When should today’s word arrive?'
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
      'Done. One note a day at $time. You can change it any time.';
  static const noteDenied =
      'That is fine. You can turn notes on later in Profile.';
  static const noteDeclined =
      'That is fine. Your road will be here whenever you come back.';
  static const noteKept = 'Good. Your note stays just as it is.';

  /// "7:00 AM" for minutes after midnight.
  static String clock(int minutes) {
    final h = minutes ~/ 60, m = minutes % 60;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
  }
}
