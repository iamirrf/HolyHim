import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'lesson.dart';

enum LessonStage { scripture, meaning, reflection, prayer }

class LessonPosition {
  final int day;
  final LessonStage stage;
  final double scrollFraction;
  final String contentRevision;
  final DateTime updatedAt;
  const LessonPosition(this.day, this.stage, this.scrollFraction,
      this.contentRevision, this.updatedAt);

  static String revision(Lesson lesson) {
    var hash = 0x811c9dc5;
    for (final unit
        in '${lesson.title}|${lesson.verse}|${lesson.meaning}|${lesson.heart}|${lesson.prayer}'
            .codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16);
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        'stage': stage.index,
        'scrollFraction': scrollFraction,
        'contentRevision': contentRevision,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  static LessonPosition? parse(Object? value, Lesson lesson) {
    if (value is! Map) return null;
    final day = value['day'],
        stage = value['stage'],
        fraction = value['scrollFraction'];
    if (day != lesson.day ||
        stage is! int ||
        stage < 0 ||
        stage >= LessonStage.values.length ||
        fraction is! num ||
        !fraction.isFinite) {
      return null;
    }
    return LessonPosition(
        day,
        LessonStage.values[stage],
        value['contentRevision'] == revision(lesson)
            ? fraction.toDouble().clamp(0, 1)
            : 0,
        revision(lesson),
        DateTime.tryParse('${value['updatedAt']}') ?? DateTime.now());
  }
}

class LessonPositionStore {
  static final Map<String, Future<void>> _writes = {};
  static String _key(String accountId) => 'holyhim.position.v1.$accountId';

  static Future<LessonPosition?> read(String accountId, Lesson lesson) async {
    try {
      await _writes[accountId]?.catchError((Object _) {});
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key(accountId));
      return raw == null ? null : LessonPosition.parse(jsonDecode(raw), lesson);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String accountId, LessonPosition position) async {
    final previous = _writes[accountId] ?? Future<void>.value();
    final next = previous.catchError((Object _) {}).then((_) async {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setString(
          _key(accountId), jsonEncode(position.toJson()))) {
        throw StateError('Reading position could not be saved on this device.');
      }
    });
    _writes[accountId] = next;
    await next;
  }

  static Future<void> clear(String accountId) async {
    final previous = _writes[accountId] ?? Future<void>.value();
    final next = previous.catchError((Object _) {}).then((_) async {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.remove(_key(accountId))) {
        throw StateError(
            'Reading position could not be cleared on this device.');
      }
    });
    _writes[accountId] = next;
    await next;
  }
}
