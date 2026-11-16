import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:holyhim/services/account_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'durable account snapshots restore themes and pending edits without crossing accounts',
      () async {
    SharedPreferences.setMockInitialValues({});
    final first = AccountCache(durable: true);
    await first.initialize();
    await first.write('alice', {
      'profile': {'theme': 'sage', 'onboardedAt': '2026-11-04T12:00:00Z'},
      'dirtyProfile': {'name': 'Amelia'}
    });
    await first.write('bob', {
      'profile': {'theme': 'midnight-rose'}
    });
    final restarted = AccountCache(durable: true);
    await restarted.initialize();
    expect(restarted.read('alice')!['profile']['theme'], 'sage');
    expect(restarted.read('alice')!['dirtyProfile']['name'], 'Amelia');
    expect(restarted.read('bob')!['profile']['theme'], 'midnight-rose');
    await restarted.remove('alice');
    final next = AccountCache(durable: true);
    await next.initialize();
    expect(next.read('alice'), isNull);
    expect(next.read('bob'), isNotNull);
  });

  test('one account finishing the welcome never marks another as done',
      () async {
    // An earlier build also kept a device-wide date and lent it to any
    // account without its own.
    SharedPreferences.setMockInitialValues(
        {'holyhim.onboarded_at.v2.last_active': '2026-11-10T08:00:00.000Z'});
    final cache = AccountCache(durable: true);
    await cache.initialize();
    expect(cache.readOnboardedAt('bob'), isNull);
    await cache.markOnboarded('alice', DateTime.utc(2026, 11, 16));
    expect(cache.readOnboardedAt('alice'), DateTime.utc(2026, 11, 16));
    expect(cache.readOnboardedAt('bob'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('holyhim.onboarded_at.v2.last_active'), isFalse);
  });
}
