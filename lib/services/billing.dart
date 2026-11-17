import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'billing_config.dart';

/// The one-time unlock sold before membership. Its owners keep every lesson
/// for life; it is no longer offered.
const lifetimeProductId = 'holyhim_lifetime';
const lifetimeEntitlement = 'lifetime';

/// Membership: one yearly price, with a free week or without. Two products,
/// because whether a trial is on is the store's to decide, product by
/// product.
const memberEntitlement = 'member';
const memberTrialProductId = 'holyhim_annual_trial';
const memberProductId = 'holyhim_annual';

/// Where Apple lets him change or cancel a subscription.
const manageSubscriptionsUrl = 'https://apps.apple.com/account/subscriptions';

/// A way to become a member, exactly as the App Store offers it: its price
/// and its trial come from the store, never from the app.
@immutable
class MemberPlan {
  final Package package;

  /// Days of free trial, or null when this plan has none.
  final int? trialDays;
  const MemberPlan(this.package, this.trialDays);

  factory MemberPlan.of(Package package) =>
      MemberPlan(package, trialDaysOf(package.storeProduct));

  /// The free introductory period, in days. A paid introductory price is not
  /// a free trial and counts as none.
  static int? trialDaysOf(StoreProduct product) {
    final intro = product.introductoryPrice;
    if (intro == null || intro.price > 0) return null;
    final unit = switch (intro.periodUnit) {
      PeriodUnit.day => 1,
      PeriodUnit.week => 7,
      PeriodUnit.month => 30,
      PeriodUnit.year => 365,
      PeriodUnit.unknown => 0,
    };
    final days = unit *
        intro.periodNumberOfUnits *
        (intro.cycles < 1 ? 1 : intro.cycles);
    return days > 0 ? days : null;
  }

  String get productId => package.storeProduct.identifier;

  /// The store's own price string, such as "$1.99".
  String get price => package.storeProduct.priceString.trim();

  /// The yearly price as a month, in the store's own format ("$0.16"), when
  /// the store gives one. Always shown smaller than [price].
  String? get perMonth {
    final value = package.storeProduct.pricePerMonthString?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool get hasTrial => trialDays != null;
}

@immutable
class AccessState {
  final bool loading, busy;

  /// A verified lifetime purchase.
  final bool purchased;

  /// Access kept from the free edition.
  final bool retained;

  /// An active membership, in its free trial or paid.
  final bool member;
  final bool inTrial, willRenew;

  /// When the membership's current period ends.
  final DateTime? memberUntil;
  final bool verified, revoked;

  /// The plan with the free trial, and the plan without it.
  final MemberPlan? trialPlan, plainPlan;

  /// Whether this Apple ID may still take the free trial. Null when the
  /// store could not say.
  final bool? trialEligible;
  final String? error;
  const AccessState(
      {this.loading = true,
      this.busy = false,
      this.purchased = false,
      this.retained = false,
      this.member = false,
      this.inTrial = false,
      this.willRenew = false,
      this.memberUntil,
      this.verified = false,
      this.revoked = false,
      this.trialPlan,
      this.plainPlan,
      this.trialEligible,
      this.error});

  /// Whether every lesson is open to him.
  bool get active => purchased || retained || member;

  /// The trial may be offered: the store has it, and this Apple ID has not
  /// used it.
  bool get canTrial => trialPlan != null && trialEligible != false;

  /// At least one plan can be bought.
  bool get plansReady => trialPlan != null || plainPlan != null;

  AccessState copyWith(
          {bool? loading,
          bool? busy,
          bool? purchased,
          bool? retained,
          bool? member,
          bool? inTrial,
          bool? willRenew,
          Object? memberUntil = _keep,
          bool? verified,
          bool? revoked,
          Object? trialPlan = _keep,
          Object? plainPlan = _keep,
          Object? trialEligible = _keep,
          String? error}) =>
      AccessState(
          loading: loading ?? this.loading,
          busy: busy ?? this.busy,
          purchased: purchased ?? this.purchased,
          retained: retained ?? this.retained,
          member: member ?? this.member,
          inTrial: inTrial ?? this.inTrial,
          willRenew: willRenew ?? this.willRenew,
          memberUntil: identical(memberUntil, _keep)
              ? this.memberUntil
              : memberUntil as DateTime?,
          verified: verified ?? this.verified,
          revoked: revoked ?? this.revoked,
          trialPlan: identical(trialPlan, _keep)
              ? this.trialPlan
              : trialPlan as MemberPlan?,
          plainPlan: identical(plainPlan, _keep)
              ? this.plainPlan
              : plainPlan as MemberPlan?,
          trialEligible: identical(trialEligible, _keep)
              ? this.trialEligible
              : trialEligible as bool?,
          // An error lasts until the next change, as a message should.
          error: error);
}

const _keep = Object();

final accessProvider =
    NotifierProvider<AccessController, AccessState>(AccessController.new);

class AccessController extends Notifier<AccessState> {
  int _generation = 0;
  String? _uid;
  CustomerInfoUpdateListener? _listener;
  static Future<void> _setup = Future.value();
  @override
  AccessState build() {
    _uid = ref.watch(authProvider.select((value) => value.user?.uid));
    final generation = ++_generation;
    ref.onDispose(() {
      ++_generation;
      final listener = _listener;
      if (listener != null) {
        Purchases.removeCustomerInfoUpdateListener(listener);
      }
      _listener = null;
    });
    if (_uid != null) scheduleMicrotask(() => load(generation));
    return AccessState(loading: _uid != null);
  }

  Future<void> _configure(String uid) async {
    final key = const String.fromEnvironment('REVENUECAT_IOS_PUBLIC_KEY',
        defaultValue: revenueCatIosPublicKey);
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS || key.isEmpty) {
      throw StateError('Purchases are unavailable on this device.');
    }
    _setup = _setup.catchError((Object _) {}).then((_) async {
      if (!await Purchases.isConfigured) {
        await Purchases.configure(PurchasesConfiguration(key)..appUserID = uid);
      } else if (await Purchases.appUserID != uid) {
        await Purchases.logIn(uid);
      }
    });
    await _setup;
  }

  Future<void> load([int? generation]) async {
    final owner = generation ?? _generation, uid = _uid;
    if (uid == null) return;
    state = state.copyWith(loading: true);
    await _loadCachedAccess(uid, owner);
    await _loadVerifiedAccess(uid, owner);
    try {
      await _configure(uid);
      if (owner != _generation) return;
      _listener ??= (_) => unawaited(_refreshInfo(uid, owner));
      Purchases.addCustomerInfoUpdateListener(_listener!);
      final info = await Purchases.getCustomerInfo();
      if (owner != _generation) return;
      await _apply(info, uid, owner);
      if (owner != _generation) return;
      final offerings = await Purchases.getOfferings();
      if (owner != _generation) return;
      final packages = [
        ...?offerings.current?.availablePackages,
        // A package can live in another offering while the store is set
        // up; the products are what matter.
        for (final o in offerings.all.values)
          if (o != offerings.current) ...o.availablePackages,
      ];
      MemberPlan? plan(String productId) {
        for (final p in packages) {
          if (p.storeProduct.identifier == productId) return MemberPlan.of(p);
        }
        return null;
      }

      final trial = plan(memberTrialProductId), plain = plan(memberProductId);
      final eligible =
          trial != null && trial.hasTrial ? await _trialEligibility() : false;
      if (owner != _generation) return;
      final available = (trial?.hasTrial ?? false) || plain != null;
      state = state.copyWith(
          loading: false,
          trialPlan: trial != null && trial.hasTrial ? trial : null,
          plainPlan: plain ?? (trial != null && !trial.hasTrial ? trial : null),
          trialEligible: eligible,
          error: available
              ? null
              : 'Membership is unavailable right now. Try again shortly.');
    } catch (_) {
      if (owner == _generation) {
        state = state.copyWith(
            loading: false,
            // The web has no App Store: membership begins on his iPhone.
            error: kIsWeb
                ? 'Membership begins in the HolyHim app on iPhone. Then sign in here with the same account.'
                : 'We could not connect to the App Store. Try again shortly.');
      }
    }
  }

  /// Whether this Apple ID can still take the free week. Null if unknown.
  Future<bool?> _trialEligibility() async {
    try {
      final result = await Purchases.checkTrialOrIntroductoryPriceEligibility(
          [memberTrialProductId]);
      return switch (result[memberTrialProductId]?.status) {
        IntroEligibilityStatus.introEligibilityStatusEligible => true,
        IntroEligibilityStatus.introEligibilityStatusIneligible ||
        IntroEligibilityStatus.introEligibilityStatusNoIntroOfferExists =>
          false,
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  String _cacheKey(String uid) => 'holyhim.access.v1.$uid';
  String _memberKey(String uid) => 'holyhim.member.v1.$uid';

  Future<void> _loadCachedAccess(String uid, int owner) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (owner != _generation) return;
      final value = prefs.getString(_cacheKey(uid));
      if (value == 'purchased') {
        state = state.copyWith(purchased: true, verified: true);
      } else if (value == 'retained') {
        state = state.copyWith(retained: true, verified: true);
      } else if (value == 'revoked') {
        state = state.copyWith(revoked: true, verified: true);
      } else if (value == 'unowned') {
        state = state.copyWith(verified: true);
      }
      // A membership seen before stays open offline until its period ends.
      final until = DateTime.tryParse(prefs.getString(_memberKey(uid)) ?? '');
      if (until != null && until.isAfter(DateTime.now())) {
        state = state.copyWith(member: true, memberUntil: until);
      }
    } catch (_) {}
  }

  Future<void> _cacheMember(String uid, int owner, DateTime? until) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (owner != _generation) return;
      if (until == null) {
        await prefs.remove(_memberKey(uid));
      } else {
        await prefs.setString(_memberKey(uid), until.toUtc().toIso8601String());
      }
    } catch (_) {}
  }

  Future<void> _loadVerifiedAccess(String uid, int owner) async {
    if (Firebase.apps.isEmpty) return;
    try {
      // Bounded, so a poor connection holds the gate for seconds, not a
      // minute; the store and the cache decide meanwhile.
      final access = await FirebaseFunctions.instance
          .httpsCallable('getAccessStatus',
              options:
                  HttpsCallableOptions(timeout: const Duration(seconds: 10)))
          .call<dynamic>();
      if (owner != _generation || access.data is! Map) return;
      final retained = access.data['retained'] == true ||
          access.data['retainedGrant'] == true;
      // The server reports what kind of access it verified. An older server
      // knew only the lifetime unlock.
      final kind = access.data['kind'] ?? 'lifetime';
      final genuine = access.data['genuinePurchase'] == true;
      final purchased = genuine && kind == 'lifetime';
      final revoked = !purchased && !retained && state.purchased;
      state = state.copyWith(
          purchased: purchased,
          retained: retained,
          member: genuine && kind == 'member' ? true : null,
          verified: true,
          revoked: revoked);
      final prefs = await SharedPreferences.getInstance();
      if (owner == _generation) {
        await prefs.setString(
            _cacheKey(uid),
            purchased
                ? 'purchased'
                : retained
                    ? 'retained'
                    : revoked
                        ? 'revoked'
                        : 'unowned');
      }
    } catch (_) {
      // A network failure does not invent or revoke a known access grant.
    }
  }

  /// Reads what the store says this account holds. A lifetime unlock is
  /// confirmed by the server before it counts; a membership is the store's
  /// own word for the signed-in account, and is kept for offline use until
  /// its period ends.
  Future<void> _apply(CustomerInfo info, String uid, int owner) async {
    final active = info.entitlements.active;
    if (active.containsKey(lifetimeEntitlement)) {
      await _syncAccess();
      await _loadVerifiedAccess(uid, owner);
    }
    if (owner != _generation) return;
    final membership = active[memberEntitlement];
    final until = DateTime.tryParse(membership?.expirationDate ?? '');
    state = state.copyWith(
        member: membership != null,
        inTrial: membership?.periodType == PeriodType.trial,
        willRenew: membership?.willRenew ?? false,
        memberUntil: until);
    await _cacheMember(uid, owner, membership == null ? null : until);
    // The server keeps its own record, for the next device he signs in on.
    if (membership != null) unawaited(_syncAccess());
  }

  Future<void> _refreshInfo(String uid, int owner) async {
    // A listener can replay RevenueCat's previous cached payload after logIn.
    // Read the current owner's SDK state rather than trusting that payload.
    try {
      if (owner != _generation || await Purchases.appUserID != uid) return;
      final info = await Purchases.getCustomerInfo();
      if (owner != _generation || await Purchases.appUserID != uid) return;
      await _apply(info, uid, owner);
    } catch (_) {/* The next foreground refresh can retry the store. */}
  }

  Future<void> _syncAccess() async {
    if (Firebase.apps.isEmpty) return;
    await FirebaseFunctions.instance
        .httpsCallable('syncAccess')
        .call<void>()
        .then<void>((_) {})
        .catchError((Object _) {});
  }

  /// Starts the trial or the subscription in [plan].
  Future<bool> purchase(MemberPlan plan) async {
    if (state.busy) return false;
    return _perform(() async =>
        (await Purchases.purchase(PurchaseParams.package(plan.package)))
            .customerInfo);
  }

  Future<bool> restore() async {
    if (state.busy || _uid == null) return false;
    return _perform(() async {
      await _configure(_uid!);
      return Purchases.restorePurchases();
    }, restoring: true);
  }

  Future<bool> _perform(Future<CustomerInfo> Function() action,
      {bool restoring = false}) async {
    final owner = _generation, uid = _uid;
    state = state.copyWith(busy: true);
    try {
      final info = await action();
      if (owner != _generation || uid == null) return false;
      await _apply(info, uid, owner);
      if (owner != _generation) return false;
      final ok = state.active;
      state = state.copyWith(
          busy: false,
          error: ok
              ? null
              : restoring
                  ? 'No membership or purchase was found for this Apple ID.'
                  : 'Your purchase is pending. Access will update when it completes.');
      return ok;
    } on PlatformException catch (e) {
      if (owner != _generation) return false;
      final code = PurchasesErrorHelper.getErrorCode(e);
      state = state.copyWith(
          busy: false,
          error: code == PurchasesErrorCode.purchaseCancelledError
              ? null
              : code == PurchasesErrorCode.paymentPendingError
                  ? 'Your purchase is awaiting approval.'
                  : 'The purchase could not finish. Please try again.');
      return false;
    } catch (_) {
      if (owner == _generation) {
        state = state.copyWith(
            busy: false,
            error: 'The App Store is unavailable. Please try again.');
      }
      return false;
    }
  }
}
