import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/constants/app_constants.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

class PurchaseState {
  final bool loading, configured;
  final String price;
  final String? error;
  const PurchaseState({
    this.loading = false,
    this.configured = false,
    this.price = AppConstants.lifetimePriceLabel,
    this.error,
  });
}

final purchaseProvider =
    StateProvider<PurchaseState>((ref) => const PurchaseState());

/// Store results carry the current SDK identity, never the original alias ID.
class BillingCustomer {
  final String uid;
  final bool lifetimeActive;
  const BillingCustomer({required this.uid, required this.lifetimeActive});
}

class LifetimeOffer {
  final String price;
  final Object? storePackage;
  const LifetimeOffer({required this.price, this.storePackage});
}

enum BillingFailureKind { cancelled, pending, unavailable, failed }

class BillingFailure implements Exception {
  final BillingFailureKind kind;
  const BillingFailure(this.kind);
}

abstract interface class BillingGateway {
  bool get available;
  Stream<BillingCustomer> get updates;
  Future<BillingCustomer> customerInfo(String uid);
  Future<LifetimeOffer?> lifetimeOffer(String uid);
  Future<BillingCustomer> purchase(String uid, LifetimeOffer offer);
  Future<BillingCustomer> restore(String uid);
  void dispose();
}

/// Configuration and native operations are serialized because RevenueCat's
/// identity is process-wide. A late response for A cannot be applied to B.
class RevenueCatBillingGateway implements BillingGateway {
  final _updates = StreamController<BillingCustomer>.broadcast();
  Future<void> _tail = Future.value();
  String? _identity;
  bool _listening = false, _closed = false;

  @override
  bool get available =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      AppConstants.revenueCatIosKey.isNotEmpty;
  @override
  Stream<BillingCustomer> get updates => _updates.stream;

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> _identify(String uid) async {
    if (!available || _closed) {
      throw const BillingFailure(BillingFailureKind.unavailable);
    }
    if (!await rc.Purchases.isConfigured) {
      await rc.Purchases.configure(
        rc.PurchasesConfiguration(AppConstants.revenueCatIosKey)
          ..appUserID = uid
          ..automaticDeviceIdentifierCollectionEnabled = false,
      );
    } else if (await rc.Purchases.appUserID != uid) {
      await rc.Purchases.logIn(uid);
    }
    _identity = uid;
    if (!_listening) {
      _listening = true;
      rc.Purchases.addCustomerInfoUpdateListener(_forward);
    }
  }

  BillingCustomer _map(String uid, rc.CustomerInfo info) {
    final entitlement = info.entitlements.active[AppConstants.entitlementId];
    return BillingCustomer(
      uid: uid,
      lifetimeActive: entitlement?.productIdentifier == AppConstants.productId,
    );
  }

  void _forward(rc.CustomerInfo info) {
    final uid = _identity;
    if (uid == null || _closed) return;
    unawaited(_serial(() async {
      if (_closed || _identity != uid) return;
      if (await rc.Purchases.appUserID != uid || _closed) return;
      _updates.add(_map(uid, info));
    }).catchError((Object _) {}));
  }

  Future<T> _forUser<T>(String uid, Future<T> Function() action) =>
      _serial(() async {
        try {
          await _identify(uid);
          return await action();
        } on PlatformException catch (error) {
          final code = rc.PurchasesErrorHelper.getErrorCode(error);
          throw BillingFailure(switch (code) {
            rc.PurchasesErrorCode.purchaseCancelledError =>
              BillingFailureKind.cancelled,
            rc.PurchasesErrorCode.paymentPendingError =>
              BillingFailureKind.pending,
            rc.PurchasesErrorCode.networkError =>
              BillingFailureKind.unavailable,
            _ => BillingFailureKind.failed,
          });
        }
      });

  @override
  Future<BillingCustomer> customerInfo(String uid) => _forUser(
      uid, () async => _map(uid, await rc.Purchases.getCustomerInfo()));

  @override
  Future<LifetimeOffer?> lifetimeOffer(String uid) => _forUser(uid, () async {
        final offerings = await rc.Purchases.getOfferings();
        for (final package
            in offerings.current?.availablePackages ?? <rc.Package>[]) {
          if (package.storeProduct.identifier == AppConstants.productId) {
            return LifetimeOffer(
                price: package.storeProduct.priceString, storePackage: package);
          }
        }
        return null;
      });

  @override
  Future<BillingCustomer> purchase(String uid, LifetimeOffer offer) =>
      _forUser(uid, () async {
        final package = offer.storePackage;
        if (package is! rc.Package) {
          throw const BillingFailure(BillingFailureKind.unavailable);
        }
        final result =
            await rc.Purchases.purchase(rc.PurchaseParams.package(package));
        return _map(uid, result.customerInfo);
      });

  @override
  Future<BillingCustomer> restore(String uid) => _forUser(
      uid, () async => _map(uid, await rc.Purchases.restorePurchases()));

  @override
  void dispose() {
    _closed = true;
    if (_listening) rc.Purchases.removeCustomerInfoUpdateListener(_forward);
    unawaited(_updates.close());
  }
}

final billingGatewayProvider = Provider<BillingGateway>((ref) {
  final gateway = RevenueCatBillingGateway();
  ref.onDispose(gateway.dispose);
  return gateway;
});

/// Only an inability to contact the server permits an offline fallback.
/// A negative server decision, authentication failure, or invalid response does
/// not become a positive purchase merely because a journey was cached.
class PurchaseAccessUnavailable implements Exception {
  const PurchaseAccessUnavailable();
}

abstract interface class PurchaseAccessGateway {
  Future<bool> syncAccess(String uid);
  Future<bool> hasStartedJourney(String uid);
  Future<void> startJourney(String uid);
}

class _FirebasePurchaseAccess implements PurchaseAccessGateway {
  final Ref ref;
  _FirebasePurchaseAccess(this.ref);
  void _checkUser(String uid) {
    if (ref.read(authProvider).user?.uid != uid ||
        (Firebase.apps.isNotEmpty &&
            fb.FirebaseAuth.instance.currentUser?.uid != uid)) {
      throw StateError('The signed-in account changed.');
    }
  }

  Future<T> _request<T>(String uid, Future<T> Function() action) async {
    _checkUser(uid);
    if (Firebase.apps.isEmpty) throw StateError('Firebase is not configured.');
    try {
      final result = await action().timeout(const Duration(seconds: 12));
      _checkUser(uid);
      return result;
    } on TimeoutException {
      throw const PurchaseAccessUnavailable();
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        throw const PurchaseAccessUnavailable();
      }
      rethrow;
    }
  }

  @override
  Future<bool> syncAccess(String uid) => _request(uid, () async {
        final result = await FirebaseFunctions.instance
            .httpsCallable('syncAccess')
            .call<Map<String, dynamic>>();
        final active = result.data['active'];
        if (active is! bool) throw StateError('Invalid purchase confirmation.');
        return active;
      });

  @override
  Future<bool> hasStartedJourney(String uid) async {
    _checkUser(uid);
    await ref.read(progressProvider.notifier).initialize();
    _checkUser(uid);
    return ref.read(progressProvider).journeyStarted;
  }

  @override
  Future<void> startJourney(String uid) =>
      _request(uid, () => ref.read(progressProvider.notifier).startJourney());
}

final purchaseAccessGatewayProvider =
    Provider<PurchaseAccessGateway>((ref) => _FirebasePurchaseAccess(ref));

class PaywallNotifier extends Notifier<bool> {
  Future<void>? _initializing, _refreshing, _offeringLoad;
  Future<bool>? _operation;
  StreamSubscription<BillingCustomer>? _subscription;
  LifetimeOffer? _offer;
  String? _uid, _error;
  String _price = AppConstants.lifetimePriceLabel;
  int _generation = 0, _evidence = 0;
  bool _checking = false, _loadingOffer = false, _working = false;
  bool _authoritativeDenial = false;
  static const _storeTimeout = Duration(seconds: 8);

  @override
  bool build() {
    _uid = ref.watch(authProvider.select((s) => s.user?.uid));
    ref.watch(billingGatewayProvider);
    ref.watch(purchaseAccessGatewayProvider);
    final generation = ++_generation;
    _subscription?.cancel();
    _initializing = _refreshing = _offeringLoad = null;
    _operation = null;
    _offer = null;
    _error = null;
    _price = AppConstants.lifetimePriceLabel;
    _checking = _loadingOffer = _working = _authoritativeDenial = false;
    _evidence++;
    ref.onDispose(() {
      _generation++;
      _subscription?.cancel();
    });
    Future.microtask(() {
      if (_generation == generation) unawaited(initialize());
    });
    return false;
  }

  bool _current(int generation, String uid) =>
      _generation == generation && _uid == uid;

  void _publish() {
    ref.read(purchaseProvider.notifier).state = PurchaseState(
      loading: _checking || _loadingOffer || _working,
      configured: _offer != null,
      price: _price,
      error: _error,
    );
  }

  /// Starts bounded store work in the background. Account/profile onboarding
  /// never waits on StoreKit product network requests during app bootstrap.
  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    final uid = _uid;
    final generation = _generation;
    final billing = ref.read(billingGatewayProvider);
    if (uid == null || !billing.available) {
      _error =
          'Purchases are temporarily unavailable. Please try again shortly.';
      _publish();
      return;
    }
    _subscription = billing.updates.listen((info) {
      if (_current(generation, uid) && info.uid == uid) {
        unawaited(_acceptCustomer(info, generation));
      }
    });
    _beginRefresh(generation, uid);
    unawaited(_loadOffer(generation, uid));
  }

  void _beginRefresh(int generation, String uid) {
    if (_refreshing != null) return;
    final task = _refreshCustomer(generation, uid);
    _refreshing = task;
    unawaited(task.whenComplete(() {
      if (_current(generation, uid) && identical(_refreshing, task)) {
        _refreshing = null;
      }
    }));
  }

  Future<void> refresh() async {
    await initialize();
    final uid = _uid;
    if (uid == null || !ref.read(billingGatewayProvider).available) return;
    _beginRefresh(_generation, uid);
    await _refreshing;
  }

  Future<void> _refreshCustomer(int generation, String uid) async {
    _checking = true;
    _publish();
    try {
      final info = await ref
          .read(billingGatewayProvider)
          .customerInfo(uid)
          .timeout(_storeTimeout);
      if (_current(generation, uid)) await _acceptCustomer(info, generation);
    } catch (_) {
      if (_current(generation, uid) && !state) {
        _error = 'We could not check your purchase. Reconnect and try again.';
      }
    } finally {
      if (_current(generation, uid)) {
        _checking = false;
        _publish();
      }
    }
  }

  Future<void> _loadOffer(int generation, String uid) {
    if (_offeringLoad != null) return _offeringLoad!;
    final task = _fetchOffer(generation, uid);
    _offeringLoad = task;
    return task.whenComplete(() {
      if (_current(generation, uid) && identical(_offeringLoad, task)) {
        _offeringLoad = null;
      }
    });
  }

  Future<void> _fetchOffer(int generation, String uid) async {
    _loadingOffer = true;
    _publish();
    try {
      final offer = await ref
          .read(billingGatewayProvider)
          .lifetimeOffer(uid)
          .timeout(_storeTimeout);
      if (!_current(generation, uid)) return;
      _offer = offer;
      if (offer != null) _price = offer.price;
    } catch (_) {
      // Product loading is independent from cached receipt/access loading.
    } finally {
      if (_current(generation, uid)) {
        _loadingOffer = false;
        _publish();
      }
    }
  }

  Future<bool> _acceptCustomer(BillingCustomer info, int generation) async {
    final uid = info.uid;
    if (!_current(generation, uid)) return false;
    final evidence = ++_evidence;
    if (!info.lifetimeActive) {
      _authoritativeDenial = true;
      state = false;
      _publish();
      return false;
    }
    final access = ref.read(purchaseAccessGatewayProvider);
    bool stillCurrent() => _current(generation, uid) && _evidence == evidence;
    try {
      final active = await access.syncAccess(uid);
      if (!stillCurrent()) return false;
      if (!active) {
        _authoritativeDenial = true;
        state = false;
        _error =
            'Your lifetime purchase is not active. Please restore purchases.';
        _publish();
        return false;
      }
      _authoritativeDenial = false;
      final started = await access.hasStartedJourney(uid);
      if (!stillCurrent()) return false;
      if (!started) await access.startJourney(uid);
      if (!stillCurrent()) return false;
      state = true;
      _error = null;
      _publish();
      return true;
    } on PurchaseAccessUnavailable {
      if (!stillCurrent()) return false;
      // This branch is never reached for an explicit negative server response.
      try {
        if (!_authoritativeDenial && await access.hasStartedJourney(uid)) {
          if (!stillCurrent()) return false;
          state = true;
          _error = null;
          _publish();
          return true;
        }
      } catch (_) {
        // An unreadable cache is not evidence of an established journey.
      }
    } catch (_) {
      if (!stillCurrent()) return false;
    }
    if (stillCurrent()) {
      state = false;
      _error =
          'Your purchase is saved. Reconnect and restore purchases to finish '
          'setting up your journey.';
      _publish();
    }
    return false;
  }

  void clearError() {
    _error = null;
    _publish();
  }

  Future<bool> unlock() => _operate(restoring: false);
  Future<bool> restore() => _operate(restoring: true);
  Future<bool> _operate({required bool restoring}) {
    if (_operation != null) return _operation!;
    final generation = _generation;
    final task = _perform(
        restoring: restoring, generation: generation, expectedUid: _uid);
    _operation = task;
    return task.whenComplete(() {
      if (_generation == generation && identical(_operation, task)) {
        _operation = null;
      }
    });
  }

  Future<bool> _perform({
    required bool restoring,
    required int generation,
    required String? expectedUid,
  }) async {
    await initialize();
    final uid = expectedUid;
    if (uid == null || !_current(generation, uid)) return false;
    final billing = ref.read(billingGatewayProvider);
    if (!billing.available) return false;
    _working = true;
    _error = null;
    _publish();
    try {
      BillingCustomer info;
      if (restoring) {
        info = await billing.restore(uid).timeout(_storeTimeout);
      } else {
        if (_offer == null) await _loadOffer(generation, uid);
        if (!_current(generation, uid)) return false;
        final offer = _offer;
        if (offer == null) {
          _error =
              'The App Store could not load this purchase. Please try again.';
          return false;
        }
        info = await billing.purchase(uid, offer);
      }
      if (!_current(generation, uid)) return false;
      final accepted = await _acceptCustomer(info, generation);
      if (!_current(generation, uid)) return false;
      if (restoring && !info.lifetimeActive) {
        _error = 'No lifetime purchase was found for this Apple Account.';
      }
      return accepted;
    } on BillingFailure catch (error) {
      if (!_current(generation, uid)) return false;
      _error = switch (error.kind) {
        BillingFailureKind.cancelled => null,
        BillingFailureKind.pending =>
          'Your purchase is awaiting approval. Your access will update when it '
              'is approved.',
        BillingFailureKind.unavailable =>
          'We could not reach the App Store. Please reconnect and try again.',
        BillingFailureKind.failed =>
          'Your purchase could not finish. Please try again or restore purchases.',
      };
      return false;
    } catch (_) {
      if (_current(generation, uid)) {
        _error = restoring
            ? 'We could not restore right now. Please reconnect and try again.'
            : 'Your purchase could not finish. Please try again.';
      }
      return false;
    } finally {
      if (_current(generation, uid)) {
        _working = false;
        _publish();
      }
    }
  }
}

final paywallProvider =
    NotifierProvider<PaywallNotifier, bool>(PaywallNotifier.new);
