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
  static const cardTitles = [
    "Today's Word",
    'What it means',
    'For your heart',
    'Prayer'
  ];
}
