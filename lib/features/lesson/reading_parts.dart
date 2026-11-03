import 'package:flutter/material.dart';

/// Visual fragments retain their exact source offsets. Semantic progress and
/// quiz identity never depend on how many fragments fit a particular screen.
class ReadingPart {
  final String text;
  final int start, end;
  const ReadingPart(this.text, this.start, this.end);
}

abstract final class ReadingLayout {
  static List<ReadingPart> split(String text,
      {required TextStyle style,
      required double width,
      required double height,
      required TextScaler scaler,
      TextDirection direction = TextDirection.ltr}) {
    if (text.isEmpty) return const [ReadingPart('', 0, 0)];
    final boundaries = <int>{0, text.length};
    for (final m in RegExp(r'[.!?][”’"\x27]?\s+|\n\n').allMatches(text)) {
      boundaries.add(m.end);
    }
    final ends = boundaries.toList()..sort();
    final parts = <ReadingPart>[];
    var start = 0;
    bool fits(int end) {
      final painter = TextPainter(
          text: TextSpan(text: text.substring(start, end), style: style),
          textDirection: direction,
          textScaler: scaler)
        ..layout(maxWidth: width);
      return painter.height <= height;
    }

    while (start < text.length) {
      var end = start;
      for (final boundary in ends.where((e) => e > start)) {
        if (fits(boundary)) {
          end = boundary;
        } else {
          break;
        }
      }
      // A very long sentence stays intact in a scrolling part, rather than
      // deleting words or dividing one answer into separate interactions.
      if (end == start) end = ends.firstWhere((e) => e > start);
      parts.add(ReadingPart(text.substring(start, end), start, end));
      start = end;
    }
    assert(parts.map((p) => p.text).join() == text);
    return parts;
  }

  static int indexAt(List<ReadingPart> parts, int sourceOffset) {
    final index = parts
        .indexWhere((p) => sourceOffset >= p.start && sourceOffset < p.end);
    return index < 0 ? 0 : index;
  }
}
