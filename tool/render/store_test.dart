// App Store screenshots: eight frames in First Watch light, from blue hour to
// brass dawn, each built around a real screenshot shown the way the iPhone
// shows it (its display's continuous corners, no hardware drawn). Four real
// cards lift out of their screens; the app's own medallions float alongside.
// Few words, in HolyHim's own voice. No paywall and no price.
//
// Run: flutter test tool/render/store_test.dart && python3 tool/finish_screenshots.py
//
// Phase 1 renders each real screen (fixture data: the reader Daniel on Day 3,
// 1 Corinthians 10:13; no invented UI) and records where its cards sit.
// Phase 2 composes the frames from those renders.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/design/widgets/glass.dart';
import 'package:holyhim/design/widgets/hide_region.dart';
import 'package:holyhim/domain/onboarding_flow.dart';
import 'package:holyhim/features/celebration/celebration_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyhim/features/lesson/lesson_screen.dart';
import 'package:holyhim/features/onboarding/onboarding_screen.dart';
import 'package:holyhim/features/paywall/paywall_screen.dart';
import 'package:holyhim/features/shell/home_shell.dart';
import 'package:holyhim/services/billing.dart';
import 'package:holyhim/services/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'fixtures.dart';
import 'harness.dart';

const out = 'store/screenshots/app-store/iphone-1290x2796';
const raw = 'build/store/raw';
const slideWidth = 430.0, slideHeight = 932.0;
const screenSize = Size(393, 852);

// First Watch: navy and slate fields, bone ink, brass for the light.
const navy = Color(0xFF0E1217), bone = Color(0xFFF4EEE3);
const brass = Color(0xFFE9BF72), brassDeep = Color(0xFF8A5E22);
const _shade = Color(0xFF04070B);

// ───────────────────────── Phase 1: the real screens ─────────────────────────

/// The iPhone status bar as a screenshot shows it, at 393 x 852 points.
class StatusBar extends StatelessWidget {
  final bool light;
  const StatusBar({super.key, required this.light});
  @override
  Widget build(BuildContext context) {
    final ink = light ? Colors.black : Colors.white;
    return SizedBox(
        height: 54,
        child: Stack(children: [
          Positioned(
              left: 0,
              width: 134,
              top: 17,
              child: Text('9:41',
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                      decoration: TextDecoration.none,
                      fontFamily: 'Manrope',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: ink,
                      letterSpacing: -.2))),
          Positioned(
              right: 0,
              width: 134,
              top: 21,
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                CustomPaint(size: const Size(18, 12), painter: _Bars(ink)),
                const SizedBox(width: 6),
                Icon(CupertinoIcons.wifi, size: 17, color: ink),
                const SizedBox(width: 6),
                CustomPaint(size: const Size(27, 13), painter: _Battery(ink)),
              ])),
        ]));
  }
}

class _Bars extends CustomPainter {
  final Color ink;
  _Bars(this.ink);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = ink;
    for (var i = 0; i < 4; i++) {
      final h = size.height * (.4 + i * .2);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(i * 4.8, size.height - h, 3.2, h),
              const Radius.circular(1)),
          paint);
    }
  }

  @override
  bool shouldRepaint(_Bars old) => old.ink != ink;
}

class _Battery extends CustomPainter {
  final Color ink;
  _Battery(this.ink);
  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(0, 0, size.width - 2.5, size.height);
    canvas.drawRRect(
        RRect.fromRectAndRadius(body.deflate(.6), const Radius.circular(3.6)),
        Paint()
          ..color = ink.withValues(alpha: .4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1);
    canvas.drawRRect(
        RRect.fromRectAndRadius(body.deflate(2.2), const Radius.circular(2)),
        Paint()..color = ink);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(
                size.width - 1.6, size.height * .34, 1.6, size.height * .32),
            const Radius.circular(1)),
        Paint()..color = ink.withValues(alpha: .4));
  }

  @override
  bool shouldRepaint(_Battery old) => old.ink != ink;
}

Finder paperWith(String text) => find
    .ancestor(of: find.textContaining(text), matching: find.byType(Paper))
    .first;

Finder glassAround(String text) => find
    .ancestor(of: find.text(text).first, matching: find.byType(Glass))
    .first;

// ─────────────────────────── Phase 2: the frames ───────────────────────────

/// Draws [src] (in image pixels) of [image] to fill the widget.
class Picture extends StatelessWidget {
  final ui.Image image;
  final Rect? src;
  final BoxFit fit;
  const Picture(this.image, {super.key, this.src, this.fit = BoxFit.fill});
  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _PicturePainter(image, src, fit),
      child: const SizedBox.expand());
}

class _PicturePainter extends CustomPainter {
  final ui.Image image;
  final Rect? src;
  final BoxFit fit;
  _PicturePainter(this.image, this.src, this.fit);
  @override
  void paint(Canvas canvas, Size size) {
    final whole =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    var from = src ?? whole;
    if (fit == BoxFit.cover) {
      final fitted = applyBoxFit(BoxFit.cover, from.size, size);
      from = Alignment.center.inscribe(fitted.source, from);
    }
    canvas.drawImageRect(
        image,
        from,
        Offset.zero & size,
        Paint()
          ..filterQuality = FilterQuality.high
          ..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_PicturePainter old) => false;
}

/// A real card from the screen, lifted toward the viewer.
class Lift {
  final Rect rect; // in screen points
  final double scale, turn, rx, ry;
  final Offset shift;
  const Lift(this.rect,
      {this.scale = 1.08,
      this.turn = 0,
      this.rx = 0,
      this.ry = 0,
      this.shift = Offset.zero});
  bool get angled => rx != 0 || ry != 0;
}

/// A screenshot as the iPhone shows it: its display's continuous corners,
/// no hardware drawn around it. Any lifted cards ride on top.
class Screen extends StatelessWidget {
  final ui.Image image;

  /// The full screen the lifted cards are cut from; [image] is the same
  /// screen rendered with those cards left out, so each appears once.
  final ui.Image? source;
  final double width, turn;
  final List<Lift> lifts;
  const Screen(this.image,
      {super.key,
      required this.width,
      this.source,
      this.turn = 0,
      this.lifts = const []});

  static const corner = 55.0; // iPhone 15/16 Pro display, in points

  @override
  Widget build(BuildContext context) {
    final s = width / 393;
    final height = 852 * s;
    final radius = BorderRadius.circular(corner * s);
    return Transform.rotate(
        angle: turn,
        child: SizedBox(
            width: width,
            height: height,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                  child: DecoratedBox(
                      decoration: ShapeDecoration(
                          shape:
                              RoundedSuperellipseBorder(borderRadius: radius),
                          shadows: [
                            BoxShadow(
                                color: _shade.withValues(alpha: .55),
                                blurRadius: 60,
                                offset: const Offset(0, 30)),
                            BoxShadow(
                                color: _shade.withValues(alpha: .3),
                                blurRadius: 14,
                                offset: const Offset(0, 6)),
                          ]),
                      child: ClipRSuperellipse(
                          borderRadius: radius, child: Picture(image)))),
              // A hairline of light along the glass edge, as a lit display.
              Positioned.fill(
                  child: IgnorePointer(
                      child: DecoratedBox(
                          decoration: ShapeDecoration(
                              shape: RoundedSuperellipseBorder(
                                  borderRadius: radius,
                                  side: BorderSide(
                                      color: bone.withValues(alpha: .14),
                                      width: 1)))))),
              for (final lift in lifts)
                Positioned(
                    left: lift.rect.left * s + lift.shift.dx,
                    top: lift.rect.top * s + lift.shift.dy,
                    width: lift.rect.width * s,
                    height: lift.rect.height * s,
                    child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, .0016)
                          ..rotateX(lift.rx)
                          ..rotateY(lift.ry)
                          ..rotateZ(lift.turn)
                          ..scaleByDouble(lift.scale, lift.scale, 1, 1),
                        child: DecoratedBox(
                            decoration: ShapeDecoration(
                                shape: RoundedSuperellipseBorder(
                                    borderRadius:
                                        BorderRadius.circular(26 * s)),
                                shadows: [
                                  BoxShadow(
                                      color: _shade.withValues(alpha: .7),
                                      blurRadius: lift.angled ? 70 : 50,
                                      offset: Offset(lift.ry * -60,
                                          lift.angled ? 44 : 28)),
                                  BoxShadow(
                                      color: _shade.withValues(alpha: .35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5)),
                                ]),
                            child: ClipRSuperellipse(
                                borderRadius: BorderRadius.circular(26 * s),
                                child: Picture(source ?? image,
                                    src: Rect.fromLTRB(
                                        lift.rect.left * 3,
                                        lift.rect.top * 3,
                                        lift.rect.right * 3,
                                        lift.rect.bottom * 3)))))),
            ])));
  }
}

/// A floating medallion with its own warm light.
class Medallion extends StatelessWidget {
  final ui.Image image;
  final double size, turn;
  const Medallion(this.image, {super.key, this.size = 120, this.turn = 0});
  @override
  Widget build(BuildContext context) => SizedBox.square(
      dimension: size * 1.8,
      child: Stack(alignment: Alignment.center, children: [
        Container(
            width: size * 1.5,
            height: size * 1.5,
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
              BoxShadow(
                  color: brass.withValues(alpha: .28),
                  blurRadius: size * .5,
                  spreadRadius: -size * .2)
            ])),
        Transform.rotate(
            angle: turn,
            child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                  BoxShadow(
                      color: _shade.withValues(alpha: .55),
                      blurRadius: 28,
                      offset: const Offset(0, 16))
                ]),
                child: Picture(image))),
      ]));
}

/// The light of each frame, from the watch before dawn to full morning.
/// Frames up to [photo] are dark and carry bone words; the last two are
/// lit and carry navy words.
enum Light { blueHour, slate, iron, ember, night, photo, stone, brass }

/// Each frame's own sky.
class Backdrop extends CustomPainter {
  final Light light;
  final ui.Image? art;
  Backdrop(this.light, {this.art});

  void _glow(Canvas canvas, Offset at, double radius, Color color) =>
      canvas.drawCircle(
          at,
          radius,
          Paint()
            ..shader =
                RadialGradient(colors: [color, color.withValues(alpha: 0)])
                    .createShader(Rect.fromCircle(center: at, radius: radius)));

  void _fill(Canvas canvas, Rect r, List<Color> colors,
          [List<double>? stops]) =>
      canvas.drawRect(
          r,
          Paint()
            ..shader = LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: colors,
                    stops: stops)
                .createShader(r));

  void _stars(Canvas canvas, Size size, int count, double reach) {
    final random = math.Random(7);
    for (var i = 0; i < count; i++) {
      final y = random.nextDouble() * size.height * reach;
      canvas.drawCircle(
          Offset(random.nextDouble() * size.width, y),
          random.nextDouble() * 1.1 + .35,
          Paint()
            ..color = bone.withValues(
                alpha: (random.nextDouble() * .7 + .2) *
                    (1 - y / (size.height * reach))));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final w = size.width, h = size.height;
    switch (light) {
      case Light.blueHour:
        // Navy overhead, the first brass light breaking at the horizon.
        _fill(canvas, r, const [
          Color(0xFF070B11),
          Color(0xFF101A28),
          Color(0xFF263A55),
          Color(0xFF6B5A44),
        ], const [
          0,
          .38,
          .72,
          1
        ]);
        _stars(canvas, size, 70, .3);
        _glow(canvas, Offset(w * .5, h * 1.04), w * 1.15,
            const Color(0xFFF2C27A).withValues(alpha: .62));
        _glow(canvas, Offset(w * .5, h * 1.0), w * .42,
            const Color(0xFFFFE6BC).withValues(alpha: .7));
      case Light.slate:
        _fill(
            canvas,
            r,
            const [Color(0xFF0B1016), Color(0xFF1A2430), Color(0xFF3A4757)],
            const [0, .5, 1]);
        _glow(canvas, Offset(w * .85, h * .12), w * .9,
            const Color(0xFFB8C7D9).withValues(alpha: .2));
        _glow(canvas, Offset(w * .1, h * .95), w * .9,
            const Color(0xFFE2B66A).withValues(alpha: .22));
      case Light.iron:
        _fill(
            canvas,
            r,
            const [Color(0xFF0C0D0F), Color(0xFF191B1E), Color(0xFF34383E)],
            const [0, .55, 1]);
        _glow(canvas, Offset(w * .5, h * .02), w * .95,
            const Color(0xFFCDD2D8).withValues(alpha: .18));
        _glow(canvas, Offset(w * .9, h * .9), w * .7,
            const Color(0xFFE8924D).withValues(alpha: .16));
      case Light.ember:
        // A low fire: deep brown, copper, the sun coming up warm.
        _fill(canvas, r, const [
          Color(0xFF0F0A08),
          Color(0xFF2A170E),
          Color(0xFF6A361C),
          Color(0xFFD98B4A)
        ], const [
          0,
          .36,
          .72,
          1
        ]);
        _glow(canvas, Offset(w * .5, h * .8), w * 1.1,
            const Color(0xFFF2C27A).withValues(alpha: .5));
        _glow(canvas, Offset(w * .5, h * .8), w * .34,
            const Color(0xFFFFE8C2).withValues(alpha: .6));
      case Light.night:
        _fill(
            canvas,
            r,
            const [Color(0xFF05080D), Color(0xFF0C1420), Color(0xFF1B2B40)],
            const [0, .55, 1]);
        _stars(canvas, size, 120, .55);
        _glow(canvas, Offset(w * .5, h * 1.05), w * 1.05,
            const Color(0xFFE2B66A).withValues(alpha: .4));
      case Light.photo:
        _PicturePainter(art!, null, BoxFit.cover).paint(canvas, size);
        _fill(canvas, r, [
          const Color(0xFF070B11).withValues(alpha: .86),
          const Color(0xFF070B11).withValues(alpha: .3),
          const Color(0xFF070B11).withValues(alpha: .05),
          const Color(0xFF070B11).withValues(alpha: .45),
        ], const [
          0,
          .3,
          .6,
          1
        ]);
      case Light.stone:
        // Limestone in morning light.
        _fill(
            canvas,
            r,
            const [Color(0xFFF1EBE0), Color(0xFFE4DACA), Color(0xFFCBBDA4)],
            const [0, .55, 1]);
        _glow(canvas, Offset(w * .5, h * .22), w * .95,
            const Color(0xFFFFFFFF).withValues(alpha: .55));
        _glow(canvas, Offset(w * .9, h * .95), w * .8,
            const Color(0xFFD8A657).withValues(alpha: .25));
      case Light.brass:
        _fill(
            canvas,
            r,
            const [Color(0xFFF8EEDB), Color(0xFFEFD8AC), Color(0xFFD9AB5E)],
            const [0, .55, 1]);
        _glow(canvas, Offset(w * .5, h * .5), w * 1.0,
            const Color(0xFFFFF1D6).withValues(alpha: .55));
    }
  }

  @override
  bool shouldRepaint(Backdrop old) => false;
}

/// Two short lines; words between asterisks set in italic brass.
class Headline extends StatelessWidget {
  final String text;
  final bool dark;
  final String? detail;
  const Headline(this.text, {super.key, required this.dark, this.detail});
  @override
  Widget build(BuildContext context) {
    final ink = dark ? bone : navy;
    final parts = text.split('*');
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text.rich(
          TextSpan(children: [
            for (var i = 0; i < parts.length; i++)
              TextSpan(
                  text: parts[i],
                  style: i.isOdd
                      ? TextStyle(
                          color: dark ? brass : brassDeep,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w700)
                      : null)
          ]),
          textAlign: TextAlign.center,
          style: HolyTypography.display.copyWith(
              color: ink,
              fontSize: 58,
              fontWeight: FontWeight.w700,
              height: .98,
              letterSpacing: -1.2,
              shadows: dark
                  ? const [Shadow(color: Color(0x99000000), blurRadius: 26)]
                  : null)),
      if (detail != null) ...[
        const SizedBox(height: 14),
        Text(detail!,
            textAlign: TextAlign.center,
            style: HolyTypography.ui.copyWith(
                color: ink.withValues(alpha: .82),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: .3)),
      ],
    ]);
  }
}

/// One App Store frame.
class Frame extends StatelessWidget {
  final Light light;
  final ui.Image? art;
  final String headline;
  final String? detail;
  final bool wordsBelow;
  final List<Widget> children;
  const Frame(
      {super.key,
      required this.light,
      required this.headline,
      this.art,
      this.detail,
      this.wordsBelow = false,
      required this.children});

  bool get dark => light.index <= Light.photo.index;

  @override
  Widget build(BuildContext context) => Material(
      type: MaterialType.transparency,
      child: SizedBox(
          width: slideWidth,
          height: slideHeight,
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            Positioned.fill(
                child: CustomPaint(painter: Backdrop(light, art: art))),
            ...children,
            Positioned(
                left: 16,
                right: 16,
                top: wordsBelow ? null : 70,
                bottom: wordsBelow ? 64 : null,
                child: Headline(headline, dark: dark, detail: detail)),
          ])));
}

Widget at(double left, double top, Widget child) =>
    Positioned(left: left, top: top, child: child);

Widget medallion(Map<String, ui.Image> images, String id, double x, double y,
        {double size = 110, double turn = 0}) =>
    Positioned(
        left: x - size * .9,
        top: y - size * .9,
        child: Medallion(images[id]!, size: size, turn: turn));

List<Frame> frames(Map<String, ui.Image> images, Map<String, Rect> rects) => [
      // Blue hour at the first frame, brass morning at the last.
      Frame(
          light: Light.blueHour,
          headline: 'Stand on\n*the Word*',
          detail: 'The daily Bible devotional for men',
          children: [
            at(
                31,
                262,
                Screen(images['walk-base']!,
                    source: images['walk'],
                    width: 368,
                    lifts: [
                      Lift(rects['walk']!,
                          scale: 1.08,
                          rx: .12,
                          ry: -.34,
                          shift: const Offset(-8, 8)),
                    ])),
          ]),
      Frame(
          light: Light.slate,
          headline: 'The Bible,\n*word for word*',
          children: [
            at(
                22,
                240,
                Screen(images['verse-base']!,
                    source: images['verse'],
                    width: 360,
                    lifts: [
                      Lift(rects['verse']!,
                          scale: 1.06,
                          rx: .1,
                          ry: .34,
                          shift: const Offset(16, 12)),
                    ])),
          ]),
      Frame(
          light: Light.iron,
          headline: 'Plain words\n*for hard days*',
          children: [
            at(31, 244, Screen(images['life']!, width: 368, turn: .035)),
          ]),
      Frame(
          light: Light.ember,
          headline: 'One morning\n*at a time*',
          children: [
            at(31, 248, Screen(images['amen']!, width: 368)),
            medallion(images, 'days-003', 352, 560, size: 140, turn: .14),
          ]),
      Frame(
          light: Light.night,
          headline: 'The first word\n*of your day*',
          wordsBelow: true,
          children: [
            at(
                31,
                -110,
                Screen(images['reminder-base']!,
                    source: images['reminder'],
                    width: 368,
                    lifts: [
                      Lift(rects['reminder']!,
                          scale: 1.14,
                          rx: .2,
                          ry: -.3,
                          shift: const Offset(-6, 18)),
                    ])),
          ]),
      Frame(
          light: Light.photo,
          art: images['ridge'],
          headline: 'One road.\n*365 mornings.*',
          children: [
            at(33, 246, Screen(images['road']!, width: 364, turn: -.035)),
            medallion(images, 'promise-kept', 372, 452, size: 108, turn: .2),
          ]),
      Frame(
          light: Light.stone,
          headline: 'Iron sharpens\n*iron*',
          children: [
            at(
                35,
                254,
                Screen(images['ranks-base']!,
                    source: images['ranks'],
                    width: 360,
                    lifts: [
                      Lift(rects['ranks']!,
                          scale: 1.08,
                          rx: .16,
                          ry: .34,
                          shift: const Offset(18, 0)),
                    ])),
          ]),
      Frame(
          light: Light.brass,
          headline: 'Earn every\n*medallion*',
          children: [
            at(35, 254, Screen(images['growth']!, width: 360)),
            medallion(images, 'days-365', 372, 286, size: 112, turn: .14),
            medallion(images, 'days-100', 50, 700, size: 100, turn: -.18),
          ]),
    ];

// ─────────────────────────────── The tests ───────────────────────────────

void main() {
  setUpAll(() async {
    tzdata.initializeTimeZones();
    await loadFonts(emoji: true);
    HolySounds.player = (String _, {double gain = 1}) async {};
    OnboardingScreen.resumeToast = false;
  });

  testWidgets('phase 1: the real screens', (tester) async {
    final zone = tz.getLocation('America/New_York');
    final today = tz.TZDateTime.now(zone);
    final morning =
        tz.TZDateTime(zone, today.year, today.month, today.day, 7, 10);
    AppProfile daniel(
            {bool onboarded = true, Map<String, dynamic> draft = const {}}) =>
        profile(
            name: 'Daniel',
            hearts: const ['strength', 'courage'],
            onboarded: onboarded,
            draft: draft);
    final reader = WalkState(profile: daniel(), completed: history(2));
    final kept = WalkState(
        profile: daniel(),
        completed: history(12),
        saved: {3: DateTime(2026, 11, 5), 6: DateTime(2026, 11, 8)});
    final rects = <String, List<double>>{};

    Future<void> screen(String id, Widget page,
        {WalkState? walk,
        AccessState? billing,
        bool light = false,
        Future<void> Function()? action,
        List<Override> overrides = const [],
        Finder Function()? card}) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues({});
      await capture(tester, '$raw/$id.png',
          Stack(children: [page, StatusBar(light: light)]),
          phone: Phone.pro, pixelRatio: 3, action: action, wrap: (app) {
        final scoped = scope(app,
            lastSignIn: null,
            walk: walk ?? reader,
            community: true,
            billing: billing ?? memberState);
        return overrides.isEmpty
            ? scoped
            : ProviderScope(overrides: overrides, child: scoped);
      });
      Rect? hidden;
      if (card != null) {
        hidden = tester.getRect(card());
        rects[id] = [hidden.left, hidden.top, hidden.right, hidden.bottom];
      }
      expect(tester.takeException(), isNull, reason: id);
      await tester.pumpWidget(const SizedBox());
      if (hidden != null) {
        // The same screen with the lifted card left out.
        SharedPreferences.setMockInitialValues({});
        await capture(tester, '$raw/$id-base.png',
            Stack(children: [page, StatusBar(light: light)]),
            phone: Phone.pro, pixelRatio: 3, action: action, wrap: (app) {
          final scoped = scope(app,
              lastSignIn: null,
              walk: walk ?? reader,
              community: true,
              billing: billing ?? memberState);
          return HideRegion(
              rect: hidden!,
              child: overrides.isEmpty
                  ? scoped
                  : ProviderScope(overrides: overrides, child: scoped));
        });
        expect(tester.takeException(), isNull, reason: '$id-base');
        await tester.pumpWidget(const SizedBox());
      }
      debugDefaultTargetPlatformOverride = null;
    }

    Future<void> Function() cards(int count) => () async {
          for (var i = 0; i < count; i++) {
            await tester.tap(find.byTooltip('Next card'));
            await tester.pump(const Duration(milliseconds: 600));
          }
        };

    await screen('walk', HomeShell(now: morning),
        card: () => find
            .byWidgetPredicate((w) => w.runtimeType.toString() == 'TodayCard')
            .first);
    await screen('verse', const LessonScreen(day: 3),
        card: () => paperWith('No temptation has taken you'));
    await screen('life', const LessonScreen(day: 3), action: cards(2));
    await screen('amen', const CelebrationScreen(day: 3),
        walk: WalkState(
            profile: daniel(), completed: history(2, today: true)));
    await screen('reminder', const OnboardingScreen(),
        // Let his answer finish arriving before the picture is taken.
        action: () => tester.pump(const Duration(seconds: 3)),
        walk: WalkState(
            profile: daniel(onboarded: false, draft: {
          'flowVersion': onboardingFlowVersion,
          'stepId': 'reminder',
          'lifeSeason': 'full',
          'familiarity': 'returning',
          'obstacle': 'busy',
          // His answer given, so the frame ends on a lit button.
          'reminder': '07:00',
        })),
        card: () => find
            .byWidgetPredicate((w) => w.runtimeType.toString() == 'NotePreview')
            .first);
    await screen('road', HomeShell(now: morning), walk: kept,
        action: () async {
      await tester.drag(
          find.byType(CustomScrollView).first, const Offset(0, -900));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Back to today'));
      await tester.pump(const Duration(milliseconds: 1200));
      // A little higher, so the walked road shows above today's stop.
      await tester.drag(
          find.byType(CustomScrollView).first, const Offset(0, 160));
      await tester.pump(const Duration(milliseconds: 400));
    });
    await screen('ranks', HomeShell(initialTab: 2, now: morning),
        walk: kept, card: () => glassAround('Daniel (you)'));
    await screen('growth', HomeShell(initialTab: 3, now: morning),
        walk: WalkState(
            profile: daniel(),
            completed: history(30),
            saved: {1: DateTime(2026, 11, 3), 3: DateTime(2026, 11, 5)}),
        action: () async {
      await tester.drag(
          find.byType(CustomScrollView).first, const Offset(0, -700));
      await tester.pump(const Duration(milliseconds: 400));
    });
    File('$raw/rects.json').writeAsStringSync(jsonEncode(rects));

    // For App Review of the subscription only, never a store screenshot.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await capture(tester, '$out/iap-review-offer.png',
        OfferScreen(locked: true, onContinue: () {}),
        phone: Phone.max,
        pixelRatio: 3,
        wrap: (app) => scope(app,
            walk: WalkState(profile: daniel(), completed: history(0))));
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull, reason: 'offer');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('phase 2: the frames', (tester) async {
    final rects = {
      for (final e in (jsonDecode(File('$raw/rects.json').readAsStringSync())
              as Map<String, dynamic>)
          .entries)
        e.key: Rect.fromLTRB(
            (e.value[0] as num).toDouble(),
            (e.value[1] as num).toDouble(),
            (e.value[2] as num).toDouble(),
            (e.value[3] as num).toDouble())
    };
    final files = {
      for (final id in [
        'walk',
        'verse',
        'life',
        'amen',
        'reminder',
        'road',
        'ranks',
        'growth'
      ])
        id: '$raw/$id.png',
      for (final id in ['walk', 'verse', 'reminder', 'ranks'])
        '$id-base': '$raw/$id-base.png',
      for (final badge in [
        'days-003',
        'days-100',
        'days-365',
        'promise-kept'
      ])
        badge: 'assets/art/badges/$badge.png',
      'ridge': 'assets/art/chapters/unit-01/portrait.webp',
    };
    final images = <String, ui.Image>{};
    await tester.runAsync(() async {
      for (final entry in files.entries) {
        final codec =
            await ui.instantiateImageCodec(File(entry.value).readAsBytesSync());
        images[entry.key] = (await codec.getNextFrame()).image;
      }
    });
    const names = [
      '01-stand-on-the-word',
      '02-word-for-word',
      '03-hard-days',
      '04-one-morning',
      '05-first-word',
      '06-one-road',
      '07-iron',
      '08-medallions'
    ];
    final all = frames(images, rects);
    for (var i = 0; i < all.length; i++) {
      await capture(tester, '$out/${names[i]}.png', all[i],
          phone: const Phone(
              'frame', Size(slideWidth, slideHeight), EdgeInsets.zero),
          pixelRatio: 3);
      expect(tester.takeException(), isNull, reason: names[i]);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
