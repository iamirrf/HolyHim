import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyher/services/reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  FlutterLocalNotificationsPlatform? original;
  final calls = <MethodCall>[];

  setUp(() {
    try {
      original = FlutterLocalNotificationsPlatform.instance;
    } catch (_) {
      original = null; // Unit-test isolates have no native plugin registrant.
    }
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    FlutterLocalNotificationsPlatform.instance =
        IOSFlutterLocalNotificationsPlugin();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'initialize' => true,
        'checkPermissions' => {'isEnabled': true, 'isAlertEnabled': true},
        _ => null,
      };
    });
  });
  tearDown(() {
    if (original != null) {
      FlutterLocalNotificationsPlatform.instance = original!;
    }
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
      'reconciliation follows a changed device zone without changing wall time',
      () async {
    var deviceZone = 'America/New_York';
    final service = ReminderService(
        resolveTimeZone: () async => deviceZone,
        account: () => 'qa-reader',
        journey: () => (startDate: '2026-10-01', timeZone: 'America/New_York'));
    expect(await service.reconcile(8 * 60), isTrue);
    deviceZone = 'America/Los_Angeles';
    expect(await service.reconcile(8 * 60), isTrue);
    final schedules = calls
        .where((call) => call.method == 'zonedSchedule')
        .map((call) => call.arguments as Map)
        .toList();
    expect(schedules.length, 120);
    expect(schedules[0]['timeZoneName'], 'America/New_York');
    expect(schedules[60]['timeZoneName'], 'America/Los_Angeles');
    expect(schedules[0]['scheduledDateTime'], contains('T08:00:00'));
    expect(schedules[60]['scheduledDateTime'], contains('T08:00:00'));
    expect(calls.where((call) => call.method == 'requestPermissions'), isEmpty);
    expect(await service.reconcile(null), isFalse);
    expect(calls.last.method, 'cancel');
  });
}
