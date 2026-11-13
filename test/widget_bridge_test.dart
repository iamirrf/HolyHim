import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/domain/lesson.dart';
import 'package:holyhim/domain/daily_verse.dart';
import 'package:holyhim/services/repository.dart';
import 'package:holyhim/services/widget_bridge.dart';
import 'package:timezone/data/latest.dart' as tzdata;

const _lessons = [
  Lesson(
      day: 1,
      title: 'A beginning',
      reference: 'Genesis 1:1',
      theme: 'Hope',
      verse: 'In the beginning, God created the heavens and the earth.',
      meaning: '',
      heart: '',
      holdOn: '',
      prayer: 'Amen.',
      teaser: 'In the beginning, God created…'),
  Lesson(
      day: 2,
      title: 'Near in trouble',
      reference: 'Psalm 46:1',
      theme: 'Refuge',
      verse: 'God is our refuge and strength, a very present help in trouble.',
      meaning: '',
      heart: '',
      holdOn: '',
      prayer: 'Amen.',
      teaser: 'God is our refuge and strength…'),
];
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tzdata.initializeTimeZones);
  test(
      'widget follows the calendar midnight independently of lesson completion',
      () {
    final profile = AppProfile(
        timeZone: 'America/New_York', onboardedAt: DateTime.utc(2026, 11, 1));
    final before = buildWidgetData(
        profile: profile,
        completed: {1: '2026-11-01'},
        lessons: _lessons,
        now: DateTime.utc(2026, 11, 2, 4, 59));
    expect(before['day'], 1);
    expect((before['calendarVerses'] as List)[1]['day'], 2);
    expect(before['version'], 4);
    expect(before['accessRequired'], false);
    final after = buildWidgetData(
        profile: profile,
        completed: {1: '2026-11-01'},
        lessons: _lessons,
        now: DateTime.utc(2026, 11, 2, 5));
    expect(after['day'], 2);
    expect(after['title'], 'Verse of the Day');
  });
  test('an unread widget still rotates the independent verse', () {
    final payload = buildWidgetData(
        profile: AppProfile(timeZone: 'UTC'),
        completed: {},
        lessons: _lessons,
        now: DateTime.utc(2026, 11, 3));
    expect(payload['day'], 1);
    expect(payload.containsKey('unlockAt'), isFalse);
    expect(payload['timeZone'], 'UTC');
    expect(payload['teaser'], contains('In the beginning'));
    expect(payload['colors'], hasLength(5));
  });
  test(
      'bridge shares data through the group, reloads correct kind, and clears after sign-out',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('home_widget');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'getWidgetData' ? null : true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final bridge = WidgetBridge();
    await bridge.refresh(
        profile: AppProfile(onboardedAt: DateTime.now()),
        completed: {},
        lessons: _lessons);
    final group = calls.firstWhere((call) => call.method == 'setAppGroupId');
    expect(group.arguments, {'groupId': 'group.com.holyhim.app'});
    final write = calls.firstWhere((call) => call.method == 'saveWidgetData');
    expect((write.arguments as Map)['id'], 'widgetData');
    expect(jsonDecode((write.arguments as Map)['data'])['day'],
        dailyVerseDay(DateTime.now(), 'UTC', count: 2));
    expect((calls.last.arguments as Map)['ios'], 'HolyHim');
    await bridge.clear();
    final cleared = calls.lastWhere((call) => call.method == 'saveWidgetData');
    expect((cleared.arguments as Map)['data'], isNull);
    expect(calls.last.method, 'updateWidget');
  });
}
