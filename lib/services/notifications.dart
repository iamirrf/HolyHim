import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../domain/lesson.dart';
import '../domain/notification_plan.dart';
import 'repository.dart';
import 'art_cache.dart';
export '../domain/notification_plan.dart' show NotificationTap;

final notificationTapProvider = StateProvider<NotificationTap?>((ref) => null);
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(
      cachedThumbnailPath: cachedLessonThumbnail,
      onTap: (tap) => ref.read(notificationTapProvider.notifier).state = tap);
  ref.onDispose(service.dispose);
  return service;
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  final void Function(NotificationTap)? onTap;
  final Future<String> Function() _deviceZone;
  final Future<String?> Function(int day)? cachedThumbnailPath;
  Future<void> _operations = Future.value();
  final StreamController<NotificationTap> _taps = StreamController.broadcast();
  Timer? _debounce;
  Future<void>? _initializing;
  String? _account;
  AppProfile? _profile;
  Map<int, String> _completed = const {};
  List<Lesson> _lessons = const [];
  int _generation = 0;
  bool _disposed = false;
  String? _coldPayload;
  NotificationService(
      {FlutterLocalNotificationsPlugin? plugin,
      this.onTap,
      Future<String> Function()? deviceZone,
      this.cachedThumbnailPath})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _deviceZone = deviceZone ??
            (() =>
                FlutterTimezone.getLocalTimezone().then((v) => v.identifier));
  Stream<NotificationTap> get taps => _taps.stream;
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  Future<void> _initialize() {
    return _initializing ??= _setup()
        .timeout(const Duration(seconds: 5))
        .catchError((Object error, StackTrace stack) {
      _initializing = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<void> _setup() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(
          await _deviceZone().timeout(const Duration(seconds: 2))));
    } catch (_) {}
    await _plugin.initialize(
        settings: const InitializationSettings(
            iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestSoundPermission: false,
                requestBadgePermission: false,
                defaultPresentBanner: true,
                defaultPresentList: true),
            android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (response) =>
            _handle(response.payload));
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _handle(launch?.notificationResponse?.payload);
    }
  }

  Future<void> initialize() async {
    if (_supported) await _initialize();
  }

  void _handle(String? payload) {
    if (_disposed) return;
    if (_account == null || _profile == null) {
      _coldPayload = payload;
      return;
    }
    final tap = parseNotificationTap(payload,
        account: _account,
        completed: _completed,
        now: DateTime.now(),
        timeZone: _profile!.timeZone);
    if (tap != null) {
      onTap?.call(tap);
      _taps.add(tap);
    }
  }

  /// The system prompt can remain visible. App navigation gets a result in 5s.
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    try {
      return await (() async {
        await _initialize();
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          return await _plugin
                  .resolvePlatformSpecificImplementation<
                      IOSFlutterLocalNotificationsPlugin>()
                  ?.requestPermissions(
                      alert: true, sound: true, badge: false) ??
              false;
        }
        return await _plugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      })()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestReminderPermission() => requestPermission();
  Future<String> deviceTimeZone() async {
    try {
      return await _deviceZone().timeout(const Duration(seconds: 2));
    } catch (_) {
      return tz.local.name;
    }
  }

  void reconcile(
      {required String uid,
      required AppProfile profile,
      required Map<int, String> completed,
      required List<Lesson> lessons}) {
    if (_disposed) return;
    _account = uid;
    _profile = profile;
    _completed = Map.of(completed);
    _lessons = lessons;
    ++_generation;
    _debounce?.cancel();
    if (_coldPayload != null) {
      final payload = _coldPayload;
      _coldPayload = null;
      _handle(payload);
    }
    _debounce = Timer(
        const Duration(milliseconds: 350), () => _enqueueRebuild(_generation));
  }

  void _enqueueRebuild(int generation) {
    _operations =
        _operations.catchError((Object _) {}).then((_) => _rebuild(generation));
  }

  Future<void> _rebuild(int generation) async {
    if (!_supported || _profile == null || _account == null) return;
    try {
      await _initialize();
      if (generation != _generation || _disposed) return;
      final profile = _profile!;
      final account = _account!;
      final plan = notificationPlan(
          now: DateTime.now(),
          timeZone: profile.timeZone,
          minutes: profile.reminderMinutes,
          name: profile.name,
          hearts: profile.hearts,
          completed: _completed,
          lessons: _lessons,
          enabled: profile.reminderEnabled);
      // Cancel only our IDs, preserving any unrelated OS notifications.
      await _cancelOwned();
      final thumbnails = <int, String?>{};
      for (final item in plan) {
        if (generation != _generation || _disposed) return;
        String? path = thumbnails[item.day];
        if (!thumbnails.containsKey(item.day) && cachedThumbnailPath != null) {
          try {
            path = await cachedThumbnailPath!(item.day)
                .timeout(const Duration(milliseconds: 300));
          } catch (_) {
            /* An optional attachment never delays the reminder queue. */
          }
        }
        thumbnails[item.day] = path;
        if (generation != _generation || _disposed) return;
        await _plugin.zonedSchedule(
            id: item.id,
            title: item.title,
            body: item.body,
            scheduledDate: item.at,
            notificationDetails: NotificationDetails(
                iOS: DarwinNotificationDetails(
                    subtitle: item.subtitle,
                    attachments: path == null
                        ? null
                        : [DarwinNotificationAttachment(path)],
                    threadIdentifier: 'holyhim.daily',
                    presentAlert: true,
                    presentBanner: true,
                    presentList: true,
                    presentSound: profile.sounds),
                android: AndroidNotificationDetails(
                    'holyhim.daily', 'Daily Scripture for Men',
                    channelDescription:
                        'Daily Scripture reminders for a man\'s steady walk with God',
                    playSound: profile.sounds,
                    styleInformation: BigTextStyleInformation(item.body,
                        contentTitle: item.title, summaryText: item.subtitle))),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: item.payload(account));
      }
    } catch (_) {/* Reminders are optional and never hold up the walk. */}
  }

  Future<void> _cancelOwned() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final item in pending) {
      // Include v1 IDs so upgrading cannot leave duplicate reminders behind.
      if (item.id == 1 ||
          (item.id >= 1000 && item.id < 1060) ||
          (item.id >= 2000 && item.id <= 2099)) {
        await _plugin.cancel(id: item.id);
      }
    }
  }

  Future<void> cancel() async {
    final generation = ++_generation;
    _account = null;
    _profile = null;
    _coldPayload = null;
    _debounce?.cancel();
    if (!_supported) return;
    try {
      await (_operations =
          _operations.catchError((Object _) {}).then((_) async {
        await _initialize();
        await _cancelOwned();
        if (generation == _generation) _coldPayload = null;
      }));
    } catch (_) {}
  }

  void dispose() {
    _disposed = true;
    ++_generation;
    _debounce?.cancel();
    unawaited(_taps.close());
  }
}
