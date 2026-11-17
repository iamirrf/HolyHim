import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../design/design.dart';
import '../services/notifications.dart';

/// Turns notes on the way iOS allows: its own prompt the first time; after a
/// "Don't Allow", a short sheet that opens HolyHim's notification settings
/// and notices when she comes back with them on.
Future<bool> enableNotifications(BuildContext context, WidgetRef ref) async {
  final service = ref.read(notificationServiceProvider);
  if (!service.supported) return false;
  final status = await service.permissionStatus();
  if (status == 'authorized' || status == 'provisional') return true;
  if (status == 'notDetermined') return service.requestPermission();
  if (!context.mounted) return false;
  final allowed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .3),
      builder: (_) => _SettingsSheet(service: service));
  return allowed ?? false;
}

class _SettingsSheet extends StatefulWidget {
  final NotificationService service;
  const _SettingsSheet({required this.service});
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet>
    with WidgetsBindingObserver {
  bool opened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && opened) _check();
  }

  Future<void> _check() async {
    final status = await widget.service.permissionStatus();
    if (!mounted) return;
    if (status == 'authorized' || status == 'provisional') {
      HolyHaptics.success();
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Padding(
        padding: EdgeInsets.fromLTRB(
            12, 0, 12, MediaQuery.paddingOf(context).bottom + 12),
        child: ClipRSuperellipse(
            borderRadius: BorderRadius.circular(HolyRadius.sheet),
            child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: ColoredBox(
                    color: t.surface.withValues(alpha: .9),
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(CupertinoIcons.bell_fill,
                              color: t.gold, size: 38),
                          const SizedBox(height: 12),
                          Text('Turn on your morning note',
                              textAlign: TextAlign.center,
                              style: HolyTypography.title
                                  .copyWith(color: t.ink, fontSize: 26)),
                          const SizedBox(height: 8),
                          Text(
                              'Notifications for HolyHim are off. Open Settings, turn on Allow Notifications, then come back.',
                              textAlign: TextAlign.center,
                              style:
                                  HolyTypography.body.copyWith(color: t.muted)),
                          const SizedBox(height: 20),
                          HolyButton('Open Settings', onPressed: () {
                            opened = true;
                            widget.service.openSettings();
                          }),
                          const SizedBox(height: 6),
                          TextAction('Not now',
                              color: t.muted,
                              onPressed: () =>
                                  Navigator.of(context).pop(false)),
                        ]))))));
  }
}
