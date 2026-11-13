import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/domain/routes.dart';

void main() {
  test('widget custom scheme and regular app links resolve the same lesson',
      () {
    for (final value in [
      'holyhim://lesson/today',
      'holyhim:///lesson/today',
      'holyhim://app/lesson/today',
      '/lesson/today'
    ]) {
      expect(appPath(Uri.parse(value)), '/lesson/today');
    }
  });
  test('ordinary web destinations and safe root remain intact', () {
    expect(appPath(Uri.parse('/saved')), '/saved');
    expect(appPath(Uri.parse('holyhim://app')), '/');
    expect(appPath(Uri.parse('/lesson/366')), '/lesson/366');
  });
}
