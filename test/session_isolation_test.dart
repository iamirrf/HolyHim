import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:holyher/services/durable_store.dart';
import 'package:holyher/services/account_cache.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/profile_service.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/streak_service.dart';
import 'support.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(user: AuthUser(uid: 'A'));
  void choose(String uid) => state = AuthState(user: AuthUser(uid: uid));
}

class _Profile extends ProfileNotifier {
  @override
  UserProfile build() =>
      const UserProfile(loaded: true, onboardingComplete: true);
}

class _SlowStore extends MemoryStore {
  final Completer<void> unblock = Completer<void>();
  final Completer<void> started = Completer<void>();
  final String? slowRead, slowWrite;
  _SlowStore(super.initial, {this.slowRead, this.slowWrite});
  @override
  Future<Object?> read(String key) async {
    if (key == slowRead) {
      if (!started.isCompleted) started.complete();
      await unblock.future;
    }
    return super.read(key);
  }

  @override
  Future<bool> write(String key, Object value) async {
    if (key == slowWrite) {
      if (!started.isCompleted) started.complete();
      await unblock.future;
    }
    return super.write(key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ProviderContainer containerFor(Map<String, MemoryStore> stores) {
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_Auth.new),
      profileProvider.overrideWith(_Profile.new),
      localClockProvider.overrideWithValue(() => DateTime(2026, 10, 29)),
      localStoreProvider.overrideWith(
          (ref) => stores[ref.watch(authProvider.select((s) => s.user!.uid))]!),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('late account A streak load cannot overwrite account B', () async {
    final a = _SlowStore({
      'streak_active_days': ['2026-10-27', '2026-10-28'],
      'streak_longest': 20
    }, slowRead: 'streak_active_days');
    final b = MemoryStore();
    final container = containerFor({'A': a, 'B': b});
    final old = container.read(streakProvider.notifier).initialize();
    await a.started.future;
    (container.read(authProvider.notifier) as _Auth).choose('B');
    await container.read(streakProvider.notifier).initialize();
    expect(container.read(streakProvider).longest, 1);
    a.unblock.complete();
    await old;
    expect(container.read(streakProvider).longest, 1);
    expect(a.writes, isEmpty);
  });
  test('queued account A completions cannot complete account B lessons',
      () async {
    Map<String, Object> cache(List<int> completed) => {
          'journey_cache': jsonEncode({
            'started': true,
            'startDate': '2026-10-29',
            'timeZone': 'America/New_York',
            'unlockedThrough': 5,
            'completedDays': completed
          })
        };
    final a = _SlowStore(cache([]), slowWrite: 'pending_completions');
    final b = MemoryStore(cache([4]));
    final container = containerFor({'A': a, 'B': b});
    final service = container.read(progressProvider.notifier);
    await service.initialize();
    final first = service.completeDay(1);
    final second = service.completeDay(2);
    await a.started.future;
    (container.read(authProvider.notifier) as _Auth).choose('B');
    await container.read(progressProvider.notifier).initialize();
    expect(container.read(progressProvider).completedDays, {4});
    a.unblock.complete();
    await Future.wait([first, second]);
    expect(container.read(progressProvider).completedDays, {4});
    expect(b.writes, isEmpty);
  });
  test('account deletion removes only that accounts local cache', () async {
    SharedPreferences.setMockInitialValues({
      'user:A:profile': 'private A',
      'user:A:journey_cache': 'A',
      'user:B:profile': 'private B'
    });
    sqfliteFfiInit();
    final database = await openAccountDatabase(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    addTearDown(database.close);
    await eraseAccountCache('A', database: database);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.get('user:A:profile'), isNull);
    expect(prefs.get('user:A:journey_cache'), isNull);
    expect(prefs.getString('user:B:profile'), 'private B');
  });
}
