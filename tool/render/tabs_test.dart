// All five home tabs over the living background. Run: flutter test tool/render/tabs_test.dart
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/features/shell/home_shell.dart';
import 'package:holyhim/services/circle.dart';
import 'package:holyhim/services/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'circle_test.dart' show members;
import 'fixtures.dart';
import 'harness.dart';

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    HolySounds.player = (String _, {double gain = 1}) async {};
    await loadFonts();
  });
  testWidgets('tabs', (tester) async {
    for (final theme in [HolyThemes.blush, HolyThemes.midnightRose]) {
      for (var tab = 0; tab < 5; tab++) {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        SharedPreferences.setMockInitialValues({});
        await capture(tester, 'build/render/tabs/${theme.id}-$tab.png',
            HomeShell(initialTab: tab),
            theme: theme,
            pixelRatio: 2,
            action: tab == 0
                ? null
                : () async {
                    await tester.drag(find.byType(Scrollable).last,
                        const Offset(0, -260));
                    await tester.pump(const Duration(milliseconds: 300));
                  },
            wrap: (app) => ProviderScope(overrides: [
                  circleBoardProvider
                      .overrideWith((ref, sort) => Stream.value(members)),
                ], child: scope(app,
                    walk: WalkState(
                        profile: profile(theme: theme.id)
                            .copyWith(circle: true, circleAvatar: 'symbol-dove'),
                        completed: history(12),
                        saved: {1: DateTime(2026, 11, 3)}))));
        final error = tester.takeException();
        debugDefaultTargetPlatformOverride = null;
        expect(error, isNull);
        await tester.pumpWidget(const SizedBox());
      }
    }
  });
}
