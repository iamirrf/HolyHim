import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:holyher/core/theme/app_theme.dart';

/// Keep the bottom reservation independent of scroll-driven minimization.
/// Labels reflow at the reader's chosen size instead of shrinking to fit.
double holyNavigationHeight(BuildContext context) {
  final width = math.min(520.0, MediaQuery.sizeOf(context).width - 32);
  final painter = TextPainter(
      text: const TextSpan(text: 'Profile', style: HolyTypography.label),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context))
    ..layout(maxWidth: (width - 3) / 3);
  return math.max(68, 26 + 3 + painter.height + 14);
}

double holyNavigationReservation(BuildContext context) =>
    holyNavigationHeight(context) + 36;
