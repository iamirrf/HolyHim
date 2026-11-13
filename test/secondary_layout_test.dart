import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/services/repository.dart';
import 'package:holyhim/services/auth_service.dart';
import 'package:holyhim/features/saved/saved_screen.dart';
import 'package:holyhim/features/growth/growth_screen.dart';
import 'package:holyhim/features/profile/profile_screen.dart';
import 'package:holyhim/features/support/support_screen.dart';

class FakeRepository extends WalkRepository {
  @override
  WalkState build() => WalkState(
      profile: AppProfile(name: 'Amelia', onboardedAt: DateTime.now()),
      completed: {1: '2026-11-01', 2: '2026-11-02'},
      saved: {1: DateTime(2026, 11, 1)});
}

class FakeAuth extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(user: AuthUser(uid: 'test', email: 'amelia@example.com'));
  void switchAccount() =>
      state = const AuthState(user: AuthUser(uid: 'second'));
}

Widget _secondaryApp(ProviderContainer container, Widget screen) =>
    UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: HolyThemeData.build(HolyThemes.charcoal),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2),
                    disableAnimations: true),
                child: Atmosphere(theme: HolyThemes.charcoal, child: child!)),
            home: screen));

void main() {
  for (final switchAccount in [false, true]) {
    testWidgets(
        'saved removal undo respects account identity: switch=$switchAccount',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(overrides: [
        repositoryProvider.overrideWith(FakeRepository.new),
        authProvider.overrideWith(FakeAuth.new)
      ]);
      addTearDown(container.dispose);
      addTearDown(GlassToast.dismiss);
      await tester.pumpWidget(_secondaryApp(container, const SavedScreen()));
      await tester.pump();
      await tester.ensureVisible(find.text('Deuteronomy 31:6'));
      await tester.tap(find.text('Deuteronomy 31:6'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Remove from Saved'));
      await tester.tap(find.text('Remove from Saved'));
      await tester.pumpAndSettle();
      expect(container.read(repositoryProvider).saved, isEmpty);
      expect(find.text('Undo'), findsOneWidget);
      if (switchAccount) {
        (container.read(authProvider.notifier) as FakeAuth).switchAccount();
        await tester.pump();
      }
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(container.read(repositoryProvider).saved.containsKey(1),
          !switchAccount);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
      'the adaptive destructive confirmation can be cancelled at200percent',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(overrides: [
      repositoryProvider.overrideWith(FakeRepository.new),
      authProvider.overrideWith(FakeAuth.new)
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(_secondaryApp(container, const ProfileScreen()));
    await tester.pump();
    await Scrollable.ensureVisible(tester.element(find.text('Settings')), alignment: .5);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(find.text('Delete account')), alignment: .5);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your HolyHim account?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(repositoryProvider).completed.length, 2);
    expect(container.read(authProvider).user?.uid, 'test');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final entry in <String, Widget>{
    'saved': const SavedScreen(),
    'growth': const GrowthScreen(),
    'profile': const ProfileScreen(),
    'support': const SupportScreen(),
    'widget': const WidgetGuideScreen()
  }.entries) {
    testWidgets('${entry.key} handles 200 percent text and reduced motion',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            repositoryProvider.overrideWith(FakeRepository.new),
            authProvider.overrideWith(FakeAuth.new)
          ],
          child: MaterialApp(
              theme: HolyThemeData.build(HolyThemes.charcoal),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: const TextScaler.linear(2),
                      disableAnimations: true),
                  child: Atmosphere(theme: HolyThemes.charcoal, child: child!)),
              home: entry.value)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      if (entry.key == 'saved') {
        await tester.tap(find.byTooltip('Search saved verses'));
        await tester.pump();
        await tester.enterText(find.byType(EditableText), 'Deuteronomy');
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      final scrolling = find.byType(SingleChildScrollView).first;
      for (var i = 0; i < 6; i++) {
        await tester.drag(scrolling, const Offset(0, -650));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
