import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/dev/preview_fixtures.dart';
import 'package:holyher/features/onboarding/checkpoint.dart';

/// Development composition review, explicitly separate from native iOS proof.
/// System-font tables arrive through a pipe and stay in memory; no font file
/// is bundled, copied to a fixture, or saved in this repository.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final width = double.parse(
          const String.fromEnvironment('REVIEW_WIDTH', defaultValue: '430')),
      height = double.parse(
          const String.fromEnvironment('REVIEW_HEIGHT', defaultValue: '932')),
      scale = double.parse(
          const String.fromEnvironment('REVIEW_SCALE', defaultValue: '1'));
  final routes =
      const String.fromEnvironment('REVIEW_ROUTES', defaultValue: '').isEmpty
          ? [
              'welcome',
              'auth',
              'auth:create',
              'reset',
              for (final stage in OnboardingStages.ids) 'onboarding:$stage',
              'learn',
              'learn:resume',
              'learn:late',
              'learn:caught-up',
              'learn:complete',
              'saved:empty',
              'saved:populated',
              'saved:error',
              'saved:detail',
              'profile',
              'calendar',
              'settings',
              'name',
              'rhythm',
              'reminder',
              'password',
              'export',
              'reset-progress',
              'help',
              'about',
              'privacy',
              'terms',
              'contact',
              'feedback',
              'recovery',
              for (final step in [
                'intro',
                'verse',
                'understand',
                'question-1',
                'confidence',
                'hope',
                'question-2',
                'carry',
                'closing'
              ])
                'lesson:$step',
              'lesson:question-1:correct',
              'lesson:question-1:wrong',
              'lesson:closing:failure',
              'lesson:resume-failure',
              for (final step in [
                'verse',
                'confidence',
                'reason',
                'hope',
                'carry'
              ])
                'existing:$step',
            ]
          : const String.fromEnvironment('REVIEW_ROUTES').split('|');
  late Map<String, dynamic> font;
  setUpAll(() async {
    final result = await Process.run('/tmp/holyher-native-review-fonts', []);
    if (result.exitCode != 0) {
      throw StateError('Review font resolver failed: ${result.stderr}');
    }
    font = Map<String, dynamic>.from(jsonDecode(result.stdout as String));
    final loader = FontLoader(HolyTypography.family);
    for (final role in ['regular', 'semibold']) {
      loader.addFont(Future.value(
          ByteData.sublistView(base64Decode(font[role] as String))));
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(File(
            '/Users/amir/development/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
        .readAsBytes()
        .then(ByteData.sublistView));
    await icons.load();
    font.remove('regular');
    font.remove('semibold');
  });
  testWidgets('export composition review frames', (tester) async {
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = Size(width * 3, height * 3);
    tester.view.padding = FakeViewPadding(
        top: (width < 700 ? 59 : 24) * 3, bottom: (width < 700 ? 34 : 20) * 3);
    addTearDown(() {
      debugDisableShadows = previousShadows;
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.view.resetPadding();
    });
    final output = Directory('store/pearl-redesign/review-renders');
    output.createSync(recursive: true);
    for (final route in routes) {
      await tester.pumpWidget(const SizedBox());
      final fixture = PreviewFixture(route),
          screen = fixture.build(),
          key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: ProviderScope(
              overrides: fixture.overrides,
              child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: buildAppTheme(),
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          disableAnimations: true,
                          textScaler: TextScaler.linear(scale)),
                      child: BlushBackdrop(child: child!)),
                  home: screen))));
      await tester.pump();
      await tester.runAsync(() => precacheImage(
          const AssetImage('assets/brand/holyher-mark.png'),
          key.currentContext!));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: route);
      final name =
          '${route.replaceAll(':', '-')}--${width.toInt()}x${height.toInt()}--s$scale';
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${output.path}/$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
        await File('${output.path}/$name.json').writeAsString(jsonEncode({
          'route': route,
          'logicalWidth': width,
          'logicalHeight': height,
          'pixelWidth': width * 3,
          'pixelHeight': height * 3,
          'textScale': scale,
          'capture':
              'Offscreen Flutter composition review using macOS rounded system tables in memory; NOT a native iOS screenshot',
          'font': font,
          'fixture': 'lib/dev/preview_fixtures.dart'
        }));
      });
    }
    await tester.pumpWidget(const SizedBox());
    debugDisableShadows = previousShadows;
  });
}
