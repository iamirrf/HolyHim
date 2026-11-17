import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design/design.dart';
import '../../design/widgets/animated_mesh_background.dart';
import '../../design/widgets/sunrise_background.dart';
import '../../services/app_icon.dart';
import '../../services/repository.dart';

/// The eight themes, each a small window onto its own living field, with
/// the app icon that matches it. Tap one and the app changes colour like
/// the light in a room; if the Home Screen icon differs, she is offered the
/// matching one.
class ThemeScreen extends ConsumerStatefulWidget {
  const ThemeScreen({super.key});
  @override
  ConsumerState<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends ConsumerState<ThemeScreen> {
  bool iconsSupported = false;
  AppIconChoice? currentIcon;

  @override
  void initState() {
    super.initState();
    () async {
      final ok = await AppIcons.supported();
      final now = ok ? await AppIcons.current() : null;
      if (mounted) {
        setState(() {
          iconsSupported = ok;
          currentIcon = now;
        });
      }
    }();
  }

  void choose(HolyTheme theme) {
    HolyHaptics.chipSelect();
    final p = ref.read(repositoryProvider).profile;
    ref
        .read(repositoryProvider.notifier)
        .updateProfile(p.copyWith(theme: theme.id));
    final match = appIconForTheme(theme.id);
    if (!iconsSupported || currentIcon?.id == match.id) return;
    GlassToast.show(context, 'Match the app icon to ${theme.name}?',
        actionLabel: 'Use icon', onAction: () async {
      try {
        final now = await AppIcons.set(match);
        if (mounted) setState(() => currentIcon = now);
      } catch (_) {
        HolyHaptics.error();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final current =
        ref.watch(repositoryProvider.select((s) => s.profile.theme));
    return ScreenFrame(
        title: 'Theme',
        subtitle: 'Colors for every hour of the day.',
        children: [
          FitFlex(
              min: 360,
              child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    for (final theme in HolyThemes.all)
                      _Swatch(
                          theme: theme,
                          selected: HolyThemes.byId(current).id == theme.id,
                          onPressed: () => choose(theme)),
                  ])),
        ]);
  }
}

class _Swatch extends StatelessWidget {
  final HolyTheme theme;
  final bool selected;
  final VoidCallback onPressed;
  const _Swatch(
      {required this.theme, required this.selected, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    final active = HolyThemeScope.of(context);
    final shape = RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
            color: selected ? active.accent : active.hairline,
            width: selected ? 2 : 1));
    return Pressable(
        onPressed: onPressed,
        selected: selected,
        semanticLabel: '${theme.name} theme',
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: ShapeDecoration(
                color: theme.paper,
                shape: shape,
                shadows: HolyDepth.paper(active, lift: .5)),
            child: ClipRSuperellipse(
                borderRadius: BorderRadius.circular(22),
                child: Stack(fit: StackFit.expand, children: [
                  // A small window onto the theme's own field.
                  AnimatedMeshBackground(
                      theme: SunriseBackground.meshFor(theme,
                          calm: SunriseBackground.calmField)),
                  Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              for (final c in [
                                theme.primary,
                                theme.accent,
                                theme.gold,
                                theme.metal[1]
                              ])
                                Container(
                                    width: 14,
                                    height: 14,
                                    margin: const EdgeInsets.only(right: 5),
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: c,
                                        border: Border.all(
                                            color: theme.surface
                                                .withValues(alpha: .7)))),
                              const Spacer(),
                              if (selected)
                                Icon(CupertinoIcons.checkmark_circle_fill,
                                    size: 20, color: theme.accent),
                            ]),
                            const Spacer(),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text('Aa',
                                            style: HolyTypography.headline
                                                .copyWith(
                                                    color: theme.ink,
                                                    fontSize: 26)),
                                        Text(theme.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: HolyTypography.label
                                                .copyWith(color: theme.muted)),
                                      ])),
                                  // The app icon that wears this theme.
                                  ClipRSuperellipse(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                          appIconForTheme(theme.id).preview,
                                          width: 30,
                                          height: 30,
                                          filterQuality: FilterQuality.medium,
                                          errorBuilder: (c, e, s) =>
                                              const SizedBox.square(
                                                  dimension: 30))),
                                ]),
                          ])),
                ]))));
  }
}
