import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:holyher/data/lessons.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/reading_destination.dart';

class QuoteReminder {
  final int id, day;
  final tz.TZDateTime scheduledDate;
  const QuoteReminder(this.id, this.day, this.scheduledDate);
}

/// Device wall time controls delivery; journey calendar controls the destination.
List<QuoteReminder> buildQuoteReminderQueue(
    {required tz.TZDateTime now,
    required int minutes,
    required String startDate,
    required String journeyTimeZone,
    int count = 60}) {
  if (minutes < 0 || minutes >= 1440 || count < 0 || count > 60) {
    throw ArgumentError('Invalid reminder plan.');
  }
  final start = DateTime.parse(startDate),
      zone =
          journeyTimeZone == 'UTC' ? tz.UTC : tz.getLocation(journeyTimeZone);
  final startOrdinal = DateTime.utc(start.year, start.month, start.day);
  final result = <QuoteReminder>[];
  for (var offset = 0; result.length < count; offset++) {
    final next = tz.TZDateTime(now.location, now.year, now.month,
        now.day + offset, minutes ~/ 60, minutes % 60);
    if (!next.isAfter(now)) continue;
    final journeyDate = tz.TZDateTime.from(next, zone);
    final day =
        (DateTime.utc(journeyDate.year, journeyDate.month, journeyDate.day)
                    .difference(startOrdinal)
                    .inDays +
                1)
            .clamp(1, 365);
    result.add(QuoteReminder(1000 + result.length, day, next));
  }
  return result;
}

class ReminderService {
  final FlutterLocalNotificationsPlugin _plugin;
  final Future<String> Function() _resolveTimeZone;
  final String? Function() _account;
  final ({String? startDate, String? timeZone}) Function() _journey;
  final void Function(String account, int day)? _open;
  ReminderService(
      {FlutterLocalNotificationsPlugin? plugin,
      Future<String> Function()? resolveTimeZone,
      String? Function()? account,
      ({String? startDate, String? timeZone}) Function()? journey,
      void Function(String account, int day)? onOpen})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _resolveTimeZone = resolveTimeZone ??
            (() =>
                FlutterTimezone.getLocalTimezone().then((v) => v.identifier)),
        _account = account ?? (() => null),
        _journey = journey ?? (() => (startDate: null, timeZone: null)),
        _open = onOpen;
  Future<void>? _initialization;
  Future<void> _operations = Future.value();
  int _generation = 0;
  String? _lastPlan;
  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  Future<void> _initialize() => _initialization ??= _setup();
  Future<void> _setup() async {
    tzdata.initializeTimeZones();
    await _refreshDeviceTimeZone();
    await _plugin.initialize(
        settings: const InitializationSettings(
            iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false),
            android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (r) => _handle(r.payload));
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _handle(launch?.notificationResponse?.payload);
    }
  }

  void _handle(String? payload) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map;
      final uid = data['account'];
      final day = data['day'];
      if (uid is String &&
          uid == _account() &&
          day is int &&
          day >= 1 &&
          day <= 365) {
        _open?.call(uid, day);
      }
    } catch (_) {}
  }

  Future<void> _refreshDeviceTimeZone() async {
    try {
      tz.setLocalLocation(tz.getLocation(await _resolveTimeZone()));
    } catch (_) {/* Last known device zone remains usable. */}
  }

  Future<bool> deviceEnabled() async {
    if (!_supported) return false;
    try {
      await _initialize();
      final permissions = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      final pending = await _plugin.pendingNotificationRequests();
      return permissions?.isEnabled == true &&
          pending.any((r) => r.id >= 1000 && r.id < 1060);
    } catch (_) {
      return false;
    }
  }

  Future<bool> schedule(int minutes) async {
    if (!_supported || minutes < 0 || minutes >= 1440) return false;
    await _initialize();
    final allowed = await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, sound: true, badge: false) ??
        false;
    if (!allowed) return false;
    await reconcile(minutes);
    // During optional setup a journey does not exist yet. Permission is still
    // correctly recorded; the queue begins after the server acknowledges it.
    return true;
  }

  Future<bool> reconcile(int? minutes) async {
    final generation = ++_generation;
    var accepted = false;
    await (_operations = _operations.catchError((Object _) {}).then((_) async {
      accepted = await _reconcile(minutes, generation);
    }));
    return accepted;
  }

  Future<void> _cancelOwned() async {
    await _plugin.cancel(id: 1); // Drain the old recurring reminder.
    for (var id = 1000; id < 1060; id++) {
      await _plugin.cancel(id: id);
    }
    _lastPlan = null;
  }

  Future<bool> _reconcile(int? minutes, int generation) async {
    if (!_supported) return false;
    await _initialize();
    await _refreshDeviceTimeZone();
    final permissions = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.checkPermissions();
    if (generation != _generation) return false;
    final account = _account(), journey = _journey();
    if (minutes == null ||
        minutes < 0 ||
        minutes >= 1440 ||
        permissions?.isEnabled != true ||
        account == null ||
        journey.startDate == null ||
        journey.timeZone == null) {
      await _cancelOwned();
      return false;
    }
    final now = tz.TZDateTime.now(tz.local);
    final key =
        '$account|$minutes|${tz.local.name}|${now.year}-${now.month}-${now.day}|${journey.startDate}|${journey.timeZone}';
    if (_lastPlan == key) return true;
    final queue = buildQuoteReminderQueue(
        now: now,
        minutes: minutes,
        startDate: journey.startDate!,
        journeyTimeZone: journey.timeZone!);
    await _cancelOwned();
    for (final reminder in queue) {
      if (generation != _generation) return false;
      final lesson = lessons[reminder.day - 1];
      final excerpt = lesson.verseText.length <= 140
          ? lesson.verseText
          : '${lesson.verseText.substring(0, 137).trimRight()}…';
      await _plugin.zonedSchedule(
          id: reminder.id,
          title: '${lesson.verseReference} · A moment with God',
          body: '$excerpt\nContinue your walk with God.',
          scheduledDate: reminder.scheduledDate,
          notificationDetails: const NotificationDetails(
              iOS: DarwinNotificationDetails(
                  presentAlert: true, presentSound: true)),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: jsonEncode({
            'account': account,
            'day': reminder.day,
            'card': 'scripture',
            'version': 1
          }));
    }
    if (generation == _generation) _lastPlan = key;
    return generation == _generation;
  }

  Future<void> cancel() async {
    ++_generation;
    if (!_supported) return;
    await (_operations = _operations.catchError((Object _) {}).then((_) async {
      await _initialize();
      await _cancelOwned();
    }));
  }
}

final reminderServiceProvider =
    Provider<ReminderService>((ref) => ReminderService(
        account: () => ref.read(authProvider).user?.uid,
        journey: () {
          final p = ref.read(progressProvider);
          return (startDate: p.startDate, timeZone: p.timeZone);
        },
        onOpen: (account, day) {
          if (ref.read(authProvider).user?.uid == account) {
            ref.read(readingDestinationProvider.notifier).state =
                ReadingDestination(day, scripture: true);
          }
        }));
final reminderEnabledProvider = FutureProvider<bool>(
    (ref) => ref.watch(reminderServiceProvider).deviceEnabled());
