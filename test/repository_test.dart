import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:holyhim/services/auth_service.dart';
import 'package:holyhim/services/repository.dart';
import 'package:holyhim/services/account_cache.dart';

class LocalAuth extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(user: AuthUser(uid: 'first', displayName: 'Mira'));
  void change(String uid) => state = AuthState(user: AuthUser(uid: uid));
}

class ControlledFirestore implements FirebaseFirestore {
  final documents = <String, ControlledDocument>{};
  @override
  ControlledDocument doc(String path) =>
      documents.putIfAbsent(path, () => ControlledDocument());
  Future<void> close() async {
    for (final doc in documents.values) {
      await doc.snapshotsController.close();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test-only SDK stand-ins: these public types have private constructors.
// ignore: subtype_of_sealed_class
class ControlledDocument implements DocumentReference<Map<String, dynamic>> {
  final snapshotsController =
      StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast(
          sync: true);
  final writes = <({
    Map<String, dynamic> data,
    SetOptions? options,
    Completer<void> receipt
  })>[];
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots(
          {bool includeMetadataChanges = false,
          ListenSource source = ListenSource.defaultSource}) =>
      snapshotsController.stream;
  void emit(Map<String, dynamic>? data,
          {bool cached = true, bool pending = false}) =>
      snapshotsController
          .add(ControlledSnapshot(data, cached: cached, pending: pending));
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) {
    final receipt = Completer<void>();
    writes.add((data: data, options: options, receipt: receipt));
    return receipt.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class ControlledSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? value;
  final bool cached, pending;
  ControlledSnapshot(this.value, {this.cached = true, this.pending = false});
  @override
  Map<String, dynamic>? data() => value;
  @override
  SnapshotMetadata get metadata =>
      ControlledMetadata(cached: cached, pending: pending);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ControlledMetadata implements SnapshotMetadata {
  final bool cached, pending;
  ControlledMetadata({required this.cached, required this.pending});
  @override
  bool get isFromCache => cached;
  @override
  bool get hasPendingWrites => pending;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FlakyDeviceCache extends AccountCache {
  bool fail = true;
  Future<void> latest = Future.value();
  @override
  Future<void> write(String uid, Map<String, dynamic> snapshot) {
    if (fail) {
      fail = false;
      return latest = Future.error(StateError('Device write failed'));
    }
    return latest = super.write(uid, snapshot);
  }

  @override
  Future<void> flush() => latest;
}

class DeferredDeviceCache extends AccountCache {
  final receipt = Completer<void>();
  @override
  Future<void> write(String uid, Map<String, dynamic> snapshot) =>
      receipt.future;
}

void main() {
  setUpAll(tzdata.initializeTimeZones);
  late ProviderContainer container;
  setUp(() => container =
      ProviderContainer(overrides: [authProvider.overrideWith(LocalAuth.new)]));
  tearDown(() => container.dispose());
  test(
      'profile/onboarding and Amen update immediately without any initialized server',
      () {
    final repository = container.read(repositoryProvider.notifier);
    repository.finishOnboarding(AppProfile(name: 'Mira', hearts: ['Hope']));
    expect(container.read(repositoryProvider).profile.onboarded, isTrue);
    expect(container.read(repositoryProvider).profile.name, 'Mira');
    expect(repository.complete(1, now: DateTime.utc(2026, 11, 3)), isTrue);
    expect(container.read(repositoryProvider).completed, {1: '2026-11-03'});
    expect(repository.complete(2, now: DateTime.utc(2026, 11, 3, 23)), isFalse);
    expect(repository.complete(1, now: DateTime.utc(2026, 11, 4)), isFalse);
    expect(repository.complete(2, now: DateTime.utc(2026, 11, 4)), isTrue);
  });
  test('save/remove and export reflect optimistic state', () {
    final repository = container.read(repositoryProvider.notifier);
    repository.toggleSaved(1, now: DateTime.utc(2026, 11, 3));
    expect(container.read(repositoryProvider).saved.keys, [1]);
    expect(repository.exportData(), contains('2026-11-03T00:00:00.000Z'));
    repository.toggleSaved(1);
    expect(container.read(repositoryProvider).saved, isEmpty);
  });
  test('a device-write failure can retry completion without a duplicate award',
      () async {
    container.dispose();
    final cache = FlakyDeviceCache();
    container = ProviderContainer(overrides: [
      authProvider.overrideWith(LocalAuth.new),
      accountCacheProvider.overrideWithValue(cache)
    ]);
    final repo = container.read(repositoryProvider.notifier);
    await expectLater(
        repo.completeDurably(1, now: DateTime.utc(2026, 11, 5, 14)),
        throwsStateError);
    expect(container.read(repositoryProvider).completed.length, 1);
    expect(await repo.completeDurably(1, now: DateTime.utc(2026, 11, 5, 14)),
        isFalse);
    expect(cache.read('first')!['completed'], {'1': '2026-11-05'});
    expect(container.read(repositoryProvider).syncError, isNull);
    expect(container.read(repositoryProvider).completed.length, 1);
  });
  test('a delayed device-cache failure cannot affect another account',
      () async {
    container.dispose();
    final cache = DeferredDeviceCache();
    container = ProviderContainer(overrides: [
      authProvider.overrideWith(LocalAuth.new),
      accountCacheProvider.overrideWithValue(cache)
    ]);
    container.read(repositoryProvider.notifier).finishOnboarding();
    (container.read(authProvider.notifier) as LocalAuth).change('second');
    container.read(repositoryProvider);
    cache.receipt.completeError(StateError('old account storage failure'));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(repositoryProvider).syncError, isNull);
    expect(container.read(repositoryProvider).profile.onboarded, isFalse);
  });
  test('a different signed-in UID cannot inherit the previous walk', () {
    final repository = container.read(repositoryProvider.notifier);
    repository.finishOnboarding(AppProfile(name: 'Mira'));
    repository.complete(1, now: DateTime.utc(2026, 11, 3));
    repository.toggleSaved(1);
    (container.read(authProvider.notifier) as LocalAuth).change('second');
    final next = container.read(repositoryProvider);
    expect(next.completed, isEmpty);
    expect(next.saved, isEmpty);
    expect(next.profile.name, isEmpty);
    expect(next.profile.onboarded, isFalse);
  });
  group('Firestore write receipts', () {
    late ControlledFirestore firestore;
    AppProfile profile(String name) => AppProfile(
        name: name,
        timeZone: 'America/New_York',
        onboardedAt: DateTime.utc(2026, 11, 3),
        migratedAt: DateTime.utc(2026, 11, 3));
    setUp(() {
      container.dispose();
      firestore = ControlledFirestore();
      container = ProviderContainer(overrides: [
        authProvider.overrideWith(LocalAuth.new),
        repositoryFirestoreProvider.overrideWithValue(firestore)
      ]);
    });
    tearDown(() => firestore.close());
    Future<void> begin() async {
      container.read(repositoryProvider);
      await Future<void>.delayed(Duration.zero);
    }

    testWidgets('a returning profile remains unresolved beyond the old timeout',
        (tester) async {
      container.read(repositoryProvider);
      await tester.pump();
      expect(container.read(repositoryProvider).ready, isFalse);
      firestore.doc('users/first').emit(null, cached: true);
      await tester.pump(const Duration(seconds: 2));
      expect(container.read(repositoryProvider).ready, isFalse);
      firestore
          .doc('users/first')
          .emit(profile('Mira').toFirestore(), cached: false);
      expect(container.read(repositoryProvider).profile.onboarded, isTrue);
      expect(container.read(repositoryProvider).ready, isTrue);
    });
    test(
        'rejected name edits and stale snapshots cannot undo onboarding or the pending name',
        () async {
      await begin();
      final original = profile('Mira').toFirestore();
      firestore.doc('users/first').emit(original, cached: false);
      final repo = container.read(repositoryProvider.notifier);
      repo.updateProfile(container
          .read(repositoryProvider)
          .profile
          .copyWith(name: 'Amelia', theme: 'forest'));
      firestore.doc('users/first').writes.last.receipt.completeError(
          FirebaseException(
              plugin: 'cloud_firestore', code: 'permission-denied'));
      await Future<void>.delayed(Duration.zero);
      firestore
          .doc('users/first')
          .emit({...original, 'onboardedAt': null}, cached: false);
      expect(container.read(repositoryProvider).profile.name, 'Amelia');
      expect(container.read(repositoryProvider).profile.theme, 'forest');
      expect(container.read(repositoryProvider).profile.onboarded, isTrue);
      expect(container.read(repositoryProvider).syncError, isNotNull);
      container.invalidate(repositoryProvider);
      final restored = container.read(repositoryProvider);
      expect(restored.profile.name, 'Amelia');
      expect(restored.profile.onboarded, isTrue);
      expect(restored.ready, isTrue);
    });
    test(
        'editing a guide answer clears later answers through stale snapshots and retry',
        () async {
      await begin();
      final original = profile('Mira').copyWith(onboardingDraft: {
        'step': 4,
        'source': 'The App Store',
        'familiarity': 'Some passages',
        'needs': 'Finding peace'
      }).toFirestore();
      firestore.doc('users/first').emit(original, cached: false);
      final repo = container.read(repositoryProvider.notifier);
      final edited = {'step': 4, 'source': 'A friend or family member'};
      repo.updateProfile(container
          .read(repositoryProvider)
          .profile
          .copyWith(onboardingDraft: edited));
      final write = firestore.doc('users/first').writes.last;
      expect(write.data['onboardingDraft'], edited);
      expect(
          write.options!.mergeFields, contains(FieldPath(['onboardingDraft'])));
      firestore.doc('users/first').emit(original, cached: false);
      expect(
          container.read(repositoryProvider).profile.onboardingDraft, edited);
      repo.retrySync();
      expect(firestore.doc('users/first').writes.last.data['onboardingDraft'],
          edited);
      firestore
          .doc('users/first')
          .emit({...original, 'onboardingDraft': edited}, cached: false);
      container.invalidate(repositoryProvider);
      expect(
          container.read(repositoryProvider).profile.onboardingDraft, edited);
    });
    test(
        'server key order and Timestamp representation acknowledge the same draft',
        () async {
      await begin();
      final original = profile('Mira').copyWith(onboardingDraft: {
        'step': 4,
        'firstName': 'Mira',
        'needs': 'Peace'
      }).toFirestore();
      firestore.doc('users/first').emit(original, cached: false);
      final repo = container.read(repositoryProvider.notifier);
      repo.updateProfile(container.read(repositoryProvider).profile.copyWith(
          onboardingDraft: {'step': 4, 'firstName': 'Mira', 'needs': 'Hope'},
          updatedAt: DateTime.utc(2026, 11, 5, 14)));
      final write = firestore.doc('users/first').writes.last;
      final acknowledged = {
        ...original,
        'updatedAt': Timestamp.fromDate(write.data['updatedAt']),
        'onboardingDraft': {'needs': 'Hope', 'firstName': 'Mira', 'step': 4}
      };
      firestore.doc('users/first').emit(acknowledged, cached: false);
      // Once acknowledged, a genuine later edit must be allowed through.
      firestore.doc('users/first').emit({
        ...acknowledged,
        'onboardingDraft': {'needs': 'Rest', 'firstName': 'Mira', 'step': 4}
      }, cached: false);
      expect(
          container.read(repositoryProvider).profile.onboardingDraft['needs'],
          'Rest');
    });
    test('an empty cache cannot replace an existing cross-device profile',
        () async {
      await begin();
      firestore.doc('users/first').emit(null, cached: true);
      final repository = container.read(repositoryProvider.notifier);
      repository.updateProfile(container
          .read(repositoryProvider)
          .profile
          .copyWith(name: 'New name'));
      expect(firestore.doc('users/first').writes, isEmpty);
      firestore.doc('users/first').emit(profile('Old name')
          .copyWith(theme: 'forest', readingScale: 1.5)
          .toFirestore());
      expect(container.read(repositoryProvider).profile.name, 'New name');
      expect(container.read(repositoryProvider).profile.theme, 'forest');
      expect(container.read(repositoryProvider).profile.readingScale, 1.5);
      final payload = firestore.doc('users/first').writes.single.data;
      expect(payload.keys.toSet(), {'schema', 'name', 'updatedAt'});
      expect(payload['name'], 'New name');
    });
    test(
        'onboarding and completion keep working while every SDK receipt is pending',
        () async {
      await begin();
      firestore
          .doc('users/first')
          .emit(profile('Mira').copyWith(onboardedAt: null).toFirestore());
      final repository = container.read(repositoryProvider.notifier);
      repository.finishOnboarding();
      expect(container.read(repositoryProvider).profile.onboarded, isTrue);
      expect(
          repository.complete(1, now: DateTime.utc(2026, 11, 3, 15)), isTrue);
      repository.toggleSaved(1, now: DateTime.utc(2026, 11, 3, 15));
      expect(container.read(repositoryProvider).completed, {1: '2026-11-03'});
      expect(container.read(repositoryProvider).saved.keys, [1]);
      expect(container.read(repositoryProvider).syncing, isTrue);
      expect(firestore.doc('users/first/walk/progress').writes.single.data, {
        'completed': {'1': '2026-11-03'}
      });
      expect(
          firestore.documents.values
              .expand((doc) => doc.writes)
              .every((write) => !write.receipt.isCompleted),
          isTrue);
    });
    test('a previous UID receipt cannot change a newly signed-in account',
        () async {
      await begin();
      firestore.doc('users/first').emit(profile('Mira').toFirestore());
      container.read(repositoryProvider.notifier).toggleSaved(1);
      final receipt =
          firestore.doc('users/first/walk/saved').writes.single.receipt;
      (container.read(authProvider.notifier) as LocalAuth).change('second');
      container.read(repositoryProvider);
      await Future<void>.delayed(Duration.zero);
      firestore.doc('users/second').emit(profile('Eve').toFirestore());
      receipt.completeError(FirebaseException(
          plugin: 'cloud_firestore', code: 'permission-denied'));
      await Future<void>.delayed(Duration.zero);
      final state = container.read(repositoryProvider);
      expect(state.profile.name, 'Eve');
      expect(state.saved, isEmpty);
      expect(state.syncError, isNull);
      expect(state.syncing, isFalse);
      firestore.doc('users/first').emit(profile('Old receipt').toFirestore());
      expect(container.read(repositoryProvider).profile.name, 'Eve');
    });
    test(
        'changing reminder enablement merges its leaf without overwriting time',
        () async {
      await begin();
      firestore.doc('users/first').emit(profile('Mira').toFirestore());
      final repository = container.read(repositoryProvider.notifier);
      repository.updateProfile(container
          .read(repositoryProvider)
          .profile
          .copyWith(reminderEnabled: true));
      expect(firestore.doc('users/first').writes.single.data['reminder'],
          {'enabled': true});
    });
    test('failed legacy reads retry on resume without a snapshot retry loop',
        () async {
      var attempts = 0;
      final pending = Completer<void>();
      container.dispose();
      container = ProviderContainer(overrides: [
        authProvider.overrideWith(LocalAuth.new),
        repositoryFirestoreProvider.overrideWithValue(firestore),
        accountMigrationProvider.overrideWithValue((db, uid, profile) {
          attempts++;
          return attempts == 1
              ? Future<void>.error(StateError('offline'))
              : pending.future;
        })
      ]);
      await begin();
      final legacy = profile('Mira').copyWith(migratedAt: null).toFirestore();
      firestore.doc('users/first').emit(legacy);
      await Future<void>.delayed(Duration.zero);
      expect(attempts, 1);
      expect(container.read(repositoryProvider).syncError, isNotNull);
      firestore.doc('users/first').emit(legacy);
      await Future<void>.delayed(Duration.zero);
      expect(attempts, 1);
      container.read(repositoryProvider.notifier).retryMigration();
      await Future<void>.delayed(Duration.zero);
      expect(attempts, 2);
      expect(pending.isCompleted, isFalse);
      expect(container.read(repositoryProvider).profile.onboarded, isTrue);
    });
  });
}
