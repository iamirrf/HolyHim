import 'package:flutter/widgets.dart';

/// The largest type size at which words fill their card.
///
/// A lesson card holds anything from a short line to a long paragraph. A
/// fixed size leaves the short ones half empty and crowds the long ones, so
/// the size is searched for: the largest one, between a floor and a ceiling,
/// at which the words still fit the card. The reader's own size setting
/// multiplies both ends, so a larger setting still reads larger; when even
/// the floor does not fit, the floor is used and the card scrolls.
abstract final class FitText {
  static final _cache = <Object, double>{};

  /// The size to set [text] at in [style] inside [box]. [min] and [max] are
  /// already in the reader's scale.
  static double size(
      {required String text,
      required TextStyle style,
      required Size box,
      required double min,
      required double max,
      TextScaler textScaler = TextScaler.noScaling,
      double step = .25}) {
    if (!box.width.isFinite || box.width <= 0 || box.height <= 0) return min;
    if (!box.height.isFinite) return max;
    final key = (
      text,
      style.fontFamily,
      style.fontStyle,
      style.fontWeight,
      style.height,
      style.letterSpacing,
      box.width.floor(),
      box.height.floor(),
      min,
      max,
      textScaler.scale(100),
    );
    final known = _cache[key];
    if (known != null) return known;
    bool fits(double size) {
      final painter = TextPainter(
          text: TextSpan(text: text, style: style.copyWith(fontSize: size)),
          textDirection: TextDirection.ltr,
          textScaler: textScaler)
        ..layout(maxWidth: box.width);
      final ok = painter.height <= box.height;
      painter.dispose();
      return ok;
    }

    double found;
    if (fits(max)) {
      found = max;
    } else if (!fits(min)) {
      found = min;
    } else {
      var lo = min, hi = max;
      while (hi - lo > step) {
        final mid = (lo + hi) / 2;
        if (fits(mid)) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      found = lo;
    }
    if (_cache.length > 256) _cache.clear();
    return _cache[key] = found;
  }
}
