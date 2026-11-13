import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'art_cache.dart';
import '../domain/lesson.dart';
import '../domain/daily_verse.dart';
import '../domain/calendar.dart';
import '../domain/notification_plan.dart';
import '../design/themes.dart';
import '../design/art_catalog.dart';
import '../design/chapter_catalog.g.dart';
import 'repository.dart';

const holyHimAppGroup = 'group.com.holyhim.app';
const holyHimWidgetKind = 'HolyHim';
String _thumbnailKey(int day) =>
    'lesson-thumbnail-${ChapterCatalog.artworkRevision}-$day';

/// WidgetKit receives the independent daily verse, account theme, and dated
/// future entries. Its bundled catalog keeps rotation available when offline.
Map<String, dynamic> buildWidgetData(
    {required AppProfile profile,
    required Map<int, String> completed,
    required List<Lesson> lessons,
    required DateTime now,
    String? artPath}) {
  if (lessons.isEmpty) return {};
  final local = localNow(now, profile.timeZone);
  final current = dailyVerse(lessons, now, profile.timeZone);
  final theme = HolyThemes.byId(profile.theme);
  String hex(Color value) => value.toARGB32().toRadixString(16).padLeft(8, '0');
  return {
    'version': 4,
    'artworkRevision': ChapterCatalog.artworkRevision,
    'accessRequired': false,
    'day': current.day,
    'title': 'Verse of the Day',
    'reference': current.reference,
    'teaser': teaserExcerpt(current.verse, limit: 180),
    'timeZone': profile.timeZone,
    'theme': profile.theme,
    'accent': hex(theme.accent),
    'ink': hex(theme.ink),
    'colors': theme.colors.map(hex).toList(),
    if (artPath != null) 'artPath': artPath,
    'calendarVerses': [
      for (var offset = 0; offset < 32; offset++) ...[
        (() {
          final date =
              DateTime.utc(local.year, local.month, local.day + offset);
          final day = DateTime.utc(date.year, date.month, date.day)
                  .difference(DateTime.utc(2026, 1, 1))
                  .inDays %
              lessons.length;
          final verse = lessons[day];
          return {
            'date': dateKey(date),
            'day': verse.day,
            'title': 'Verse of the Day',
            'reference': verse.reference,
            'teaser': teaserExcerpt(verse.verse, limit: 180)
          };
        })(),
      ],
    ],
    'updatedAt': now.millisecondsSinceEpoch ~/ 1000,
  };
}

final widgetBridgeProvider = Provider<WidgetBridge>((ref) => WidgetBridge());
final _bridge = WidgetBridge();
Future<void> refreshWidget(
        {required AppProfile profile,
        required Map<int, String> completed,
        required List<Lesson> lessons}) =>
    _bridge.refresh(profile: profile, completed: completed, lessons: lessons);
Future<void> clearWidget() => _bridge.clear();

/// A notification may reuse an already materialized widget thumbnail; this
/// lookup never downloads an image or delays a reading screen.
Future<String?> cachedWidgetThumbnailPath(int day) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
  try {
    return await HomeWidget.getWidgetData<String>(_thumbnailKey(day),
            appGroupId: holyHimAppGroup)
        .timeout(const Duration(milliseconds: 300));
  } catch (_) {
    return null;
  }
}

class WidgetBridge {
  Future<void> _operations = Future.value();
  int _generation = 0;
  String? _fingerprint;
  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  Future<void> refresh(
      {required AppProfile profile,
      required Map<int, String> completed,
      required List<Lesson> lessons}) async {
    if (!_supported || !profile.onboarded || lessons.isEmpty) return;
    final data = buildWidgetData(
        profile: profile,
        completed: completed,
        lessons: lessons,
        now: DateTime.now());
    final fingerprint = jsonEncode(Map.of(data)..remove('updatedAt'));
    if (_fingerprint == fingerprint) return;
    _fingerprint = fingerprint;
    final generation = ++_generation;
    await (_operations = _operations.catchError((Object _) {}).then((_) async {
      if (generation != _generation) return;
      try {
        await HomeWidget.setAppGroupId(holyHimAppGroup);
        final art = await _bundledThumbnail(data['day'] as int);
        if (generation != _generation) return;
        if (art != null) data['artPath'] = art;
        await HomeWidget.saveWidgetData<String>('widgetData', jsonEncode(data));
        await HomeWidget.updateWidget(iOSName: holyHimWidgetKind);
      } catch (_) {
        _fingerprint = null; /* App Group signing can be configured later. */
      }
    }));
  }

  Future<String?> _bundledThumbnail(int day) async {
    try {
      final cached = await cachedWidgetThumbnailPath(day);
      if (cached != null) return cached;
      final cachedArt = await cachedLessonThumbnail(day);
      if (cachedArt != null) {
        final bytes = await readCachedLessonThumbnail(day);
        if (bytes != null) {
          return await HomeWidget.saveFile(_thumbnailKey(day), bytes,
              extension: 'png', appGroupId: holyHimAppGroup);
        }
      }
      final bytes = await rootBundle.load(HolyArtCatalog.thumbnailForDay(day));
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List(),
          targetWidth: 360, targetHeight: 640);
      final frame = await codec.getNextFrame();
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (png == null) return null;
      return await HomeWidget.saveFile(
          _thumbnailKey(day), png.buffer.asUint8List(),
          extension: 'png', appGroupId: holyHimAppGroup);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    if (!_supported) return;
    ++_generation;
    _fingerprint = null;
    await (_operations = _operations.catchError((Object _) {}).then((_) async {
      try {
        await HomeWidget.setAppGroupId(holyHimAppGroup);
        await HomeWidget.saveWidgetData<String>('widgetData', null);
        await HomeWidget.updateWidget(iOSName: holyHimWidgetKind);
      } catch (_) {}
    }));
  }
}
