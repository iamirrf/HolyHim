import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/features/common.dart';

double _contrast(Color a, Color b) {
  final light = math.max(a.computeLuminance(), b.computeLuminance());
  final dark = math.min(a.computeLuminance(), b.computeLuminance());
  return (light + .05) / (dark + .05);
}

void _check(HolyTheme theme) {
  for (var step = 0; step <= 20; step++) {
    final background = Color.lerp(
        theme.buttonGradient.first, theme.buttonGradient.last, step / 20)!;
    expect(background.a, 1,
        reason: 'Primary controls must not depend on the art behind them.');
    expect(_contrast(theme.buttonInk, background), greaterThanOrEqualTo(4.5),
        reason: '${theme.name} at gradient position $step');
    for (final progress in [0.0, .5, 1.0]) {
      final fill = Color.alphaBlend(
          theme.holdFill.withValues(alpha: theme.holdFill.a * progress),
          background);
      expect(_contrast(theme.buttonInk, fill), greaterThanOrEqualTo(4.5),
          reason: '${theme.name} while holding');
    }
  }
}

void main() {
  test(
      'primary labels keep normal-text contrast in every theme and during live theme changes',
      () {
    for (final theme in HolyThemes.all) {
      _check(theme);
    }
    for (final from in HolyThemes.all) {
      for (final to in HolyThemes.all) {
        for (final progress in [.25, .5, .75]) {
          _check(HolyTheme.lerp(from, to, progress));
        }
      }
    }
  });
  testWidgets(
      'Action and Hold render opaque contrast-tested tokens with either transparency preference',
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
                          ActionButton('Begin', onPressed: () {}),
                          const SizedBox(height: 20),
                          HoldButton(label: 'Say Amen', onComplete: () {})
                        ]))))));
        await tester.pump();
        for (final type in [ActionButton, HoldButton]) {
          final controls = find.byType(type);
          final decorated = find.descendant(
              of: controls,
              matching: find.byWidgetPredicate((widget) =>
                  widget is Container &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration).gradient != null));
          final decoration =
              tester.widget<Container>(decorated).decoration as BoxDecoration;
          expect((decoration.gradient! as LinearGradient).colors,
              theme.buttonGradient);
          final label = tester.widget<Text>(
              find.descendant(of: controls, matching: find.byType(Text)).first);
          expect(label.style!.color, theme.buttonInk);
          for (final background in decoration.gradient!.colors) {
            expect(_contrast(label.style!.color!, background),
                greaterThanOrEqualTo(4.5));
          }
        }
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
}
