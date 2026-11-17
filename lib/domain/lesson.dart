/// The four-screen, public-domain Scripture lesson shipped with the app.
class Lesson {
  final int day;
  final String title,
      reference,
      theme,
      verse,
      meaning,
      heart,
      holdOn,
      prayer,
      teaser;
  const Lesson(
      {required this.day,
      required this.title,
      required this.reference,
      required this.theme,
      required this.verse,
      required this.meaning,
      required this.heart,
      required this.holdOn,
      required this.prayer,
      required this.teaser});

  List<String> get cards => [verse, meaning, heart, prayer];

  /// The verse with its quotation marks whole and never doubled. A verse
  /// with no speech of its own is set in marks; an excerpt that begins or
  /// ends inside someone's words gets the one mark it is missing; balanced
  /// speech marks stand as they are.
  String get quotedVerse => quoteVerse(verse);
  static const cardTitles = [
    "Today's Word",
    'What it means',
    'For your life',
    'Prayer'
  ];
}

/// See [Lesson.quotedVerse].
String quoteVerse(String verse) {
  final body = verse.trim();
  final marks = RegExp('[“”]').allMatches(body).map((m) => m[0]).toList();
  // No speech of its own: the whole verse is the quotation.
  if (marks.isEmpty) return '“$body”';
  var quoted = body;
  // The excerpt begins inside someone's words: their opening mark is
  // missing. (Jeremiah 29:11 begins this way and ends inside new words.)
  if (marks.first == '”') quoted = '“$quoted';
  // It ends inside them: their closing mark is missing.
  if (marks.last == '“') quoted = '$quoted”';
  // Its own speech marks, balanced: shown as they are, never doubled.
  return quoted;
}
