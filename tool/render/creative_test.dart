// Sets the words on the App Store header and search results art in
// HolyHim's own fonts, lit with a gradient fill and a halo of glow and
// bloom. tool/art/store_creative.py prepares the graded art first and
// finishes the files after; run that script, not this test on its own.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'harness.dart' show loadFonts;

class _Asset {
  final String name, eyebrow;
  final Size size;

  /// Apple's art safe area for this size: nothing that matters leaves it.
  final Rect safe;
  final Offset centre;

  /// Each line as (words, italic) runs, and its type size.
  final List<List<(String, bool)>> lines;
  final List<double> sizes;
  final double eyebrowSize, rule;
  const _Asset(
      {required this.name,
      required this.eyebrow,
      required this.size,
      required this.safe,
      required this.centre,
      required this.lines,
      required this.sizes,
      required this.eyebrowSize,
      required this.rule});
}

const _assets = [
  _Asset(
      name: 'header-3840x1646',
      size: Size(3840, 1646),
      safe: Rect.fromLTWH(1097, 493, 1646, 661),
      centre: Offset(1920, 800),
      eyebrow: 'EVERY MORNING',
      lines: [
        [('Rise', false), ('with God', true)]
      ],
      sizes: [292],
      eyebrowSize: 54,
      rule: 40),
  _Asset(
      name: 'search-3840x2560',
      size: Size(3840, 2560),
      safe: Rect.fromLTWH(836, 765, 2168, 1030),
      centre: Offset(1920, 1318),
      eyebrow: 'FIVE QUIET MINUTES',
      lines: [
        [('Begin each morning', false)],
        [('with God', true)]
      ],
      sizes: [250, 362],
      eyebrowSize: 72,
      rule: 50),
];

const _upright = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFDF7),
      Color(0xFFFFF2D6),
      Color(0xFFF7D99F),
      Color(0xFFE5B467),
      Color(0xFFF4D294),
      Color(0xFFFFEBC6),
    ],
    stops: [
      0,
      .24,
      .48,
      .66,
      .82,
      1
    ]);

const _italic =
    LinearGradient(begin: Alignment(-1, -.3), end: Alignment(1, .3), colors: [
  Color(0xFFFAD9C6),
  Color(0xFFF6C79B),
  Color(0xFFFFE9BC),
  Color(0xFFEBB56C),
  Color(0xFFF7CDAB),
], stops: [
  0,
  .24,
  .48,
  .7,
  1
]);

/// The display serif. A [stroke] draws thickened letters, which give a glow
/// far more light to spread than the thin strokes of the face alone.
TextStyle _serif(double size, bool italic, Color color, {double? stroke}) =>
    TextStyle(
        fontFamily: 'CormorantGaramond',
        fontWeight: FontWeight.w600,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        fontSize: size,
        height: 1.02,
        letterSpacing: -size * .005,
        color: stroke == null ? color : null,
        foreground: stroke == null
            ? null
            : (Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = stroke
              ..strokeJoin = StrokeJoin.round
              ..color = color));

/// One line of words: a plum shade for depth, a wide bloom, a tight glow,
/// and on top the letters themselves in their gradient.
class _Line extends StatelessWidget {
  final List<(String, bool)> runs;
  final double size;
  const _Line(this.runs, this.size);

  Widget _row({Color? color, double? stroke}) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            for (final (i, (words, italic)) in runs.indexed) ...[
              // A word space between runs, set by hand.
              if (i > 0) SizedBox(width: size * .12),
              Padding(
                  // Room for the italic's overhang inside its own gradient.
                  padding: EdgeInsets.symmetric(horizontal: size * .05),
                  child: color != null
                      ? Text(words,
                          style: _serif(size, italic, color, stroke: stroke))
                      : ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bounds) =>
                              (italic ? _italic : _upright)
                                  .createShader(bounds),
                          child: Text(words,
                              style: _serif(size, italic, Colors.white)))),
            ],
          ]);

  Widget _blur(double sigma, Widget child) => ImageFiltered(
      imageFilter: ui.ImageFilter.blur(
          sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
      child: child);

  @override
  Widget build(BuildContext context) =>
      Stack(clipBehavior: Clip.none, children: [
        // A plum shadow beneath, for depth on bright cloud.
        Transform.translate(
            offset: Offset(0, size * .045),
            child: _blur(size * .06, _row(color: const Color(0xC2140510)))),
        // The halo, from wide and warm to close and bright: an aura and a
        // bloom from thickened letters, a luminous rim, then a tight glow.
        _blur(size * .30,
            _row(color: const Color(0xD9FFA65C), stroke: size * .06)),
        _blur(size * .12,
            _row(color: const Color(0xF2FFC283), stroke: size * .045)),
        _blur(size * .06,
            _row(color: const Color(0xA6FFC98A), stroke: size * .03)),
        _blur(size * .02, _row(color: const Color(0x8CFFE3B6))),
        // A fine plum edge keeps each letter crisp in front of its light.
        _blur(size * .012,
            _row(color: const Color(0x73200712), stroke: size * .012)),
        _row(),
      ]);
}

class _Star extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    Path star() {
      final p = Path()..moveTo(c.dx, c.dy - r);
      p.cubicTo(c.dx + r * .08, c.dy - r * .28, c.dx + r * .28, c.dy - r * .08,
          c.dx + r, c.dy);
      p.cubicTo(c.dx + r * .28, c.dy + r * .08, c.dx + r * .08, c.dy + r * .28,
          c.dx, c.dy + r);
      p.cubicTo(c.dx - r * .08, c.dy + r * .28, c.dx - r * .28, c.dy + r * .08,
          c.dx - r, c.dy);
      p.cubicTo(c.dx - r * .28, c.dy - r * .08, c.dx - r * .08, c.dy - r * .28,
          c.dx, c.dy - r);
      return p;
    }

    canvas.drawPath(
        star(),
        Paint()
          ..color = const Color(0xF2FFD6A0)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .55));
    canvas.drawPath(
        star(),
        Paint()
          ..shader = const RadialGradient(colors: [
            Color(0xFFFFF8E6),
            Color(0xFFF3CF8E),
            Color(0xFFD9A35C)
          ], stops: [
            0,
            .55,
            1
          ]).createShader(Rect.fromCircle(center: c, radius: r)));
  }

  @override
  bool shouldRepaint(_Star old) => false;
}

class _Rule extends StatelessWidget {
  final double size;
  const _Rule(this.size);
  @override
  Widget build(BuildContext context) {
    final line = math.max(2.0, size / 14);
    Widget stroke(List<Color> colors) => Container(
        width: size * 7,
        height: line,
        decoration: BoxDecoration(gradient: LinearGradient(colors: colors)));
    return Row(mainAxisSize: MainAxisSize.min, children: [
      stroke(const [Color(0x00F3CF8E), Color(0xF2F3CF8E)]),
      SizedBox(width: size * .55),
      CustomPaint(size: Size.square(size), painter: _Star()),
      SizedBox(width: size * .55),
      stroke(const [Color(0xF2F3CF8E), Color(0x00F3CF8E)]),
    ]);
  }
}

/// Stretches a radial gradient to fill its box as an ellipse.
class _Ellipse extends GradientTransform {
  const _Ellipse();
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final sx = bounds.width / bounds.shortestSide;
    final sy = bounds.height / bounds.shortestSide;
    final c = bounds.center;
    return Matrix4.identity()
      ..setEntry(0, 0, sx)
      ..setEntry(1, 1, sy)
      ..setEntry(0, 3, c.dx - sx * c.dx)
      ..setEntry(1, 3, c.dy - sy * c.dy);
  }
}

class _Creative extends StatelessWidget {
  final _Asset asset;
  final ui.Image art;
  const _Creative(this.asset, this.art);

  @override
  Widget build(BuildContext context) {
    final a = asset;
    final eyebrow = a.eyebrowSize, spacing = a.eyebrowSize * .44;
    final block = Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
          // Letter spacing trails the last letter; this re-centres it.
          padding: EdgeInsets.only(left: spacing),
          child: Text(a.eyebrow,
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w600,
                  fontSize: eyebrow,
                  height: 1,
                  letterSpacing: spacing,
                  color: const Color(0xFFF7DFB4),
                  shadows: [
                    Shadow(
                        color: const Color(0xA6FFCC91),
                        blurRadius: eyebrow * .5),
                    Shadow(
                        color: const Color(0xB3180510),
                        blurRadius: eyebrow * .26,
                        offset: Offset(0, eyebrow * .06)),
                  ]))),
      SizedBox(height: eyebrow * .62),
      for (var i = 0; i < a.lines.length; i++) _Line(a.lines[i], a.sizes[i]),
      SizedBox(height: a.rule * .55),
      _Rule(a.rule),
    ]);
    final box = Size(a.safe.width * .92, a.safe.height * .86);
    Widget glow(double w, double h, List<Color> colors, List<double> stops) =>
        Positioned(
            left: a.centre.dx - w / 2,
            top: a.centre.dy - h / 2,
            width: w,
            height: h,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: RadialGradient(
                        colors: colors,
                        stops: stops,
                        transform: const _Ellipse()))));
    return SizedBox.fromSize(
        size: a.size,
        child: Stack(clipBehavior: Clip.hardEdge, children: [
          Positioned.fill(child: RawImage(image: art, fit: BoxFit.cover)),
          // A warm light round the words, wider than the dark beneath them.
          glow(
              a.safe.width * 1.7,
              a.safe.height * 1.5,
              const [Color(0x38FFC98F), Color(0x1FFFB682), Color(0x00FFA078)],
              const [.3, .6, 1]),
          // A plum aura so the gold always has something deep behind it.
          glow(
              a.safe.width * 1.08,
              a.safe.height * .96,
              const [Color(0x9E12050D), Color(0x6112050D), Color(0x0012050D)],
              const [0, .5, 1]),
          Positioned(
              left: a.centre.dx - box.width / 2,
              top: a.centre.dy - box.height / 2,
              width: box.width,
              height: box.height,
              child: FittedBox(fit: BoxFit.scaleDown, child: block)),
        ]));
  }
}

void main() {
  setUpAll(() async => loadFonts());

  for (final asset in _assets) {
    testWidgets('creative ${asset.name}', (tester) async {
      final source = File('build/creative/${asset.name}-graded.png');
      expect(source.existsSync(), isTrue,
          reason: 'Run tool/art/store_creative.py');
      final art = (await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(source.readAsBytesSync());
        return (await codec.getNextFrame()).image;
      }))!;
      tester.view.physicalSize = asset.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(key: key, child: _Creative(asset, art)))));
      await tester.pump();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await File('build/creative/${asset.name}-type.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      });
      art.dispose();
    });
  }
}
