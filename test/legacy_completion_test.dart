import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/dev/preview_fixtures.dart';
import 'package:holyher/features/lesson/lesson_cards.dart';

void main() {
  testWidgets(
      'rejected five-card completion preserves the durable reading position',
      (tester) async {
    final fixture = PreviewFixture('existing:carry');
    fixture.store.values['card_position_fixture_6'] = 4;
    await tester.pumpWidget(ProviderScope(
        overrides: fixture.overrides,
        child: MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!),
            home: HolyScaffold(
                body: LessonCards(
                    lesson: lessons[5],
                    done: false,
                    saving: false,
                    onComplete: () async => false,
                    onClose: () {})))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete lesson'));
    await tester.pumpAndSettle();
    expect(fixture.store.values['card_position_fixture_6'], 4);
    expect(find.text('Take this with you.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
