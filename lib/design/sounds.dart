// Ported from Cognein; see store/v2-design-ports.json.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Sound effects, the audible partner to [HolyHaptics].
///
/// The lesson cues are meant to be felt more than heard, and to arrive *with*
/// the thing they belong to, never after it:
///
/// * a swipe's whoosh starts the instant the card is let go, as loud as the
///   flick was fast, and a different one each time, as air is;
/// * a card landing is a very soft low pat, once the next one has settled;
/// * a right answer is a small glassy note, and a wrong one is silent (a mistake
///   is information, not a scolding);
/// * a finished lesson is the one cue allowed to be a moment of its own: air
///   that circles the listener once, as the blue light circles the card.
///
/// They are preloaded into small pools of players (see [warmUp]) so that playing
/// one is a single "go" to a player that already holds the sound. Loading the
/// asset and setting up the audio session on every play, as this used to, added
/// a delay that made a cue trail the card it belonged to.
class HolySounds {
  const HolySounds._();

  /// Purchase or restore confirmed. The same chime as SunRize's badge reveal.
  static const purchaseChimeAsset = 'sounds/soft_chime.mp3';

  /// A card leaving forward: three whooshes in rotation, so no two in a row are
  /// the same.
  static const lessonSwipeAssets = [
    'sounds/lesson_swipe_1.mp3',
    'sounds/lesson_swipe_2.mp3',
    'sounds/lesson_swipe_3.mp3',
  ];

  /// A card going back: shorter, and the air falls instead of rising.
  static const lessonSwipeBackAsset = 'sounds/lesson_swipe_back.mp3';

  /// The next card settling into place.
  static const lessonLandAsset = 'sounds/lesson_land.mp3';
  static const lessonCorrectAsset = 'sounds/lesson_correct.mp3';

  /// The lesson saved. Stereo, 2.7 s: a swell of air that pans once round the
  /// listener on the same curve as the aura's orbit, with the four-note arpeggio
  /// at its crest. (`LessonCelebration` paces the screen to this file.)
  static const lessonSurgeAsset = 'sounds/lesson_surge.mp3';

  /// `scripts/make_lesson_sounds.py` writes all of these.
  static const cueAssets = [
    ...lessonSwipeAssets,
    lessonSwipeBackAsset,
    lessonLandAsset,
    lessonCorrectAsset,
    lessonSurgeAsset,
  ];

  // How loud each cue plays (0..1), on top of how loud its file was mixed. All
  // low: a cue should be something a learner would miss, not something they
  // notice.
  static const _chimeGain = 0.7;
  static const swipeGain = 0.30;
  static const landGain = 0.20;
  static const correctGain = 0.24;
  // The one cue that is a moment of its own: a touch above a swipe's whoosh.
  static const surgeGain = 0.50;

  /// The app-wide switch (Settings → Sound effects).
  static bool enabled = true;

  /// Plays an asset under `assets/` at [gain] (0..1). Swapped out in widget
  /// tests, which have no audio plugin behind them.
  @visibleForTesting
  static Future<void> Function(String asset, {double gain}) player = _play;

  static int _swipeTurn = 0;

  /// The whoosh to play next: the next one in the rotation.
  @visibleForTesting
  static String nextSwipeAsset() {
    final asset = lessonSwipeAssets[_swipeTurn % lessonSwipeAssets.length];
    _swipeTurn++;
    return asset;
  }

  @visibleForTesting
  static void resetRotation() => _swipeTurn = 0;

  // The pools: each cue has a couple of players that already hold its sound, so
  // a quick second swipe can start while the first is still fading.
  static final _pools = <String, List<AudioPlayer>>{};
  static final _turns = <String, int>{};
  static Future<void>? _warm;
  static AudioPlayer? _chimePlayer;

  static final _ambient = AudioContext(
    // A UI sound, not media: it follows the ring/silent switch and plays over
    // the user's music instead of stopping it.
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.assistanceSonification,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  /// Loads every lesson cue into its players. Called when a lesson opens, well
  /// before the first swipe; safe to call again. Never throws.
  static Future<void> warmUp() {
    // With the player swapped out (every widget test) there is no plugin to load.
    if (!_isRealPlayer) return Future<void>.value();
    return _warm ??= _prepare();
  }

  static bool get _isRealPlayer => player == _play;

  static Future<void> _prepare() async {
    try {
      await AudioPlayer.global.setAudioContext(_ambient);
    } catch (e) {
      debugPrint('Sound effect error: $e');
    }
    for (final asset in cueAssets) {
      // Two each: a quick second swipe can start while the first still fades.
      const voices = 2;
      final players = <AudioPlayer>[];
      for (var i = 0; i < voices; i++) {
        try {
          final player = AudioPlayer();
          await player.setPlayerMode(PlayerMode.lowLatency);
          await player.setReleaseMode(ReleaseMode.stop);
          await player.setSource(AssetSource(asset));
          players.add(player);
        } catch (e) {
          debugPrint('Sound effect error: $e');
        }
      }
      if (players.isNotEmpty) _pools[asset] = players;
    }
  }

  /// A video upgrades the iOS audio session to "playback", which would make the
  /// next cue interrupt the learner's music and ignore the silent switch. Put it
  /// back to what a cue wants once the reel is behind them.
  static Future<void> reassertSession() async {
    if (!_isRealPlayer) return;
    try {
      await AudioPlayer.global.setAudioContext(_ambient);
    } catch (e) {
      debugPrint('Sound effect error: $e');
    }
  }

  static Future<void> _play(String asset, {double gain = 1}) async {
    try {
      if (cueAssets.contains(asset)) {
        await _playCue(asset, gain);
        return;
      }
      final player = _chimePlayer ??= AudioPlayer();
      await player.setAudioContext(_ambient);
      await player.play(AssetSource(asset), volume: _chimeGain * gain);
    } catch (e) {
      debugPrint('Sound effect error: $e');
    }
  }

  static Future<void> _playCue(String asset, double gain) async {
    await warmUp();
    final voices = _pools[asset];
    if (voices == null || voices.isEmpty) return;
    final turn = _turns[asset] ?? 0;
    _turns[asset] = turn + 1;
    final voice = voices[turn % voices.length];
    // Volume and rewind are independent, so they go together; then "go". Not
    // every platform's low-latency player can rewind (Android's throws), and a
    // sound that cannot be rewound still starts from the top, so a refused
    // rewind must never stop the cue.
    await Future.wait([
      voice.setVolume(gain.clamp(0.0, 1.0)),
      voice.seek(Duration.zero).catchError((Object _) {}),
    ]);
    await voice.resume();
  }

  static Future<void> _cue(String asset, {double gain = 1}) async {
    if (enabled) await player(asset, gain: gain);
  }

  static Future<void> purchaseChime() => _cue(purchaseChimeAsset);

  /// A card let go and on its way. [intensity] is 0..1, how fast it was thrown:
  /// a flick is airier than a slow, deliberate drag.
  static Future<void> lessonSwipe({
    bool forward = true,
    double intensity = 1,
  }) =>
      _cue(
        forward ? nextSwipeAsset() : lessonSwipeBackAsset,
        gain: swipeGain * intensity.clamp(0.0, 1.0),
      );

  /// The next card has settled.
  static Future<void> lessonLand({double intensity = 1}) =>
      _cue(lessonLandAsset, gain: landGain * intensity.clamp(0.0, 1.0));

  /// A right answer.
  static Future<void> lessonCorrect() =>
      _cue(lessonCorrectAsset, gain: correctGain);

  /// The lesson is saved: the whoosh that goes with the blue light's lap.
  static Future<void> lessonSurge() => _cue(lessonSurgeAsset, gain: surgeGain);
}
