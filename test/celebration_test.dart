import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../tool/render/harness.dart' show loadFonts;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:holyhim/design/design.dart';
import 'package:holyhim/domain/badges.dart';
import 'package:holyhim/features/celebration/celebration_screen.dart';
import 'package:holyhim/services/badge_share.dart';
import 'package:holyhim/services/auth_service.dart';
import 'package:holyhim/services/repository.dart';

final _now = DateTime.utc(2026, 11, 3, 12);
WalkState _walk(int count) => WalkState(
        profile: AppProfile(
            name: 'Mira',
            haptics: false,
            sounds: false,
            timeZone: 'America/New_York',
            promiseStartedAt: DateTime.utc(2026, 10, 28),
            onboardedAt: DateTime.utc(2026, 10, 28)),
        completed: {
          for (var day = 1; day <= count; day++)
            day: DateTime.utc(2026, 10, 27 + day)
                .toIso8601String()
                .substring(0, 10)
        },
        saved: {
          1: DateTime.utc(2026, 10, 28)
        });

class _Repository extends WalkRepository {
  final WalkState fixture;
  _Repository(this.fixture);
  @override
  WalkState build() => fixture;
}

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(user: AuthUser(uid: 'first'));
  void switchAccount() =>
      state = const AuthState(user: AuthUser(uid: 'second'));
}

Widget _app(Widget screen, {double scale = 2}) => MaterialApp(
    theme: HolyThemeData.build(HolyThemes.blush),
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale), disableAnimations: true),
        child: ThemeHost(theme: HolyThemes.blush, child: child!)),
    home: screen);

void main() {
  setUpAll(() async {
    tzdata.initializeTimeZones();
    await loadFonts();
  });
  setUp(() {
    HolyHaptics.enabled = false;
    HolySounds.player = (String asset, {double gain = 1}) async {};
  });
  test('a completion awards only badges that crossed their goal in that update',
      () {
    final receipt = completionMomentBetween(
        day: 7, before: _walk(6), after: _walk(7), now: _now);
    expect(receipt.previousStreak, 6);
    expect(receipt.streak, 7);
    expect(receipt.newlyEarned.map((badge) => badge.id).toSet(),
        {'days-7', 'streak-7', 'promise'});
    expect(
        receipt.newlyEarned.any((badge) => badge.id == 'first-saved'), isFalse);
    final repeated = completionMomentBetween(
        day: 7, before: _walk(7), after: _walk(7), now: _now);
    expect(repeated.newlyEarned, isEmpty);
  });

  test('an account change discards an unconsumed completion receipt', () {
    final container =
        ProviderContainer(overrides: [authProvider.overrideWith(_Auth.new)]);
    addTearDown(container.dispose);
    expect(container.read(completionMomentProvider), isNull);
    container.read(completionMomentProvider.notifier).state =
        completionMomentBetween(
            day: 7, before: _walk(6), after: _walk(7), now: _now);
    expect(container.read(completionMomentProvider), isNotNull);
    (container.read(authProvider.notifier) as _Auth).switchAccount();
    expect(container.read(completionMomentProvider), isNull);
  });

  testWidgets(
      'a celebration consumes its receipt and rereading cannot show a new keepsake',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final after = _walk(7);
    final receipt = completionMomentBetween(
        day: 7, before: _walk(6), after: after, now: _now);
    final container = ProviderContainer(overrides: [
      repositoryProvider.overrideWith(() => _Repository(after)),
      completionMomentProvider.overrideWith((ref) => receipt)
    ]);
    addTearDown(container.dispose);
    Widget screen() => UncontrolledProviderScope(
        container: container, child: _app(const CelebrationScreen(day: 7)));
    await tester.pumpWidget(screen());
    await tester.pump();
    expect(container.read(completionMomentProvider), isNull);
    expect(find.text('Amen.'), findsOneWidget);
    expect(find.text('NEW MEDALLION'), findsOneWidget);
    expect(find.text('A Faithful Week'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen());
    await tester.pump();
    // Reading again never shows a new keepsake.
    expect(find.text('NEW MEDALLION'), findsNothing);
    expect(find.text('CARRY THIS TODAY'), findsOneWidget);
    expect(container.read(repositoryProvider).completed.length, 7);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('badge sharing renders an opaque 1080 by 1920 PNG',
      (tester) async {
    late BuildContext captureContext;
    await tester.pumpWidget(_app(Builder(builder: (context) {
      captureContext = context;
      return const Scaffold(body: SizedBox());
    }), scale: 1));
    const badge = WalkBadge(
        id: 'days-7',
        title: 'A Faithful Week',
        description: 'Spend seven days in Scripture.',
        progress: 7,
        goal: 7);
    final imageFuture =
        renderBadgeImage(captureContext, badge, icon: CupertinoIcons.sparkles);
    await tester.pump();
    final bytes = await tester.runAsync(() => imageFuture);
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(1000));
    final dimensions = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size =
          Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      final pixels =
          await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(pixels!.getUint8(3), 255);
      expect(pixels.getUint8(pixels.lengthInBytes - 1), 255);
      frame.image.dispose();
      codec.dispose();
      return size;
    });
    expect(dimensions, const Size(1080, 1920));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
