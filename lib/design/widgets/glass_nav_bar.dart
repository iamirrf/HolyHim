// Ported from Cognein; see store/v2-design-ports.json.
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'package:holyhim/design/haptics.dart';
import 'package:holyhim/design/widgets/pressable.dart';
import '../themes.dart';

/// One destination in a [MinimizingGlassNavBar].
@immutable
class MinimizingNavItem {
  const MinimizingNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// A floating liquid-glass tab bar that shrinks to a small capsule while the
/// content scrolls and springs back open on the way up, the way the iOS 26
/// tab bar does.
///
/// The bar is one refracting [LiquidGlassLens] whose width and height are
/// driven by a spring, so the glass itself changes size rather than being
/// scaled or cross-faded. Expanded, a second lens (the selection pill) rides
/// over the selected tab, stretching with its own velocity and following a
/// finger dragged across the bar. Minimized, only the selected tab's icon is
/// left, in a capsule at the leading edge; tapping it opens the bar again.
///
/// The widget fills the space it is given and paints the bar at the bottom
/// left of it (or wherever [alignment] puts it), so place it over the page in a
/// [Stack]. Empty parts of that space do not take touches. Reserve the room the
/// bar covers with [reservedHeight] (the bar is always laid out at its expanded
/// height so the page underneath does not jump as it shrinks).
///
/// [minimized] is a listenable instead of a bool because the scroll that
/// drives it fires every frame: the parent flips the notifier and only this
/// widget rebuilds.
class MinimizingGlassNavBar extends StatefulWidget {
  const MinimizingGlassNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.minimized,
    required this.onExpand,
    required this.activeColor,
    required this.inactiveColor,
    this.visible = true,
    this.onSettled,
    this.alignment = Alignment.bottomLeft,
    this.maxWidth = double.infinity,
  }) : assert(items.length > 0);

  final List<MinimizingNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Whether the bar is collapsed to its compact capsule.
  final ValueListenable<bool> minimized;

  /// The compact capsule was tapped: the parent should set [minimized] false.
  final VoidCallback onExpand;

  final Color activeColor;
  final Color inactiveColor;

  /// Whether the bar is drawn. Hidden, it paints nothing and takes no touches
  /// but keeps its state, so a host that shows something else at rest (the
  /// native iOS bar) can bring this in only for the fold.
  final bool visible;

  /// Called when a fold or unfold has finished, with whether the bar ended up
  /// minimized. The host uses it to hand back to whatever it shows at rest.
  final ValueChanged<bool>? onSettled;

  /// Where the bar sits in the space it is given. A phone keeps it at the
  /// bottom left so it can fold into a capsule there; a desktop window centres
  /// it under the content.
  final Alignment alignment;

  /// The widest the expanded bar grows. Beyond it the bar stays this wide, so a
  /// window wider than a phone does not stretch five tabs across the screen.
  final double maxWidth;

  static const double barHeight = 68;
  static const double compactHeight = 52;
  static const double compactWidth = 68;
  static const double sideMargin = 16;
  static const double bottomMargin = 12;

  /// On iOS the bar floats over the home indicator, this far from the screen's
  /// edge, as the system's own tab bar does.
  static const double iosBottomGap = 14;

  /// The space between the bar and the bottom edge of the screen. Elsewhere the
  /// bar rides above the system gesture area instead.
  static double bottomGap(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.iOS
          ? iosBottomGap
          : bottomMargin + MediaQuery.viewPaddingOf(context).bottom;

  /// How much of the screen's bottom the expanded bar covers, safe area
  /// included: give the page this much bottom room so its last row can be
  /// scrolled clear of the bar.
  static double reservedHeight(BuildContext context) =>
      barHeight + bottomGap(context) + 6;

  @override
  State<MinimizingGlassNavBar> createState() => _MinimizingGlassNavBarState();
}

class _MinimizingGlassNavBarState extends State<MinimizingGlassNavBar>
    with TickerProviderStateMixin {
  /// Inner padding between the capsule rim and the first/last tab.
  static const double _pad = 6;

  static const double _iconSize = 28;
  static const double _labelSize = 11;

  // The shrink dips a little past its ends on purpose: the bar overshoots
  // when it reopens and settles, which is most of what makes it feel liquid.
  static final SpringDescription _shrinkSpring =
      SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 260,
    ratio: 0.8,
  );
  static final SpringDescription _selectSpring =
      SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 340,
    ratio: 0.72,
  );
  // The lifted pill is a raised bubble of glass: quick to rise, and under
  // damped on the way down so it squashes a touch below its resting size as it
  // lands before settling.
  static final SpringDescription _liftSpring =
      SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: 0.62,
  );
  static const Tolerance _tolerance =
      Tolerance(distance: 0.001, velocity: 0.02);

  /// How much taller than the bar the pill grows when lifted, in total. Half
  /// of it shows above the bar's top edge and half below its bottom edge.
  static const double _liftExtraHeight = 16;

  /// The lifted pill's width, as a multiple of a tab's width.
  static const double _liftWidthFactor = 1.32;

  /// 0 = expanded, 1 = minimized. Unbounded so the spring can overshoot.
  late final AnimationController _shrink;

  /// The selection pill's position in tab units (2.0 = centred on the third
  /// tab). Fractional while it travels or is dragged.
  late final AnimationController _select;

  /// How far the pill is raised: 0 at rest, 1 when it has grown past the bar.
  /// It rises while a finger holds or drags the pill and while it travels
  /// between tabs, and settles back once it lands. Unbounded so the landing
  /// can squash slightly below rest.
  late final AnimationController _lift;

  bool _dragging = false;

  /// A finger is down on the selected tab, so the pill it sits under is held.
  bool _pressedSelected = false;

  /// The pill is springing toward a tab.
  bool _traveling = false;

  double _liftTarget = 0;
  int _lastHapticTab = 0;

  @override
  void initState() {
    super.initState();
    _shrink = AnimationController.unbounded(
      vsync: this,
      value: widget.minimized.value ? 1 : 0,
    );
    _select = AnimationController.unbounded(
      vsync: this,
      value: widget.selectedIndex.toDouble(),
    );
    _lift = AnimationController.unbounded(vsync: this, value: 0);
    _lastHapticTab = widget.selectedIndex;
    widget.minimized.addListener(_onMinimizedChanged);
    _select.addListener(_onSelectTick);
    _select.addStatusListener(_onSelectStatus);
    _shrink.addStatusListener(_onShrinkStatus);
  }

  @override
  void didUpdateWidget(MinimizingGlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minimized != widget.minimized) {
      oldWidget.minimized.removeListener(_onMinimizedChanged);
      widget.minimized.addListener(_onMinimizedChanged);
      _onMinimizedChanged();
    }
    if (oldWidget.selectedIndex != widget.selectedIndex && !_dragging) {
      _lastHapticTab = widget.selectedIndex;
      _travelTo(widget.selectedIndex.toDouble());
    }
  }

  @override
  void dispose() {
    widget.minimized.removeListener(_onMinimizedChanged);
    _select.removeListener(_onSelectTick);
    _select.removeStatusListener(_onSelectStatus);
    _shrink.removeStatusListener(_onShrinkStatus);
    _shrink.dispose();
    _select.dispose();
    _lift.dispose();
    super.dispose();
  }

  void _onMinimizedChanged() {
    if (!mounted) return;
    _springTo(_shrink, widget.minimized.value ? 1 : 0, _shrinkSpring);
    // Reduced motion snaps instead of springing, so nothing will report the
    // end of it.
    if (!_shrink.isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_shrink.isAnimating) {
          widget.onSettled?.call(widget.minimized.value);
        }
      });
    }
  }

  void _onShrinkStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onSettled?.call(widget.minimized.value);
    }
  }

  void _springTo(
    AnimationController controller,
    double target,
    SpringDescription spring, {
    double? velocity,
  }) {
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.value = target;
      return;
    }
    controller.animateWith(SpringSimulation(
      spring,
      controller.value,
      target,
      velocity ?? controller.velocity,
      tolerance: _tolerance,
    ));
  }

  /// Tab units at horizontal position [dx] inside the capsule.
  double _tabAt(double dx, double cellWidth) =>
      ((dx - _pad) / cellWidth - 0.5).clamp(0.0, widget.items.length - 1.0);

  /// Springs the pill to [target] and raises it for the journey.
  void _travelTo(double target, {double? velocity}) {
    _traveling = true;
    _springTo(_select, target, _selectSpring, velocity: velocity);
    _syncLift();
  }

  void _onSelectStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      _traveling = false;
      _syncLift();
    }
  }

  /// Sets the pill back down as soon as it has reached its tab and slowed,
  /// rather than after the spring's last invisible wobble, so the landing is
  /// felt when the pill arrives.
  void _onSelectTick() {
    if (!_traveling || _dragging) return;
    final arrived = (_select.value - widget.selectedIndex).abs() < 0.06 &&
        _select.velocity.abs() < 2.5;
    if (arrived) {
      _traveling = false;
      _syncLift();
    }
  }

  /// Raises the pill while it is held, dragged or travelling; lowers it
  /// otherwise. Reduced motion never grows it: that is a transformation, not
  /// a state change.
  void _syncLift() {
    if (!mounted) return;
    final raised = _dragging || _pressedSelected || _traveling;
    final want = raised && !MediaQuery.disableAnimationsOf(context) ? 1.0 : 0.0;
    if (want == _liftTarget) return;
    _liftTarget = want;
    _springTo(_lift, want, _liftSpring);
  }

  void _pointerDown(PointerDownEvent event, double cellWidth) {
    final tab = _tabAt(event.localPosition.dx, cellWidth);
    if ((tab - widget.selectedIndex).abs() >= 0.5) return;
    _pressedSelected = true;
    _syncLift();
  }

  void _pointerUp() {
    if (!_pressedSelected) return;
    _pressedSelected = false;
    _syncLift();
  }

  void _dragStart(DragStartDetails details) {
    _dragging = true;
    _traveling = false;
    _select.stop();
    _syncLift();
    // The pill was already held down under the finger if it started on the
    // selected tab, and that press has ticked; only a new grab gets its own.
    if (!_pressedSelected) HolyHaptics.tap();
  }

  void _dragUpdate(DragUpdateDetails details, double cellWidth) {
    final tab = _tabAt(details.localPosition.dx, cellWidth);
    _select.value = tab;
    final nearest = tab.round();
    if (nearest != _lastHapticTab) {
      _lastHapticTab = nearest;
      HolyHaptics.detent();
    }
  }

  void _dragEnd(DragEndDetails details, double cellWidth) {
    _dragging = false;
    final flick = details.velocity.pixelsPerSecond.dx / cellWidth;
    final target = (_select.value + flick * 0.12)
        .round()
        .clamp(0, widget.items.length - 1);
    _travelTo(target.toDouble(), velocity: flick);
    // Set down on a tab.
    HolyHaptics.tap();
    if (target != widget.selectedIndex) widget.onSelected(target);
  }

  void _dragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _travelTo(widget.selectedIndex.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final bottomGap = MinimizingGlassNavBar.bottomGap(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = math.min(
          widget.maxWidth,
          math.max(
            0.0,
            constraints.maxWidth - 2 * MinimizingGlassNavBar.sideMargin,
          ),
        );
        return Align(
          alignment: widget.alignment,
          child: Padding(
            // Both sides, so a centred bar is centred and not nudged by the
            // margin; the bar's own width is set explicitly either way.
            padding: EdgeInsets.only(
              left: MinimizingGlassNavBar.sideMargin,
              right: MinimizingGlassNavBar.sideMargin,
              bottom: bottomGap,
            ),
            child: AnimatedBuilder(
              animation: Listenable.merge([_shrink, _select, _lift]),
              builder: (context, _) => _buildBar(fullWidth, isDark),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBar(double fullWidth, bool isDark) {
    final items = widget.items;
    final t = _shrink.value.clamp(-0.06, 1.06);
    final p = t.clamp(0.0, 1.0);
    final width = math.max(
      MinimizingGlassNavBar.compactWidth * 0.8,
      lerpDouble(fullWidth, MinimizingGlassNavBar.compactWidth, t)!,
    );
    final height = lerpDouble(
      MinimizingGlassNavBar.barHeight,
      MinimizingGlassNavBar.compactHeight,
      t,
    )!;
    // Tabs keep their expanded width the whole way, so shrinking translates
    // them instead of squeezing five icons into a narrowing capsule.
    final cellWidth = (fullWidth - 2 * _pad) / items.length;
    final interactive = p < 0.5;
    final select = _select.value;

    // The pill melts away over the first third of the shrink; after that the
    // capsule itself is the selection.
    final pillPresence = 1 - math.pow((p / 0.35).clamp(0.0, 1.0), 2).toDouble();
    final speed = _dragging ? 0.0 : _select.velocity.abs();
    final stretch = (speed * 0.03).clamp(0.0, 0.36);
    // A touch past 0..1 on purpose: the landing spring dips below rest.
    final lift = _lift.value.clamp(-0.25, 1.25) * (1 - p);
    final pillBaseHeight =
        lerpDouble(height - 10, height + _liftExtraHeight, lift)!;
    final pillBaseWidth =
        lerpDouble(cellWidth - 4, cellWidth * _liftWidthFactor, lift)!;
    final pillHeight = pillBaseHeight * (1 - stretch * 0.3) * pillPresence;
    final pillWidth = pillBaseWidth * (1 + stretch) * pillPresence;
    final pillCenter = lerpDouble(
      _pad + (select + 0.5) * cellWidth,
      MinimizingGlassNavBar.compactWidth / 2,
      p,
    )!;

    // A raw listener beside the gesture detector: it must see the finger land
    // (to raise the pill under it) without taking part in the tap/drag arena.
    return Listener(
      onPointerDown: interactive ? (e) => _pointerDown(e, cellWidth) : null,
      onPointerUp: (_) => _pointerUp(),
      onPointerCancel: (_) => _pointerUp(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: interactive ? _dragStart : null,
        onHorizontalDragUpdate:
            interactive ? (d) => _dragUpdate(d, cellWidth) : null,
        onHorizontalDragEnd: interactive ? (d) => _dragEnd(d, cellWidth) : null,
        onHorizontalDragCancel: interactive ? _dragCancel : null,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: HolyThemeScope.opaqueOf(context)
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                            color: HolyThemeScope.of(context).colors.first,
                            borderRadius: BorderRadius.circular(height / 2),
                            border: Border.all(
                                color:
                                    widget.activeColor.withValues(alpha: .18))))
                    : LiquidGlassLens(style: _barStyle(height, isDark)),
              ),
              // Under the icons, not over them: glass over a glyph refracts it,
              // and the rim of a pill bends the icon's top and the label's
              // bottom into stray fragments. Underneath, the pill only bends
              // the bar and page behind it and the tab stays crisp on top.
              if (pillPresence > 0.04 && pillWidth > 2 && pillHeight > 2)
                Positioned(
                  left: pillCenter - pillWidth / 2,
                  top: (height - pillHeight) / 2,
                  width: pillWidth,
                  height: pillHeight,
                  child: IgnorePointer(
                    child: HolyThemeScope.opaqueOf(context)
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                                color:
                                    widget.activeColor.withValues(alpha: .16),
                                borderRadius:
                                    BorderRadius.circular(pillHeight / 2)))
                        : LiquidGlassLens(
                            style: _pillStyle(pillHeight, isDark, lift),
                          ),
                  ),
                ),
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(height / 2),
                  child: Stack(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        _buildTab(i, cellWidth, p, select, lift, interactive),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(
    int index,
    double cellWidth,
    double p,
    double select,
    double lift,
    bool interactive,
  ) {
    final item = widget.items[index];
    final isSelected = index == widget.selectedIndex;
    // Colour follows the pill as it slides, so a tab lights up as the glass
    // reaches it rather than when the tap lands.
    final glow = (1 - (select - index).abs()).clamp(0.0, 1.0);
    final color = Color.lerp(widget.inactiveColor, widget.activeColor, glow)!;
    final presence = isSelected ? 1.0 : (1 - p * 2.2).clamp(0.0, 1.0);
    final labelOpen = (1 - p * 2.5).clamp(0.0, 1.0);
    final centre = lerpDouble(
      _pad + (index + 0.5) * cellWidth,
      MinimizingGlassNavBar.compactWidth / 2,
      p,
    )!;

    // Minimized, every tab is stacked on the same spot. The hidden ones must
    // not take the tap (the topmost would swallow it before it reached the
    // selected tab) or be read out by a screen reader.
    final hidden = !interactive && !isSelected;

    return Positioned(
      left: centre - cellWidth / 2,
      width: cellWidth,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: hidden,
        child: ExcludeSemantics(
          excluding: hidden,
          child: Pressable(
            semanticLabel: item.label,
            selected: isSelected,
            borderRadius: BorderRadius.circular(30),
            onPressed:
                interactive ? () => widget.onSelected(index) : widget.onExpand,
            child: _buildTabContent(
              item,
              color,
              presence,
              labelOpen,
              glow,
              // The raised pill magnifies what it is over, so the icon and
              // label swell as it passes and ease back down behind it.
              underGlass: lift * glow,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(
    MinimizingNavItem item,
    Color color,
    double presence,
    double labelOpen,
    double glow, {
    required double underGlass,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: Offset(0, -2 * underGlass),
            child: Transform.scale(
              scale: 1 + 0.16 * underGlass,
              child: Icon(
                item.icon,
                size: _iconSize,
                color: color.withValues(alpha: color.a * presence),
              ),
            ),
          ),
          // Scaled outside the clip: the clip only folds the label away, and
          // must not shave the enlarged glyphs.
          Transform.scale(
            scale: 1 + 0.09 * underGlass,
            child: ClipRect(
              child: Align(
                heightFactor: labelOpen,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    softWrap: false,
                    // Capped so a large system font cannot outgrow the bar.
                    textScaler: MediaQuery.textScalerOf(context)
                        .clamp(maxScaleFactor: 1.2),
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: _labelSize,
                      height: 1.2,
                      fontWeight:
                          glow > 0.5 ? FontWeight.w700 : FontWeight.w500,
                      color: color.withValues(
                        alpha: color.a * presence * labelOpen,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  LiquidGlassStyle _barStyle(double height, bool isDark) {
    return LiquidGlassStyle(
      shape: LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: height / 2,
        // Light glass over a light page has nothing to refract that shows,
        // so it needs an edge of its own to read as a surface.
        borderColor: isDark ? null : const Color(0x33C9A227),
      ),
      appearance: LiquidGlassAppearance(
        color: isDark ? const Color(0x1AFFFFFF) : const Color(0x30C9A227),
        blur: const LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
        shadow: LiquidGlassShadow(blur: 3.5, opacity: isDark ? 0.2 : 0.3),
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.1,
        distortionWidth: 26,
        chromaticAberration: 0.002,
      ),
    );
  }

  LiquidGlassStyle _pillStyle(double height, bool isDark, double lift) {
    final raised = lift.clamp(0.0, 1.0);
    final tint = isDark ? const Color(0x24FFFFFF) : const Color(0x33C9A227);
    return LiquidGlassStyle(
      shape: LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: height / 2,
      ),
      appearance: LiquidGlassAppearance(
        // Clearer as it rises: a raised pill is a lens over the page, not a
        // tinted button.
        color: tint.withValues(alpha: tint.a * (1 - 0.45 * raised)),
        blur: const LiquidGlassBlur(sigmaX: 1, sigmaY: 1),
        shadow: raised > 0.04
            ? LiquidGlassShadow(blur: 6, opacity: 0.3 * raised)
            : null,
      ),
      // Gentle at rest, where the pill sits over its own tab; it bends the
      // page more once raised past the bar's edge. The icon and label are
      // drawn above the glass, so neither is ever refracted.
      refraction: LiquidGlassRefraction(
        distortion: 0.03 + 0.07 * raised,
        distortionWidth: 6 + 8 * raised,
        chromaticAberration: 0.001 + 0.002 * raised,
      ),
    );
  }
}
