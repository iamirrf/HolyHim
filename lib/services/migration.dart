import 'package:cloud_firestore/cloud_firestore.dart';
import 'repository.dart';

class MigrationData {
  final AppProfile profile;
  final Map<int, String> completed;
  final Map<int, DateTime> saved;
  const MigrationData(
      {required this.profile, required this.completed, required this.saved});
}

/// Mapping is pure so old account shapes can be tested without Firebase.
MigrationData mapLegacyAccount(
    {required Map<String, dynamic> profile,
    required Map<String, dynamic> journey,
    Map<String, dynamic> saved = const {},
    DateTime? now}) {
  final instant = now ?? DateTime.now();
  final oldSaved =
      saved['verses'] ?? saved['savedDays'] ?? saved['days'] ?? saved;
  final values = <int, DateTime>{};
  if (oldSaved is Map) {
    for (final entry in oldSaved.entries) {
      final day = int.tryParse('${entry.key}'.replaceFirst('day-', ''));
      if (day == null ||
          day < 1 ||
          day > 365 ||
          entry.value == false ||
          entry.value == null) {
        continue;
      }
      final raw =
          entry.value is Map ? (entry.value as Map)['savedAt'] : entry.value;
      values[day] = raw is int
          ? DateTime.fromMillisecondsSinceEpoch(raw)
          : profileDate(raw) ?? instant;
    }
  } else if (oldSaved is List) {
    for (final item in oldSaved) {
      final day = item is num ? item.toInt() : int.tryParse('$item');
      if (day != null && day >= 1 && day <= 365) values[day] = instant;
    }
  }
  final mapped = AppProfile.fromFirestore({
    ...profile,
    if (journey['timeZone'] is String) 'timeZone': journey['timeZone']
  });
  return MigrationData(
      profile: mapped.copyWith(migratedAt: instant),
      completed: completionMap(journey['completionDates']),
      saved: values);
}

/// Runs in the background. The marker is written only once every copy has been
/// acknowledged, making an interrupted/offline migration safe to retry.
Future<void> migrateLegacyAccount(
    FirebaseFirestore db, String uid, Map<String, dynamic> oldProfile) async {
  if (oldProfile['migratedAt'] != null) return;
  final user = db.doc('users/$uid');
  final writes = <Future<bool>>[];
  void track(Future<void> write) {
    // Attach an error handler immediately, even while the legacy reads wait.
    writes.add(write.then((_) => true, onError: (Object _) => false));
  }

  if (oldProfile['schema'] != 6) {
    final profile = AppProfile.fromFirestore(oldProfile).toFirestore()
      ..remove('migratedAt');
    // Enqueue synchronously before async reads, preserving later user edits.
    track(user.set(profile, SetOptions(merge: true)));
  }
  final docs = await Future.wait([
    db.doc('users/$uid/private/journey').get(),
    db.doc('users/$uid/private/savedCatalog').get(),
    db.doc('users/$uid/walk/progress').get(),
    db.doc('users/$uid/walk/saved').get(),
  ]);
  final migration = mapLegacyAccount(
      profile: oldProfile,
      journey: docs[0].data() ?? {},
      saved: docs[1].data() ?? {});
  final existingCompleted = completionMap(docs[2].data()?['completed']);
  final existingSaved = savedMap(docs[3].data()?['verses']);
  void copyMap(String document, String field, Map<String, dynamic> values) {
    for (var group = 0; group < 19; group++) {
      final entries = values.entries
          .where((entry) => (int.parse(entry.key) - 1) ~/ 20 == group);
      if (entries.isEmpty) continue;
      track(db.doc('users/$uid/walk/$document').set(
          {field: Map<String, dynamic>.fromEntries(entries)},
          SetOptions(merge: true)));
    }
  }

  copyMap('progress', 'completed', {
    for (final e in {...migration.completed, ...existingCompleted}.entries)
      '${e.key}': e.value
  });
  copyMap('saved', 'verses', {
    for (final e in {...migration.saved, ...existingSaved}.entries)
      '${e.key}': Timestamp.fromDate(e.value)
  });
  final accepted = await Future.wait(writes);
  if (accepted.contains(false)) {
    throw StateError('Migration will retry after reconnecting.');
  }
  await user.set(
      {'migratedAt': Timestamp.fromDate(migration.profile.migratedAt!)},
      SetOptions(merge: true));
}
