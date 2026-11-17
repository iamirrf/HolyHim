// Walk path review renders. Run: flutter test tool/render/walk_test.dart
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/features/shell/home_shell.dart';
import 'package:holyhim/services/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'fixtures.dart';
import 'harness.dart';

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    HolySounds.player = (String _, {double gain = 1}) async {};
    await loadFonts();
  });
  testWidgets('growth', (tester) async {
    for (final read in [2, 30]) {
      for (final theme in [HolyThemes.blush, HolyThemes.midnightRose]) {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        SharedPreferences.setMockInitialValues({});
        await capture(tester, 'build/render/growth/growth-$read-${theme.id}.png',
            const HomeShell(initialTab: 3),
            theme: theme,
            pixelRatio: 2,
            action: () async {
              await tester.drag(find.byType(CustomScrollView).first,
                  const Offset(0, -820));
              await tester.pump(const Duration(milliseconds: 400));
            },
            wrap: (app) => scope(app,
                walk: WalkState(
                    profile: profile(theme: theme.id),
                    completed: history(read),
                    saved: {1: DateTime(2026, 11, 3)})));
        final error = tester.takeException();
        debugDefaultTargetPlatformOverride = null;
        expect(error, isNull);
        await tester.pumpWidget(const SizedBox());
      }
    }
  });
}
