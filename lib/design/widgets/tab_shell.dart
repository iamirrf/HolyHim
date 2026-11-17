import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import '../themes.dart';
import 'glass_nav_bar.dart';

/// Cognein's native iOS 26 setup and its refracting, minimizing portable bar.
/// The caller keeps the atmosphere outside this shell, across all routes.
/// One destination: a Cupertino icon for the glass bar and SF Symbol names
/// for the native iOS 26 Liquid Glass bar.
class HolyTab {
  final String label, symbol, selectedSymbol;
  final IconData icon;
  const HolyTab(this.label, this.icon, this.symbol, this.selectedSymbol);
}

class HolyTabShell extends StatefulWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<HolyTab> tabs;
  final Widget child;
  const HolyTabShell(
      {super.key,
      required this.index,
      required this.onChanged,
      required this.tabs,
      required this.child});
  static double bottomInset(BuildContext context) =>
      MinimizingGlassNavBar.reservedHeight(context) + 16;

  /// Forces the native iOS 26 bar on or off, so a test can walk the path a
  /// phone on iOS 26 takes. Null asks the phone.
  @visibleForTesting
  static bool? debugNativeBar;

  static bool get _nativeBar =>
      debugNativeBar ?? (!kIsWeb && PlatformInfo.isIOS26OrHigher());

  /// What the native scaffold paints with: a clear sheet, so the field
  /// behind every tab shows through, and the HolyHim theme's light or dark,
  /// not the phone's, so the bar and the page agree.
  static Widget nativeFrame(BuildContext context, {required Widget child}) {
    final theme = HolyThemeScope.of(context);
    final brightness = theme.isDark ? Brightness.dark : Brightness.light;
    return MediaQuery(
        data: MediaQuery.of(context).copyWith(platformBrightness: brightness),
        child: CupertinoTheme(
            data: CupertinoTheme.of(context).copyWith(
                brightness: brightness,
                primaryColor: theme.accent,
                scaffoldBackgroundColor: const Color(0x00000000)),
            child: child));
  }

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

  @override
  Widget build(BuildContext context) {
    if (HolyTabShell._nativeBar) {
      // The native scaffold is a CupertinoPageScaffold, which paints a flat
      // sheet in the theme's background colour over the mesh.
      return HolyTabShell.nativeFrame(context,
          child: AdaptiveScaffold(
              body: widget.child,
              enableBlur: false,
              minimizeBehavior: TabBarMinimizeBehavior.automatic,
              bottomNavigationBar: AdaptiveBottomNavigationBar(
                  selectedIndex: widget.index,
                  useNativeBottomBar: true,
                  onTap: widget.onChanged,
                  items: [
                    for (final tab in widget.tabs)
                      AdaptiveNavigationDestination(
                          icon: tab.symbol,
                          selectedIcon: tab.selectedSymbol,
                          label: tab.label)
                  ])));
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
              items: [
                for (final tab in widget.tabs)
                  MinimizingNavItem(icon: tab.icon, label: tab.label)
              ],
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
