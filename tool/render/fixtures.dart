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

class FakeBilling extends AccessController {
  final AccessState fixed;
  FakeBilling(this.fixed);
  @override
  AccessState build() => fixed;
}

const _offering = PresentedOfferingContext('default', null, null);

/// The App Store as it will be: one yearly price, with a free week or not.
const trialPlan = MemberPlan(
    Package(
        r'$rc_custom_annual_trial',
        PackageType.custom,
        StoreProduct('holyhim_annual_trial', 'Every lesson, every morning',
            'HolyHim Membership', 1.99, r'$1.99', 'USD',
            introductoryPrice:
                IntroductoryPrice(0, r'$0.00', 'P1W', 1, PeriodUnit.week, 1),
            subscriptionPeriod: 'P1Y',
            pricePerMonthString: r'$0.16'),
        _offering),
    7);
const plainPlan = MemberPlan(
    Package(
        r'$rc_annual',
        PackageType.annual,
        StoreProduct('holyhim_annual', 'Every lesson, every morning',
            'HolyHim Membership', 1.99, r'$1.99', 'USD',
            subscriptionPeriod: 'P1Y', pricePerMonthString: r'$0.16'),
        _offering),
    null);

/// Someone who has not joined yet, with the store's two plans loaded.
const offerState = AccessState(
    loading: false,
    trialPlan: trialPlan,
    plainPlan: plainPlan,
    trialEligible: true);

/// A member in her free week.
final memberState = AccessState(
    loading: false,
    member: true,
    inTrial: true,
    willRenew: true,
    memberUntil: DateTime(2026, 11, 22));

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
    String? lastSignIn = 'apple',
    AccessState billing = offerState}) {
  return ProviderScope(overrides: [
    authProvider.overrideWith(() => FakeAuth(user, fixed: auth)),
    repositoryProvider.overrideWith(
        () => FakeRepository(walk ?? WalkState(profile: profile()))),
    accessProvider.overrideWith(() => FakeBilling(billing)),
    lastSignInProvider.overrideWith((ref) async => lastSignIn),
  ], child: app);
}
