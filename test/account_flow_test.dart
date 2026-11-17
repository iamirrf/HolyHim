// Who sees what after signing in, end to end: the real repository, the real
// device cache and the real router. Only Firestore and the App Store are
// stand-ins.
//
//   new account                 -> the welcome (onboarding), always
//   returning, welcome unfinished -> back into the welcome where she left it
//   returning member            -> Home, with every lesson she has read
//   returning, not a member     -> the offer, with no way past it; her walk
//                                  is kept, and is all there once she joins
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:holyhim/design/design.dart';
import 'package:holyhim/domain/lesson.dart';
import 'package:holyhim/features/onboarding/onboarding_screen.dart';
import 'package:holyhim/features/paywall/paywall_screen.dart';
import 'package:holyhim/features/shell/home_shell.dart';
import 'package:holyhim/main.dart';
import 'package:holyhim/services/account_cache.dart';
import 'package:holyhim/services/app_router.dart';
import 'package:holyhim/services/auth_service.dart';
import 'package:holyhim/services/billing.dart';
import 'package:holyhim/services/notifications.dart';
import 'package:holyhim/services/repository.dart';
import '../tool/render/fixtures.dart' show offerState;
import '../tool/render/harness.dart' show loadFonts;
import 'fixtures/controlled_firestore.dart';

class _Auth extends AuthNotifier {
  final String uid;
  final bool isNew;
  _Auth(this.uid, this.isNew);
  @override
  AuthState build() => AuthState(
      user:
          AuthUser(uid: uid, email: '$uid@example.test', isNewAccount: isNew));
}

class _Access extends AccessController {
  final bool member;
  _Access(this.member);
  @override
  AccessState build() => member
      ? const AccessState(loading: false, member: true, verified: true)
      : offerState;
  @override
  Future<bool> purchase(MemberPlan plan) async {
    state =
        state.copyWith(member: true, inTrial: plan.hasTrial, willRenew: true);
    return true;
  }
}

class _Notes extends NotificationService {
  @override
  Future<void> initialize() async {}
  @override
  Future<String> deviceTimeZone() async => 'America/New_York';
  @override
  bool get supported => false;
  @override
  Future<String> permissionStatus() async => 'notDetermined';
  @override
  Future<bool> requestPermission() async => false;
  @override
  void reconcile(
      {required String uid,
      required AppProfile profile,
      required Map<int, String> completed,
      required List<Lesson> lessons}) {}
  @override
  Future<void> cancel() async {}
}

/// A phone that another account has already used: her welcome is finished
/// and her walk is cached, and an earlier build left its shared date.
const _usedPhone = <String, Object>{
  'holyhim.onboarded_at.v2.someone-else': '2026-11-10T08:00:00.000Z',
  'holyhim.onboarded_at.v2.last_active': '2026-11-10T08:00:00.000Z',
  'holyhim.account.v3.someone-else':
      '{"profile":{"name":"Ruth","onboardedAt":"2026-11-10T08:00:00.000Z"},'
          '"completed":{"1":"2026-11-10"}}',
};

const _walk = {'1': '2026-11-01', '2': '2026-11-02', '3': '2026-11-03'};

class _App {
  final ProviderContainer container;
  final ControlledFirestore db;
  final String uid;
  _App(this.container, this.db, this.uid);

  /// What the server holds for her: nothing, for a new account.
  Future<void> serve(WidgetTester tester,
      {Map<String, dynamic>? profile, Map<String, String>? completed}) async {
    final fromServer = profile != null;
    db.doc('users/$uid').emit(profile, cached: !fromServer);
    db.doc('users/$uid/walk/progress').emit(
        completed == null ? null : {'completed': completed},
        cached: !fromServer);
    db.doc('users/$uid/walk/saved').emit(null, cached: !fromServer);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  WalkState get walk => container.read(repositoryProvider);
}

Future<_App> _open(WidgetTester tester,
    {required String uid,
    required bool isNew,
    required bool member,
    Map<String, Object> phone = _usedPhone}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  SharedPreferences.setMockInitialValues(phone);
  final cache = AccountCache(durable: true);
  await cache.initialize();
  final db = ControlledFirestore();
  final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/:location(.*)', pageBuilder: appRoutePage)]);
  final container = ProviderContainer(overrides: [
    authProvider.overrideWith(() => _Auth(uid, isNew)),
    accessProvider.overrideWith(() => _Access(member)),
    notificationServiceProvider.overrideWithValue(_Notes()),
    repositoryFirestoreProvider.overrideWithValue(db),
    accountCacheProvider.overrideWithValue(cache),
    accountMigrationProvider.overrideWithValue((db, uid, profile) async {}),
    appRouterProvider.overrideWithValue(router),
  ]);
  addTearDown(() async {
    container.dispose();
    await db.close();
  });
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container, child: const HolyHimApp()));
  await tester.pump();
  return _App(container, db, uid);
}

Map<String, dynamic> _returning({Map<String, dynamic>? extra}) => {
      'schema': 6,
      'name': 'Mira',
      'timeZone': 'America/New_York',
      'onboardedAt': '2026-11-01T08:00:00.000Z',
      ...?extra,
    };

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(() async {
    tzdata.initializeTimeZones();
    await loadFonts();
  });
  setUp(() {
    OnboardingScreen.resumeToast = false;
    HolySounds.player = (String asset, {double gain = 1}) async {};
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  testWidgets('a new account on a used phone begins with the welcome',
      (tester) async {
    final app =
        await _open(tester, uid: 'newcomer', isNew: true, member: false);
    await app.serve(tester);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(OfferScreen), findsNothing);
    expect(find.byType(HomeShell), findsNothing);
    expect(app.walk.profile.onboarded, isFalse);
    expect(app.walk.completed, isEmpty);
    await _close(tester);
  });

  testWidgets('a new account on a fresh phone begins with the welcome',
      (tester) async {
    final app = await _open(tester,
        uid: 'newcomer', isNew: true, member: false, phone: const {});
    await app.serve(tester);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(OfferScreen), findsNothing);
    await _close(tester);
  });

  testWidgets('an account that left the welcome part-way goes back into it',
      (tester) async {
    final app =
        await _open(tester, uid: 'returning', isNew: false, member: false);
    await app.serve(tester, profile: {
      'schema': 6,
      'name': 'Mira',
      'timeZone': 'America/New_York',
      'onboardingDraft': {'stepId': 'season', 'step': 3, 'flowVersion': 3},
    });
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(OfferScreen), findsNothing);
    await _close(tester);
  });

  testWidgets('a returning member goes straight Home with her whole walk',
      (tester) async {
    final app =
        await _open(tester, uid: 'returning', isNew: false, member: true);
    await app.serve(tester, profile: _returning(), completed: _walk);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(OfferScreen), findsNothing);
    expect(app.walk.completed.keys, unorderedEquals([1, 2, 3]));
    await _close(tester);
  });

  testWidgets(
      'a returning account without membership meets the offer, walk kept',
      (tester) async {
    final app =
        await _open(tester, uid: 'returning', isNew: false, member: false);
    await app.serve(tester, profile: _returning(), completed: _walk);
    expect(find.byType(OfferScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeShell), findsNothing);
    expect(find.byTooltip('Close'), findsNothing);
    expect(app.walk.completed.keys, unorderedEquals([1, 2, 3]));
    // Joining opens Home, and every lesson she read is still hers.
    await _tap(tester, 'Start my 7 days free');
    expect(find.text('You’re in.'), findsOneWidget);
    await _tap(tester, 'Continue');
    expect(find.byType(HomeShell), findsOneWidget);
    expect(app.walk.completed.keys, unorderedEquals([1, 2, 3]));
    await _close(tester);
  });
}
