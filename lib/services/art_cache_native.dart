import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '../design/art_catalog.dart';
import '../design/chapter_catalog.g.dart';
import 'package:path_provider/path_provider.dart';

final _active = <int, Future<void>>{};
Future<File> _thumbnail(int day) async {
  final directory = Directory(
      '${(await getTemporaryDirectory()).path}/holyhim-art-${ChapterCatalog.artworkRevision}');
  await directory.create(recursive: true);
  return File('${directory.path}/day-${day.toString().padLeft(3, '0')}.png');
}

Future<String?> cachedLessonThumbnail(int day) async {
  try {
    final file = await _thumbnail(day);
    return await file.exists() ? file.path : null;
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> readCachedLessonThumbnail(int day) async {
  try {
    final path = await cachedLessonThumbnail(day);
    if (path == null) return null;
    return await File(path).readAsBytes();
  } catch (_) {
    return null;
  }
}

Future<void> cacheLessonThumbnail(int day) {
  if (day < 1 || day > 365) return Future.value();
  return _active.putIfAbsent(
      day, () => _cache(day).whenComplete(() => _active.remove(day)));
}

Future<void> _cache(int day) async {
  try {
    final target = await _thumbnail(day);
    if (await target.exists()) return;
    final bytes = (await rootBundle.load(HolyArtCatalog.thumbnailForDay(day)))
        .buffer
        .asUint8List();
    // UNNotificationAttachment receives PNG derived from the bundled WebP.
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 360);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    if (data != null) {
      await target.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
  } catch (_) {/* Missing art leaves the themed atmosphere and text intact. */}
}
