import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:holyher/services/local_store.dart';

/// One database for all accounts; every row and migration is account scoped.
final localDatabaseProvider =
    Provider<Future<Database> Function()>((ref) => () => openAccountDatabase());

Future<Database> openAccountDatabase(
        {String path = 'holyher-local-v1.db', DatabaseFactory? factory}) =>
    (factory ?? databaseFactory).openDatabase(path,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) async {
            // A successful write means SQLite has committed to durable storage.
            await db.execute('PRAGMA synchronous = FULL');
            // This PRAGMA returns a row even when assigning its value. The
            // Darwin driver's update API rejects SQLITE_ROW and aborts open.
            await db.rawQuery('PRAGMA secure_delete = ON');
          },
          onCreate: (db, _) async {
            await db.execute(
                'CREATE TABLE account_records (account TEXT NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY (account, key))');
            await db.execute(
                'CREATE TABLE erased_accounts (account TEXT PRIMARY KEY NOT NULL)');
          },
        ));

abstract interface class TransactionalLocalStore implements LocalStore {
  Future<bool> writeBatch(Map<String, Object> values);
}

/// Production uses a single SQLite transaction. The fallback supports legacy
/// adapters and small test doubles; no production acceptance uses preferences.
Future<bool> writeLocalBatch(
    LocalStore store, Map<String, Object> values) async {
  if (store is TransactionalLocalStore) return store.writeBatch(values);
  for (final entry in values.entries) {
    if (!await store.write(entry.key, entry.value)) return false;
  }
  return true;
}

class SqliteLocalStore
    implements TransactionalLocalStore, ExportableLocalStore {
  final String account;
  final Future<Database> Function() _open;
  Future<Database> get database => _open();
  final LocalStore legacy;
  SqliteLocalStore(
      {required this.account,
      Future<Database>? database,
      Future<Database> Function()? open,
      required this.legacy})
      : assert(database != null || open != null),
        _open = open ?? (() => database!);

  Future<void> _check(DatabaseExecutor tx) async {
    final erased = await tx
        .query('erased_accounts', where: 'account = ?', whereArgs: [account]);
    if (erased.isNotEmpty) throw StateError('This account was deleted.');
  }

  @override
  Future<Object?> read(String key) async {
    try {
      final db = await database;
      return await db.transaction((tx) async {
        await _check(tx);
        final records = await tx.query('account_records',
            columns: ['value'],
            where: 'account = ? AND key = ?',
            whereArgs: [account, key]);
        if (records.isNotEmpty) {
          return jsonDecode(records.single['value'] as String);
        }
        // A null is also recorded: later reads cannot resurrect an old preference.
        // Original preference bytes are retained for recovery until deletion.
        final original = await legacy.read(key);
        await tx.insert('account_records',
            {'account': account, 'key': key, 'value': jsonEncode(original)});
        return original;
      });
    } on DatabaseException {
      throw LocalStorageUnavailable();
    }
  }

  @override
  Future<Map<String, Object?>> exportRecords() async {
    final db = await database;
    return db.transaction((tx) async {
      await _check(tx);
      final rows = await tx.query('account_records',
          where: 'account = ?', whereArgs: [account], orderBy: 'key');
      return {
        for (final row in rows)
          row['key'] as String: _exportValue(row['value'] as String)
      };
    });
  }

  Object? _exportValue(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return {'unreadableRaw': raw};
    }
  }

  @override
  Future<bool> write(String key, Object value) => writeBatch({key: value});

  @override
  Future<bool> writeBatch(Map<String, Object> values) async {
    try {
      if (values.values.any((value) =>
          value is! String &&
          value is! bool &&
          value is! int &&
          value is! List<String>)) {
        return false;
      }
      final db = await database;
      await db.transaction((tx) async {
        await _check(tx);
        for (final entry in values.entries) {
          await tx.insert(
              'account_records',
              {
                'account': account,
                'key': entry.key,
                'value': jsonEncode(entry.value)
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// The tombstone and removal commit together. In-flight old-account services
/// cannot repopulate local storage after a successful account deletion.
Future<void> eraseDurableAccount(Database db, String account) =>
    db.transaction((tx) async {
      await tx.insert('erased_accounts', {'account': account},
          conflictAlgorithm: ConflictAlgorithm.ignore);
      await tx.delete('account_records',
          where: 'account = ?', whereArgs: [account]);
    });
