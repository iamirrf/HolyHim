import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/dev/preview_fixtures.dart';

void main() {
  Future<void> start(WidgetTester tester,
      {String route = 'learn', double scale = 1}) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final fixture = PreviewFixture(route);
    await tester.pumpWidget(ProviderScope(
        overrides: fixture.overrides,
        child: MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    disableAnimations: true,
                    textScaler: TextScaler.linear(scale)),
                child: BlushBackdrop(child: child!)),
            home: fixture.build())));
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('late journey reveals current lesson lazily at ${scale}x text',
        (tester) async {
      await start(tester, route: 'learn:late', scale: scale);
      final current = find.bySemanticsLabel(RegExp(r'^Day 148,'));
      expect(current, findsOneWidget);
      final center = tester.getCenter(current);
      expect(center.dy, inInclusiveRange(0, 852));
      expect(find.byType(LessonMedallion).evaluate().length, lessThan(30));
      final scroll = find.byType(CustomScrollView).first;
      final controller = PrimaryScrollController.of(tester.element(scroll));
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Return to today'));
      await tester.pumpAndSettle();
      expect(tester.getCenter(current).dy, inInclusiveRange(0, 852));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'only user vertical scrolling minimizes navigation and upward scrolling expands it',
      (tester) async {
    await start(tester);
    expect(find.text('Walk'), findsOneWidget);
    final scroll = find.byType(CustomScrollView).first;
    final controller = PrimaryScrollController.of(tester.element(scroll));
    controller.jumpTo(240);
    await tester.pumpAndSettle();
    expect(find.text('Walk'), findsOneWidget,
        reason: 'Programmatic movement must keep navigation expanded');
    await tester.drag(scroll, const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(find.text('Walk'), findsNothing);
    await tester.drag(scroll, const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(find.text('Walk'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Saved search survives tab changes and reselecting Walk returns to the top',
      (tester) async {
    await start(tester);
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'kept words');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved').first);
    await tester.pumpAndSettle();
    expect(find.text('kept words'), findsOneWidget);
    await tester.tap(find.text('Walk'));
    await tester.pumpAndSettle();
    final scroll = find.byType(CustomScrollView).first,
        controller = PrimaryScrollController.of(
            tester.element(find.byType(CustomScrollView).first));
    controller.jumpTo(600);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Walk'));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(scroll, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
