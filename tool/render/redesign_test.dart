// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renders the redesigned home tabs to build/render/redesign for review.
// Run: flutter test tool/render/redesign_test.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/features/community/community_screen.dart';
import 'package:holyhim/features/shell/home_shell.dart';
import 'package:holyhim/services/billing.dart';
import 'package:holyhim/services/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'fixtures.dart';
import 'harness.dart';

const out = 'build/render/redesign';

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    SharedPreferences.setMockInitialValues({});
    HolySounds.player = (String _, {double gain = 1}) async {};
    await loadFonts();
  });

  Future<void> shot(WidgetTester tester, String id, Widget screen,
      {required WalkState walk,
      bool owned = true,
      bool community = true,
      Phone phone = Phone.max,
      HolyTheme theme = HolyThemes.blush,
      Future<void> Function()? action}) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    await capture(tester, '$out/$id.png', screen,
        phone: phone,
        theme: theme,
        pixelRatio: 2,
        action: action,
        wrap: (app) => scope(app,
            walk: walk,
            community: community,
            billing: LifetimeState(loading: false, purchased: owned, product: product)));
    final error = tester.takeException();
    if (error != null) debugPrint('!! $id: $error');
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  }

  final kept = WalkState(
      profile: profile(),
      completed: history(12),
      saved: {3: DateTime(2026, 11, 5), 6: DateTime(2026, 11, 8)});

  testWidgets('redesign tabs', (tester) async {
    await shot(tester, 'walk', const HomeShell(), walk: kept);
    await shot(tester, 'walk-road', const HomeShell(), walk: kept, action: () async {
      await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -1250));
      await tester.pump(const Duration(milliseconds: 400));
    });
    await shot(tester, 'walk-today', const HomeShell(), walk: kept, action: () async {
      await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -900));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Back to today'));
      await tester.pump(const Duration(milliseconds: 1200));
    });
    await shot(tester, 'walk-new', const HomeShell(),
        walk: WalkState(profile: profile(), completed: history(0)), owned: false);
    await shot(tester, 'walk-locked', const HomeShell(),
        walk: WalkState(profile: profile(), completed: history(7)), owned: false,
        action: () async {
      await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -1100));
      await tester.pump(const Duration(milliseconds: 400));
    });
    await shot(tester, 'brothers', const HomeShell(initialTab: 1), walk: kept);
    await shot(tester, 'brothers-join', const HomeShell(initialTab: 1), walk: kept, community: false);
    await shot(tester, 'ranks', const HomeShell(initialTab: 2), walk: kept);
    await shot(tester, 'composer', const HomeShell(initialTab: 1), walk: kept, action: () async {
      await tester.tap(find.text('Prayer').first);
      await tester.pump(const Duration(milliseconds: 600));
    });
    await shot(tester, 'join-sheet', const HomeShell(initialTab: 1), walk: kept, community: false,
        action: () async {
      await tester.tap(find.text('Join the brothers').last);
      await tester.pump(const Duration(milliseconds: 600));
    });
    await shot(tester, 'growth', const HomeShell(initialTab: 3), walk: kept);
    await shot(tester, 'growth-medals', const HomeShell(initialTab: 3), walk: kept,
        action: () async {
      await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -700));
      await tester.pump(const Duration(milliseconds: 400));
    });
    await shot(tester, 'profile', const HomeShell(initialTab: 4), walk: kept);
    await shot(tester, 'post', const PostScreen(id: 'p2'), walk: kept);
    await shot(tester, 'walk-light', const HomeShell(), walk: kept, theme: HolyThemes.rose);
    await shot(tester, 'walk-se', const HomeShell(), walk: kept, phone: Phone.se);
    await shot(tester, 'swipe-mid', const HomeShell(), walk: kept, action: () async {
      final gesture = await tester.startGesture(const Offset(300, 500));
      await gesture.moveBy(const Offset(-160, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
    });
  });
}
