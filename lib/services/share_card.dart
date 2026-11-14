import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants/app_constants.dart';
import '../design/art_catalog.dart';
import '../domain/lesson.dart';
import '../design/design.dart';

enum KeepsakeStyle {
  /// 9:16, for Stories.
  story,

  /// 1:1, for posts and messages.
  square,
}

/// A keepsake: the day's photograph, the verse in display italic, the
/// reference and a quiet wordmark. Rendered at 1080 wide.
class KeepsakeCard extends StatelessWidget {
  final Lesson lesson;
  final KeepsakeStyle style;
  const KeepsakeCard(
      {super.key, required this.lesson, this.style = KeepsakeStyle.story});

  @override
  Widget build(BuildContext context) {
    final story = style == KeepsakeStyle.story;
    final long = lesson.verse.length;
    final size = story
        ? (long > 320 ? 22.0 : long > 200 ? 26.0 : 31.0)
        : (long > 320 ? 17.0 : long > 200 ? 20.0 : 24.0);
    return Stack(fit: StackFit.expand, children: [
      Image.asset(HolyArtCatalog.assetForDay(lesson.day),
          fit: BoxFit.cover, alignment: const Alignment(0, -.2)),
      const DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, .35, 1],
                  colors: [
            Color(0x66140C10),
            Color(0x22140C10),
            Color(0xCC140C10),
          ]))),
      Padding(
          padding: EdgeInsets.fromLTRB(30, story ? 70 : 28, 30, story ? 60 : 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Center(child: Wordmark(size: 26, color: HolyTheme.photoInk)),
            const Spacer(),
            // Scales down rather than overflowing when shown small.
            Flexible(
                child: LayoutBuilder(
                    builder: (context, box) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: SizedBox(
                            width: box.maxWidth,
                            child: Text('“${lesson.verse}”',
                                style: HolyTypography.verse.copyWith(
                                    fontSize: size,
                                    color: HolyTheme.photoInk,
                                    height: 1.22,
                                    shadows: const [
                                      Shadow(
                                          color: Color(0x88000000),
                                          blurRadius: 16)
                                    ])))))),
            const SizedBox(height: 14),
            Row(children: [
              const Flourish(width: 28, color: Color(0xFFF2D7A6)),
              const SizedBox(width: 10),
              Text(lesson.reference,
                  style: HolyTypography.label
                      .copyWith(color: const Color(0xFFF2D7A6))),
            ]),
            if (story) ...[
              const SizedBox(height: 28),
              Text('Day ${lesson.day} · HolyHim',
                  style: HolyTypography.caption.copyWith(
                      color: HolyTheme.photoInk.withValues(alpha: .8))),
            ],
          ])),
    ]);
  }
}

Future<void> shareVerseCard(BuildContext context, Lesson lesson,
    {KeepsakeStyle style = KeepsakeStyle.story}) async {
  final key = GlobalKey();
  final overlay = Overlay.of(context);
  final theme = HolyThemeScope.of(context);
  final logical = style == KeepsakeStyle.story
      ? const Size(360, 640)
      : const Size(360, 360);
  final entry = OverlayEntry(
      builder: (context) => Positioned(
          left: -2000,
          top: 0,
          width: logical.width,
          height: logical.height,
          child: RepaintBoundary(
              key: key,
              child: MediaQuery(
                  data: MediaQueryData(
                      size: logical, textScaler: TextScaler.noScaling),
                  child: HolyThemeScope(
                      theme: theme,
                      child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: KeepsakeCard(lesson: lesson, style: style)))))));
  overlay.insert(entry);
  try {
    await precacheImage(
        AssetImage(HolyArtCatalog.assetForDay(lesson.day)), context);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 80));
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
        text: '${lesson.reference}. A word to stand on, every morning: '
            '${AppConstants.shareUrl}',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size));
  } finally {
    entry.remove();
  }
}
