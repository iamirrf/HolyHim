import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/core/constants/app_constants.dart';
import 'package:holyher/data/lessons.dart';

void main() {
  final sources = (jsonDecode(
    File('test/fixtures/scripture.json').readAsStringSync(),
  ) as List)
      .cast<Map<String, dynamic>>();

  int words(String value) => value.trim().split(RegExp(r'\s+')).length;

  test('all 365 complete lessons match pinned public-domain WEB evidence', () {
    expect(lessons.length, 365);
    expect(lessons.length, AppConstants.totalDays);
    expect(sources.length, lessons.length);
    expect(lessons.map((lesson) => lesson.title).toSet().length, 365);
    expect(lessons.map((lesson) => lesson.verseReference).toSet().length, 365);

    for (var index = 0; index < lessons.length; index++) {
      final lesson = lessons[index];
      final source = sources[index];
      expect(lesson.day, index + 1);
      expect(source['day'], lesson.day);
      expect(lessonForDay(lesson.day), same(lesson));
      expect(lesson.translation, 'WEB');
      expect(lesson.verseReference, '${source['reference']} (WEB)');
      expect(lesson.verseText, source['text']);
      expect(source['translation'], 'WEB');
      expect(source['edition'], 'World English Bible Protestant Edition');
      expect(source['corpusSource'],
          'https://ebible.org/Scriptures/engwebp_usfx.zip');
      expect(source['source'], startsWith('https://ebible.org/engwebp/'));
      expect(source['verseKeys'], isNotEmpty);
      for (final key in ['archiveSha256', 'textSha256', 'verseSha256']) {
        expect(source[key], matches(RegExp(r'^[a-f0-9]{64}$')));
      }
      expect([
        lesson.title,
        lesson.theme,
        lesson.verseReference,
        lesson.verseText,
        lesson.confidence,
        lesson.reason,
        lesson.hope,
        lesson.devotionalReflection,
        lesson.reflection,
      ], everyElement(isNotEmpty));
      expect(words(lesson.confidence), inInclusiveRange(20, 35));
      expect(words(lesson.reason), inInclusiveRange(30, 50));
      expect(words(lesson.hope), inInclusiveRange(15, 30));
      expect(words(lesson.devotionalReflection), inInclusiveRange(20, 35));
      expect(words(lesson.reflection), inInclusiveRange(5, 15));
      expect(
        [
          lesson.confidence,
          lesson.reason,
          lesson.hope,
          lesson.devotionalReflection,
          lesson.reflection
        ].map(words).reduce((total, count) => total + count),
        inInclusiveRange(110, 160),
        reason: 'Day ${lesson.day} complete prose length',
      );
    }
    expect(lessonForDay(-1), isNull);
    expect(lessonForDay(0), isNull);
    expect(lessonForDay(366), isNull);
  });

  test('each day has distinct confidence, reason, hope, and reflection prose',
      () {
    final fields = <String, List<String>>{
      'confidence': [for (final lesson in lessons) lesson.confidence],
      'reason': [for (final lesson in lessons) lesson.reason],
      'hope': [for (final lesson in lessons) lesson.hope],
      'devotionalReflection': [
        for (final lesson in lessons) lesson.devotionalReflection,
      ],
      'reflection': [for (final lesson in lessons) lesson.reflection],
    };
    for (final field in fields.entries) {
      expect(field.value.toSet().length, 365, reason: field.key);
    }
  });

  test('source evidence retains edition and corpus identity for every lesson',
      () {
    final provenance = jsonDecode(
      File('tool/scripture/provenance.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final source in sources) {
      expect(source['archiveSha256'], provenance['archiveSha256']);
      expect(source['textSha256'], provenance['textSha256']);
      expect(source['edition'], provenance['edition']);
      expect(source['retrieved'], provenance['retrieved']);
    }
  });
}
