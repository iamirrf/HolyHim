import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:holyher/services/durable_store.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/profile_service.dart';
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('profile and pending draft flag roll back together when storage fails',
      () async {
    final db = await openAccountDatabase(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    addTearDown(db.close);
    final store = SqliteLocalStore(
        account: 'profile-test',
        database: Future.value(db),
        legacy: MemoryStore({
          'profile': jsonEncode(const UserProfile(name: 'Original').toJson())
        }));
    final container = ProviderContainer(
        overrides: [localStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    final service = container.read(profileProvider.notifier);
    await service.initialize();
    await store.read('profile_pending');
    await db.execute(
        "CREATE TRIGGER fail_pending BEFORE INSERT ON account_records WHEN NEW.key = 'profile_pending' BEGIN SELECT RAISE(ABORT, 'injected failure'); END");
    await expectLater(service.saveDraft(const UserProfile(name: 'New draft')),
        throwsStateError);
    expect(container.read(profileProvider).name, 'Original');
    expect(
        jsonDecode(await store.read('profile') as String)['name'], 'Original');
    expect(await store.read('profile_pending'), isNull);
    await db.execute('DROP TRIGGER fail_pending');
    await service.saveDraft(const UserProfile(name: 'New draft'));
    expect(await store.read('profile_pending'), true);
    expect(
        jsonDecode(await store.read('profile') as String)['name'], 'New draft');
  });

  test('unreadable setup cannot be replaced by a new draft', () async {
    final store = MemoryStore({'profile': 'unreadable profile bytes'});
    final container = ProviderContainer(
        overrides: [localStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    final service = container.read(profileProvider.notifier);
    await expectLater(service.initialize(), throwsStateError);
    await expectLater(service.saveDraft(const UserProfile(name: 'Replacement')),
        throwsStateError);
    expect(store.values['profile'], 'unreadable profile bytes');
    expect(store.writes, isEmpty);
  });
}
