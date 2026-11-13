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

/// An explicit local development override; distributable builds must omit it.
const testingPaywallExit =
    bool.fromEnvironment('HOLYHIM_TESTING_PAYWALL_EXIT', defaultValue: false);
const lifetimeProductId = 'holyhim_lifetime';

class LifetimeState {
  final bool loading, busy, purchased, retained, testingDismissed;
  final StoreProduct? product;
  final String? error;
  final bool verified, revoked;
  const LifetimeState(
      {this.loading = true,
      this.busy = false,
      this.purchased = false,
      this.retained = false,
      this.testingDismissed = false,
      this.verified = false,
      this.revoked = false,
      this.product,
      this.error});
  bool get active => purchased || retained;
  LifetimeState copyWith(
          {bool? loading,
          bool? busy,
          bool? purchased,
          bool? retained,
          bool? testingDismissed,
          bool? verified,
          bool? revoked,
          StoreProduct? product,
          String? error}) =>
      LifetimeState(
          loading: loading ?? this.loading,
          busy: busy ?? this.busy,
          purchased: purchased ?? this.purchased,
          retained: retained ?? this.retained,
          testingDismissed: testingDismissed ?? this.testingDismissed,
          verified: verified ?? this.verified,
          revoked: revoked ?? this.revoked,
          product: product ?? this.product,
          error: error);
}

final lifetimeProvider =
    NotifierProvider<LifetimeController, LifetimeState>(LifetimeController.new);

class LifetimeController extends Notifier<LifetimeState> {
  int _generation = 0;
  String? _uid;
  CustomerInfoUpdateListener? _listener;
  static Future<void> _setup = Future.value();
  @override
  LifetimeState build() {
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
    return LifetimeState(loading: _uid != null);
  }

  Future<void> _configure(String uid) async {
    final key = const String.fromEnvironment('REVENUECAT_IOS_PUBLIC_KEY',
        defaultValue: revenueCatIosPublicKey);
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS || key.isEmpty) {
      throw StateError(
          'Purchases are unavailable on this device. You can continue testing.');
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
      if (info.entitlements.active.containsKey('lifetime')) {
        await _syncAccess();
        await _loadVerifiedAccess(uid, owner);
      }
      final products = await Purchases.getProducts([lifetimeProductId],
          productCategory: ProductCategory.nonSubscription);
      if (owner != _generation) return;
      state = state.copyWith(
          loading: false,
          product: products.isEmpty ? null : products.first,
          error: products.isEmpty
              ? 'The lifetime purchase is unavailable right now. Try again shortly.'
              : null);
    } catch (_) {
      if (owner == _generation) {
        state = state.copyWith(
            loading: false,
            error: 'We could not connect to the App Store. Try again shortly.');
      }
    }
  }

  Future<void> _loadCachedAccess(String uid, int owner) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (owner != _generation) return;
      final value = prefs.getString('holyhim.access.v1.$uid');
      if (value == 'purchased') {
        state = state.copyWith(purchased: true, verified: true);
      } else if (value == 'retained') {
        state = state.copyWith(retained: true, verified: true);
      } else if (value == 'revoked') {
        state = state.copyWith(revoked: true, verified: true);
      } else if (value == 'unowned') {
        state = state.copyWith(verified: true);
      }
    } catch (_) {}
  }

  Future<void> _loadVerifiedAccess(String uid, int owner) async {
    if (Firebase.apps.isEmpty) return;
    try {
      final access = await FirebaseFunctions.instance
          .httpsCallable('getAccessStatus')
          .call<dynamic>();
      if (owner != _generation || access.data is! Map) return;
      final retained = access.data['retained'] == true ||
          access.data['retainedGrant'] == true;
      final purchased = access.data['genuinePurchase'] == true;
      final revoked = !purchased && !retained && state.purchased;
      state = state.copyWith(
          purchased: purchased,
          retained: retained,
          verified: true,
          revoked: revoked);
      final prefs = await SharedPreferences.getInstance();
      if (owner == _generation) {
        await prefs.setString(
            'holyhim.access.v1.$uid',
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

  Future<void> _refreshInfo(String uid, int owner) async {
    // A listener can replay RevenueCat's previous cached payload after logIn.
    // Read the current owner's SDK state rather than trusting that payload.
    try {
      if (owner != _generation || await Purchases.appUserID != uid) return;
      final info = await Purchases.getCustomerInfo();
      if (owner != _generation ||
          await Purchases.appUserID != uid ||
          owner != _generation) {
        return;
      }
      final active = info.entitlements.active.containsKey('lifetime');
      if (active) {
        await _syncAccess();
        await _loadVerifiedAccess(uid, owner);
      }
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

  Future<bool> purchase() async {
    final product = state.product;
    if (product == null || state.busy) return false;
    return _perform(() async =>
        (await Purchases.purchase(PurchaseParams.storeProduct(product)))
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
    final owner = _generation;
    state = state.copyWith(busy: true);
    try {
      final info = await action();
      if (owner != _generation) return false;
      final active = info.entitlements.active.containsKey('lifetime');
      if (active && _uid != null) {
        await _syncAccess();
        await _loadVerifiedAccess(_uid!, owner);
      }
      state = state.copyWith(
          busy: false,
          error: active
              ? null
              : restoring
                  ? 'No lifetime purchase was found for this Apple account.'
                  : 'Your purchase is pending. Access will update when it completes.');
      return state.active;
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

  void dismissForTesting() {
    if (testingPaywallExit) state = state.copyWith(testingDismissed: true);
  }
}
