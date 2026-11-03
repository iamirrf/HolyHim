import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/durable_store.dart';

@JS('holyherStorageRead')
external JSPromise<JSString> _read(JSString account, JSString key);
@JS('holyherStorageWrite')
external JSPromise<JSBoolean> _write(JSString account, JSString batch);
@JS('holyherStorageExport')
external JSPromise<JSString> _export(JSString account);
@JS('holyherStorageErase')
external JSPromise<JSBoolean> _erase(JSString account);
@JS('holyherStorageRelease')
external void _release(JSString account);

class IndexedDbLocalStore
    implements TransactionalLocalStore, ExportableLocalStore {
  final String account;
  IndexedDbLocalStore(this.account);
  @override
  Future<Object?> read(String key) async {
    try {
      return jsonDecode((await _read(account.toJS, key.toJS).toDart).toDart);
    } catch (error) {
      throw LocalStorageUnavailable(error.toString().contains('another tab')
          ? 'Your walk is open in another tab. Close that tab, then Retry here.'
          : null);
    }
  }

  @override
  Future<bool> write(String key, Object value) => writeBatch({key: value});
  @override
  Future<bool> writeBatch(Map<String, Object> values) async {
    try {
      return (await _write(account.toJS, jsonEncode(values).toJS).toDart)
          .toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, Object?>> exportRecords() async =>
      Map<String, Object?>.from(
          jsonDecode((await _export(account.toJS).toDart).toDart) as Map);
}

LocalStore createPlatformStore(Ref ref, String account) =>
    IndexedDbLocalStore(account);
Future<void> eraseBrowserAccount(String account) async {
  await _erase(account.toJS).toDart;
}

void releaseBrowserAccount(String account) => _release(account.toJS);
