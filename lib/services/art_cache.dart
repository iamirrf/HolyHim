import 'dart:async';
import 'package:flutter/material.dart';
import '../design/art_catalog.dart';
import 'art_cache_stub.dart' if (dart.library.io) 'art_cache_native.dart'
    as thumbnails;
export 'art_cache_stub.dart' if (dart.library.io) 'art_cache_native.dart'
    show cachedLessonThumbnail, readCachedLessonThumbnail;

/// The image cache owns eviction; there is no second database or outbox.
void prefetchLessonArt(BuildContext context, int day) {
  for (var current = day; current <= day + 3 && current <= 365; current++) {
    unawaited(thumbnails.cacheLessonThumbnail(current));
  }
  for (var next = day + 1; next <= day + 3 && next <= 365; next++) {
    precacheImage(
        AssetImage(HolyArtCatalog.assetForDay(next)),
        context,
        onError: (_, __) {});
  }
}
