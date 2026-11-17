import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../design/sounds.dart';

/// One lesson read aloud: its file, its length, and the moment each of its
/// four cards begins. Written by tool/voice/narrate.py.
@immutable
class NarrationTrack {
  final String file;
  final double seconds;
  final List<double> cues;
  const NarrationTrack(
      {required this.file, required this.seconds, required this.cues});

  /// The card the voice is reading at [position].
  int cardAt(Duration position) {
    final t = position.inMilliseconds / 1000;
    var card = 0;
    for (var i = 0; i < cues.length; i++) {
      if (t + .05 >= cues[i]) card = i;
    }
    return card;
  }

  /// Where [card]'s reading begins.
  Duration startOf(int card) => Duration(
      milliseconds: (cues[card.clamp(0, cues.length - 1)] * 1000).round());
}

/// Six quiet instrumental pieces made for HolyHim, one under each day's
/// reading in turn, so the music changes from morning to morning.
const narrationMusic = [
  'audio/music/before-the-world-wakes.m4a',
  'audio/music/orchards-of-stillness.m4a',
  'audio/music/grace-before-dawn.m4a',
  'audio/music/where-the-light-softens.m4a',
  'audio/music/the-first-gentle-breath.m4a',
  'audio/music/safe-harbor-at-dusk.m4a',
];

/// The day's piece of music.
String musicForDay(int day) =>
    narrationMusic[(day - 1) % narrationMusic.length];

/// The readings the app carries, by day. Days without a reading yet are
/// simply absent: their lessons show no play control.
abstract final class NarrationCatalog {
  static Future<Map<int, NarrationTrack>>? _loaded;

  static Future<Map<int, NarrationTrack>> load([AssetBundle? bundle]) =>
      _loaded ??= _read(bundle ?? rootBundle);

  @visibleForTesting
  static void reset() => _loaded = null;

  static Future<Map<int, NarrationTrack>> _read(AssetBundle bundle) async {
    try {
      final raw = jsonDecode(
              await bundle.loadString('assets/audio/lessons/manifest.json'))
          as Map<String, dynamic>;
      final lessons = raw['lessons'] as Map<String, dynamic>;
      return {
        for (final entry in lessons.entries)
          int.parse(entry.key): NarrationTrack(
              file: 'audio/lessons/${entry.value['file']}',
              seconds: (entry.value['seconds'] as num).toDouble(),
              cues: [
                for (final c in entry.value['cues'] as List)
                  (c as num).toDouble()
              ]),
      };
    } catch (_) {
      return const {};
    }
  }
}

/// Whether a lesson begins reading itself aloud when it opens. A choice
/// for this phone, kept on it.
abstract final class NarrationPrefs {
  static const _key = 'holyhim.narration.autoplay.v1';
  static Future<bool> autoplay() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setAutoplay(bool value) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, value);
    } catch (_) {}
  }
}

/// A lesson read aloud, with the day's music very quietly beneath it.
///
/// The voice follows the cards: [seekToCard] when he swipes, and
/// [onCard] tells the screen when the voice has moved on to the next one,
/// so the cards can turn by themselves. The music fades in as the reading
/// begins and fades out when it pauses or ends, at a tenth of the voice's
/// volume.
class LessonNarration extends ChangeNotifier {
  final int day;
  LessonNarration(this.day);

  /// Music sits at a tenth of the voice.
  static const musicVolume = .10;
  static const _fadeIn = Duration(milliseconds: 2400);
  static const _fadeOut = Duration(milliseconds: 2800);
  static const _pauseFade = Duration(milliseconds: 600);

  /// Speech: it plays with the ring switch off, as spoken audio does, and
  /// pauses other audio instead of talking over it.
  static final _speech = AudioContext(
      iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback, options: const {}),
      android: const AudioContextAndroid(
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain));

  NarrationTrack? track;
  bool loaded = false, playing = false;

  /// The card the voice is on.
  int card = 0;

  /// Told when the voice moves on to a new card by itself.
  ValueChanged<int>? onCard;

  AudioPlayer? _voice, _music;
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _fade;
  double _musicLevel = 0;
  bool _disposed = false;

  bool get available => track != null;

  Future<void> init() async {
    final catalog = await NarrationCatalog.load();
    if (_disposed) return;
    track = catalog[day];
    loaded = true;
    notifyListeners();
  }

  Future<void> _ensurePlayers() async {
    if (_voice != null) return;
    final voice = _voice = AudioPlayer(playerId: 'holyhim-voice-$day');
    final music = _music = AudioPlayer(playerId: 'holyhim-music-$day');
    await voice.setAudioContext(_speech);
    await music.setAudioContext(_speech);
    await voice.setReleaseMode(ReleaseMode.stop);
    await music.setReleaseMode(ReleaseMode.loop);
    _subscriptions
      ..add(voice.onPositionChanged.listen(_onPosition))
      ..add(voice.onPlayerComplete.listen((_) => _finished()));
  }

  void _onPosition(Duration position) {
    final t = track;
    if (t == null || !playing) return;
    final now = t.cardAt(position);
    if (now != card) {
      card = now;
      onCard?.call(now);
      notifyListeners();
    }
  }

  /// Starts reading at [fromCard], or carries on where it paused.
  Future<void> play({int? fromCard}) async {
    final t = track;
    if (t == null || _disposed) return;
    try {
      await _ensurePlayers();
      final voice = _voice!, music = _music!;
      if (fromCard != null) card = fromCard;
      playing = true;
      notifyListeners();
      if (voice.state == PlayerState.paused && fromCard == null) {
        await voice.resume();
      } else {
        await voice.setSource(AssetSource(t.file));
        await voice.seek(t.startOf(card));
        await voice.resume();
      }
      // The music is optional: without it the reading goes on alone.
      try {
        if (music.state != PlayerState.paused) {
          await music.setSource(AssetSource(musicForDay(day)));
        }
        await music.setVolume(_musicLevel);
        await music.resume();
        _fadeMusic(musicVolume, _fadeIn);
      } catch (e) {
        debugPrint('Narration music unavailable: $e');
      }
    } catch (e) {
      debugPrint('Narration error: $e');
      playing = false;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (!playing) return;
    playing = false;
    notifyListeners();
    try {
      await _voice?.pause();
      _fadeMusic(0, _pauseFade, then: () => _music?.pause());
    } catch (e) {
      debugPrint('Narration error: $e');
    }
  }

  Future<void> toggle(int fromCard) =>
      playing ? pause() : play(fromCard: _voice == null ? fromCard : null);

  /// He swiped to [to]: the voice follows him there.
  Future<void> seekToCard(int to) async {
    final t = track;
    if (t == null || to == card) return;
    card = to;
    notifyListeners();
    if (!playing) return;
    try {
      await _voice?.seek(t.startOf(to));
    } catch (e) {
      debugPrint('Narration error: $e');
    }
  }

  void _finished() {
    playing = false;
    notifyListeners();
    _fadeMusic(0, _fadeOut, then: () async {
      await _music?.stop();
      await HolySounds.reassertSession();
    });
  }

  /// Stops at once, music faded quickly, for when the lesson closes.
  Future<void> stop() async {
    playing = false;
    _fade?.cancel();
    try {
      await _voice?.stop();
      await _music?.stop();
      await HolySounds.reassertSession();
    } catch (_) {}
  }

  void _fadeMusic(double to, Duration over, {FutureOr<void> Function()? then}) {
    _fade?.cancel();
    final from = _musicLevel;
    const step = Duration(milliseconds: 50);
    final steps =
        (over.inMilliseconds / step.inMilliseconds).ceil().clamp(1, 1000);
    var i = 0;
    _fade = Timer.periodic(step, (timer) {
      i++;
      final p = i / steps;
      // Ease in and out, so neither end of the fade is heard as a step.
      final eased = p < .5 ? 2 * p * p : 1 - 2 * (1 - p) * (1 - p);
      _musicLevel = from + (to - from) * eased.clamp(0.0, 1.0);
      _music?.setVolume(_musicLevel).catchError((Object _) {});
      if (i >= steps) {
        timer.cancel();
        if (then != null) Future.sync(then).catchError((Object _) {});
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _fade?.cancel();
    for (final s in _subscriptions) {
      s.cancel();
    }
    final voice = _voice, music = _music;
    if (voice != null || music != null) {
      () async {
        try {
          await voice?.stop();
          await music?.stop();
          await voice?.dispose();
          await music?.dispose();
          await HolySounds.reassertSession();
        } catch (_) {}
      }();
    }
    super.dispose();
  }
}
