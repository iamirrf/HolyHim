import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/design/widgets/animated_mesh_background.dart';
import 'package:holyhim/design/widgets/tab_shell.dart';

/// On iOS 26 the tab shell is the package's native scaffold, which is a
/// CupertinoPageScaffold under the native bar. Its sheet once covered the
/// mesh with flat paper on every tab, and took light or dark from the phone.
void main() {
  const tabs = [
    HolyTab('Today', CupertinoIcons.sun_max, 'sun.max', 'sun.max.fill'),
    HolyTab('Walk', CupertinoIcons.map, 'map', 'map.fill'),
  ];

  Widget app(HolyTheme theme, Widget Function(BuildContext) shell) =>
      MaterialApp(
          theme: HolyThemeData.build(theme),
          home: HolyThemeScope(
              theme: theme,
              child: Scaffold(
                  backgroundColor: theme.paper,
                  body: HolyBackdrop(child: Builder(builder: shell)))));

  tearDown(() => HolyTabShell.debugNativeBar = null);

  for (final theme in [HolyThemes.blush, HolyThemes.midnightRose]) {
    testWidgets('the native frame leaves the ${theme.name} mesh uncovered',
        (tester) async {
      // The phone says the opposite of the theme.
      tester.platformDispatcher.platformBrightnessTestValue =
          theme.isDark ? Brightness.light : Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      Brightness? seen;
      await tester.pumpWidget(app(
          theme,
          (context) => HolyTabShell.nativeFrame(context,
              child: CupertinoPageScaffold(child: Builder(builder: (context) {
                seen = MediaQuery.platformBrightnessOf(context);
                return const SizedBox.expand(key: Key('page'));
              })))));
      await tester.pump();

      expect(find.byType(AnimatedMeshBackground), findsOneWidget);
      final sheets = tester.widgetList<DecoratedBox>(find.descendant(
          of: find.byType(CupertinoPageScaffold),
          matching: find.byType(DecoratedBox)));
      expect(sheets, isNotEmpty);
      for (final sheet in sheets) {
        final color = (sheet.decoration as BoxDecoration).color;
        expect(color == null || color.a == 0, isTrue,
            reason: 'the scaffold paints $color over the mesh');
      }
      expect(seen, theme.isDark ? Brightness.dark : Brightness.light);
    });
  }

  testWidgets('the shell puts the native scaffold in that frame',
      (tester) async {
    HolyTabShell.debugNativeBar = true;
    await tester.pumpWidget(app(
        HolyThemes.midnightRose,
        (context) => HolyTabShell(
            index: 0,
            onChanged: (_) {},
            tabs: tabs,
            child: const SizedBox.expand())));
    final scaffold = tester.element(find.byType(AdaptiveScaffold));
    expect(CupertinoTheme.of(scaffold).scaffoldBackgroundColor.a, 0);
    expect(CupertinoTheme.of(scaffold).brightness, Brightness.dark);
    expect(MediaQuery.platformBrightnessOf(scaffold), Brightness.dark);
  });
}
