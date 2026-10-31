import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/paywall_service.dart';

class _Auth extends AuthNotifier {
  final String? initialUid;
  _Auth(this.initialUid);
  @override
  AuthState build() =>
      AuthState(user: initialUid == null ? null : AuthUser(uid: initialUid!));
  void select(String? uid) =>
      state = AuthState(user: uid == null ? null : AuthUser(uid: uid));
}

class _Billing implements BillingGateway {
  final events = StreamController<BillingCustomer>.broadcast();
  final customers = <String, bool>{};
  final customerRequests = <String>[];
  final purchases = <String>[];
  final restores = <String>[];
  Future<BillingCustomer> Function(String)? onCustomer;
  Future<LifetimeOffer?> Function(String)? onOffer;
  BillingFailure? purchaseFailure;
  bool restored = false;
  @override
  bool available = true;
  @override
  Stream<BillingCustomer> get updates => events.stream;
  @override
  Future<BillingCustomer> customerInfo(String uid) async {
    customerRequests.add(uid);
    if (onCustomer != null) return onCustomer!(uid);
    return BillingCustomer(uid: uid, lifetimeActive: customers[uid] ?? false);
  }

  @override
  Future<LifetimeOffer?> lifetimeOffer(String uid) async {
    if (onOffer != null) return await onOffer!(uid);
    return const LifetimeOffer(price: '£1.99');
  }

  @override
  Future<BillingCustomer> purchase(String uid, LifetimeOffer offer) async {
    purchases.add(uid);
    if (purchaseFailure != null) throw purchaseFailure!;
    return BillingCustomer(uid: uid, lifetimeActive: true);
  }

  @override
  Future<BillingCustomer> restore(String uid) async {
    restores.add(uid);
    return BillingCustomer(uid: uid, lifetimeActive: restored);
  }

  void emit(String uid, {required bool active}) =>
      events.add(BillingCustomer(uid: uid, lifetimeActive: active));
  @override
  void dispose() => unawaited(events.close());
}

class _Access implements PurchaseAccessGateway {
  final started = <String>{};
  final confirmations = <String>[];
  final starts = <String>[];
  bool active = true;
  Object? error;
  Future<bool> Function(String)? onSync;
  @override
  Future<bool> syncAccess(String uid) async {
    confirmations.add(uid);
    if (onSync != null) return onSync!(uid);
    if (error != null) throw error!;
    return active;
  }

  @override
  Future<bool> hasStartedJourney(String uid) async => started.contains(uid);
  @override
  Future<void> startJourney(String uid) async {
    starts.add(uid);
    started.add(uid);
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _Billing billing;
  late _Access access;
  late ProviderContainer container;

  void create({String? uid = 'alice'}) {
    billing = _Billing();
    access = _Access();
    container = ProviderContainer(overrides: [
      authProvider.overrideWith(() => _Auth(uid)),
      billingGatewayProvider.overrideWithValue(billing),
      purchaseAccessGatewayProvider.overrideWithValue(access),
    ]);
    addTearDown(() {
      container.dispose();
      billing.dispose();
    });
  }

  Future<PaywallNotifier> load() async {
    final service = container.read(paywallProvider.notifier);
    await service.initialize();
    await service.refresh();
    await _settle();
    return service;
  }

  test('cached paid access opens offline independently of product loading',
      () async {
    create();
    billing.customers['alice'] = true;
    access.started.add('alice');
    access.error = const PurchaseAccessUnavailable();
    final offer = Completer<LifetimeOffer?>();
    billing.onOffer = (_) => offer.future;
    final service = container.read(paywallProvider.notifier);
    await service.initialize();
    await service.refresh();
    expect(container.read(paywallProvider), isTrue);
    expect(container.read(purchaseProvider).configured, isFalse);
    expect(access.starts, isEmpty);
    offer.completeError(StateError('Offline product catalog'));
    await _settle();
    expect(container.read(paywallProvider), isTrue);
    expect(container.read(purchaseProvider).loading, isFalse);
  });

  test('bootstrap returns before an unresolved store request', () async {
    create();
    final customer = Completer<BillingCustomer>();
    billing.onCustomer = (_) => customer.future;
    await container.read(paywallProvider.notifier).initialize();
    expect(container.read(purchaseProvider).loading, isTrue);
    customer
        .complete(const BillingCustomer(uid: 'alice', lifetimeActive: false));
    await _settle();
    expect(container.read(purchaseProvider).loading, isFalse);
  });

  test('negative server decision cannot fall back to a cached journey',
      () async {
    create();
    billing.customers['alice'] = true;
    access.started.add('alice');
    access.active = false;
    final service = await load();
    expect(container.read(paywallProvider), isFalse);
    expect(container.read(purchaseProvider).error, contains('not active'));
    access.error = const PurchaseAccessUnavailable();
    await service.refresh();
    expect(container.read(paywallProvider), isFalse);
  });

  test('authentication or validation errors never grant offline access',
      () async {
    create();
    billing.customers['alice'] = true;
    access.started.add('alice');
    access.error = StateError('Permission denied');
    await load();
    expect(container.read(paywallProvider), isFalse);
  });

  test('pending purchase approval updates access without relaunch or restore',
      () async {
    create();
    final service = await load();
    billing.purchaseFailure = const BillingFailure(BillingFailureKind.pending);
    expect(await service.unlock(), isFalse);
    expect(
        container.read(purchaseProvider).error, contains('awaiting approval'));
    billing.emit('alice', active: true);
    await _settle();
    expect(container.read(paywallProvider), isTrue);
    expect(access.starts, ['alice']);
    expect(container.read(purchaseProvider).error, isNull);
  });

  test('late account A responses and updates cannot unlock account B',
      () async {
    create();
    final alice = Completer<BillingCustomer>();
    billing.onCustomer = (uid) => uid == 'alice'
        ? alice.future
        : Future.value(BillingCustomer(uid: uid, lifetimeActive: false));
    await container.read(paywallProvider.notifier).initialize();
    (container.read(authProvider.notifier) as _Auth).select('beth');
    await container.pump();
    await container.read(paywallProvider.notifier).initialize();
    alice.complete(const BillingCustomer(uid: 'alice', lifetimeActive: true));
    billing.emit('alice', active: true);
    await _settle();
    expect(container.read(paywallProvider), isFalse);
    expect(access.confirmations, isNot(contains('alice')));
    expect(access.starts, isEmpty);
    expect(billing.customerRequests, containsAll(['alice', 'beth']));
  });

  test('revocation invalidates an older positive confirmation in flight',
      () async {
    create();
    await load();
    final confirmation = Completer<bool>();
    access.onSync = (_) => confirmation.future;
    billing.emit('alice', active: true);
    await _settle();
    billing.emit('alice', active: false);
    await _settle();
    confirmation.complete(true);
    await _settle();
    expect(container.read(paywallProvider), isFalse);
    expect(access.starts, isEmpty);
  });

  test('a current-account revocation closes previously verified access',
      () async {
    create();
    billing.customers['alice'] = true;
    access.started.add('alice');
    await load();
    expect(container.read(paywallProvider), isTrue);
    billing.emit('alice', active: false);
    await _settle();
    expect(container.read(paywallProvider), isFalse);
  });

  test('restore verifies ownership and starts a new journey once', () async {
    create();
    billing.restored = true;
    final service = await load();
    expect(await service.restore(), isTrue);
    expect(container.read(paywallProvider), isTrue);
    expect(billing.restores, ['alice']);
    expect(access.starts, ['alice']);
    expect(await service.restore(), isTrue);
    expect(access.starts, ['alice']);
  });

  test('empty restore does not invent ownership from cached progress',
      () async {
    create();
    access.started.add('alice');
    final service = await load();
    expect(await service.restore(), isFalse);
    expect(container.read(paywallProvider), isFalse);
    expect(access.confirmations, isEmpty);
    expect(container.read(purchaseProvider).error, contains('No lifetime'));
  });

  test('cancellation clears busy state without showing a failure', () async {
    create();
    final service = await load();
    billing.purchaseFailure =
        const BillingFailure(BillingFailureKind.cancelled);
    expect(await service.unlock(), isFalse);
    expect(container.read(purchaseProvider).loading, isFalse);
    expect(container.read(purchaseProvider).error, isNull);
    expect(container.read(paywallProvider), isFalse);
  });

  test('signed-out users cannot load or buy as a previous account', () async {
    create(uid: null);
    final service = await load();
    expect(await service.unlock(), isFalse);
    expect(await service.restore(), isFalse);
    expect(billing.customerRequests, isEmpty);
    expect(billing.purchases, isEmpty);
    expect(billing.restores, isEmpty);
  });
}
