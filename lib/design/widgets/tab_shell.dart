import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import '../themes.dart';
import 'glass_nav_bar.dart';

/// Cognein's native iOS 26 setup and its refracting, minimizing portable bar.
/// The caller keeps the atmosphere outside this shell, across all routes.
class HolyTabShell extends StatefulWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final Widget child;
  const HolyTabShell(
      {super.key,
      required this.index,
      required this.onChanged,
      required this.child});
  static double bottomInset(BuildContext context) =>
      MinimizingGlassNavBar.reservedHeight(context) + 16;
  @override
  State<HolyTabShell> createState() => _HolyTabShellState();
}

class _HolyTabShellState extends State<HolyTabShell> {
  final _minimized = ValueNotifier(false);
  @override
  void dispose() {
    _minimized.dispose();
    super.dispose();
  }

  static const _items = [
    MinimizingNavItem(icon: CupertinoIcons.sparkles, label: 'Walk'),
    MinimizingNavItem(icon: CupertinoIcons.heart, label: 'Saved'),
    MinimizingNavItem(icon: CupertinoIcons.chart_bar_alt_fill, label: 'Growth'),
    MinimizingNavItem(icon: CupertinoIcons.person_crop_circle, label: 'Profile')
  ];
  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && PlatformInfo.isIOS26OrHigher()) {
      return AdaptiveScaffold(
          body: widget.child,
          enableBlur: false,
          minimizeBehavior: TabBarMinimizeBehavior.automatic,
          bottomNavigationBar: AdaptiveBottomNavigationBar(
              selectedIndex: widget.index,
              useNativeBottomBar: true,
              onTap: widget.onChanged,
              items: const [
                AdaptiveNavigationDestination(
                    icon: 'sparkles', selectedIcon: 'sparkles', label: 'Walk'),
                AdaptiveNavigationDestination(
                    icon: 'heart', selectedIcon: 'heart.fill', label: 'Saved'),
                AdaptiveNavigationDestination(
                    icon: 'chart.bar',
                    selectedIcon: 'chart.bar.fill',
                    label: 'Growth'),
                AdaptiveNavigationDestination(
                    icon: 'person.crop.circle',
                    selectedIcon: 'person.crop.circle.fill',
                    label: 'Profile')
              ]));
    }
    final theme = HolyThemeScope.of(context);
    return NotificationListener<UserScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axis == Axis.vertical && n.metrics.pixels > 32) {
            if (n.direction == ScrollDirection.reverse) _minimized.value = true;
            if (n.direction == ScrollDirection.forward) {
              _minimized.value = false;
            }
          } else if (n.metrics.axis == Axis.vertical &&
              n.metrics.pixels <= 32) {
            _minimized.value = false;
          }
          return false;
        },
        child: Stack(fit: StackFit.expand, children: [
          widget.child,
          MinimizingGlassNavBar(
              items: _items,
              selectedIndex: widget.index,
              onSelected: (i) {
                _minimized.value = false;
                widget.onChanged(i);
              },
              minimized: _minimized,
              onExpand: () => _minimized.value = false,
              activeColor: theme.accent,
              inactiveColor: theme.muted,
              alignment: Alignment.bottomCenter,
              maxWidth: 430)
        ]));
  }
}
