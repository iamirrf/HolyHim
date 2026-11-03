import 'package:flutter/foundation.dart';
import 'platform_store_native.dart'
    if (dart.library.js_interop) 'platform_store_web.dart' as platform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:holyher/services/durable_store.dart';
import 'package:sqflite/sqflite.dart';

/// Remove only the deleted account's local data; other accounts stay isolated.
Future<void> eraseAccountCache(String uid, {Database? database}) async {
  if (kIsWeb) {
    await platform.eraseBrowserAccount('user:$uid');
  } else {
    await eraseDurableAccount(
        database ?? await openAccountDatabase(), 'user:$uid');
  }
  final preferences = await SharedPreferences.getInstance();
  final prefix = 'user:$uid:';
  final keys =
      preferences.getKeys().where((key) => key.startsWith(prefix)).toList();
  for (final key in keys) {
    if (!await preferences.remove(key)) {
      throw StateError('Local account cleanup failed.');
    }
  }
}
