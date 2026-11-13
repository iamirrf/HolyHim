// Renders the launch wordmark so the native launch screen matches the
// first Flutter frame exactly. Writes ios/Runner/Assets.xcassets/LaunchImage.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/design/design.dart';
import 'harness.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('launch wordmark', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
            child: RepaintBoundary(
                key: key,
                // Even padding keeps the centre identical while leaving
                // room for the descender and the italic overhang.
                child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Wordmark(size: 46, color: HolyTheme.photoInk))))));
    final box = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final size = box.size;
    stdout.writeln('wordmark ${size.width} x ${size.height}');
    final dir = Directory('ios/Runner/Assets.xcassets/LaunchImage.imageset');
    for (final scale in [1, 2, 3]) {
      await tester.runAsync(() async {
        final image = await box.toImage(pixelRatio: scale.toDouble());
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        File('${dir.path}/LaunchImage${scale == 1 ? '' : '@${scale}x'}.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    File('build/render/launch-size.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('${size.width} ${size.height}');
  });
}
