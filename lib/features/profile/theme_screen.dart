import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design/design.dart';
import '../../services/repository.dart';

/// The eight themes as small printed pages; tap one and the app changes
/// colour like the light in a room.
class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(repositoryProvider.select((s) => s.profile.theme));
    return ScreenFrame(
        title: 'Theme',
        subtitle: 'Paper and ink for every time of day.',
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
                          onPressed: () {
                            HolyHaptics.chipSelect();
                            final p = ref.read(repositoryProvider).profile;
                            ref
                                .read(repositoryProvider.notifier)
                                .updateProfile(p.copyWith(theme: theme.id));
                          }),
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
    return Pressable(
        onPressed: onPressed,
        selected: selected,
        semanticLabel: '${theme.name} theme',
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(14),
            decoration: ShapeDecoration(
                color: theme.paper,
                shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: BorderSide(
                        color: selected ? active.accent : active.hairline,
                        width: selected ? 2 : 1)),
                shadows: HolyDepth.paper(active, lift: .5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                for (final c in [theme.primary, theme.accent, theme.gold, theme.olive])
                  Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
                const Spacer(),
                if (selected)
                  Icon(CupertinoIcons.checkmark_circle_fill,
                      size: 20, color: theme.accent),
              ]),
              const Spacer(),
              Text('Aa',
                  style: HolyTypography.headline
                      .copyWith(color: theme.ink, fontSize: 26)),
              Text(theme.name,
                  style: HolyTypography.label.copyWith(color: theme.muted)),
            ])));
  }
}
