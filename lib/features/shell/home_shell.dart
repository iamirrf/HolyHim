import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../design/design.dart';
import '../walk/walk_screen.dart';
import '../saved/saved_screen.dart';
import '../growth/growth_screen.dart';
import '../profile/profile_screen.dart';

class HomeShell extends StatefulWidget {
  final int initialTab;
  final ValueChanged<double>? onMood;
  const HomeShell({super.key, this.initialTab = 0, this.onMood});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final PageController pages;
  late int index;
  static const paths = ['/', '/saved', '/growth', '/profile'];
  @override
  void initState() {
    super.initState();
    index = widget.initialTab;
    pages = PageController(initialPage: index);
    pages.addListener(() {
      widget.onMood?.call(pages.page ?? index.toDouble());
    });
  }

  @override
  void didUpdateWidget(HomeShell old) {
    super.didUpdateWidget(old);
    if (old.initialTab != widget.initialTab && index != widget.initialTab) {
      index = widget.initialTab;
      final destination = index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && pages.hasClients && widget.initialTab == destination) {
          pages.jumpToPage(destination);
        }
      });
    }
  }

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  void choose(int i) {
    pages.animateToPage(i,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) => HolyTabShell(
      index: index,
      onChanged: choose,
      child: NotificationListener<ScrollEndNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis == Axis.horizontal &&
                GoRouterState.of(context).uri.path != paths[index]) {
              context.go(paths[index]);
            }
            return false;
          },
          child: PageView(
              controller: pages,
              onPageChanged: (i) {
                setState(() => index = i);
              },
              children: const [
                _KeptTab(child: WalkScreen()),
                _KeptTab(child: SavedScreen()),
                _KeptTab(child: GrowthScreen()),
                _KeptTab(child: ProfileScreen())
              ])));
}

class _KeptTab extends StatefulWidget {
  final Widget child;
  const _KeptTab({required this.child});
  @override
  State<_KeptTab> createState() => _KeptTabState();
}

class _KeptTabState extends State<_KeptTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
