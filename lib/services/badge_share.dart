import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import '../design/design.dart';
import '../domain/badges.dart';

/// The same porcelain keepsake used on the shelf, rendered as a 9:16 image.
class BadgeShareCard extends StatelessWidget {
  final WalkBadge badge;
  final IconData icon;
  const BadgeShareCard({super.key, required this.badge, required this.icon});
  @override
  Widget build(BuildContext context) {
    final theme = HolyThemeScope.of(context);
    return DecoratedBox(
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: theme.colors)),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 46, 32, 40),
            child: Column(children: [
              Text('HOLYHIM',
                  style: HolyTypography.eyebrow
                      .copyWith(letterSpacing: 3, color: theme.ink)),
              const Spacer(),
              Badge3D(
                  badgeId: badge.id,
                  icon: icon,
                  label: '',
                  earned: true,
                  size: 190),
              const SizedBox(height: 20),
              Text(badge.title,
                  textAlign: TextAlign.center,
                  style: HolyTypography.title
                      .copyWith(fontSize: 28, color: theme.ink)),
              const SizedBox(height: 16),
              Text(badge.description,
                  textAlign: TextAlign.center,
                  style: HolyTypography.ui
                      .copyWith(fontSize: 14, color: theme.muted)),
              const Spacer(),
              Text('A little closer, every day.',
                  textAlign: TextAlign.center,
                  style: HolyTypography.accent
                      .copyWith(fontSize: 28, color: theme.accent)),
              const SizedBox(height: 10),
              Text('A keepsake from my walk with God',
                  textAlign: TextAlign.center,
                  style: HolyTypography.ui
                      .copyWith(fontSize: 10, color: theme.muted))
            ])));
  }
}

/// Opacity sits outside the repaint boundary: the exported pixels stay opaque.
/// Keeping the boundary in the viewport guarantees it paints before toImage.
Future<Uint8List?> renderBadgeImage(BuildContext context, WalkBadge badge,
    {IconData icon = Icons.auto_awesome_rounded}) async {
  final key = GlobalKey();
  final theme = HolyThemeScope.of(context);
  final entry = OverlayEntry(
      builder: (context) => Positioned(
          left: 0,
          top: 0,
          width: 360,
          height: 640,
          child: IgnorePointer(
              child: Opacity(
                  opacity: .01,
                  child: RepaintBoundary(
                      key: key,
                      child: MediaQuery(
                          data: const MediaQueryData(
                              size: Size(360, 640),
                              textScaler: TextScaler.noScaling,
                              disableAnimations: true),
                          child: HolyThemeScope(
                              theme: theme,
                              child: Theme(
                                  data: HolyThemeData.build(theme),
                                  child: Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: BadgeShareCard(
                                          badge: badge, icon: icon))))))))));
  Overlay.of(context).insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    entry.remove();
  }
}

Future<void> shareBadgeImage(BuildContext context, WalkBadge badge,
    {IconData icon = Icons.auto_awesome_rounded}) async {
  final path = HolyArtAssets.badgePath(badge.id);
  final bundle = DefaultAssetBundle.of(context);
  if (path != null && await HolyArtAssets.contains(bundle, path)) {
    if (!context.mounted) return;
    await precacheImage(AssetImage(path, bundle: bundle), context,
        onError: (error, stack) {});
  }
  if (!context.mounted) return;
  final bytes = await renderBadgeImage(context, badge, icon: icon);
  if (bytes == null || !context.mounted) return;
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(ShareParams(
      files: [
        XFile.fromData(bytes,
            mimeType: 'image/png', name: 'holyhim-${badge.id}.png')
      ],
      text: '${badge.title} · HolyHim',
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size));
}
