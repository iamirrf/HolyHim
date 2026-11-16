import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/data/lessons.g.dart';
import 'package:holyhim/domain/lesson.dart';

/// 54 verses once showed a doubled closing mark: an excerpt that ends inside
/// someone's words already carries its own, and the card added another.
void main() {
  test('every verse has whole quotation marks, never doubled', () {
    for (final lesson in lessons) {
      final quoted = lesson.quotedVerse;
      expect(quoted.contains('””') || quoted.contains('““'), isFalse,
          reason: 'Day ${lesson.day}: $quoted');
      expect('“'.allMatches(quoted).length, '”'.allMatches(quoted).length,
          reason: 'Day ${lesson.day}: $quoted');
      // Scripture is never edited: only marks are added around it.
      expect(quoted.replaceAll('“', '').replaceAll('”', ''),
          lesson.verse.trim().replaceAll('“', '').replaceAll('”', ''),
          reason: 'Day ${lesson.day}');
    }
  });

  test('each kind of excerpt gets only the mark it is missing', () {
    expect(quoteVerse('Be still.'), '“Be still.”');
    expect(
        quoteVerse('He will not forsake you.”'), '“He will not forsake you.”');
    expect(quoteVerse('The LORD said, “I have seen.'),
        'The LORD said, “I have seen.”');
    expect(quoteVerse('He said, “Rest.”'), 'He said, “Rest.”');
    // Begins inside one saying and ends inside the next.
    expect(quoteVerse('toward you,” says the LORD, “thoughts of peace.'),
        '“toward you,” says the LORD, “thoughts of peace.”');
  });
}
