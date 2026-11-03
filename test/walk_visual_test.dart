import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/dev/preview_fixtures.dart';
import 'package:holyher/features/settings/theme_screen.dart';
import 'package:holyher/features/home/badges_screen.dart';

void main() {
  setUpAll(() async {
    for (final entry in [
      ('Manrope', 'assets/fonts/Manrope[wght].ttf'),
      ('SourceSerif4', 'assets/fonts/SourceSerif4[opsz,wght].ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf')
    ]) {
      await (FontLoader(entry.$1)..addFont(rootBundle.load(entry.$2))).load();
    }
  });
  testWidgets(
      'capture real HolyHer widgets across six themes and adaptive surfaces',
      (tester) async {
    final key = GlobalKey();
    final manifest = <Map<String, Object>>[];
    Future<void> capture(String route, String name,
        {String theme = 'pearl',
        Size size = const Size(390, 844),
        double scale = 1,
        Widget? screen,
        bool complete = false}) async {
      await tester.pumpWidget(const SizedBox());
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final fixture = PreviewFixture(route, theme: theme);
      await tester.pumpWidget(ProviderScope(
          key: UniqueKey(),
          overrides: fixture.overrides,
          child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                  theme: buildAppTheme(theme: theme),
                  debugShowCheckedModeBanner: false,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          disableAnimations: true,
                          padding: const EdgeInsets.only(top: 30, bottom: 20),
                          textScaler: TextScaler.linear(scale)),
                      child: BlushBackdrop(child: child!)),
                  home: screen ?? fixture.build()))));
      await tester.runAsync(() => precacheImage(
          const AssetImage('assets/brand/holyher-mark.png'),
          key.currentContext!));
      await tester.pumpAndSettle();
      if (complete) {
        await tester.tap(find.text('Finish my reading'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull,
          reason: '$route $theme $size $scale');
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final path = 'store/walk-redesign/$name.png';
        await File(path).parent.create(recursive: true);
        await File(path).writeAsBytes(bytes!.buffer.asUint8List());
        if (name == 'pearl-walk') {
          await File('public/images/walk-screen.png')
              .writeAsBytes(bytes.buffer.asUint8List());
        }
        if (name == 'pearl-scripture') {
          await File('public/images/reader-screen.png')
              .writeAsBytes(bytes.buffer.asUint8List());
        }
        image.dispose();
        manifest.add({
          'file': path,
          'route': route,
          'theme': theme,
          'width': size.width,
          'height': size.height,
          'textScale': scale,
          'source': 'actual Flutter widgets with isolated local QA fixtures'
        });
      });
    }

    for (final palette in HolyPalette.all) {
      await capture('learn', '${palette.id}-walk', theme: palette.id);
      await capture('lesson:verse', '${palette.id}-scripture',
          theme: palette.id);
      await capture('profile', '${palette.id}-profile', theme: palette.id);
    }
    for (final part in ['meaning', 'encouragement', 'hope', 'prayer']) {
      await capture('reading:$part', 'reader-$part');
    }
    await capture('reading:complete', 'reading-complete', complete: true);
    await capture('reading:error', 'reading-save-error');
    await capture('welcome', 'welcome');
    await capture('auth', 'account');
    for (final stage in ['name', 'focus', 'reminder', 'day-one']) {
      await capture('onboarding:$stage', 'setup-$stage');
    }
    await capture('saved:populated', 'saved');
    await capture('settings', 'settings');
    await capture('calendar', 'calendar');
    await capture('profile', 'themes', screen: const ThemeScreen());
    await capture('profile', 'badges', screen: const BadgesScreen());
    await capture('learn', 'ipad-walk', size: const Size(1024, 1366));
    await capture('lesson:verse', 'ipad-reader', size: const Size(1366, 1024));
    await capture('lesson:verse', 'reader-large-text',
        size: const Size(320, 568), scale: 2);
    await tester.runAsync(() async {
      await File('store/walk-redesign/manifest.json').writeAsString(
          '${const JsonEncoder.withIndent('  ').convert(manifest)}\n');
    });
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
