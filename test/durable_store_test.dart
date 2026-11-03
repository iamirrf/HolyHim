import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:holyher/services/durable_store.dart';
import 'package:holyher/services/local_store.dart';
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late Database db;
  late MemoryStore legacy;
  late SqliteLocalStore alice;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('holyher-sqlite-');
    db = await openAccountDatabase(
        path: '${directory.path}/test.db', factory: databaseFactoryFfi);
    legacy = MemoryStore({'attempt_outbox': 'original legacy bytes'});
    alice = SqliteLocalStore(
        account: 'user:alice', database: Future.value(db), legacy: legacy);
  });
  tearDown(() async {
    if (db.isOpen) await db.close();
    await directory.delete(recursive: true);
  });

  test('migration is repeatable and preserves original preference bytes',
      () async {
    expect(await alice.read('attempt_outbox'), 'original legacy bytes');
    expect(legacy.values['attempt_outbox'], 'original legacy bytes');
    expect(await alice.write('attempt_outbox', 'updated bytes'), true);
    legacy.values['attempt_outbox'] = 'stale preference';
    await db.close();
    db = await openAccountDatabase(
        path: '${directory.path}/test.db', factory: databaseFactoryFfi);
    alice = SqliteLocalStore(
        account: 'user:alice', database: Future.value(db), legacy: legacy);
    expect(await alice.read('attempt_outbox'), 'updated bytes');
    expect(await alice.read('missing'), isNull);
    legacy.values['missing'] = 'must not resurrect';
    expect(await alice.read('missing'), isNull);
  });

  test('a failed second write rolls back an entire completion transaction',
      () async {
    expect(await alice.write('attempt_outbox', 'old'), true);
    expect(await alice.write('lesson_resume_1', 'old checkpoint'), true);
    await db.execute(
        "CREATE TRIGGER injected_failure BEFORE INSERT ON account_records WHEN NEW.key = 'lesson_resume_1' BEGIN SELECT RAISE(ABORT, 'injected failure'); END");
    expect(
        await alice.writeBatch(
            {'attempt_outbox': 'new accepted attempt', 'lesson_resume_1': ''}),
        false);
    expect(await alice.read('attempt_outbox'), 'old');
    expect(await alice.read('lesson_resume_1'), 'old checkpoint');
  });

  test('a failed migration can retry without losing the source', () async {
    await db.execute(
        "CREATE TRIGGER injected_migration_failure BEFORE INSERT ON account_records BEGIN SELECT RAISE(ABORT, 'injected failure'); END");
    await expectLater(
        alice.read('attempt_outbox'), throwsA(isA<LocalStorageUnavailable>()));
    expect(legacy.values['attempt_outbox'], 'original legacy bytes');
    await db.execute('DROP TRIGGER injected_migration_failure');
    expect(await alice.read('attempt_outbox'), 'original legacy bytes');
  });

  test(
      'deletion isolates accounts and prevents delayed writes or migration from recreating data',
      () async {
    final bob = SqliteLocalStore(
        account: 'user:bob', database: Future.value(db), legacy: MemoryStore());
    await alice.write('attempt_outbox', 'alice private');
    await bob.write('attempt_outbox', 'bob private');
    await eraseDurableAccount(db, 'user:alice');
    expect(await alice.write('attempt_outbox', 'late alice response'), false);
    await expectLater(alice.read('attempt_outbox'), throwsStateError);
    expect(await bob.read('attempt_outbox'), 'bob private');
    expect(
        await db.query('account_records',
            where: 'account = ?', whereArgs: ['user:alice']),
        isEmpty);
  });

  test('unavailable storage throws rather than pretending an account is empty',
      () async {
    await db.close();
    await expectLater(
        alice.read('attempt_outbox'), throwsA(isA<LocalStorageUnavailable>()));
    expect(await alice.write('attempt_outbox', 'replacement'), false);
    expect(legacy.values['attempt_outbox'], 'original legacy bytes');
  });
}
