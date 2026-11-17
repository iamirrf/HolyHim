import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/services/narration.dart';

class _Bundle extends CachingAssetBundle {
  final String manifest;
  _Bundle(this.manifest);
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(manifest)));
}

void main() {
  const track = NarrationTrack(
      file: 'audio/lessons/day-001.m4a', seconds: 80, cues: [0, 21.5, 44, 63]);

  test('the voice is on the card whose cue it has passed', () {
    expect(track.cardAt(Duration.zero), 0);
    expect(track.cardAt(const Duration(seconds: 21)), 0);
    expect(track.cardAt(const Duration(milliseconds: 21500)), 1);
    expect(track.cardAt(const Duration(seconds: 50)), 2);
    expect(track.cardAt(const Duration(seconds: 79)), 3);
  });

  test('a swipe starts the voice at the top of that card', () {
    expect(track.startOf(2), const Duration(seconds: 44));
    expect(track.startOf(9), const Duration(seconds: 63));
  });

  test('the music changes from morning to morning, then comes round', () {
    expect(musicForDay(1), narrationMusic.first);
    expect(musicForDay(2), isNot(musicForDay(1)));
    expect(musicForDay(1 + narrationMusic.length), musicForDay(1));
    expect(narrationMusic.toSet().length, 6);
  });

  test('the catalog reads the manifest the narration tool writes', () async {
    NarrationCatalog.reset();
    final catalog = await NarrationCatalog.load(_Bundle(jsonEncode({
      'voice': 'af_heart',
      'lessons': {
        '1': {
          'file': 'day-001.m4a',
          'seconds': 80.2,
          'cues': [0, 21.5, 44, 63],
          'text': 'x'
        }
      }
    })));
    expect(catalog.keys, [1]);
    expect(catalog[1]!.file, 'audio/lessons/day-001.m4a');
    expect(catalog[1]!.cues.length, 4);
    NarrationCatalog.reset();
  });

  test('a missing or broken manifest means no reading, not a crash', () async {
    NarrationCatalog.reset();
    expect(await NarrationCatalog.load(_Bundle('{not json')), isEmpty);
    NarrationCatalog.reset();
  });
}
