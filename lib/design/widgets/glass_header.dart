import 'package:flutter/material.dart';
import '../themes.dart';
import '../typography.dart';
import 'top_bar.dart';

/// Cognein's top bar for a scrolling tab: clear at rest, it gathers into
/// progressive glass as he scrolls, and the screen's title settles into it
/// once the large title has scrolled away.
class GlassHeaderScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final Color? background;
  const GlassHeaderScaffold(
      {super.key, required this.title, required this.body, this.background});
  @override
  State<GlassHeaderScaffold> createState() => _GlassHeaderScaffoldState();
}

class _GlassHeaderScaffoldState extends State<GlassHeaderScaffold> {
  double offset = 0;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final next = n.metrics.pixels.clamp(0.0, 160.0);
    if ((next - offset).abs() > .5) setState(() => offset = next);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final shown = ((offset - 56) / 40).clamp(0.0, 1.0);
    return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: widget.background ?? Colors.transparent,
        appBar: GlassTopBar(
            automaticallyImplyLeading: false,
            centerTitle: true,
            scrollOffset: offset,
            maxOpacity: .92,
            maxBlurSigma: 18,
            title: Opacity(
                opacity: shown,
                child: Text(widget.title,
                    style: HolyTypography.headline
                        .copyWith(color: t.ink, fontSize: 21)))),
        body: NotificationListener<ScrollNotification>(
            onNotification: _onScroll, child: widget.body));
  }
}
