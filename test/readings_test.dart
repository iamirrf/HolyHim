import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/data/readings.dart';
import 'package:holyher/services/reading_service.dart';

void main() {
  test(
      '365 retained titles and references each have five reading-only cards with pinned WEB',
      () {
    final scripture =
        jsonDecode(File('test/fixtures/scripture.json').readAsStringSync())
            as List;
    expect(readings.length, 365);
    for (var i = 0; i < 365; i++) {
      final reading = readings[i];
      expect(reading.day, i + 1);
      expect(reading.title, lessons[i].title);
      expect('${reading.reference} (WEB)', lessons[i].verseReference);
      expect(reading.cards.map((c) => c.kind),
          ['scripture', 'meaning', 'encouragement', 'hope', 'prayer']);
      expect(reading.cards.first.text, (scripture[i] as Map)['text']);
      expect(reading.cards.expand((c) => c.text.split(RegExp(r'\s+'))).length,
          inInclusiveRange(280, 380));
    }
  });
  test('all legacy semantic positions have valid five-card destinations', () {
    for (final id in [
      'opening',
      'verse',
      'understand',
      'question-1',
      'confidence',
      'reason',
      'hope',
      'question-2',
      'carry',
      'closing',
      'unknown'
    ]) {
      expect(legacyReadingIndex(id), inInclusiveRange(0, 4));
    }
    expect(legacyReadingIndex('understand'), 1);
    expect(legacyReadingIndex('question-2'), 3);
    expect(legacyReadingIndex('closing'), 4);
  });
}
