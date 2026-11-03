import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/features/lesson/reading_parts.dart';

void main() {
  test(
      'all Scripture is preserved exactly across reading widths and text scales',
      () {
    for (final width in [247.0, 305.0, 620.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final lesson in lessons) {
          final parts = ReadingLayout.split(lesson.verseText,
              style: const TextStyle(fontSize: 22, height: 32 / 22),
              width: width,
              height: 220,
              scaler: TextScaler.linear(scale));
          expect(parts.map((p) => p.text).join(), lesson.verseText,
              reason: 'Day ${lesson.day}, $width, $scale');
          expect(parts.first.start, 0);
          expect(parts.last.end, lesson.verseText.length);
          for (var i = 1; i < parts.length; i++) {
            expect(parts[i].start, parts[i - 1].end);
          }
        }
      }
    }
  });
  test('reflow resumes at or before the first unread source offset', () {
    const text =
        'First sentence. Second sentence. Third sentence. Fourth sentence. Fifth sentence.';
    List<ReadingPart> split(double width) => ReadingLayout.split(text,
        style: const TextStyle(fontSize: 20),
        width: width,
        height: 50,
        scaler: TextScaler.noScaling);
    final before = split(240), after = split(130);
    for (final part in before) {
      final index = ReadingLayout.indexAt(after, part.start);
      expect(after[index].start, lessThanOrEqualTo(part.start));
      expect(after[index].end, greaterThan(part.start));
    }
  });
}
