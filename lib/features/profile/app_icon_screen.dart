import 'package:flutter/cupertino.dart';
import '../../design/design.dart';
import '../../services/app_icon.dart';
import '../common.dart';

/// The Home Screen icons, grouped: the cross in each theme's colours, five
/// symbols, and two for the seasons. Tap one and iOS changes the icon.
class AppIconScreen extends StatefulWidget {
  const AppIconScreen({super.key});
  @override
  State<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends State<AppIconScreen> {
  AppIconChoice? current;
  bool supported = true;
  String? changing;

  @override
  void initState() {
    super.initState();
    () async {
      final ok = await AppIcons.supported();
      final now = await AppIcons.current();
      if (mounted) {
        setState(() {
          supported = ok;
          current = now;
        });
      }
    }();
  }

  Future<void> choose(AppIconChoice icon) async {
    if (changing != null || icon.id == current?.id) return;
    HolyHaptics.chipSelect();
    setState(() => changing = icon.id);
    try {
      final now = await AppIcons.set(icon);
      if (mounted) setState(() => current = now);
    } catch (_) {
      HolyHaptics.error();
      if (mounted) {
        toast(context, 'The icon could not change. Try again.');
      }
    } finally {
      if (mounted) setState(() => changing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final groups = <String, List<AppIconChoice>>{};
    for (final icon in appIcons) {
      groups.putIfAbsent(icon.group, () => []).add(icon);
    }
    return ScreenFrame(
        title: 'App icon',
        subtitle: supported
            ? 'Choose how HolyHim looks on your Home Screen.'
            : 'This iPhone keeps the standard icon.',
        scroll: true,
        children: [
          for (final entry in groups.entries) ...[
            Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 0, 12),
                child: Eyebrow(entry.key, color: t.muted)),
            GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 18,
                crossAxisSpacing: 14,
                childAspectRatio: .78,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 22),
                children: [
                  for (final icon in entry.value)
                    _IconTile(
                        icon: icon,
                        selected: current?.id == icon.id,
                        busy: changing == icon.id,
                        onPressed: supported ? () => choose(icon) : null),
                ]),
          ],
          if (supported)
            // iOS 18.1 and later keep the old icon on notifications until the
            // iPhone restarts; nothing an app can do refreshes it sooner.
            Padding(
                padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(CupertinoIcons.bell,
                              size: 15, color: t.muted)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              'Notifications may keep the previous icon until you restart your iPhone.',
                              style: HolyTypography.caption
                                  .copyWith(color: t.muted))),
                    ])),
        ]);
  }
}

class _IconTile extends StatelessWidget {
  final AppIconChoice icon;
  final bool selected, busy;
  final VoidCallback? onPressed;
  const _IconTile(
      {required this.icon,
      required this.selected,
      required this.busy,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Pressable(
        onPressed: onPressed,
        selected: selected,
        semanticLabel: '${icon.name} app icon',
        child: Column(children: [
          Expanded(
              child: Center(
                  child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(clipBehavior: Clip.none, children: [
                        Positioned.fill(
                            child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                padding: EdgeInsets.all(selected ? 4 : 0),
                                decoration: ShapeDecoration(
                                    shape: RoundedSuperellipseBorder(
                                        borderRadius: BorderRadius.circular(26),
                                        side: BorderSide(
                                            color: selected
                                                ? t.accent
                                                : const Color(0x00000000),
                                            width: 2.5))),
                                child: ClipRSuperellipse(
                                    borderRadius: BorderRadius.circular(
                                        selected ? 21 : 24),
                                    child: DecoratedBox(
                                        decoration: BoxDecoration(
                                            boxShadow:
                                                HolyDepth.paper(t, lift: .6)),
                                        child: Image.asset(icon.preview,
                                            fit: BoxFit.cover,
                                            filterQuality:
                                                FilterQuality.medium))))),
                        if (busy)
                          const Positioned.fill(
                              child: Center(
                                  child: CupertinoActivityIndicator(
                                      color: Color(0xFFFFFFFF)))),
                        if (selected)
                          Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle, color: t.paper),
                                  child: Icon(
                                      CupertinoIcons.checkmark_circle_fill,
                                      size: 24,
                                      color: t.accent))),
                      ])))),
          const SizedBox(height: 8),
          Text(icon.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: HolyTypography.label.copyWith(
                  color: selected ? t.ink : t.muted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        ]));
  }
}
