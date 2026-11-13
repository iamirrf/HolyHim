// Stand-in providers so real screens render without Firebase or the store.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:holyhim/domain/calendar.dart';
import 'package:holyhim/services/auth_service.dart';
import 'package:holyhim/services/billing.dart';
import 'package:holyhim/services/repository.dart';

class FakeAuth extends AuthNotifier {
  final AuthUser? user;
  final AuthState? fixed;
  FakeAuth(this.user, {this.fixed});
  @override
  AuthState build() => fixed ?? AuthState(user: user);
  @override
  void clearError() {}
}

class FakeRepository extends WalkRepository {
  final WalkState initial;
  FakeRepository(this.initial);
  @override
  WalkState build() => initial;
  @override
  void updateProfile(AppProfile value) =>
      state = state.copyWith(profile: value);
  @override
  void toggleSaved(int day, {DateTime? now}) {}
  @override
  Future<void> finishOnboardingDurably([AppProfile? profile]) async =>
      updateProfile((profile ?? state.profile)
          .copyWith(onboardedAt: DateTime(2026, 11, 4)));
}

class FakeBilling extends LifetimeController {
  final LifetimeState fixed;
  FakeBilling(this.fixed);
  @override
  LifetimeState build() => fixed;
}

const product = StoreProduct('holyhim_lifetime', 'All 365 lessons',
    'HolyHim Lifetime', 1.99, r'$1.99', 'USD');

AppProfile profile(
        {String name = 'Mira Rose',
        bool onboarded = true,
        Map<String, dynamic> draft = const {},
        List<String> hearts = const ['peace', 'hope'],
        String theme = 'blush',
        double readingScale = 1}) =>
    AppProfile(
        name: name,
        theme: theme,
        haptics: false,
        sounds: false,
        readingScale: readingScale,
        timeZone: 'America/New_York',
        reminderEnabled: true,
        reminderMinutes: 420,
        birthday: '1995-06-15',
        hearts: hearts,
        onboardedAt: onboarded ? DateTime(2026, 11, 4) : null,
        onboardingDraft: draft);

/// [read] lessons completed on consecutive days ending yesterday, plus today
/// when [today] is true.
Map<int, String> history(int read, {bool today = false, DateTime? now}) {
  final local = localNow(now ?? DateTime.now(), 'America/New_York');
  final out = <int, String>{};
  final total = read + (today ? 1 : 0);
  for (var i = 0; i < total; i++) {
    final daysAgo = total - i - (today ? 1 : 0);
    out[i + 1] =
        dateKey(DateTime(local.year, local.month, local.day - daysAgo));
  }
  return out;
}

Widget scope(Widget app,
    {WalkState? walk,
    AuthUser? user = const AuthUser(uid: 'review', email: 'mira@example.com'),
    AuthState? auth,
    LifetimeState billing = const LifetimeState(loading: false, product: product)}) {
  return ProviderScope(overrides: [
    authProvider.overrideWith(() => FakeAuth(user, fixed: auth)),
    repositoryProvider.overrideWith(
        () => FakeRepository(walk ?? WalkState(profile: profile()))),
    lifetimeProvider.overrideWith(() => FakeBilling(billing)),
    lastSignInProvider.overrideWith((ref) async => 'apple'),
  ], child: app);
}
