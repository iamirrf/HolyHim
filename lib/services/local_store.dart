import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:holyher/services/auth_service.dart';
import 'platform_store_native.dart'
    if (dart.library.js_interop) 'platform_store_web.dart' as platform;

/// Small injectable local I/O boundary; services retain ownership of their keys.
abstract interface class LocalStore {
  Future<Object?> read(String key);
  Future<bool> write(String key, Object value);
}

abstract interface class ExportableLocalStore {
  Future<Map<String, Object?>> exportRecords();
}

class LocalStorageUnavailable extends StateError {
  LocalStorageUnavailable([String? detail])
      : super(detail ??
            'Local storage is unavailable. Your saved data has not been changed.');
}

class PreferencesStore implements LocalStore {
  final String prefix;
  PreferencesStore({this.prefix = ''});
  Future<SharedPreferences>? _loading;

  Future<SharedPreferences> _preferences() => _loading ??=
      SharedPreferences.getInstance().timeout(const Duration(seconds: 3));

  @override
  Future<Object?> read(String key) async {
    try {
      return (await _preferences()).get('$prefix$key');
    } catch (_) {
      _loading = null;
      throw LocalStorageUnavailable();
    }
  }

  @override
  Future<bool> write(String key, Object value) async {
    try {
      final prefs = await _preferences();
      final Future<bool> result;
      if (value is bool) {
        result = prefs.setBool('$prefix$key', value);
      } else if (value is int) {
        result = prefs.setInt('$prefix$key', value);
      } else if (value is List<String>) {
        result = prefs.setStringList('$prefix$key', value);
      } else if (value is String) {
        result = prefs.setString('$prefix$key', value);
      } else {
        return false;
      }
      return await result.timeout(const Duration(seconds: 3));
    } catch (_) {
      return false;
    }
  }
}

final localStoreProvider = Provider<LocalStore>((ref) {
  final uid = ref.watch(authProvider.select((s) => s.user?.uid));
  final account = uid == null ? 'signed-out' : 'user:$uid';
  ref.onDispose(() => platform.releaseBrowserAccount(account));
  return platform.createPlatformStore(ref, account);
});
