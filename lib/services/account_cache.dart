import 'package:shared_preferences/shared_preferences.dart';

/// Remove only the deleted account's local data; other accounts stay isolated.
Future<void> eraseAccountCache(String uid) async {
  final preferences = await SharedPreferences.getInstance();
  final prefix = 'user:$uid:';
  final keys =
      preferences.getKeys().where((key) => key.startsWith(prefix)).toList();
  for (final key in keys) {
    await preferences.remove(key);
  }
}
