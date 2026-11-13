/// A description of the practice someone chose, derived from their answers.
/// It does not change the canonical lesson order or promise an outcome.
class PersonalizedPlan {
  final String context, orientation, advice, encouragement, pace, reminder;
  final int? minutes;

  const PersonalizedPlan(this.context, this.orientation, this.advice,
      this.encouragement, this.pace, this.reminder, this.minutes);

  factory PersonalizedPlan.fromAnswers(Map<String, dynamic> draft,
      List<String> intentions, bool reminderEnabled) {
    final context = switch (draft['lifeSeason']) {
      'A full season' => 'For the full days you are living',
      'A time of change' => 'For this season of change',
      'Providing for others' => 'While you provide for others',
      'Finding my footing' => 'As you find your footing',
      'Making space for faith' => 'As you make space for faith',
      _ => 'For the season you are in'
    };
    final orientation = switch (draft['faithRoutine']) {
      'I’m new to Scripture' => 'Begin with the passage and its context.',
      'I’m returning after some time' =>
        'Return to the passage at your own pace.',
      'I’m finding a steady rhythm' =>
        'Give this reading a small, regular place.',
      'I read regularly' => 'Take time with the passage before moving on.',
      _ => 'Begin with today’s passage.'
    };
    final advice = switch (draft['obstacle']) {
      'My days are full' => 'Choose a steady moment that fits a full day.',
      'Understanding Scripture is hard' => 'Read the Meaning card for context.',
      'I forget to return' =>
        'Let a reminder bring you back when you want one.',
      'Beginning feels hard' => 'Open Scripture and start with one sentence.',
      _ => 'Read, reflect, and pray at a pace that fits today.'
    };
    final pace = draft['pace'] as String? ?? 'A flexible moment';
    final minutes = switch (pace) {
      'One minute' => 1,
      'Three minutes' => 3,
      'Five minutes' => 5,
      _ => null
    };
    final reminder = reminderEnabled
        ? 'Daily verse reminder: ${draft['reminder'] ?? 'your chosen time'}'
        : draft['reminder'] == 'No reminders'
            ? 'No reminder selected'
            : 'Reminders are off on this device';
    return PersonalizedPlan(
        context,
        orientation,
        advice,
        intentions.isEmpty ? 'Room to grow in faith' : intentions.join(' · '),
        pace,
        reminder,
        minutes);
  }
}
