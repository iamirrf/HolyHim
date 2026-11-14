import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import '../../design/design.dart';
import '../../design/widgets/atmosphere.dart';
import '../../design/widgets/glass_nav_bar.dart';
import '../community/community_screen.dart';
import '../community/ranks_screen.dart';
import '../growth/growth_screen.dart';
import '../profile/profile_screen.dart';
import '../walk/walk_screen.dart';

@immutable
class HomeTab {
  final String path, label, symbol;
  final IconData icon;
  const HomeTab(this.path, this.label, this.symbol, this.icon);
}

/// The five home tabs, in swipe order. The order wraps: past Profile comes
/// the Walk again.
const homeTabs = [
  HomeTab('/', 'Walk', 'map.fill', CupertinoIcons.map_fill),
  HomeTab('/brothers', 'Brothers', 'person.2.fill', CupertinoIcons.person_2_fill),
  HomeTab('/ranks', 'Ranks', 'trophy.fill', Icons.emoji_events_rounded),
  HomeTab('/growth', 'Growth', 'chart.bar.fill', CupertinoIcons.chart_bar_alt_fill),
  HomeTab('/profile', 'Profile', 'person.crop.circle.fill',
      CupertinoIcons.person_crop_circle_fill),
];

/// Bottom room every tab keeps clear for the floating bar.
double homeBarInset(BuildContext context) =>
    MinimizingGlassNavBar.reservedHeight(context) + 12;

/// The home of the app: five tabs on one living field, swiped left and right
/// without end, under Cognein's liquid glass bar. On iOS 26 the bar is the
/// system's own; elsewhere it is the refracting capsule that folds away as
/// you scroll and opens again on the way back up.
class HomeShell extends StatefulWidget {
  final int initialTab;
  final ValueChanged<double>? onMood;

  /// Fixes the walk's clock; for rendering only.
  final DateTime? now;
  const HomeShell({super.key, this.initialTab = 0, this.onMood, this.now});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with TickerProviderStateMixin {
  static const _n = 5;
  static final _settleSpring =
      SpringDescription.withDampingRatio(mass: .5, stiffness: 100, ratio: 1.1);

  /// The pager's position in pages. It runs without bounds; the tab shown
  /// is the position modulo five.
  late final _position =
      AnimationController.unbounded(vsync: this, value: widget.initialTab * 1.0);
  late final _page = ValueNotifier<double>(widget.initialTab * 1.0);
  final _minimized = ValueNotifier(false);
  late int index = widget.initialTab;
  double _dragStart = 0;
  late final List<Widget> _tabs = [
    WalkScreen(now: widget.now),
    const CommunityScreen(),
    const RanksScreen(),
    GrowthScreen(now: widget.now),
    const ProfileScreen(),
  ];
  final _keys = List.generate(_n, (i) => GlobalKey(debugLabel: 'tab-$i'));

  @override
  void initState() {
    super.initState();
    _position.addListener(_onMove);
  }

  @override
  void didUpdateWidget(HomeShell old) {
    super.didUpdateWidget(old);
    if (old.initialTab != widget.initialTab && index != widget.initialTab) {
      _goTo(widget.initialTab, navigate: false);
    }
  }

  @override
  void dispose() {
    _position.dispose();
    _page.dispose();
    _minimized.dispose();
    super.dispose();
  }

  static int _wrap(int i) => ((i % _n) + _n) % _n;

  void _onMove() {
    _page.value = _position.value;
    widget.onMood?.call(_position.value % _n);
    final now = _wrap(_position.value.round());
    if (now != index) {
      setState(() => index = now);
      _minimized.value = false;
      HolyHaptics.detent();
    }
  }

  void _syncRoute() {
    if (!mounted) return;
    final path = homeTabs[index].path;
    final router = GoRouter.maybeOf(context);
    if (router != null &&
        GoRouterState.of(context).uri.path != path &&
        ModalRoute.of(context)?.isCurrent != false) {
      context.go(path);
    }
  }

  void _settle(double target, {double velocity = 0}) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _position.value = target;
      _syncRoute();
      return;
    }
    _position
        .animateWith(SpringSimulation(
            _settleSpring, _position.value, target, velocity,
            tolerance: const Tolerance(distance: .0005, velocity: .01)))
        .whenCompleteOrCancel(() {
      if (!_position.isAnimating) _syncRoute();
    });
  }

  /// Moves to [tab] the short way round.
  void _goTo(int tab, {bool navigate = true}) {
    final current = _position.value.round();
    var delta = _wrap(tab - _wrap(current));
    if (delta > _n / 2) delta -= _n;
    if (delta == 0 && (_position.value - current).abs() < .001) {
      if (navigate) _syncRoute();
      return;
    }
    HolyHaptics.chipSelect();
    _minimized.value = false;
    _settle((current + delta).toDouble());
  }

  void _dragStarted(DragStartDetails _) {
    _position.stop();
    _dragStart = _position.value.roundToDouble();
  }

  void _dragUpdated(DragUpdateDetails d, double width) {
    _position.value -= d.delta.dx / width;
  }

  void _dragEnded(DragEndDetails d, double width) {
    final v = -d.velocity.pixelsPerSecond.dx / width;
    final p = _position.value;
    var target = v.abs() > .55
        ? (v > 0 ? p.floorToDouble() + 1 : p.ceilToDouble() - 1)
        : p.roundToDouble();
    // One page per swipe, as a pager should.
    target = target.clamp(_dragStart - 1, _dragStart + 1);
    _settle(target, velocity: v);
  }

  bool _onScroll(UserScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n.metrics.pixels <= 32) {
      _minimized.value = false;
    } else if (n.direction == ScrollDirection.reverse) {
      _minimized.value = true;
    } else if (n.direction == ScrollDirection.forward) {
      _minimized.value = false;
    }
    return false;
  }

  Widget _pager(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final width = box.maxWidth;
        return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _dragStarted,
            onHorizontalDragUpdate: (d) => _dragUpdated(d, width),
            onHorizontalDragEnd: (d) => _dragEnded(d, width),
            onHorizontalDragCancel: () => _settle(_position.value.roundToDouble()),
            child: AnimatedBuilder(
                animation: _position,
                builder: (context, _) {
                  final p = _position.value;
                  return Stack(fit: StackFit.expand, children: [
                    for (var i = 0; i < _n; i++) _place(i, p, width),
                  ]);
                }));
      });

  Widget _place(int i, double p, double width) {
    // Signed distance from the pager to tab i, the short way round.
    var d = (i - p) % _n;
    if (d >= _n / 2) d -= _n;
    final visible = d.abs() < .999;
    return Offstage(
        offstage: !visible,
        child: TickerMode(
            enabled: visible,
            child: Transform.translate(
                offset: Offset(d * width, 0),
                child: RepaintBoundary(
                    child: KeyedSubtree(key: _keys[i], child: _tabs[i])))));
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final media = MediaQuery.of(context);
    final native = !kIsWeb && PlatformInfo.isIOS26OrHigher();
    final content = MediaQuery(
        data: media.copyWith(
            padding: media.padding.copyWith(bottom: homeBarInset(context))),
        child: _pager(context));

    if (native) {
      return HolyAtmosphere(
          page: _page,
          child: CupertinoTheme(
              data: CupertinoTheme.of(context)
                  .copyWith(scaffoldBackgroundColor: Colors.transparent),
              child: AdaptiveScaffold(
                  body: content,
                  enableBlur: true,
                  minimizeBehavior: TabBarMinimizeBehavior.automatic,
                  bottomNavigationBar: AdaptiveBottomNavigationBar(
                      selectedIndex: index,
                      useNativeBottomBar: true,
                      selectedItemColor: t.accent,
                      onTap: _goTo,
                      items: [
                        for (final tab in homeTabs)
                          AdaptiveNavigationDestination(
                              icon: tab.symbol,
                              selectedIcon: tab.symbol,
                              label: tab.label),
                      ]))));
    }
    return HolyAtmosphere(
        page: _page,
        child: NotificationListener<UserScrollNotification>(
            onNotification: _onScroll,
            child: Stack(fit: StackFit.expand, children: [
              content,
              Positioned.fill(
                  child: MinimizingGlassNavBar(
                      items: [
                        for (final tab in homeTabs)
                          MinimizingNavItem(icon: tab.icon, label: tab.label),
                      ],
                      selectedIndex: index,
                      onSelected: _goTo,
                      minimized: _minimized,
                      onExpand: () => _minimized.value = false,
                      activeColor: t.accent,
                      inactiveColor: t.muted,
                      alignment: Alignment.bottomCenter,
                      maxWidth: 440)),
            ])));
  }
}
