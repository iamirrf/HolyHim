import 'dart:async';
import 'package:flutter/material.dart';
import '../haptics.dart';
import '../themes.dart';
import '../typography.dart';
import 'glass.dart';
import 'pressable.dart';

/// Cognein's one-at-a-time floating notification surface, adapted to rose glass.
class GlassToast {
  GlassToast._();
  static OverlayEntry? _current;
  static Timer? _timer;
  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }

  static void show(BuildContext context, String message,
      {String? actionLabel, VoidCallback? onAction, bool error = false}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final theme = HolyThemeScope.of(context),
        opaque = HolyThemeScope.opaqueOf(context);
    dismiss();
    HolyHaptics.detent();
    _current = OverlayEntry(
        builder: (context) => Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: HolyThemeScope(
                        theme: theme,
                        reduceTransparency: opaque,
                        child: _ToastCard(
                            message: message,
                            actionLabel: actionLabel,
                            onAction: onAction,
                            error: error))))));
    overlay.insert(_current!);
    _timer = Timer(Duration(seconds: actionLabel == null ? 4 : 6), dismiss);
  }

  static void success(BuildContext c, String message) => show(c, message);
  static void info(BuildContext c, String message) => show(c, message);
  static void error(BuildContext c, String message) =>
      show(c, message, error: true);
}

class _ToastCard extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool error;
  const _ToastCard(
      {required this.message,
      this.actionLabel,
      this.onAction,
      this.error = false});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        builder: (context, p, child) => Opacity(
            opacity: p,
            child: Transform.translate(
                offset: Offset(0, -24 * (1 - p)), child: child)),
        child: Material(
            type: MaterialType.transparency,
            child: Semantics(
                liveRegion: true,
                label: message,
                child: Glass(
                    radius: 22,
                    elevation: 3,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    child: Row(children: [
                      Icon(
                          error
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 22,
                          color: t.accent),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(message,
                              style: HolyTypography.ui
                                  .copyWith(fontSize: 14, color: t.ink))),
                      if (actionLabel != null)
                        Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Pressable(
                                onPressed: () {
                                  GlassToast.dismiss();
                                  onAction?.call();
                                },
                                child: Text(actionLabel!,
                                    style: HolyTypography.ui.copyWith(
                                        fontSize: 14,
                                        color: t.accent,
                                        fontWeight: FontWeight.w800))))
                    ])))));
  }
}
