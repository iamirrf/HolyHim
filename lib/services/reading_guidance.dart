/// Introductory guidance changes with the optional focus; Scripture and order do not.
String readingGuidance(String focus, String familiarity) {
  final opening = switch (focus) {
    'courage' ||
    'confidence' =>
      'You can arrive with honest fear. Courage can begin with a small step.',
    'hope' =>
      'There is room here for hope, even while part of your story remains unfinished.',
    'guidance' =>
      'You do not need every answer before you begin. Make a little space to listen.',
    'rest' => 'Let this be a moment to set down the need to finish everything.',
    _ => 'Let this be a quiet pause in the middle of a full day.',
  };
  return familiarity == 'new'
      ? '$opening The next card explains the passage’s context.'
      : opening;
}
