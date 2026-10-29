import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/data/lessons.dart';

void main() {
  test('ten complete ordered lessons match independently fetched KJV evidence',
      () {
    final sources =
        jsonDecode(File('test/fixtures/scripture.json').readAsStringSync())
            as List;
    expect(lessons.length, 10);
    expect(
        lessons.map((lesson) => lesson.title).toSet().length, lessons.length);
    expect(lessons.map((lesson) => lesson.verseReference).toSet().length,
        lessons.length);
    for (var index = 0; index < lessons.length; index++) {
      final lesson = lessons[index];
      final source = sources[index] as Map;
      expect(lesson.day, index + 1);
      expect(lesson.verseReference, '${source['reference']} (KJV)');
      expect(lesson.verseText, source['text']);
      expect([
        lesson.title,
        lesson.verseReference,
        lesson.verseText,
        lesson.confidence,
        lesson.reason,
        lesson.hope,
        lesson.reflection
      ], everyElement(isNotEmpty));
    }
    expect(lessonForDay(0), isNull);
    expect(lessonForDay(11), isNull);
  });
}
