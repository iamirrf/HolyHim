import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/features/profile/app_icon_screen.dart';
import 'package:holyhim/services/app_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('holyhim/app-icon');

  test('every icon has its preview and its asset catalog set', () {
    expect(appIcons.length, 15);
    expect(appIcons.map((i) => i.id).toSet().length, appIcons.length);
    expect(appIcons.first.iosName, isNull, reason: 'the primary icon');
    for (final icon in appIcons) {
      expect(File(icon.preview).existsSync(), isTrue, reason: icon.preview);
      final set = icon.iosName ?? 'AppIcon';
      final contents =
          File('ios/Runner/Assets.xcassets/$set.appiconset/Contents.json');
      expect(contents.existsSync(), isTrue, reason: set);
      final images = (jsonDecode(contents.readAsStringSync())
          as Map<String, dynamic>)['images'] as List;
      for (final image in images.cast<Map<String, dynamic>>()) {
        final file = image['filename'] as String?;
        if (file != null) {
          expect(
              File('ios/Runner/Assets.xcassets/$set.appiconset/$file')
                  .existsSync(),
              isTrue,
              reason: '$set/$file');
        }
      }
    }
  });

  test('every alternate set is offered, and the build includes them', () {
    final sets = Directory('ios/Runner/Assets.xcassets')
        .listSync()
        .map((e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last)
        .where((n) => n.endsWith('.appiconset'))
        .map((n) => n.replaceFirst('.appiconset', ''))
        .toSet();
    expect(sets, {for (final i in appIcons) i.iosName ?? 'AppIcon'});
    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(
        'ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = YES;'
            .allMatches(project)
            .length,
        'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;'
            .allMatches(project)
            .length);
  });

  test('each theme has its own matching icon', () {
    final matched = {for (final t in HolyThemes.all) appIconForTheme(t.id).id};
    expect(matched.length, HolyThemes.all.length);
    expect(appIconForTheme('blush').iosName, isNull);
    expect(appIconForTheme('midnight-rose').id, 'evening');
    expect(appIconForTheme('unknown').id, 'first-light');
  });

  testWidgets('tapping an icon asks iOS for its set and marks it chosen',
      (tester) async {
    String? shown;
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call);
      switch (call.method) {
        case 'supported':
          return true;
        case 'current':
          return shown;
        case 'set':
          shown = call.arguments as String?;
          return shown;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    // The smallest phone, with larger text.
    tester.view.physicalSize = const Size(375, 667) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            theme: HolyThemeData.build(HolyThemes.blush),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.3),
                    disableAnimations: true),
                child: HolyThemeScope(theme: HolyThemes.blush, child: child!)),
            home: const AppIconScreen())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('First Light'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.checkmark_circle_fill), findsOneWidget);
    final list = find
        .descendant(
            of: find.byType(ListView), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Candle'), 160, scrollable: list);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Candle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(calls.last.method, 'set');
    expect(calls.last.arguments, 'AppIcon-Candle');
    expect(shown, 'AppIcon-Candle');
    expect(find.byIcon(CupertinoIcons.checkmark_circle_fill), findsOneWidget);
  });
}
