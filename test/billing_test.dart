import 'dart:async';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:holyhim/design/design.dart';
import 'package:holyhim/features/paywall/paywall_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:holyhim/services/auth_service.dart';
import 'package:holyhim/services/billing.dart';
import 'package:holyhim/services/repository.dart';
import '../tool/render/fixtures.dart'
    show FakeBilling, FakeRepository, offerState, trialPlan, plainPlan, profile;

class BillingAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(user: AuthUser(uid: 'alice'));
  void change(String uid) => state = AuthState(user: AuthUser(uid: uid));
}

/// What the store holds for an account: nothing, a lifetime unlock, or a
/// membership (in its trial or paid, live or lapsed).
enum Holding { none, lifetime, trial, member, lapsed }

Map<String, dynamic> _entitlement(String id, String product,
        {String? period, String? expires, bool renews = false}) =>
    {
      'identifier': id,
      'isActive': true,
      'willRenew': renews,
      'latestPurchaseDate': '2026-11-15T12:00:00Z',
      'originalPurchaseDate': '2026-11-15T12:00:00Z',
      'productIdentifier': product,
      'isSandbox': true,
      if (period != null) 'periodType': period,
      if (expires != null) 'expirationDate': expires,
    };

Map<String, dynamic> info(String uid, Holding holding) {
  final active = <String, dynamic>{
    if (holding == Holding.lifetime)
      'lifetime': _entitlement('lifetime', lifetimeProductId),
    if (holding == Holding.trial)
      'member': _entitlement('member', memberTrialProductId,
          period: 'TRIAL', expires: '2099-11-22T12:00:00Z', renews: true),
    if (holding == Holding.member)
      'member': _entitlement('member', memberProductId,
          period: 'NORMAL', expires: '2099-11-15T12:00:00Z', renews: true),
  };
  return {
    'entitlements': {'all': active, 'active': active},
    'allPurchaseDates': {},
    'activeSubscriptions': [],
    'allPurchasedProductIdentifiers': [],
    'nonSubscriptionTransactions': [],
    'firstSeen': '2026-11-04T12:00:00Z',
    'originalAppUserId': uid,
    'allExpirationDates': {},
    'requestDate': '2026-11-15T12:00:00Z'
  };
}

Map<String, dynamic> _package(String id, String type, String product,
        {bool trial = false}) =>
    {
      'identifier': id,
      'packageType': type,
      'product': {
        'identifier': product,
        'description': 'Every lesson, every morning',
        'title': 'HolyHim Membership',
        'price': 1.99,
        'priceString': r'$1.99',
        'currencyCode': 'USD',
        'productCategory': 'SUBSCRIPTION',
        'subscriptionPeriod': 'P1Y',
        if (trial)
          'introPrice': {
            'price': 0,
            'priceString': r'$0.00',
            'period': 'P1W',
            'cycles': 1,
            'periodUnit': 'WEEK',
            'periodNumberOfUnits': 1
          },
      },
      'presentedOfferingContext': {
        'offeringIdentifier': 'default',
        'placementIdentifier': null,
        'targetingContext': null
      },
    };

Map<String, dynamic> offerings({required bool available}) {
  final offering = {
    'identifier': 'default',
    'serverDescription': 'Membership',
    'metadata': <String, Object>{},
    'availablePackages': available
        ? [
            _package(r'$rc_custom_annual_trial', 'CUSTOM', memberTrialProductId,
                trial: true),
            _package(r'$rc_annual', 'ANNUAL', memberProductId),
          ]
        : [],
  };
  return {
    'all': {'default': offering},
    'current': offering
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tzdata.initializeTimeZones);
  const channel = MethodChannel('purchases_flutter');
  late ProviderContainer container;
  String current = 'alice';
  bool configured = false, available = true;
  Holding holding = Holding.none;

  /// What a purchase gives, by product.
  Holding Function(String product)? bought;

  /// 2 is eligible, 1 is not (IntroEligibilityStatus by index).
  int eligibility = 2;
  String? purchaseError;
  Completer<Map<String, dynamic>>? heldRestore;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    current = 'alice';
    configured = false;
    available = true;
    holding = Holding.none;
    bought = null;
    eligibility = 2;
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
          holding = Holding.none;
          return {
            'customerInfo': info(current, Holding.none),
            'created': false
          };
        case 'getCustomerInfo':
          return info(current, holding);
        case 'getOfferings':
          return offerings(available: available);
        case 'checkTrialOrIntroductoryPriceEligibility':
          return {
            memberTrialProductId: {'status': eligibility, 'description': ''}
          };
        case 'purchasePackage':
          if (purchaseError != null) {
            throw PlatformException(
                code: purchaseError!, message: 'Fixture purchase result');
          }
          final package = call.arguments['packageIdentifier'] as String;
          final product = package.contains('trial')
              ? memberTrialProductId
              : memberProductId;
          holding = bought?.call(product) ?? holding;
          return {
            'customerInfo': info(current, holding),
            'transaction': {
              'transactionIdentifier': 'fixture',
              'productIdentifier': product,
              'purchaseDate': '2026-11-15T12:00:00Z'
            }
          };
        case 'restorePurchases':
          return heldRestore?.future ?? info(current, holding);
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
  AccessState read() => container.read(accessProvider);
  Future<void> ready() async {
    container.read(accessProvider);
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < 50 && read().loading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('trial on: the store’s free week and yearly price load, nothing opens',
      () async {
    await ready();
    expect(read().trialPlan!.trialDays, 7);
    expect(read().trialPlan!.price, r'$1.99');
    expect(read().plainPlan!.hasTrial, isFalse);
    expect(read().canTrial, isTrue);
    expect(read().active, isFalse);
  });

  test('trial off: an Apple ID that used its free week is not offered one',
      () async {
    eligibility = 1;
    await ready();
    expect(read().trialEligible, isFalse);
    expect(read().canTrial, isFalse);
    expect(read().plainPlan, isNotNull);
  });

  test('starting the free week opens every lesson, and says it is a trial',
      () async {
    bought = (_) => Holding.trial;
    await ready();
    expect(await container.read(accessProvider.notifier).purchase(trialPlan),
        isTrue);
    expect(read().active, isTrue);
    expect(read().member, isTrue);
    expect(read().inTrial, isTrue);
    expect(read().memberUntil, DateTime.utc(2099, 11, 22, 12));
    // Kept on the phone for the walk offline.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('holyhim.member.v1.alice'), isNotNull);
  });

  test('subscribing without the trial opens every lesson', () async {
    bought = (_) => Holding.member;
    await ready();
    expect(await container.read(accessProvider.notifier).purchase(plainPlan),
        isTrue);
    expect(read().member, isTrue);
    expect(read().inTrial, isFalse);
  });

  test('restore finds a membership bought on another phone', () async {
    await ready();
    holding = Holding.member;
    expect(await container.read(accessProvider.notifier).restore(), isTrue);
    expect(read().active, isTrue);
  });

  test('a lifetime owner keeps every lesson', () async {
    SharedPreferences.setMockInitialValues(
        {'holyhim.access.v1.alice': 'purchased'});
    await ready();
    expect(read().purchased, isTrue);
    expect(read().active, isTrue);
  });

  test('an expired membership closes the door, cached or not', () async {
    SharedPreferences.setMockInitialValues(
        {'holyhim.member.v1.alice': '2026-01-01T00:00:00.000Z'});
    holding = Holding.lapsed;
    await ready();
    expect(read().member, isFalse);
    expect(read().active, isFalse);
  });

  test('the store’s word ends a membership the phone still remembers',
      () async {
    SharedPreferences.setMockInitialValues(
        {'holyhim.member.v1.alice': '2099-01-01T00:00:00.000Z'});
    holding = Holding.none;
    await ready();
    expect(read().member, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('holyhim.member.v1.alice'), isNull);
  });

  test('cancelled or pending purchases leave her outside', () async {
    await ready();
    purchaseError = '1';
    expect(await container.read(accessProvider.notifier).purchase(trialPlan),
        isFalse);
    expect(read().error, isNull);
    expect(read().active, isFalse);
    purchaseError = '20';
    expect(await container.read(accessProvider.notifier).purchase(trialPlan),
        isFalse);
    expect(read().error, contains('awaiting approval'));
  });

  test('a store without the plans says so', () async {
    available = false;
    await ready();
    expect(read().plansReady, isFalse);
    expect(read().error, contains('unavailable'));
  });

  test('an unverified lifetime restore does not grant access across accounts',
      () async {
    await ready();
    holding = Holding.lifetime;
    expect(await container.read(accessProvider.notifier).restore(), isFalse);
    expect(read().purchased, isFalse);
    (container.read(authProvider.notifier) as BillingAuth).change('bob');
    await ready();
    expect(read().active, isFalse);
    expect(current, 'bob');
  });

  test('a late restore result cannot grant access to the next account',
      () async {
    await ready();
    heldRestore = Completer();
    final result = container.read(accessProvider.notifier).restore();
    await Future<void>.delayed(Duration.zero);
    (container.read(authProvider.notifier) as BillingAuth).change('bob');
    await ready();
    heldRestore!.complete(info('alice', Holding.member));
    expect(await result, isFalse);
    expect(read().active, isFalse);
  });

  group('the gate', () {
    Future<void> pump(WidgetTester tester, AccessState state) async {
      await tester.pumpWidget(ProviderScope(
          overrides: [
            authProvider.overrideWith(BillingAuth.new),
            accessProvider.overrideWith(() => FakeBilling(state)),
            repositoryProvider.overrideWith(
                () => FakeRepository(WalkState(profile: profile()))),
          ],
          child: MaterialApp(
              theme: HolyThemeData.build(HolyThemes.blush),
              builder: (context, child) =>
                  ThemeHost(theme: HolyThemes.blush, child: child!),
              home: const OfferScreen(locked: true))));
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> done(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      debugDefaultTargetPlatformOverride = null;
    }

    testWidgets('has no way past but the offer, and keeps every exit in reach',
        (tester) async {
      await pump(tester, offerState);
      expect(find.byTooltip('Close'), findsNothing);
      expect(find.byIcon(CupertinoIcons.xmark), findsNothing);
      for (final link in [
        'Restore purchases',
        'Terms',
        'Privacy',
        'Sign out',
        'Delete account'
      ]) {
        expect(find.text(link), findsOneWidget, reason: link);
      }
      expect(find.text('Start my 7 days free'), findsOneWidget);
      expect(find.textContaining('Renews automatically each year'),
          findsOneWidget);
      expect(find.textContaining('7 days free, then \$1.99 per year'),
          findsOneWidget);
      await done(tester);
    });

    testWidgets('the trial switch moves between the two plans', (tester) async {
      await pump(tester, offerState);
      expect(find.text('Free trial enabled'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('paywall-trial-switch')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Enable 7-day free trial'), findsOneWidget);
      expect(find.text('Subscribe for \$1.99 a year'), findsOneWidget);
      expect(find.textContaining('charged when you confirm'), findsOneWidget);
      await done(tester);
    });

    testWidgets('an Apple ID without the trial never reads the word free',
        (tester) async {
      await pump(
          tester,
          const AccessState(
              loading: false,
              trialPlan: trialPlan,
              plainPlan: plainPlan,
              trialEligible: false));
      expect(find.text('Subscribe for \$1.99 a year'), findsOneWidget);
      expect(find.textContaining(RegExp('free', caseSensitive: false)),
          findsNothing);
      await done(tester);
    });

    testWidgets('a member sees that he is in', (tester) async {
      await pump(tester,
          const AccessState(loading: false, member: true, inTrial: true));
      expect(find.text('You’re in.'), findsOneWidget);
      expect(find.textContaining('Your free week has started'), findsOneWidget);
      await done(tester);
    });
  });
}
