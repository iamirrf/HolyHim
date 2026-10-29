import 'package:holyher/services/local_store.dart';

class MemoryStore implements LocalStore {
  final Map<String, Object> values;
  final List<String> writes = [];
  int? writesAllowed;
  MemoryStore([Map<String, Object>? initial]) : values = {...?initial};

  @override
  Future<Object?> read(String key) async => values[key];

  @override
  Future<bool> write(String key, Object value) async {
    writes.add(key);
    if (writesAllowed != null) {
      if (writesAllowed == 0) return false;
      writesAllowed = writesAllowed! - 1; // Explicitly non-null in this branch.
    }
    values[key] = value is List<String> ? List<String>.of(value) : value;
    return true;
  }
}
