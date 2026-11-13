import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/domain/badges.dart';
import 'package:holyhim/domain/streak.dart';

// A one-pixel codec fixture, not a generated product asset.
final _pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=');

class _Bundle extends CachingAssetBundle {
  final Map<String, Uint8List> art;
  final List<String> loads = [];
  _Bundle(this.art);
  @override
  Future<ByteData> load(String key) async {
    loads.add(key);
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage({
        for (final path in art.keys)
          path: [
            {'asset': path, 'dpr': 1.0}
          ]
      })!;
    }
    final bytes = art[key];
    if (bytes == null) {
      throw FlutterError('Unexpected missing asset request: $key');
    }
    return ByteData.sublistView(bytes);
  }
}

class _SynchronousBundle extends _Bundle {
  _SynchronousBundle(super.art);
  @override
  Future<ByteData> load(String key) {
    if (key == 'AssetManifest.bin') {
      return SynchronousFuture(const StandardMessageCodec().encodeMessage({
        for (final path in art.keys)
          path: [
            {'asset': path, 'dpr': 1.0}
          ]
      })!);
    }
    return SynchronousFuture(ByteData.sublistView(art[key]!));
  }
}

Widget _app(_Bundle bundle, Widget child,
        {bool reduceMotion = true}) =>
    DefaultAssetBundle(
        bundle: bundle,
        child: MaterialApp(
            theme: HolyThemeData.build(HolyThemes.midnightRose),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2),
                    disableAnimations: reduceMotion),
                child: HolyThemeScope(
                    theme: HolyThemes.midnightRose, child: child!)),
            home: Scaffold(
                body: Center(child: SizedBox(width: 300, child: child)))));
Widget _sceneAndBadge() =>
    const Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
          height: 190,
          child: PhotoStage(
              images: ['assets/art/library/sky-dawn.webp'],
              child: Center(child: Text('A quiet moment')))),
      Badge3D(badgeId: 'days-1', label: 'A Beautiful Beginning', earned: true)
    ]);

void main() {
  test('a synchronously cached manifest resolves the first artwork request',
      () async {
    const path = 'assets/art/library/cross-hill.webp';
    final bundle = _SynchronousBundle({path: _pixel});
    expect(
        await HolyArtAssets.contains(bundle, path)
            .timeout(const Duration(milliseconds: 100)),
        isTrue);
    expect(
        await HolyArtAssets.contains(bundle, 'missing.webp')
            .timeout(const Duration(milliseconds: 100)),
        isFalse);
  });
  test('all nineteen domain badge IDs map to the approved package filenames',
      () {
    final badges = badgesFor(
        completed: {},
        saved: {},
        streak:
            const Streak(current: 0, longest: 0, graceDays: 0, graceDates: {}));
    expect(badges.length, 19);
    final paths =
        badges.map((badge) => HolyArtAssets.badgePath(badge.id)).toSet();
    expect(paths.length, 19);
    expect(paths, isNot(contains(null)));
    expect(HolyArtAssets.badgePath('days-1'), 'assets/art/badges/days-001.png');
    expect(
        HolyArtAssets.badgePath('days-365'), 'assets/art/badges/days-365.png');
    expect(HolyArtAssets.badgePath('streak-7'),
        'assets/art/badges/streak-007.png');
    expect(HolyArtAssets.badgePath('promise'),
        'assets/art/badges/promise-kept.png');
    expect(HolyArtAssets.badgePath('days-2'), isNull);
    expect(HolyArtAssets.scenePath('saved-empty'),
        'assets/art/library/scripture-morning.webp');
    expect(HolyArtAssets.scenes.length, 8);
  });
  testWidgets(
      'missing scenes and badges keep accessible fallbacks without requesting missing files',
      (tester) async {
    final bundle = _Bundle({});
    await tester.pumpWidget(_app(bundle, _sceneAndBadge()));
    await tester.pumpAndSettle();
    // The photograph may be requested; a missing file falls back quietly.
    expect(find.text('A quiet moment'), findsOneWidget);
    expect(find.text('A Beautiful Beginning'), findsOneWidget);
    expect(
        bundle.loads.where((path) => path.startsWith('assets/art/badges/')),
        isEmpty);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'packaged scene and medallion are loaded, then Reduce Motion freezes their movement',
      (tester) async {
    final bundle = _Bundle({
      'assets/art/library/sky-dawn.webp': _pixel,
      'assets/art/badges/days-001.png': _pixel
    });
    await tester
        .pumpWidget(_app(bundle, _sceneAndBadge(), reduceMotion: false));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
        bundle.loads,
        containsAll([
          'assets/art/library/sky-dawn.webp',
          'assets/art/badges/days-001.png'
        ]));
    expect(find.byType(Image), findsNWidgets(2));
    final camera = find
        .descendant(of: find.byType(PhotoStage), matching: find.byType(Transform))
        .first;
    final moving =
        List<double>.of(tester.widget<Transform>(camera).transform.storage);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<Transform>(camera).transform.storage,
        isNot(equals(moving)));
    await tester.pumpWidget(_app(bundle, _sceneAndBadge()));
    await tester.pump();
    final still =
        List<double>.of(tester.widget<Transform>(camera).transform.storage);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<Transform>(camera).transform.storage, equals(still));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'a corrupt listed scene falls back without an unhandled image error',
      (tester) async {
    final bundle = _Bundle({
      'assets/art/library/sky-dawn.webp': Uint8List.fromList([1, 2, 3])
    });
    await tester.pumpWidget(_app(
        bundle,
        const SizedBox(
            height: 250,
            child: PhotoStage(
                images: ['assets/art/library/sky-dawn.webp'],
                child: Center(child: Text('Still a quiet place'))))));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('Still a quiet place'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
