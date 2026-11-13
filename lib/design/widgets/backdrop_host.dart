// Ported from Cognein; see store/v2-design-ports.json.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Marks a subtree whose background is painted by an ancestor.
///
/// Normally every screen paints its own field: `GradientBackdrop` draws the
/// gradient, the screen draws its content on top, and the top bar tints itself
/// to the gradient's first stop. That works for a pushed route, but it makes a
/// tab swipe a hard cut — five screens, five unrelated backgrounds, sliding
/// past each other.
///
/// So the five main tabs hand their background up. `MainAppScreen` paints one
/// mesh field behind the whole `PageView` and morphs it as the pages scroll;
/// each tab still asks for its own backdrop exactly as before, and this marker
/// is what tells that backdrop to stand down.
///
/// It carries [tint] as well, because the bars have the same problem in
/// reverse: `AppTopBar` and `FadeAppBar` fall back to
/// `scaffoldBackgroundColor` when given no tint, which in light mode is a
/// near-white slab painted over a coloured field. Inside a host they take the
/// host's colour instead.
///
/// [tint] is a [ValueListenable] rather than a plain [Color] on purpose. It
/// changes every frame of a swipe, and an `InheritedWidget` carrying the colour
/// directly would rebuild every dependent — the whole tab subtree, Firestore
/// stream builders included — at 60fps. As a listenable the inherited widget
/// itself stays identical for the life of the host, and only the strip of
/// chrome that actually paints the tint listens.
class BackdropHost extends InheritedWidget {
  /// The colour chrome above this subtree should tint itself with: the field's
  /// own colour at the top edge, tracking the swipe.
  final ValueListenable<Color> tint;

  const BackdropHost({
    super.key,
    required this.tint,
    required super.child,
  });

  /// The host's tint, or null when this subtree paints its own field.
  static ValueListenable<Color>? tintOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<BackdropHost>()?.tint;
  }

  /// True when an ancestor is painting the background for this subtree.
  static bool isHosted(BuildContext context) => tintOf(context) != null;

  @override
  bool updateShouldNotify(BackdropHost oldWidget) => oldWidget.tint != tint;
}
