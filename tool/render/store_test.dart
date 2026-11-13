// App Store screenshots: seven frames, each with its own light, each built
// around a real screenshot shown the way the iPhone shows it (its display's
// continuous corners, no hardware drawn). Real cards lift out of the screens;
// the app's own medallions float alongside. Few words, written to move.
// No paywall.
//
// Run: flutter test tool/render/store_test.dart && python3 tool/finish_screenshots.py
//
// Phase 1 renders each real screen (fixture data, no invented UI) and records
// where its cards sit. Phase 2 composes the frames from those renders.
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
import 'package:holyhim/domain/onboarding_flow.dart';
import 'package:holyhim/features/celebration/celebration_screen.dart';
import 'package:holyhim/features/journey/journey_screen.dart';
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
const plum = Color(0xFF33202A), cream = Color(0xFFFFF7EF);
const gold = Color(0xFFF3C98B), rose = Color(0xFF9B4560);

// ───────────────────────── Phase 1: the real screens ─────────────────────────

/// The iPhone status bar as a screenshot shows it, at 393 x 852 points.
class StatusBar extends StatelessWidget {
  final bool light;
  const StatusBar({super.key, required this.light});
  @override
  Widget build(BuildContext context) {
    final ink = light ? Colors.white : Colors.black;
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
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
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
  final double scale, turn;
  final Offset shift;
  const Lift(this.rect,
      {this.scale = 1.08, this.turn = 0, this.shift = Offset.zero});
}

/// A screenshot as the iPhone shows it: its display's continuous corners,
/// no hardware drawn around it. Any lifted cards ride on top.
class Screen extends StatelessWidget {
  final ui.Image image;
  final double width, turn;
  final List<Lift> lifts;
  const Screen(this.image,
      {super.key, required this.width, this.turn = 0, this.lifts = const []});

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
                          shape: RoundedSuperellipseBorder(borderRadius: radius),
                          shadows: const [
                            BoxShadow(
                                color: Color(0x4D1A0A10),
                                blurRadius: 60,
                                offset: Offset(0, 30)),
                            BoxShadow(
                                color: Color(0x261A0A10),
                                blurRadius: 14,
                                offset: Offset(0, 6)),
                          ]),
                      child: ClipRSuperellipse(
                          borderRadius: radius, child: Picture(image)))),
              for (final lift in lifts)
                Positioned(
                    left: lift.rect.left * s + lift.shift.dx,
                    top: lift.rect.top * s + lift.shift.dy,
                    width: lift.rect.width * s,
                    height: lift.rect.height * s,
                    child: Transform.rotate(
                        angle: lift.turn,
                        child: Transform.scale(
                            scale: lift.scale,
                            child: DecoratedBox(
                                decoration: ShapeDecoration(
                                    shape: RoundedSuperellipseBorder(
                                        borderRadius:
                                            BorderRadius.circular(30 * s)),
                                    shadows: const [
                                      BoxShadow(
                                          color: Color(0x591A0A10),
                                          blurRadius: 50,
                                          offset: Offset(0, 28)),
                                      BoxShadow(
                                          color: Color(0x261A0A10),
                                          blurRadius: 10,
                                          offset: Offset(0, 5)),
                                    ]),
                                child: ClipRSuperellipse(
                                    borderRadius: BorderRadius.circular(30 * s),
                                    child: Picture(image,
                                        src: Rect.fromLTRB(
                                            lift.rect.left * 3,
                                            lift.rect.top * 3,
                                            lift.rect.right * 3,
                                            lift.rect.bottom * 3))))))),
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
        DecoratedBox(
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
              const Color(0xFFFFE2B0).withValues(alpha: .5),
              const Color(0xFFFFE2B0).withValues(alpha: 0),
            ])),
            child: const SizedBox.expand()),
        Transform.rotate(
            angle: turn,
            child: Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Color(0x553A1E10),
                          blurRadius: 28,
                          offset: Offset(0, 16))
                    ]),
                child: Picture(image))),
      ]));
}

enum Light { night, mulberry, photo, sunrise, blush, olive, gold }

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
            ..shader = RadialGradient(
                    colors: [color, color.withValues(alpha: 0)])
                .createShader(Rect.fromCircle(center: at, radius: radius)));

  void _fill(Canvas canvas, Rect r, List<Color> colors, [List<double>? stops]) =>
      canvas.drawRect(
          r,
          Paint()
            ..shader = LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: colors,
                    stops: stops)
                .createShader(r));

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final w = size.width, h = size.height;
    switch (light) {
      case Light.night:
        _fill(canvas, r, const [Color(0xFF120A10), Color(0xFF2A1420), Color(0xFF5A2A3C)],
            const [0, .55, 1]);
        final random = math.Random(5);
        for (var i = 0; i < 110; i++) {
          final y = random.nextDouble() * h * .5;
          canvas.drawCircle(
              Offset(random.nextDouble() * w, y),
              random.nextDouble() * 1.1 + .35,
              Paint()
                ..color = cream.withValues(
                    alpha: (random.nextDouble() * .7 + .2) * (1 - y / (h * .5))));
        }
        _glow(canvas, Offset(w * .5, h * 1.02), w * 1.05,
            const Color(0xFFD98A7A).withValues(alpha: .55));
      case Light.mulberry:
        _fill(canvas, r, const [Color(0xFF2B1220), Color(0xFF5E2840), Color(0xFF94485D)],
            const [0, .5, 1]);
        _glow(canvas, Offset(w * .78, h * .18), w * .9,
            const Color(0xFFF3C98B).withValues(alpha: .22));
      case Light.photo:
        _PicturePainter(art!, null, BoxFit.cover).paint(canvas, size);
        _fill(canvas, r, [
          const Color(0xFF1A0D14).withValues(alpha: .82),
          const Color(0xFF1A0D14).withValues(alpha: .25),
          const Color(0xFF1A0D14).withValues(alpha: .05),
          const Color(0xFF1A0D14).withValues(alpha: .4),
        ], const [0, .3, .6, 1]);
      case Light.sunrise:
        _fill(canvas, r, const [Color(0xFF5E2C3E), Color(0xFFB45F62), Color(0xFFF0A97F), Color(0xFFF8D2AE)],
            const [0, .35, .7, 1]);
        _glow(canvas, Offset(w * .5, h * .74), w * 1.1,
            const Color(0xFFFFE3B5).withValues(alpha: .7));
        _glow(canvas, Offset(w * .5, h * .74), w * .35,
            const Color(0xFFFFF6E4).withValues(alpha: .8));
      case Light.blush:
        _fill(canvas, r, const [Color(0xFFF2CFC4), Color(0xFFF8E2D6), Color(0xFFE9B9AC)],
            const [0, .55, 1]);
        _glow(canvas, Offset(w * .5, h * .28), w * .95,
            const Color(0xFFFFFFFF).withValues(alpha: .55));
      case Light.olive:
        _fill(canvas, r, const [Color(0xFFF7F0E4), Color(0xFFEDE3D0), Color(0xFFDCD3B6)],
            const [0, .6, 1]);
        _glow(canvas, Offset(w * .1, h * .9), w * .9,
            const Color(0xFFA6B07E).withValues(alpha: .35));
        _glow(canvas, Offset(w * .9, h * .15), w * .7,
            const Color(0xFFFFE6BE).withValues(alpha: .5));
      case Light.gold:
        _fill(canvas, r, const [Color(0xFFFCF4EA), Color(0xFFF6E6CF), Color(0xFFEFD2AE)],
            const [0, .55, 1]);
        _glow(canvas, Offset(w * .5, h * .5), w * 1.0,
            const Color(0xFFFFE2A8).withValues(alpha: .45));
    }
  }

  @override
  bool shouldRepaint(Backdrop old) => false;
}

/// Two short lines; words between asterisks set in italic accent.
class Headline extends StatelessWidget {
  final String text;
  final bool dark;
  final String? detail;
  const Headline(this.text, {super.key, required this.dark, this.detail});
  @override
  Widget build(BuildContext context) {
    final ink = dark ? cream : plum;
    final parts = text.split('*');
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text.rich(
          TextSpan(children: [
            for (var i = 0; i < parts.length; i++)
              TextSpan(
                  text: parts[i],
                  style: i.isOdd
                      ? TextStyle(
                          color: dark ? gold : rose,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600)
                      : null)
          ]),
          textAlign: TextAlign.center,
          style: HolyTypography.display.copyWith(
              color: ink,
              fontSize: 50,
              height: 1.02,
              letterSpacing: -.6,
              shadows: dark
                  ? const [Shadow(color: Color(0x80000000), blurRadius: 26)]
                  : null)),
      if (detail != null) ...[
        const SizedBox(height: 14),
        Text(detail!,
            textAlign: TextAlign.center,
            style: HolyTypography.ui.copyWith(
                color: ink.withValues(alpha: .8),
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

  bool get dark => light.index <= Light.sunrise.index;

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
      Frame(
          light: Light.night,
          headline: 'Feel God’s love\n*every morning*',
          detail: 'A daily Bible devotional for women',
          children: [
            at(31, 262, Screen(images['today']!, width: 368, lifts: [
              Lift(rects['today']!, scale: 1.07, shift: const Offset(-8, 0)),
            ])),
          ]),
      Frame(
          light: Light.mulberry,
          headline: 'His promises,\n*spoken over you*',
          children: [
            at(22, 236, Screen(images['verse']!, width: 366, turn: -.04, lifts: [
              Lift(rects['verse']!,
                  scale: 1.1, turn: .06, shift: const Offset(18, 14)),
            ])),
          ]),
      Frame(
          light: Light.photo,
          art: images['seaside'],
          headline: 'On hard days,\n*you’re not alone*',
          children: [
            at(31, 244, Screen(images['heart']!, width: 368, turn: .04)),
          ]),
      Frame(
          light: Light.sunrise,
          headline: 'Say Amen.\n*Walk in peace.*',
          children: [
            at(31, 248, Screen(images['amen']!, width: 368)),
            medallion(images, 'days-003', 352, 560, size: 140, turn: .14),
          ]),
      Frame(
          light: Light.blush,
          headline: 'Good morning,\n*beloved*',
          wordsBelow: true,
          children: [
            at(31, -110, Screen(images['reminder']!, width: 368, lifts: [
              Lift(rects['reminder']!, scale: 1.16, shift: const Offset(0, 6)),
            ])),
          ]),
      Frame(
          light: Light.olive,
          headline: '365 days\n*closer to Him*',
          children: [
            at(33, 246, Screen(images['journey']!, width: 364, turn: -.035)),
            medallion(images, 'promise-kept', 372, 452, size: 108, turn: .2),
          ]),
      Frame(
          light: Light.gold,
          headline: 'Watch your faith\n*blossom*',
          children: [
            at(35, 254, Screen(images['growth']!, width: 360)),
            medallion(images, 'days-365', 372, 286, size: 112, turn: .14),
            medallion(images, 'days-100', 50, 700, size: 100, turn: -.18),
            medallion(images, 'first-saved', 384, 610, size: 82, turn: .22),
          ]),
    ];

// ─────────────────────────────── The tests ───────────────────────────────

void main() {
  setUpAll(() async {
    tzdata.initializeTimeZones();
    await loadFonts();
    HolySounds.player = (String _, {double gain = 1}) async {};
  });

  testWidgets('phase 1: the real screens', (tester) async {
    final zone = tz.getLocation('America/New_York');
    final today = tz.TZDateTime.now(zone);
    final morning =
        tz.TZDateTime(zone, today.year, today.month, today.day, 7, 10);
    final reader =
        WalkState(profile: profile(name: 'Grace'), completed: history(2));
    final rects = <String, List<double>>{};

    Future<void> screen(String id, Widget page,
        {WalkState? walk,
        LifetimeState? billing,
        bool light = true,
        Future<void> Function()? action,
        Finder Function()? card}) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues({});
      await capture(tester, '$raw/$id.png',
          Stack(children: [page, StatusBar(light: light)]),
          phone: Phone.pro,
          pixelRatio: 3,
          action: action,
          wrap: (app) => scope(app,
              lastSignIn: null,
              walk: walk ?? reader,
              billing: billing ??
                  const LifetimeState(loading: false, product: product)));
      if (card != null) {
        final r = tester.getRect(card());
        rects[id] = [r.left, r.top, r.right, r.bottom];
      }
      debugDefaultTargetPlatformOverride = null;
      expect(tester.takeException(), isNull, reason: id);
      await tester.pumpWidget(const SizedBox());
    }

    Future<void> Function() cards(int count) => () async {
          for (var i = 0; i < count; i++) {
            await tester.tap(find.text('${i + 1} of 4').first);
            await tester.pump(const Duration(milliseconds: 600));
          }
          expect(find.text('${count + 1} of 4'), findsWidgets);
        };

    await screen('today', HomeShell(now: morning),
        light: false, card: () => paperWith('A Place to Bring Trouble'));
    await screen('verse', const LessonScreen(day: 3),
        card: () => paperWith('God is our refuge'));
    await screen('heart', const LessonScreen(day: 3), action: cards(2));
    await screen('prayer', const LessonScreen(day: 3), action: cards(3));
    await screen('amen', const CelebrationScreen(day: 3),
        walk: WalkState(
            profile: profile(name: 'Grace'),
            completed: history(2, today: true)));
    await screen('reminder', const OnboardingScreen(),
        walk: WalkState(
            profile: profile(name: 'Grace', onboarded: false, draft: {
          'flowVersion': onboardingFlowVersion,
          'stepId': 'reminder',
          'lifeSeason': 'full',
          'familiarity': 'returning',
          'obstacle': 'busy',
        })),
        card: () => find
            .byWidgetPredicate(
                (w) => w.runtimeType.toString() == '_NotificationPreview')
            .first);
    await screen('journey', const JourneyScreen());
    await screen('growth', HomeShell(initialTab: 2, now: morning),
        light: false,
        walk: WalkState(
            profile: profile(name: 'Grace'),
            completed: history(30),
            saved: {1: DateTime(2026, 11, 3), 3: DateTime(2026, 11, 5)}),
        billing: const LifetimeState(loading: false, purchased: true));
    File('$raw/rects.json').writeAsStringSync(jsonEncode(rects));

    // For App Review of the purchase only, never a store screenshot.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await capture(tester, '$out/iap-review-offer.png',
        OfferScreen(lockedDay: 8, onContinue: () {}),
        phone: Phone.max, pixelRatio: 3, wrap: (app) => scope(app, walk: reader));
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
        'today',
        'verse',
        'heart',
        'prayer',
        'amen',
        'reminder',
        'journey',
        'growth'
      ])
        id: '$raw/$id.png',
      for (final badge in [
        'days-003',
        'days-007',
        'days-100',
        'days-365',
        'first-saved',
        'promise-kept'
      ])
        badge: 'assets/art/badges/$badge.png',
      'seaside': 'assets/art/library/jesus-seaside.webp',
    };
    final images = <String, ui.Image>{};
    await tester.runAsync(() async {
      for (final entry in files.entries) {
        final codec = await ui
            .instantiateImageCodec(File(entry.value).readAsBytesSync());
        images[entry.key] = (await codec.getNextFrame()).image;
      }
    });
    const names = [
      '01-love', '02-promises', '03-hard-days', '04-amen', '05-morning',
      '06-closer', '07-blossom'
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
