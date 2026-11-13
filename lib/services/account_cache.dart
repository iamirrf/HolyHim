import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final accountCacheProvider = Provider<AccountCache>((ref) => AccountCache());

/// Account-scoped UI snapshots and unsynced edits. Cloud acknowledgments never
/// erase a locally completed onboarding or a newer edit while it is pending.
class AccountCache {
  final bool durable;
  AccountCache({this.durable = false});
  SharedPreferences? _preferences;
  final Map<String, Map<String, dynamic>> _memory = {};
  Future<void> _writes = Future.value();
  static const _prefix = 'holyhim.account.v3.';
  static const _onboardedPrefix = 'holyhim.onboarded_at.v2.';

  Future<void> initialize() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      for (final key
          in _preferences!.getKeys().where((k) => k.startsWith(_prefix))) {
        final value = jsonDecode(_preferences!.getString(key) ?? '{}');
        if (value is Map) {
          _memory[key.substring(_prefix.length)] =
              Map<String, dynamic>.from(value);
        }
      }
    } catch (_) {
      // Memory remains usable in tests; durable actions report write failures.
    }
  }

  DateTime? readOnboardedAt(String uid) {
    final prefs = _preferences;
    if (prefs == null) return null;
    final iso = prefs.getString('$_onboardedPrefix$uid') ??
        prefs.getString('${_onboardedPrefix}last_active');
    if (iso != null && iso.isNotEmpty) {
      return DateTime.tryParse(iso);
    }
    return null;
  }

  Future<void> markOnboarded(String uid, [DateTime? at]) async {
    final instant = at ?? DateTime.now();
    final iso = instant.toIso8601String();
    final prefs = _preferences;
    if (prefs != null) {
      await prefs.setString('$_onboardedPrefix$uid', iso);
      await prefs.setString('${_onboardedPrefix}last_active', iso);
    }
  }

  Map<String, dynamic>? read(String uid) =>
      _memory[uid] == null ? null : Map<String, dynamic>.from(_memory[uid]!);

  Future<void> write(String uid, Map<String, dynamic> snapshot) {
    final encoded = jsonEncode(snapshot);
    _memory[uid] = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
    final preferences = _preferences;
    final previous = _writes.catchError((Object _) {});
    return _writes = previous.then((_) async {
      if (durable && preferences == null) {
        throw StateError("Device storage is unavailable.");
      }
      if (preferences != null &&
          !await preferences.setString('$_prefix$uid', encoded)) {
        throw StateError('Your changes could not be saved on this device.');
      }
    });
  }

  Future<void> flush() => _writes;
  Future<void> remove(String uid) async {
    _memory.remove(uid);
    await _writes.catchError((Object _) {});
    await _preferences?.remove('$_prefix$uid');
  }
}
