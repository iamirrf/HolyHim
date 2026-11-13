// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renders the real screens used for App Store screenshots at 6.9-inch
// resolution (430 x 932 points at 3x = 1290 x 2796) to build/render/store.
// Frame them with: python3 tool/store_screenshots.py
// Run: flutter test tool/render/him_screenshots_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/features/celebration/celebration_screen.dart';
import 'package:holyhim/features/lesson/lesson_screen.dart';
import 'package:holyhim/features/shell/home_shell.dart';
import 'package:holyhim/services/billing.dart';
import 'package:holyhim/services/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'fixtures.dart';
import 'harness.dart';

const out = 'build/render/store';

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    SharedPreferences.setMockInitialValues({});
    HolySounds.player = (String _, {double gain = 1}) async {};
    await loadFonts();
  });

  Future<void> shot(WidgetTester tester, String id, Widget screen,
      {required WalkState walk, Future<void> Function()? action}) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    await capture(tester, '$out/$id.png', screen,
        phone: Phone.max,
        pixelRatio: 3,
        action: action,
        wrap: (app) => scope(app,
            walk: walk,
            billing: const LifetimeState(
                loading: false, purchased: true, product: product)));
    final error = tester.takeException();
    if (error != null) debugPrint('!! $id: $error');
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  }

  final kept = WalkState(
      profile: profile(),
      completed: history(12),
      saved: {3: DateTime(2026, 11, 5), 6: DateTime(2026, 11, 8), 7: DateTime(2026, 11, 9)});

  testWidgets('App Store screens', (tester) async {
    await shot(tester, '01-today', const HomeShell(), walk: kept);
    for (final (card, id) in [(0, '02-scripture'), (2, '03-life')]) {
      await shot(tester, id, const LessonScreen(day: 3),
          walk: WalkState(profile: profile(), completed: history(2)),
          action: () async {
        for (var i = 0; i < card; i++) {
          await tester.tap(find.byTooltip('Next card'));
          await tester.pump(const Duration(milliseconds: 600));
        }
      });
    }
    await shot(tester, '04-amen', const CelebrationScreen(day: 3),
        walk: WalkState(profile: profile(), completed: history(2, today: true)));
    await shot(tester, '05-growth', const HomeShell(initialTab: 2), walk: kept);
    await shot(tester, '06-saved', const HomeShell(initialTab: 1), walk: kept);
  });
}
