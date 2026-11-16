import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/services/notifications.dart';
import 'package:holyhim/services/repository.dart';
import 'package:holyhim/domain/lesson.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  FlutterLocalNotificationsPlatform? previousPlatform;
  setUp(() {
    try {
      previousPlatform = FlutterLocalNotificationsPlatform.instance;
    } catch (_) {
      previousPlatform = null;
    }
    FlutterLocalNotificationsPlatform.instance =
        IOSFlutterLocalNotificationsPlugin();
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    if (previousPlatform != null) {
      FlutterLocalNotificationsPlatform.instance = previousPlatform!;
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('a cold daily verse waits for sign-in and opens the displayed verse',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'getNotificationAppLaunchDetails') {
        return {
          'notificationLaunchedApp': true,
          'notificationResponse': {
            'notificationResponseType': 0,
            'id': 2000,
            'payload':
                '{"version":3,"account":"owner","day":42,"card":"verse","continuation":"A displayed excerpt…"}'
          }
        };
      }
      return null;
    });
    final taps = <NotificationTap>[];
    final service =
        NotificationService(deviceZone: () async => 'UTC', onTap: taps.add);
    addTearDown(service.dispose);
    await service.initialize();
    expect(taps, isEmpty);
    service.reconcile(
        uid: 'owner',
        profile: AppProfile(timeZone: 'UTC'),
        completed: {},
        lessons: const []);
    expect(taps.single.day, 42);
    expect(taps.single.verseOnly, isTrue);
  });
  const native = MethodChannel('holyhim/notifications');

  test('a transient native initialization failure can be retried', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var attempts = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initialize') {
        if (++attempts == 1) {
          throw PlatformException(code: 'temporary-unavailable');
        }
        return true;
      }
      if (call.method == 'getNotificationAppLaunchDetails') {
        return {'notificationLaunchedApp': false};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(native, (call) async =>
        call.method == 'status' ? 'notDetermined' : call.method == 'request');
    addTearDown(() => messenger.setMockMethodCallHandler(native, null));
    final service = NotificationService(deviceZone: () async => 'UTC');
    addTearDown(service.dispose);
    expect(await service.requestPermission(), isFalse);
    expect(await service.requestPermission(), isTrue);
    expect(attempts, 2);
  });

  testWidgets('iOS prompt waits for her answer, however long she reads',
      (tester) async {
    final permission = Completer<bool>();
    var requests = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'getNotificationAppLaunchDetails') {
        return {'notificationLaunchedApp': false};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(native, (call) async {
      if (call.method == 'status') return 'notDetermined';
      if (call.method == 'request') {
        requests++;
        return permission.future;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(native, null));
    final service = NotificationService(deviceZone: () async => 'UTC');
    addTearDown(service.dispose);
    var answered = false;
    final result = service.requestPermission().then((value) {
      answered = true;
      return value;
    });
    await tester.pump();
    expect(requests, 1);
    await tester.pump(const Duration(seconds: 30));
    expect(answered, isFalse);
    permission.complete(true);
    await tester.pump();
    expect(await result, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  test('once she said no, iOS is not asked again', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var requests = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'getNotificationAppLaunchDetails') {
        return {'notificationLaunchedApp': false};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(native, (call) async {
      if (call.method == 'request') requests++;
      return call.method == 'status' ? 'denied' : true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(native, null));
    final service = NotificationService(deviceZone: () async => 'UTC');
    addTearDown(service.dispose);
    expect(await service.permissionStatus(), 'denied');
    expect(await service.requestPermission(), isFalse);
    expect(requests, 0);
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('a hanging optional thumbnail does not stop the daily queue',
      (tester) async {
    var scheduled = 0, lookups = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'getNotificationAppLaunchDetails') {
        return {'notificationLaunchedApp': false};
      }
      if (call.method == 'pendingNotificationRequests') {
        return <Map<String, dynamic>>[];
      }
      if (call.method == 'zonedSchedule') scheduled++;
      return null;
    });
    final service = NotificationService(
        deviceZone: () async => 'UTC',
        cachedThumbnailPath: (day) {
          lookups++;
          return Completer<String?>().future;
        });
    addTearDown(service.dispose);
    service.reconcile(
        uid: 'owner',
        profile:
            AppProfile(name: 'Mira', timeZone: 'UTC', reminderEnabled: true),
        completed: {},
        lessons: const [
          Lesson(
              day: 1,
              title: 'Near',
              reference: 'Psalm 46:1',
              theme: 'Hope',
              verse: 'God is our refuge and strength.',
              meaning: '',
              heart: '',
              holdOn: 'God is near.',
              prayer: 'Amen.',
              teaser: 'God is near…')
        ]);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(scheduled, 0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(scheduled, inInclusiveRange(29, 30)); // 29 daily notes, plus tonight's walk note when due.
    expect(lookups, 1);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
