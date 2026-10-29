import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small injectable local I/O boundary; services retain ownership of their keys.
abstract interface class LocalStore {
  Future<Object?> read(String key);
  Future<bool> write(String key, Object value);
}

class PreferencesStore implements LocalStore {
  Future<SharedPreferences>? _loading;

  Future<SharedPreferences> _preferences() => _loading ??=
      SharedPreferences.getInstance().timeout(const Duration(seconds: 3));

  @override
  Future<Object?> read(String key) async {
    try {
      return (await _preferences()).get(key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> write(String key, Object value) async {
    try {
      final prefs = await _preferences();
      final Future<bool> result;
      if (value is bool) {
        result = prefs.setBool(key, value);
      } else if (value is int) {
        result = prefs.setInt(key, value);
      } else if (value is List<String>) {
        result = prefs.setStringList(key, value);
      } else {
        return false;
      }
      return await result.timeout(const Duration(seconds: 3));
    } catch (_) {
      return false;
    }
  }
}

final localStoreProvider = Provider<LocalStore>((ref) => PreferencesStore());
