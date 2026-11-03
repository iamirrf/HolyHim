import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/data/lessons.dart';

/// The same measured geometry drives rendering and current-lesson scrolling.
/// Units can therefore stay lazy even when Dynamic Type changes their height.
class RoadmapUnitLayout {
  final double rowHeight, bannerHeight, numberSize, progressSize;
  final bool stacked;
  const RoadmapUnitLayout(
      {required this.rowHeight,
      required this.bannerHeight,
      required this.numberSize,
      required this.progressSize,
      required this.stacked});
  double get extent => bannerHeight + 5 * rowHeight;
  factory RoadmapUnitLayout.measure(
      {required int index,
      required String title,
      required double width,
      required TextScaler scaler,
      required TextDirection direction}) {
    Size textSize(String text, TextStyle style,
        [double maxWidth = double.infinity]) {
      final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textScaler: scaler,
          textDirection: direction)
        ..layout(maxWidth: math.max(1, maxWidth));
      final size = painter.size;
      painter.dispose();
      return size;
    }

    final number =
        textSize('${index + 1}'.padLeft(2, '0'), HolyTypography.section);
    final numberSize =
        math.max(48.0, math.max(number.width, number.height) + 14);
    final progress = textSize('5/5', HolyTypography.label);
    final progressSize =
        math.max(38.0, math.max(progress.width, progress.height) + 12);
    final stacked = scaler.scale(17) > 24;
    final titleWidth =
        width - 34 - numberSize - 14 - (stacked ? 0 : progressSize + 12);
    final label = textSize('UNIT ${index + 1}',
            HolyTypography.label.copyWith(letterSpacing: 1), titleWidth)
        .height;
    final heading = textSize(title, HolyTypography.action, titleWidth).height;
    var bannerHeight = math.max(numberSize,
            math.max(stacked ? 0.0 : progressSize, label + 4 + heading)) +
        30;
    if (stacked) {
      bannerHeight += 12 +
          textSize('5 of 5 lessons complete', HolyTypography.supporting,
                  width - 34)
              .height +
          8 +
          4;
    }
    final nodeWidth = math.min(230.0, width * .70);
    final titleHeight = lessons
        .sublist(index * 5, index * 5 + 5)
        .map((l) =>
            textSize(l.title, HolyTypography.supporting, nodeWidth).height)
        .reduce(math.max);
    final rowHeight = math.max(
        184.0,
        112 +
            textSize('DAY 01', HolyTypography.label, nodeWidth).height +
            titleHeight +
            textSize('Begin here', HolyTypography.label, nodeWidth).height);
    return RoadmapUnitLayout(
        rowHeight: rowHeight,
        bannerHeight: bannerHeight,
        numberSize: numberSize,
        progressSize: progressSize,
        stacked: stacked);
  }
}
