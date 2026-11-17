// Raster review harness. Renders real widgets with real fonts and art to PNG
// so every screen, state and theme can be looked at before a device build.
// It does not replace verification on the iPhone.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/design/design.dart';

/// Serves files straight from the checkout so new art needs no rebuild.
class DiskBundle extends CachingAssetBundle {
  late final _manifest = const StandardMessageCodec().encodeMessage({
    for (final dir in ['assets/art', 'assets/brand'])
      for (final file
          in Directory(dir).listSync(recursive: true).whereType<File>())
        file.path: [
          {'asset': file.path, 'dpr': 1.0}
        ]
  })!;
  @override
  Future<ByteData> load(String key) {
    if (key == 'AssetManifest.bin') return SynchronousFuture(_manifest);
    final file = File(key);
    return file.existsSync()
        ? SynchronousFuture(ByteData.sublistView(file.readAsBytesSync()))
        : rootBundle.load(key);
  }
}

final diskBundle = DiskBundle();

/// Loads the app's fonts. [emoji] also loads the Mac's colour emoji font, so
/// renders meant to be seen (screens, store frames) show emoji as the phone
/// does; layout tests leave it out and keep their fixed glyph boxes.
Future<void> loadFonts({bool emoji = false}) async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(
          Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
    }
    await loader.load();
  }

  final fonts = Directory('assets/fonts')
      .listSync()
      .whereType<File>()
      .map((f) => f.path)
      .where((p) => p.endsWith('.ttf'))
      .toList();
  for (final name in ['SourceSerif4Display', 'SourceSerif4', 'Manrope']) {
    await family(name, fonts.where((p) => p.contains('/$name-')).toList());
  }
  final icons = FontLoader('packages/cupertino_icons/CupertinoIcons')
    ..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'));
  await icons.load();
  final material = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await material.load();
  const emojiFont = '/System/Library/Fonts/Apple Color Emoji.ttc';
  if (emoji && File(emojiFont).existsSync()) {
    await family('Apple Color Emoji', [emojiFont]);
  }
}

/// Phone sizes the layouts must fit, with their safe-area insets.
class Phone {
  final String id;
  final Size size;
  final EdgeInsets padding;
  const Phone(this.id, this.size, this.padding);
  static const se = Phone('se', Size(375, 667), EdgeInsets.only(top: 20));
  static const pro =
      Phone('pro', Size(393, 852), EdgeInsets.only(top: 59, bottom: 34));
  static const max =
      Phone('max', Size(430, 932), EdgeInsets.only(top: 59, bottom: 34));
  static const max17 =
      Phone('max17', Size(440, 956), EdgeInsets.only(top: 62, bottom: 34));
  // iPhone Duo (2026): the inner display is inferred from its App Store
  // screenshot size (2007 x 2853 px at 3x); the app must read sizes at runtime.
  static const duo =
      Phone('duo', Size(669, 951), EdgeInsets.only(top: 32, bottom: 20));
  static const duoOpenWide =
      Phone('duo-wide', Size(951, 669), EdgeInsets.only(top: 24, bottom: 20));
  static const duoOuter =
      Phone('duo-outer', Size(466, 678), EdgeInsets.only(top: 48, bottom: 24));
  static const all = [se, pro, max, max17, duoOuter, duo];
}

/// Pumps [child] at [phone] size inside the app theme and writes a PNG.
Future<void> capture(WidgetTester tester, String path, Widget child,
    {Phone phone = Phone.pro,
    HolyTheme theme = HolyThemes.blush,
    double textScale = 1,
    double pixelRatio = 2,
    double keyboard = 0,
    bool settle = true,
    Future<void> Function()? action,
    Widget Function(Widget app)? wrap}) async {
  debugDisableShadows = false;
  tester.view.physicalSize = phone.size * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  final key = GlobalKey();
  Widget app = MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: HolyThemeData.build(theme),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              padding: phone.padding,
              viewPadding: phone.padding,
              viewInsets: EdgeInsets.only(bottom: keyboard),
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true),
          child: HolyThemeScope(theme: theme, child: child!)),
      home: child);
  if (wrap != null) app = wrap(app);
  await tester.pumpWidget(DefaultAssetBundle(
      bundle: diskBundle, child: RepaintBoundary(key: key, child: app)));
  await tester.pump();
  if (action != null) {
    await action();
    await tester.pump();
  }
  for (var frame = 0; frame < (settle ? 4 : 1); frame++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 500));
  }
  debugDisableShadows = true;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File(path)..parent.createSync(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}
