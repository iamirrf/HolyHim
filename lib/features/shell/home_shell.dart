import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../design/design.dart';
import '../growth/growth_screen.dart';
import '../profile/profile_screen.dart';
import '../saved/saved_screen.dart';
import '../today/today_screen.dart';

/// Height the floating tab bar occupies above the home indicator. Tab
/// content adds this to its bottom padding so nothing hides beneath it.
const tabBarHeight = 64.0;

class HomeShell extends StatefulWidget {
  final int initialTab;
  final ValueChanged<double>? onMood;

  /// Fixes Today's clock; for rendering only.
  final DateTime? now;
  const HomeShell({super.key, this.initialTab = 0, this.onMood, this.now});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  static const paths = ['/', '/saved', '/growth', '/profile'];
  late int index = widget.initialTab;
  final _visited = <int>{};
  late final _fade = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280), value: 1);

  @override
  void initState() {
    super.initState();
    _visited.add(index);
  }

  @override
  void didUpdateWidget(HomeShell old) {
    super.didUpdateWidget(old);
    if (old.initialTab != widget.initialTab && index != widget.initialTab) {
      _select(widget.initialTab, navigate: false);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _select(int i, {bool navigate = true}) {
    if (i == index) return;
    HolyHaptics.chipSelect();
    setState(() {
      index = i;
      _visited.add(i);
    });
    widget.onMood?.call(i.toDouble());
    if (MediaQuery.disableAnimationsOf(context)) {
      _fade.value = 1;
    } else {
      _fade.forward(from: 0);
    }
    if (navigate && GoRouterState.of(context).uri.path != paths[i]) {
      context.go(paths[i]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final media = MediaQuery.of(context);
    final barBottom = media.padding.bottom > 16 ? media.padding.bottom - 8 : 8.0;
    final tabs = [
      TodayScreen(now: widget.now),
      const SavedScreen(),
      const GrowthScreen(),
      const ProfileScreen()
    ];
    return Scaffold(
        backgroundColor: t.paper,
        body: Stack(children: [
          // Content gets extra bottom padding for the floating bar.
          MediaQuery(
              data: media.copyWith(
                  padding: media.padding
                      .copyWith(bottom: barBottom + tabBarHeight + 12)),
              child: Stack(children: [
                for (var i = 0; i < tabs.length; i++)
                  if (_visited.contains(i))
                    Offstage(
                        offstage: i != index,
                        child: TickerMode(
                            enabled: i == index,
                            child: i == index
                                ? FadeTransition(
                                    opacity: CurvedAnimation(
                                        parent: _fade,
                                        curve: Curves.easeOutCubic),
                                    child: ScaleTransition(
                                        scale: Tween(begin: .985, end: 1.0)
                                            .animate(CurvedAnimation(
                                                parent: _fade,
                                                curve: Curves.easeOutCubic)),
                                        child: tabs[i]))
                                : tabs[i])),
              ])),
          Positioned(
              left: 0,
              right: 0,
              bottom: barBottom,
              child: Center(
                  child: _TabBar(index: index, onSelect: _select))),
        ]));
  }
}

class _TabBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.index, required this.onSelect});
  static const items = [
    (CupertinoIcons.sun_max, CupertinoIcons.sun_max_fill, 'Today'),
    (CupertinoIcons.bookmark, CupertinoIcons.bookmark_fill, 'Saved'),
    (CupertinoIcons.tree, CupertinoIcons.tree, 'Growth'),
    (CupertinoIcons.person, CupertinoIcons.person_fill, 'Profile'),
  ];
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return DecoratedBox(
        decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            shadows: HolyDepth.paper(t, lift: 1.2)),
        child: FrostedGlass(
            radius: 40,
            padding: const EdgeInsets.all(6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < items.length; i++)
                Semantics(
                    button: true,
                    selected: i == index,
                    label: items[i].$3,
                    excludeSemantics: true,
                    child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelect(i),
                        child: AnimatedContainer(
                            duration: reduced
                                ? Duration.zero
                                : const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            height: 52,
                            padding: EdgeInsets.symmetric(
                                horizontal: i == index ? 18 : 16),
                            decoration: ShapeDecoration(
                                color: i == index
                                    ? t.primary
                                    : Colors.transparent,
                                shape: const StadiumBorder()),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(i == index ? items[i].$2 : items[i].$1,
                                  size: 21,
                                  color: i == index ? t.onPrimary : t.muted),
                              AnimatedSize(
                                  duration: reduced
                                      ? Duration.zero
                                      : const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                  child: i == index
                                      ? Padding(
                                          padding:
                                              const EdgeInsets.only(left: 8),
                                          child: Text(items[i].$3,
                                              textScaler: TextScaler.linear(
                                                  MediaQuery.textScalerOf(context)
                                                      .scale(1)
                                                      .clamp(1.0, 1.2)),
                                              style: HolyTypography.label
                                                  .copyWith(
                                                      color: t.onPrimary,
                                                      fontWeight:
                                                          FontWeight.w700)))
                                      : const SizedBox.shrink()),
                            ])))),
            ])));
  }
}
