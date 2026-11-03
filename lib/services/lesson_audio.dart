import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Adapted from Cognein's low-latency cue pools. Lifetime is one lesson route.
class LessonAudio {
  final bool Function() enabled;
  final Map<String, List<AudioPlayer>> _pools = {};
  Future<void>? _warming;
  int _generation = 0, _turn = 0;
  bool _closed = false;
  LessonAudio(this.enabled);
  static const cues = [
    'lesson_swipe_1',
    'lesson_swipe_2',
    'lesson_swipe_3',
    'lesson_swipe_back',
    'lesson_land',
    'lesson_correct',
    'lesson_surge'
  ];
  Future<void> warmUp() => _warming ??= _prepare();
  Future<void> _prepare() async {
    if (!enabled()) return;
    final generation = _generation;
    for (final cue in cues) {
      for (var i = 0; i < 2; i++) {
        if (_closed || generation != _generation) return;
        final player = AudioPlayer();
        try {
          await player.setAudioContext(AudioContext(
              iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
              android: const AudioContextAndroid(
                  contentType: AndroidContentType.sonification,
                  usageType: AndroidUsageType.assistanceSonification,
                  audioFocus: AndroidAudioFocus.none)));
          await player.setPlayerMode(PlayerMode.lowLatency);
          await player.setReleaseMode(ReleaseMode.stop);
          await player.setSource(AssetSource('sounds/$cue.mp3'));
          if (_closed || generation != _generation) {
            await player.dispose();
            return;
          }
          (_pools[cue] ??= []).add(player);
        } catch (_) {
          try {
            await player.dispose();
          } catch (_) {}
        }
      }
    }
  }

  Future<void> play(String cue, double gain) async {
    if (_closed || !enabled()) return;
    final generation = _generation;
    try {
      await warmUp();
      if (_closed || generation != _generation || !enabled()) return;
      final pool = _pools[cue];
      if (pool == null || pool.isEmpty) return;
      final player = pool[_turn++ % pool.length];
      await Future.wait([
        player.setVolume(gain),
        player.seek(Duration.zero).catchError((Object _) {})
      ]);
      if (_closed || generation != _generation || !enabled()) return;
      await player.resume();
    } catch (_) {/* A cue never owns navigation or completion. */}
  }

  void swipe(bool forward, double intensity) => unawaited(play(
      forward ? 'lesson_swipe_${(_turn % 3) + 1}' : 'lesson_swipe_back',
      .30 * intensity));
  void stop() {
    _generation++;
    for (final pool in _pools.values) {
      for (final player in pool) {
        unawaited(player.stop().catchError((Object _) {}));
      }
    }
  }

  void dispose() {
    _closed = true;
    stop();
    for (final pool in _pools.values) {
      for (final player in pool) {
        unawaited(player.dispose().catchError((Object _) {}));
      }
    }
    _pools.clear();
  }
}
