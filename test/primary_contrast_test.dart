import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/design/widgets/animated_mesh_background.dart';
import 'package:holyhim/design/widgets/sunrise_background.dart';

double _contrast(Color a, Color b) {
  final light = math.max(a.computeLuminance(), b.computeLuminance());
  final dark = math.min(a.computeLuminance(), b.computeLuminance());
  return (light + .05) / (dark + .05);
}

void _check(HolyTheme theme) {
  expect(theme.primary.a, 1,
      reason: 'Primary controls must not depend on the art behind them.');
  expect(_contrast(theme.onPrimary, theme.primary), greaterThanOrEqualTo(4.5),
      reason: theme.name);
}

void main() {
  test(
      'primary labels keep normal-text contrast in every theme and during live theme changes',
      () {
    for (final theme in HolyThemes.all) {
      _check(theme);
    }
    // Within a brightness, every moment of a theme change stays legible.
    // Between light and dark the button inverts, so only the ends count.
    for (final from in HolyThemes.all) {
      for (final to in HolyThemes.all.where((t) => t.isDark == from.isDark)) {
        for (final progress in [.25, .5, .75]) {
          _check(HolyTheme.lerp(from, to, progress));
        }
      }
    }
  });
  test('reading ink, secondary text and accent text are legible in every theme',
      () {
    for (final t in HolyThemes.all) {
      for (final ground in [t.paper, t.surface]) {
        expect(_contrast(t.ink, ground), greaterThanOrEqualTo(12),
            reason: '${t.name} ink');
        expect(_contrast(t.muted, ground), greaterThanOrEqualTo(4.5),
            reason: '${t.name} muted');
        expect(_contrast(t.accent, ground), greaterThanOrEqualTo(4.5),
            reason: '${t.name} accent');
      }
      expect(_contrast(t.onPrimary, t.primary), greaterThanOrEqualTo(7),
          reason: '${t.name} primary button');
    }
    // Text on photographs always sits on the dark veil colour.
    expect(_contrast(HolyTheme.photoInk, HolyTheme.photoShade),
        greaterThanOrEqualTo(12));
  });
  test('words set on the moving field stay legible in every theme', () {
    List<Color> colours(MeshTheme m) => [
          ...m.baseColors,
          m.b1Start,
          m.b1End,
          m.b2Start,
          m.b2End,
          m.b3Start,
          m.b3End,
          m.b4Start,
          m.b4Mid,
          m.b4End
        ];
    for (final t in HolyThemes.all) {
      // The full field sits behind the home tabs, where reading happens on
      // cards: body ink keeps normal-text contrast and secondary labels keep
      // the large-text floor wherever a blob drifts.
      for (final ground in colours(SunriseBackground.meshFor(t))) {
        expect(_contrast(t.ink, ground), greaterThanOrEqualTo(4.5),
            reason: '${t.name} ink on the field');
        expect(_contrast(t.muted, ground), greaterThanOrEqualTo(3),
            reason: '${t.name} muted on the field');
      }
      // The calm field sits behind screens that set captions straight on it.
      for (final ground in colours(SunriseBackground.meshFor(t,
          calm: SunriseBackground.calmField))) {
        expect(_contrast(t.ink, ground), greaterThanOrEqualTo(7),
            reason: '${t.name} ink on the calm field');
        expect(_contrast(t.muted, ground), greaterThanOrEqualTo(4.5),
            reason: '${t.name} muted on the calm field');
      }
    }
  });
  testWidgets(
      'HolyButton and HoldButton draw opaque primary fills with tested ink',
      (tester) async {
    for (final theme in HolyThemes.all) {
      for (final opaque in [false, true]) {
        await tester.pumpWidget(MaterialApp(
            theme: HolyThemeData.build(theme),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2),
                    disableAnimations: true),
                child: HolyThemeScope(
                    theme: theme, reduceTransparency: opaque, child: child!)),
            home: Scaffold(
                body: Center(
                    child: SizedBox(
                        width: 320,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          HolyButton('Begin', onPressed: () {}),
                          const SizedBox(height: 20),
                          HoldButton(label: 'Say Amen', onComplete: () {})
                        ]))))));
        await tester.pump();
        for (final type in [HolyButton, HoldButton]) {
          final controls = find.byType(type);
          final fills = tester
              .widgetList(find.descendant(of: controls, matching: find.byWidgetPredicate((w) =>
                  (w is DecoratedBox && w.decoration is ShapeDecoration) ||
                  (w is Container && w.decoration is ShapeDecoration))))
              .map((w) => w is DecoratedBox
                  ? w.decoration as ShapeDecoration
                  : (w as Container).decoration as ShapeDecoration)
              .where((d) => d.color == theme.primary);
          expect(fills, isNotEmpty, reason: '${theme.name} $type fill');
          final label = tester.widget<Text>(
              find.descendant(of: controls, matching: find.byType(Text)).first);
          expect(label.style!.color, theme.onPrimary);
          expect(_contrast(label.style!.color!, theme.primary),
              greaterThanOrEqualTo(4.5));
        }
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
}
