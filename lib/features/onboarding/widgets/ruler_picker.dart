// Ported from Cognein (which took it from SunRize); see
// store/v2-design-ports.json.
import 'package:flutter/material.dart';
import '../../../design/design.dart';
import 'onboarding_tokens.dart';

/// A horizontal ruler with a centred tick: drag it and the value under the
/// tick is the answer.
///
/// The geometry is what makes it read as a dial and not a list: ticks grow
/// toward the centre, the centre tick glows, the edges fade out, and a
/// release settles on the nearest value. Each value it passes gives one
/// light tick in the hand.
class RulerPicker extends StatefulWidget {
  final List<int> items;
  final int selectedValue;
  final Color accent;

  /// The settled value, once the ruler has come to rest.
  final ValueChanged<int> onChange;

  /// The value under the centre tick while dragging, or null once the ruler
  /// has settled and [onChange] has taken over.
  final ValueChanged<int?> onPreview;

  static const double itemWidth = 20;

  const RulerPicker(
      {super.key,
      required this.items,
      required this.selectedValue,
      required this.accent,
      required this.onChange,
      required this.onPreview});

  @override
  State<RulerPicker> createState() => _RulerPickerState();
}

class _RulerPickerState extends State<RulerPicker> {
  late ScrollController _scroll;
  double _exact = 0;
  late int _committed;
  late int _previewed;

  @override
  void initState() {
    super.initState();
    final index = widget.items.indexOf(widget.selectedValue);
    _exact = (index >= 0 ? index : 0).toDouble();
    _committed = widget.selectedValue;
    _previewed = widget.selectedValue;
    _scroll =
        ScrollController(initialScrollOffset: _exact * RulerPicker.itemWidth);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RulerPicker old) {
    super.didUpdateWidget(old);
    if (old.selectedValue != widget.selectedValue) {
      _committed = widget.selectedValue;
      _previewed = widget.selectedValue;
    }
    // The day ruler shortens when the month changes: move to where the
    // chosen day now sits.
    if (old.items.length != widget.items.length) {
      final index = widget.items.indexOf(widget.selectedValue);
      if (index >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.animateTo(index * RulerPicker.itemWidth,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut);
          }
        });
      }
    }
  }

  void _onScroll() {
    final exact = _scroll.offset / RulerPicker.itemWidth;
    setState(() => _exact = exact);
    if (widget.items.isEmpty) return;
    final value = widget.items[exact.round().clamp(0, widget.items.length - 1)];
    if (value != _previewed) {
      _previewed = value;
      HolyHaptics.detent();
      widget.onPreview(value);
    }
  }

  void _snap() {
    if (!_scroll.hasClients || widget.items.isEmpty) return;
    final exact = _scroll.offset / RulerPicker.itemWidth;
    final nearest = exact.round().clamp(0, widget.items.length - 1);
    final target = nearest * RulerPicker.itemWidth;
    if ((_scroll.offset - target).abs() > 0.5) {
      _scroll.animateTo(target.toDouble(),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic);
      // The settle sends its own end notification; commit from that one, so
      // one gesture gives one answer.
      return;
    }
    final value = widget.items[nearest];
    if (value != _committed) {
      _committed = value;
      widget.onChange(value);
    } else {
      // Back where it started: nothing to save, but the label may still be
      // showing somewhere the drag passed through.
      widget.onPreview(null);
    }
    _previewed = value;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final half = constraints.maxWidth / 2 - RulerPicker.itemWidth / 2;
      return SizedBox(
          height: 52,
          child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                _onScroll();
                if (notification is ScrollEndNotification) {
                  Future.microtask(_snap);
                }
                return false;
              },
              child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(colors: [
                        Colors.transparent,
                        Colors.black,
                        Colors.black,
                        Colors.transparent
                      ], stops: [
                        0.0,
                        0.14,
                        0.86,
                        1.0
                      ]).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: ListView.builder(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      physics: const _CappedFlingPhysics(),
                      itemCount: widget.items.length + 2,
                      itemBuilder: (context, index) {
                        if (index == 0 || index == widget.items.length + 1) {
                          return SizedBox(width: half);
                        }
                        final item = index - 1;
                        final distance = (item - _exact).abs();
                        final centre = distance < 0.5;
                        // The falloff is fitted to the ruler's length, so the
                        // twelve-month ruler tapers like the longer ones.
                        final toEnd = _exact > (widget.items.length - 1) / 2
                            ? _exact
                            : widget.items.length - 1 - _exact;
                        final falloff = toEnd.clamp(1.0, 8.5);
                        final scaled =
                            (36.0 - distance * 32.0 / falloff).clamp(4.0, 36.0);
                        final height = centre ? 44.0 : scaled;
                        final dot = !centre && height <= 6;
                        final width = centre ? 4.0 : (dot ? height : 2.5);
                        final opacity = (1 - distance * 0.08).clamp(0.15, 1.0);
                        return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _scroll.animateTo(
                                item * RulerPicker.itemWidth,
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeOutCubic),
                            child: SizedBox(
                                width: RulerPicker.itemWidth,
                                child: Center(
                                    child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 90),
                                        height: height,
                                        width: width,
                                        decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                                height / 2),
                                            color: centre
                                                ? widget.accent
                                                : OnboardingTokens.plum
                                                    .withValues(
                                                        alpha: .34 * opacity),
                                            boxShadow: centre
                                                ? [
                                                    BoxShadow(
                                                        color: widget.accent
                                                            .withValues(
                                                                alpha: .5),
                                                        blurRadius: 8,
                                                        spreadRadius: 1)
                                                  ]
                                                : null)))));
                      }))));
    });
  }
}

/// Caps how far one flick can carry the ruler.
///
/// A fling's travel grows with its starting speed, so on the year ruler, well
/// over a hundred values wide, one hard flick could move the answer by
/// decades. Capping the speed fed into the simulation holds that to a handful
/// of values, and leaves ordinary drags untouched.
class _CappedFlingPhysics extends ClampingScrollPhysics {
  const _CappedFlingPhysics({super.parent});
  static const double _maxFlingVelocity = 700.0;

  @override
  _CappedFlingPhysics applyTo(ScrollPhysics? ancestor) =>
      _CappedFlingPhysics(parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
          ScrollMetrics position, double velocity) =>
      super.createBallisticSimulation(
          position, velocity.clamp(-_maxFlingVelocity, _maxFlingVelocity));
}
