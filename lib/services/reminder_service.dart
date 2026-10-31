import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class ReminderService {
  final FlutterLocalNotificationsPlugin _plugin;
  final Future<String> Function() _resolveTimeZone;
  ReminderService({
    FlutterLocalNotificationsPlugin? plugin,
    Future<String> Function()? resolveTimeZone,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _resolveTimeZone = resolveTimeZone ??
            (() async => (await FlutterTimezone.getLocalTimezone()).identifier);
  Future<void>? _initialization;
  int _generation = 0;
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
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
  }

  Future<void> _refreshDeviceTimeZone() async {
    try {
      tz.setLocalLocation(tz.getLocation(await _resolveTimeZone()));
    } catch (_) {
      // Keep the last known device zone if the platform lookup is unavailable.
    }
  }

  Future<bool> deviceEnabled() async {
    if (!_supported) return false;
    try {
      await _initialize();
      final permission = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      final pending = await _plugin.pendingNotificationRequests();
      return permission?.isEnabled == true &&
          pending.any((item) => item.id == 1);
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
    return reconcile(minutes);
  }

  /// Apply an account preference on this device without prompting for permission.
  Future<bool> reconcile(int? minutes) async {
    final generation = ++_generation;
    if (!_supported) return false;
    await _initialize();
    await _refreshDeviceTimeZone();
    final permission = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.checkPermissions();
    if (_generation != generation) return false;
    if (minutes == null ||
        minutes < 0 ||
        minutes >= 1440 ||
        permission?.isEnabled != true) {
      await _plugin.cancel(id: 1);
      return false;
    }
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
    if (!next.isAfter(now)) {
      next = tz.TZDateTime(tz.local, now.year, now.month, now.day + 1,
          minutes ~/ 60, minutes % 60);
    }
    if (_generation != generation) return false;
    await _plugin.zonedSchedule(
        id: 1,
        title: 'A little hope for today',
        body: 'Your HolyHer message is here whenever you are ready.',
        scheduledDate: next,
        notificationDetails: const NotificationDetails(
            iOS: DarwinNotificationDetails(
                presentAlert: true, presentSound: true)),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time);
    return true;
  }

  Future<void> cancel() async {
    ++_generation;
    if (!_supported) return;
    try {
      await _initialize();
      await _plugin.cancel(id: 1);
    } catch (_) {}
  }
}

final reminderServiceProvider =
    Provider<ReminderService>((ref) => ReminderService());
final reminderEnabledProvider = FutureProvider<bool>(
    (ref) => ref.watch(reminderServiceProvider).deviceEnabled());
