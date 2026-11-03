import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/dev/preview_fixtures.dart';
import 'package:holyher/features/home/home_shell.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('tab shell retains Saved query through URL changes',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final fixture = PreviewFixture('saved:populated');
    final scope = ProviderContainer(overrides: fixture.overrides);
    final router = GoRouter(initialLocation: '/saved', routes: [
      GoRoute(
          path: '/:location(.*)',
          pageBuilder: (context, state) => NoTransitionPage<void>(
              key: const ValueKey('root'),
              child: HomeShell(
                  initialTab: state.uri.path == '/saved'
                      ? 1
                      : state.uri.path == '/profile'
                          ? 2
                          : 0)))
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: scope,
        child:
            MaterialApp.router(theme: buildAppTheme(), routerConfig: router)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    final search = find.byWidgetPredicate((w) =>
        w is TextField && w.decoration?.labelText == 'Search saved lessons');
    expect(search, findsOneWidget);
    await tester.enterText(search, 'quiet');
    await tester.pump();
    router.go('/profile');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    router.go('/saved');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect((tester.widget(search) as TextField).controller?.text, 'quiet');
    await tester.pumpWidget(const SizedBox());
    scope.dispose();
    expect(tester.takeException(), isNull);
  });
}
