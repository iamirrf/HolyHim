// iPhone Duo review renders: the lesson as an open book on the inner display
// (both postures), mid page-turn, and the main screens at Duo sizes.
// Run: flutter test tool/render/duo_test.dart  → build/render/duo/
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/features/celebration/celebration_screen.dart';
import 'package:holyhim/features/lesson/lesson_screen.dart';
import 'package:holyhim/features/shell/home_shell.dart';
import 'package:holyhim/services/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'fixtures.dart';
import 'harness.dart';

const out = 'build/render/duo';

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    HolySounds.player = (String _, {double gain = 1}) async {};
    await loadFonts();
  });

  Future<void> shot(WidgetTester tester, String id, Widget screen, Phone phone,
      {WalkState? walk, Future<void> Function()? action, bool settle = true}) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    await capture(tester, '$out/$id-${phone.id}.png', screen,
        phone: phone,
        pixelRatio: 1.5,
        action: action,
        settle: settle,
        wrap: (app) => scope(app,
            walk: walk ?? WalkState(profile: profile(), completed: history(2))));
    final error = tester.takeException();
    debugDefaultTargetPlatformOverride = null;
    expect(error, isNull, reason: '$id-${phone.id}');
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('lesson as a book', (tester) async {
    for (final p in [Phone.duo, Phone.duoOpenWide]) {
      await shot(tester, 'book-spread1', const LessonScreen(day: 3), p);
      await shot(tester, 'book-spread2', const LessonScreen(day: 3), p,
          action: () async {
        await tester.tap(find.byTooltip('Next card'));
        await tester.pump(const Duration(milliseconds: 1000));
      });
    }
    await shot(tester, 'book-turning', const LessonScreen(day: 3), Phone.duo,
        settle: false, action: () async {
      await tester.tap(find.byTooltip('Next card'));
      await tester.pump(const Duration(milliseconds: 60));
    });
    await shot(tester, 'deck', const LessonScreen(day: 3), Phone.duoOuter);
  });

  testWidgets('main screens', (tester) async {
    for (final p in [Phone.duo, Phone.duoOpenWide, Phone.duoOuter]) {
      await shot(tester, 'today', const HomeShell(), p);
      await shot(tester, 'celebration', const CelebrationScreen(day: 3), p,
          walk: WalkState(profile: profile(), completed: history(2, today: true)));
    }
  });
}
