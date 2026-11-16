import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../design/design.dart';
import '../../design/widgets/tab_shell.dart';
import '../growth/growth_screen.dart';
import '../profile/profile_screen.dart';
import '../circle/circle_screen.dart';
import '../today/today_screen.dart';
import '../walk/walk_screen.dart';

/// Height the floating tab bar occupies above the home indicator. Tab
/// content adds this to its bottom padding so nothing hides beneath it.
const tabBarHeight = 64.0;

/// The home screens, in swipe order. Paths are the router's.
const homeTabs = [
  (
    path: '/',
    tab: HolyTab('Today', CupertinoIcons.sun_max, 'sun.max', 'sun.max.fill')
  ),
  (path: '/walk', tab: HolyTab('Walk', CupertinoIcons.map, 'map', 'map.fill')),
  (
    path: '/circle',
    tab: HolyTab('Circle', CupertinoIcons.person_3, 'person.3', 'person.3.fill')
  ),
  (
    path: '/growth',
    tab: HolyTab('Growth', CupertinoIcons.tree, 'leaf', 'leaf.fill')
  ),
  (
    path: '/profile',
    tab: HolyTab('Profile', CupertinoIcons.person, 'person.crop.circle',
        'person.crop.circle.fill')
  ),
];

/// The tabs live on an endless carousel: swipe left or right forever and the
/// screens come around again, with Cognein's Liquid Glass bar in step. Each
/// screen is built fresh as it swipes in, so nothing runs offscreen.
class HomeShell extends StatefulWidget {
  final int initialTab;

  /// Fixes Today's clock; for rendering only.
  final DateTime? now;
  const HomeShell({super.key, this.initialTab = 0, this.now});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _laps = 10000;
  static int get _count => homeTabs.length;
  late int index = widget.initialTab;
  late final pages = PageController(initialPage: _laps * _count + index);

  @override
  void didUpdateWidget(HomeShell old) {
    super.didUpdateWidget(old);
    if (old.initialTab != widget.initialTab && index != widget.initialTab) {
      _select(widget.initialTab, navigate: false);
    }
  }

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  /// A tap on the bar: travel the short way round to that tab.
  void _select(int i, {bool navigate = true}) {
    if (i == index || !pages.hasClients) return;
    final current = pages.page?.round() ?? pages.initialPage;
    final forward = ((i - index) % _count + _count) % _count;
    final step = forward <= _count - forward ? forward : forward - _count;
    if (MediaQuery.disableAnimationsOf(context) || step.abs() > 1) {
      pages.jumpToPage(current + step);
    } else {
      pages.animateToPage(current + step,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic);
    }
    if (!navigate) _settle(i, navigate: false);
  }

  void _settle(int i, {bool navigate = true}) {
    if (i == index) return;
    HolyHaptics.chipSelect();
    setState(() => index = i);
    final path = homeTabs[i].path;
    if (navigate && GoRouterState.of(context).uri.path != path) {
      context.go(path);
    }
  }

  Widget _screen(int i) => switch (i) {
        0 => TodayScreen(now: widget.now),
        1 => const WalkScreen(),
        2 => const CircleScreen(),
        3 => const GrowthScreen(),
        _ => const ProfileScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final media = MediaQuery.of(context);
    final barBottom =
        media.padding.bottom > 16 ? media.padding.bottom - 8 : 8.0;
    return Scaffold(
        backgroundColor: t.paper,
        body: HolyBackdrop(
            child: HolyTabShell(
                index: index,
                tabs: [for (final entry in homeTabs) entry.tab],
                onChanged: _select,
                child: MediaQuery(
                    data: media.copyWith(
                        padding: media.padding
                            .copyWith(bottom: barBottom + tabBarHeight + 12)),
                    child: PageView.builder(
                        controller: pages,
                        onPageChanged: (page) => _settle(page % _count),
                        itemBuilder: (context, page) => KeyedSubtree(
                            key: ValueKey(page),
                            child: _screen(page % _count)))))));
  }
}
