import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/core/constants/app_constants.dart';
import 'package:holyhim/data/lessons.g.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/services/share_card.dart';

void main() {
  test('a shared keepsake says where it came from and links to the store', () {
    final text = keepsakeShareText(lessons[2]);
    expect(text, contains(lessons[2].reference));
    expect(text, contains('HolyHim'));
    expect(AppConstants.shareUrl, 'https://apps.apple.com/app/id');
    expect(text, endsWith(AppConstants.shareUrl));
  });

  testWidgets('every look and shape carries the mark and never overflows',
      (tester) async {
    // The longest verse in the year, in each look and shape.
    final longest =
        lessons.reduce((a, b) => a.verse.length >= b.verse.length ? a : b);
    for (final lesson in [lessons[2], longest]) {
      for (final style in KeepsakeStyle.values) {
        for (final look in KeepsakeLook.values) {
          final size = style == KeepsakeStyle.story
              ? const Size(360, 640)
              : const Size(360, 360);
          await tester.pumpWidget(MaterialApp(
              home: HolyThemeScope(
                  theme: HolyThemes.blush,
                  child: Center(
                      child: SizedBox.fromSize(
                          size: size,
                          child: MediaQuery(
                              data: MediaQueryData(
                                  size: size, textScaler: TextScaler.noScaling),
                              child: KeepsakeCard(
                                  lesson: lesson,
                                  style: style,
                                  look: look)))))));
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: 'Day ${lesson.day} $style $look');
          expect(find.text('HolyHim · on the App Store'), findsOneWidget);
          expect(find.text(lesson.reference), findsOneWidget);
          expect(find.byType(Wordmark), findsOneWidget);
        }
      }
    }
  });
}
