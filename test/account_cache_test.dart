import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:holyhim/services/account_cache.dart';
import 'package:holyhim/services/avatar_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('removing a photo also hides a social-provider photo', () {
    expect(visibleAvatarUrl(null, 'https://provider.test/avatar'),
        'https://provider.test/avatar');
    expect(
        visibleAvatarUrl(
            'https://storage.test/avatar', 'https://provider.test/avatar'),
        'https://storage.test/avatar');
    expect(visibleAvatarUrl('', 'https://provider.test/avatar'), isNull);
  });
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
}
