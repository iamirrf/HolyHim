import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/dev/preview_fixtures.dart';

void main() {
  testWidgets(
      'ambient painting leaves the screen subtree and subscriptions stable',
      (tester) async {
    var builds = 0;
    await tester.pumpWidget(
        MaterialApp(home: BlushBackdrop(child: Builder(builder: (context) {
      builds++;
      return const Text('A stable reading screen');
    }))));
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(builds, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('saved verse overflow remains an independent accessible action',
      (tester) async {
    final semantics = tester.ensureSemantics();

    final fixture = PreviewFixture('saved:populated');
    await tester.pumpWidget(ProviderScope(
        overrides: fixture.overrides,
        child: MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!),
            home: fixture.build())));
    await tester.pumpAndSettle();
    final action = find.byTooltip('Verse actions').first;
    expect(
        tester
            .getSemantics(action)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('Remove from Saved'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });
  testWidgets(
      'labeled navigation buttons activate through accessibility actions',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final fixture = PreviewFixture('learn');
    await tester.pumpWidget(ProviderScope(
        overrides: fixture.overrides,
        child: MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!),
            home: fixture.build())));
    await tester.pumpAndSettle();
    final button = tester.getSemantics(find.bySemanticsLabel('Saved').first);
    expect(button.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    button.owner!.performAction(button.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(find.text('Keep a verse close.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });
}
