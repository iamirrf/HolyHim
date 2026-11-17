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

/// How a keepsake looks: the day's photograph, warm paper, or a starry night.
enum KeepsakeLook { photo, paper, night }

/// The colours of one look.
class _Palette {
  final Color ink, muted, accent, frame;
  const _Palette(this.ink, this.muted, this.accent, this.frame);
}

const _palettes = {
  KeepsakeLook.photo: _Palette(Color(0xFFFFFBF6), Color(0xD9FFFBF6),
      Color(0xFFF2D7A6), Color(0x47FFFBF6)),
  KeepsakeLook.paper: _Palette(Color(0xFF33202A), Color(0xFF6E5560),
      Color(0xFF9B4560), Color(0x73B4904F)),
  KeepsakeLook.night: _Palette(Color(0xFFF6EAE5), Color(0xFFC5AFB6),
      Color(0xFFE8C38A), Color(0x59E6A3B7)),
};

/// A keepsake of the day's verse, made to be passed on: the HolyHim icon and
/// wordmark at the top, the verse set large in the middle, and where to find
/// HolyHim at the foot, inside a fine frame. Rendered at 1080 wide.
class KeepsakeCard extends StatelessWidget {
  final Lesson lesson;
  final KeepsakeStyle style;
  final KeepsakeLook look;
  const KeepsakeCard(
      {super.key,
      required this.lesson,
      this.style = KeepsakeStyle.story,
      this.look = KeepsakeLook.photo});

  @override
  Widget build(BuildContext context) {
    final story = style == KeepsakeStyle.story;
    final p = _palettes[look]!;
    final long = lesson.verse.length;
    final size = story
        ? (long > 260
            ? 21.0
            : long > 180
                ? 24.0
                : long > 120
                    ? 28.0
                    : 32.0)
        : (long > 260
            ? 15.5
            : long > 180
                ? 17.5
                : long > 120
                    ? 20.0
                    : 23.0);
    final inset = story ? 12.0 : 10.0;
    return Stack(fit: StackFit.expand, children: [
      _Background(look: look, day: lesson.day),
      // A fine frame, as on a printed card.
      Positioned.fill(
          child: Padding(
              padding: EdgeInsets.all(inset),
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(story ? 22 : 18),
                      border: Border.all(color: p.frame))))),
      Padding(
          padding: story
              ? const EdgeInsets.fromLTRB(36, 48, 36, 40)
              : const EdgeInsets.fromLTRB(28, 24, 28, 20),
          child: Column(children: [
            _Brand(ink: p.ink, compact: !story),
            SizedBox(height: story ? 8 : 5),
            Text('DAY ${lesson.day} · ${lesson.theme.toUpperCase()}',
                textAlign: TextAlign.center,
                style: HolyTypography.eyebrow.copyWith(
                    color: p.muted,
                    fontSize: story ? 10.5 : 9,
                    letterSpacing: 2.2)),
            // The verse, centred in the room between the mark and the foot.
            Expanded(
                child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
              Flourish(width: story ? 44 : 34, color: p.accent),
              SizedBox(height: story ? 18 : 10),
              // Scales down rather than overflowing when shown small.
              Flexible(
                  child: LayoutBuilder(
                      builder: (context, box) => FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                              width: box.maxWidth,
                              child: Text(lesson.quotedVerse,
                                  textAlign: TextAlign.center,
                                  style: HolyTypography.verse.copyWith(
                                      fontSize: size,
                                      color: p.ink,
                                      height: 1.24,
                                      shadows: look == KeepsakeLook.photo
                                          ? const [
                                              Shadow(
                                                  color: Color(0x99000000),
                                                  blurRadius: 18)
                                            ]
                                          : null)))))),
              SizedBox(height: story ? 16 : 10),
              Text(lesson.reference,
                  textAlign: TextAlign.center,
                  style: HolyTypography.label.copyWith(
                      color: p.accent,
                      fontSize: story ? 14 : 12,
                      letterSpacing: .6,
                      fontWeight: FontWeight.w700)),
            ]))),
            Container(
                width: 36,
                height: 1,
                color: p.frame,
                margin: EdgeInsets.only(bottom: story ? 12 : 8)),
            Text('A quiet word with God, every morning',
                textAlign: TextAlign.center,
                style: HolyTypography.caption
                    .copyWith(color: p.muted, fontSize: story ? 12.5 : 10.5)),
            SizedBox(height: story ? 4 : 2),
            Text('HolyHim · on the App Store',
                textAlign: TextAlign.center,
                style: HolyTypography.label.copyWith(
                    color: p.ink,
                    fontSize: story ? 13 : 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .4)),
          ])),
    ]);
  }
}

/// The app's icon beside its wordmark: the same mark people see on the
/// Home Screen and in the App Store.
class _Brand extends StatelessWidget {
  final Color ink;
  final bool compact;
  const _Brand({required this.ink, required this.compact});
  @override
  Widget build(BuildContext context) {
    final icon = compact ? 22.0 : 28.0;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ClipRRect(
          borderRadius: BorderRadius.circular(icon * .24),
          child: Image.asset('assets/icons/first-watch.png',
              width: icon, height: icon, filterQuality: FilterQuality.high)),
      SizedBox(width: compact ? 7 : 9),
      Wordmark(size: compact ? 21 : 27, color: ink),
    ]);
  }
}

class _Background extends StatelessWidget {
  final KeepsakeLook look;
  final int day;
  const _Background({required this.look, required this.day});
  @override
  Widget build(BuildContext context) {
    switch (look) {
      case KeepsakeLook.photo:
        return Stack(fit: StackFit.expand, children: [
          Image.asset(HolyArtCatalog.assetForDay(day),
              fit: BoxFit.cover, alignment: const Alignment(0, -.2)),
          const DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [
                0,
                .3,
                .62,
                1
              ],
                      colors: [
                Color(0x99140C10),
                Color(0x33140C10),
                Color(0x99140C10),
                Color(0xE6140C10),
              ]))),
        ]);
      case KeepsakeLook.paper:
        return const DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFCF7F1), Color(0xFFF4E6DB)])),
            child: Stack(fit: StackFit.expand, children: [
              _Glow(Alignment(.9, -.85), Color(0x80F1C8C6), .9),
              _Glow(Alignment(-.95, .9), Color(0x80F5E1C0), .8),
            ]));
      case KeepsakeLook.night:
        return const DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2B1622), Color(0xFF140C12)])),
            child: Stack(fit: StackFit.expand, children: [
              _Glow(Alignment(0, -.75), Color(0x666B2D44), 1.1),
              _Stars(),
            ]));
    }
  }
}

/// A soft round light in a corner of the card.
class _Glow extends StatelessWidget {
  final Alignment at;
  final Color color;
  final double radius;
  const _Glow(this.at, this.color, this.radius);
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          gradient: RadialGradient(
              center: at,
              radius: radius,
              colors: [color, color.withValues(alpha: 0)])));
}

/// A few small stars, always in the same places.
class _Stars extends StatelessWidget {
  const _Stars();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _StarPainter());
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const spots = [
      (.12, .08, 1.3),
      (.31, .16, .9),
      (.78, .1, 1.5),
      (.9, .24, .8),
      (.06, .34, .9),
      (.94, .44, 1.1),
      (.18, .58, .7),
      (.86, .64, 1.0),
      (.1, .8, 1.2),
      (.7, .86, .8),
      (.42, .05, .7),
      (.58, .22, .9),
    ];
    for (final (x, y, r) in spots) {
      final c = Offset(x * size.width, y * size.height);
      canvas.drawCircle(
          c,
          r * 3.2,
          Paint()
            ..color = const Color(0x33FFE9F0)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawCircle(c, r, Paint()..color = const Color(0xE6FFF4F7));
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}

/// The words that travel with a shared keepsake: where it is from and where
/// to find HolyHim.
String keepsakeShareText(Lesson lesson) =>
    '${lesson.reference} 🤍 A quiet word with God, every morning, '
    'from HolyHim: ${AppConstants.shareUrl}';

/// Renders the keepsake at 1080 wide and opens the share sheet with it.
Future<void> shareVerseCard(BuildContext context, Lesson lesson,
    {KeepsakeStyle style = KeepsakeStyle.story,
    KeepsakeLook look = KeepsakeLook.photo}) async {
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
                          child: KeepsakeCard(
                              lesson: lesson, style: style, look: look)))))));
  overlay.insert(entry);
  try {
    await Future.wait([
      if (look == KeepsakeLook.photo)
        precacheImage(
            AssetImage(HolyArtCatalog.assetForDay(lesson.day)), context),
      precacheImage(const AssetImage('assets/icons/first-watch.png'), context),
    ]);
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
        text: keepsakeShareText(lesson),
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size));
  } finally {
    entry.remove();
  }
}
