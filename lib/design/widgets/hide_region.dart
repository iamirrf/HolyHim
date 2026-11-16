import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// For store screenshots only: one card, by its exact on-screen rectangle,
/// is left unpainted so it can be shown lifted out of the screen elsewhere.
/// The app never provides a region, so nothing is ever hidden there.
class HideRegion extends InheritedWidget {
  final Rect rect;
  const HideRegion({super.key, required this.rect, required super.child});
  static Rect? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HideRegion>()?.rect;
  @override
  bool updateShouldNotify(HideRegion old) => old.rect != rect;
}

/// Wraps a card that a [HideRegion] may leave unpainted.
class Hideable extends SingleChildRenderObjectWidget {
  const Hideable({super.key, super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderHideable(HideRegion.of(context));
  @override
  void updateRenderObject(BuildContext context, RenderHideable renderObject) =>
      renderObject.region = HideRegion.of(context);
}

class RenderHideable extends RenderProxyBox {
  RenderHideable(this._region);
  Rect? _region;
  set region(Rect? value) {
    if (value == _region) return;
    _region = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final region = _region;
    if (region != null && hasSize) {
      final here = localToGlobal(Offset.zero) & size;
      if ((here.topLeft - region.topLeft).distance < 1.5 &&
          (here.width - region.width).abs() < 1.5 &&
          (here.height - region.height).abs() < 1.5) {
        return;
      }
    }
    super.paint(context, offset);
  }
}
