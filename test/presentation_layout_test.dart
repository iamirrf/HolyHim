import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/dev/preview_fixtures.dart';
import 'package:holyher/features/onboarding/checkpoint.dart';

void main() {
  final routes = [
    'welcome',
    'auth',
    'auth:create',
    'reset',
    for (final stage in OnboardingStages.ids) 'onboarding:$stage',
    'learn',
    'saved:empty',
    'saved:populated',
    'saved:error',
    'profile',
    'calendar',
    'settings',
    'name',
    'rhythm',
    'reminder',
    'password',
    'reset-progress',
    'export',
    'help',
    'about',
    'contact',
    'feedback',
    'privacy',
    'terms',
    'lesson:verse',
    'lesson:question-1',
    'lesson:closing:failure',
    'existing:hope'
  ];
  for (final viewport in [
    (const Size(375, 667), 'narrow-phone'),
    (const Size(393, 852), 'reference-phone'),
    (const Size(430, 932), '14-pro-max'),
    (const Size(1024, 1366), 'ipad-portrait'),
    (const Size(1366, 1024), 'ipad-landscape'),
    (const Size(375, 1000), 'ipad-split')
  ]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('${viewport.$2} text $scale reflows every screen family',
          (tester) async {
        tester.view.physicalSize = viewport.$1;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        for (final route in routes) {
          await tester.pumpWidget(const SizedBox());
          final fixture = PreviewFixture(route), screen = fixture.build();
          await tester.pumpWidget(ProviderScope(
              key: UniqueKey(),
              overrides: fixture.overrides,
              child: MaterialApp(
                  theme: buildAppTheme(),
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          disableAnimations: true,
                          textScaler: TextScaler.linear(scale)),
                      child: BlushBackdrop(child: child!)),
                  home: screen)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '$route at ${viewport.$2}, scale $scale');
        }
      });
    }
  }
}
