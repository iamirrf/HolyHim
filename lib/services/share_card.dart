import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/lesson.dart';
import '../design/design.dart';

/// Render at 1080×1920; keep it attached until the end of the raster frame.
Future<void> shareVerseCard(BuildContext context, Lesson lesson) async {
  final key = GlobalKey();
  final overlay = Overlay.of(context);
  final theme = HolyThemeScope.of(context);
  final entry = OverlayEntry(
      builder: (context) => Positioned(
          left: -1000,
          top: 0,
          width: 360,
          height: 640,
          child: RepaintBoundary(
              key: key,
              child: MediaQuery(
                  data: const MediaQueryData(
                      size: Size(360, 640), textScaler: TextScaler.noScaling),
                  child: Theme(
                      data: HolyThemeData.build(theme),
                      child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: ArtImage(
                              day: lesson.day,
                              animate: false,
                              child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(32, 64, 32, 42),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('HOLYHIM',
                                            style: HolyTypography.eyebrow
                                                .copyWith(
                                                    letterSpacing: 3,
                                                    color: theme.ink)),
                                        const Spacer(),
                                        Text('“${lesson.verse}”',
                                            maxLines: 13,
                                            overflow: TextOverflow.fade,
                                            style: HolyTypography.verse
                                                .copyWith(
                                                    fontSize:
                                                        lesson.verse.length >
                                                                300
                                                            ? 19
                                                            : 24,
                                                    color: theme.ink)),
                                        const SizedBox(height: 24),
                                        Text('${lesson.reference} · WEB',
                                            style: HolyTypography.eyebrow
                                                .copyWith(color: theme.accent)),
                                        const Spacer(),
                                        Text(
                                            'A word to carry.\nDay ${lesson.day}',
                                            style: HolyTypography.ui.copyWith(
                                                fontSize: 12, color: theme.ink))
                                      ])))))))));
  overlay.insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null || !context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
        files: [
          XFile.fromData(bytes.buffer.asUint8List(),
              mimeType: 'image/png', name: 'holyhim-day-${lesson.day}.png')
        ],
        text: '${lesson.reference} · HolyHim',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size));
  } finally {
    entry.remove();
  }
}
