import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../themes.dart';
import '../tokens.dart';
import 'backdrop.dart';

/// A fixed composition: children are laid out to fill exactly one viewport,
/// with [Spacer]s and [Expanded] distributing the space. When the content
/// cannot fit (very large accessibility text) the column grows to the size it
/// needs and scrolls, instead of overflowing. Wrap a flexible child in
/// [FitFlex] to give it a minimum height for that fallback; plain spacers
/// shrink to nothing. At normal sizes there is no scroll extent.
///
/// This never asks children for intrinsic sizes, so images, pickers and
/// layout builders are all safe inside it.
class FitColumn extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final double maxWidth;
  const FitColumn(
      {super.key,
      required this.children,
      this.padding = const EdgeInsets.symmetric(horizontal: HolySpace.gutter),
      this.crossAxisAlignment = CrossAxisAlignment.stretch,
      this.mainAxisAlignment = MainAxisAlignment.start,
      this.maxWidth = 560});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Center(
              child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                      padding: padding,
                      child: _FitHeight(
                          viewport: (box.maxHeight - padding.vertical)
                              .clamp(0.0, double.infinity),
                          child: _MeasuredColumn(
                              crossAxisAlignment: crossAxisAlignment,
                              mainAxisAlignment: mainAxisAlignment,
                              children: children)))))));
}

/// A column that records how much height its fixed children need plus the
/// minimum its [FitFlex] children declare.
class _MeasuredColumn extends Column {
  const _MeasuredColumn(
      {super.crossAxisAlignment, super.mainAxisAlignment, super.children});
  @override
  RenderFlex createRenderObject(BuildContext context) => _RenderMeasuredFlex(
      direction: direction,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: getEffectiveTextDirection(context),
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      clipBehavior: clipBehavior,
      spacing: spacing);
}

class _RenderMeasuredFlex extends RenderFlex {
  _RenderMeasuredFlex(
      {super.direction,
      super.mainAxisAlignment,
      super.mainAxisSize,
      super.crossAxisAlignment,
      super.textDirection,
      super.verticalDirection,
      super.textBaseline,
      super.clipBehavior,
      super.spacing});
  double needed = 0;
  @override
  void performLayout() {
    super.performLayout();
    var total = 0.0;
    var node = firstChild;
    while (node != null) {
      final data = node.parentData! as FlexParentData;
      if ((data.flex ?? 0) > 0) {
        total += node is _RenderFlexMin ? node.min : 0;
      } else {
        total += node.size.height;
      }
      node = data.nextSibling;
    }
    needed = total;
  }
}

/// An [Expanded] that keeps at least [min] of height when a [FitColumn]
/// has to fall back to scrolling.
class FitFlex extends StatelessWidget {
  final double min;
  final int flex;
  final Widget child;
  const FitFlex(
      {super.key, required this.min, this.flex = 1, required this.child});
  @override
  Widget build(BuildContext context) =>
      Expanded(flex: flex, child: _FlexMin(min: min, child: child));
}

class _FlexMin extends SingleChildRenderObjectWidget {
  final double min;
  const _FlexMin({required this.min, super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFlexMin(min);
  @override
  void updateRenderObject(BuildContext context, _RenderFlexMin r) =>
      r.min = min;
}

class _RenderFlexMin extends RenderProxyBox {
  double min;
  _RenderFlexMin(this.min);
}

class _FitHeight extends SingleChildRenderObjectWidget {
  final double viewport;
  const _FitHeight({required this.viewport, super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFitHeight(viewport);
  @override
  void updateRenderObject(BuildContext context, _RenderFitHeight r) =>
      r.viewport = viewport;
}

class _RenderFitHeight extends RenderProxyBox {
  _RenderFitHeight(this._viewport);
  double _viewport;
  set viewport(double v) {
    if (v == _viewport) return;
    _viewport = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final c = child;
    final width = constraints.maxWidth;
    if (c == null) {
      size = constraints.constrain(Size(width, _viewport));
      return;
    }
    c.layout(BoxConstraints.tightFor(width: width, height: _viewport),
        parentUsesSize: true);
    var height = _viewport;
    if (c is _RenderMeasuredFlex && c.needed > _viewport + .5) {
      height = c.needed;
      c.layout(BoxConstraints.tightFor(width: width, height: height),
          parentUsesSize: true);
    }
    size = constraints.constrain(Size(width, height));
  }
}

/// A screen that keeps its primary action above the keyboard.
///
/// It reads [MediaQuery.viewInsetsOf] directly, which iOS updates on every
/// frame of the keyboard animation, so the footer rides up with the keys
/// rather than jumping after them. [builder] learns whether the keyboard is
/// up so art can collapse and titles can compact.
class KeyboardLift extends StatelessWidget {
  final Widget Function(BuildContext context, bool keyboardOpen) builder;
  final Widget? footer;
  final Widget? background;
  final Color? color;
  final bool safeTop;
  const KeyboardLift(
      {super.key,
      required this.builder,
      this.footer,
      this.background,
      this.color,
      this.safeTop = true});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final inset = media.viewInsets.bottom;
    final open = inset > 60;
    final bottom =
        math.max(inset + HolySpace.s, media.padding.bottom + HolySpace.m);
    return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: color ?? HolyThemeScope.of(context).paper,
        body: _field(Stack(children: [
          if (background != null) Positioned.fill(child: background!),
          Padding(
              padding: EdgeInsets.only(
                  top: safeTop ? media.padding.top : 0, bottom: bottom),
              child: MediaQuery.removePadding(
                  context: context,
                  removeTop: safeTop,
                  removeBottom: true,
                  child: Column(children: [
                    Expanded(child: builder(context, open)),
                    if (footer != null)
                      Padding(
                          padding: const EdgeInsets.fromLTRB(HolySpace.gutter,
                              HolySpace.s, HolySpace.gutter, 0),
                          child: Center(
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 560),
                                  child: footer))),
                  ]))),
        ])));
  }

  /// The moving field, unless the caller asked for a colour of its own.
  Widget _field(Widget child) =>
      color == null ? HolyBackdrop(calm: true, child: child) : child;
}

/// A standard sub-screen frame: back control, a display title and a fitted
/// body on the calm field.
class ScreenFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? trailing;
  final bool scroll;
  final VoidCallback? onBack;
  const ScreenFrame(
      {super.key,
      required this.title,
      required this.children,
      this.subtitle,
      this.trailing,
      this.scroll = false,
      this.onBack});

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final header = Padding(
        padding: const EdgeInsets.fromLTRB(
            HolySpace.gutter - 4, HolySpace.xs, HolySpace.gutter, 0),
        child: Row(children: [
          _Back(onBack: onBack),
          const Spacer(),
          if (trailing != null) trailing!,
        ]));
    final titleBlock = Padding(
        padding: const EdgeInsets.only(top: HolySpace.l, bottom: HolySpace.l),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
              header: true,
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium!
                      .copyWith(color: t.ink))),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(color: t.muted)),
          ]
        ]));
    final bottom = MediaQuery.paddingOf(context).bottom + HolySpace.m;
    return Scaffold(
        backgroundColor: t.paper,
        body: HolyBackdrop(
            calm: true,
            child: SafeArea(
                bottom: false,
                child: Column(children: [
                  header,
                  Expanded(
                      child: scroll
                          ? ListView(
                              padding: EdgeInsets.fromLTRB(HolySpace.gutter, 0,
                                  HolySpace.gutter, bottom + HolySpace.l),
                              children: [titleBlock, ...children])
                          : FitColumn(
                              padding: EdgeInsets.fromLTRB(HolySpace.gutter, 0,
                                  HolySpace.gutter, bottom),
                              children: [titleBlock, ...children])),
                ]))));
  }
}

class _Back extends StatelessWidget {
  final VoidCallback? onBack;
  const _Back({this.onBack});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Semantics(
        button: true,
        label: 'Back',
        excludeSemantics: true,
        child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20, color: t.ink))));
  }
}
