import 'dart:async';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/features/paywall/paywall_screen.dart';
import 'package:holyhim/services/navigation_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:holyhim/services/auth_service.dart';
import 'package:holyhim/services/billing.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class BillingAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(user: AuthUser(uid: 'alice'));
  void change(String uid) => state = AuthState(user: AuthUser(uid: uid));
}

class PresentationBilling extends LifetimeController {
  @override
  LifetimeState build() => const LifetimeState(loading: false);
}

class PricedBilling extends LifetimeController {
  final String price;
  PricedBilling(this.price);
  @override
  LifetimeState build() => LifetimeState(
      loading: false,
      product: StoreProduct(lifetimeProductId, 'All 365 lessons',
          'HolyHim Lifetime', 1.99, price, 'USD'));
}

Map<String, dynamic> info(String uid, bool owned) {
  final entitlement = {
    'identifier': 'lifetime',
    'isActive': true,
    'willRenew': false,
    'latestPurchaseDate': '2026-11-04T12:00:00Z',
    'originalPurchaseDate': '2026-11-04T12:00:00Z',
    'productIdentifier': lifetimeProductId,
    'isSandbox': true
  };
  return {
    'entitlements': {
      'all': owned ? {'lifetime': entitlement} : {},
      'active': owned ? {'lifetime': entitlement} : {}
    },
    'allPurchaseDates': {},
    'activeSubscriptions': [],
    'allPurchasedProductIdentifiers': owned ? [lifetimeProductId] : [],
    'nonSubscriptionTransactions': [],
    'firstSeen': '2026-11-04T12:00:00Z',
    'originalAppUserId': uid,
    'allExpirationDates': {},
    'requestDate': '2026-11-04T12:00:00Z'
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tzdata.initializeTimeZones);
  const channel = MethodChannel('purchases_flutter');
  late ProviderContainer container;
  String current = 'alice';
  bool configured = false, owned = false, unavailable = false;
  String? purchaseError;
  Completer<Map<String, dynamic>>? heldRestore;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    current = 'alice';
    configured = false;
    owned = false;
    unavailable = false;
    purchaseError = null;
    heldRestore = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'isConfigured':
          return configured;
        case 'setupPurchases':
          configured = true;
          current = call.arguments['appUserId'] as String;
          return null;
        case 'getAppUserID':
          return current;
        case 'logIn':
          current = call.arguments['appUserID'] as String;
          owned = false;
          return {'customerInfo': info(current, false), 'created': false};
        case 'getCustomerInfo':
          return info(current, owned);
        case 'getProductInfo':
          return unavailable
              ? []
              : [
                  {
                    'identifier': lifetimeProductId,
                    'description': 'Lifetime',
                    'title': 'HolyHim lifetime',
                    'price': 1.99,
                    'priceString': '€1,99',
                    'currencyCode': 'EUR',
                    'productCategory': 'NON_SUBSCRIPTION'
                  }
                ];
        case 'purchaseProduct':
          throw PlatformException(
              code: purchaseError ?? '1', message: 'Fixture purchase result');
        case 'restorePurchases':
          return heldRestore?.future ?? info(current, owned);
      }
      return null;
    });
    container = ProviderContainer(
        overrides: [authProvider.overrideWith(BillingAuth.new)]);
  });
  tearDown(() {
    container.dispose();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  Future<void> ready() async {
    container.read(lifetimeProvider);
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < 50 && container.read(lifetimeProvider).loading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test(
      'localized lifetime product and production default never fabricate ownership',
      () async {
    await ready();
    expect(container.read(lifetimeProvider).product!.priceString, '€1,99');
    container.read(lifetimeProvider.notifier).dismissForTesting();
    expect(testingPaywallExit, isFalse);
    expect(container.read(lifetimeProvider).testingDismissed, isFalse);
    expect(container.read(lifetimeProvider).active, isFalse);
  });
  test('unavailable product and cancelled or pending purchases remain unowned',
      () async {
    await ready();
    purchaseError = '1';
    expect(await container.read(lifetimeProvider.notifier).purchase(), isFalse);
    expect(container.read(lifetimeProvider).error, isNull);
    expect(container.read(lifetimeProvider).active, isFalse);
    purchaseError = '20';
    expect(await container.read(lifetimeProvider.notifier).purchase(), isFalse);
    expect(
        container.read(lifetimeProvider).error, contains('awaiting approval'));
    unavailable = true;
    await container.read(lifetimeProvider.notifier).load();
    expect(container.read(lifetimeProvider).error, contains('unavailable'));
  });
  test('unverified SDK restoration does not grant access across accounts',
      () async {
    await ready();
    owned = true;
    expect(await container.read(lifetimeProvider.notifier).restore(), isFalse);
    expect(container.read(lifetimeProvider).purchased, isFalse);
    container.read(lifetimeProvider.notifier).dismissForTesting();
    (container.read(authProvider.notifier) as BillingAuth).change('bob');
    await ready();
    expect(container.read(lifetimeProvider).active, isFalse);
    expect(container.read(lifetimeProvider).testingDismissed, isFalse);
    expect(current, 'bob');
  });
  testWidgets('an unowned paywall cannot dismiss a pending verse',
      (tester) async {
    container.dispose();
    container = ProviderContainer(overrides: [
      authProvider.overrideWith(BillingAuth.new),
      lifetimeProvider.overrideWith(PresentationBilling.new)
    ]);
    final router = GoRouter(initialLocation: '/paywall', routes: [
      GoRoute(
          path: '/paywall', builder: (context, state) => const OfferScreen()),
      GoRoute(
          path: '/verse/:day',
          builder: (context, state) =>
              const Scaffold(body: Text('Exact daily verse'))),
    ]);
    container.read(pendingDestinationProvider.notifier).state = '/verse/42';
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
            theme: HolyThemeData.build(HolyThemes.blush),
            routerConfig: router,
            builder: (context, child) =>
                ThemeHost(theme: HolyThemes.blush, child: child!))));
    await tester.pump();
    expect(find.byTooltip('Close paywall for testing'), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, '/paywall');
    expect(container.read(pendingDestinationProvider), '/verse/42');
    expect(container.read(lifetimeProvider).active, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
    router.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
  test('a late restore result cannot grant access to the next account',
      () async {
    await ready();
    heldRestore = Completer();
    final result = container.read(lifetimeProvider.notifier).restore();
    await Future<void>.delayed(Duration.zero);
    (container.read(authProvider.notifier) as BillingAuth).change('bob');
    await ready();
    heldRestore!.complete(info('alice', true));
    expect(await result, isFalse);
    expect(container.read(lifetimeProvider).active, isFalse);
  });
  testWidgets('the offer shows the store price, and never a blank one',
      (tester) async {
    Future<void> offer(String price) => tester.pumpWidget(ProviderScope(
            overrides: [
              authProvider.overrideWith(BillingAuth.new),
              lifetimeProvider.overrideWith(() => PricedBilling(price))
            ],
            child: MaterialApp(
                theme: HolyThemeData.build(HolyThemes.blush),
                builder: (context, child) =>
                    ThemeHost(theme: HolyThemes.blush, child: child!),
                home: const OfferScreen(lockedDay: 8))));
    await offer(r'$1.99');
    await tester.pump();
    expect(find.text(r'Unlock for life · $1.99'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await offer('  ');
    await tester.pump();
    expect(find.text('Unlock for life'), findsOneWidget);
    expect(find.textContaining('Unlock for life ·'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
    debugDefaultTargetPlatformOverride = null;
  });
}
