import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/services/accessibility_service.dart';

/// Blur and tint both fall off. Disjoint clipped bands sample the same scene;
/// unlike a color-only fade, the final band has no filter at all.
class HolyFadingMaterial extends ConsumerWidget {
  final Widget child;
  final bool bottom;
  const HolyFadingMaterial(
      {super.key, required this.child, this.bottom = false});
  static const stops = [0.0, .30, .60, .82, 1.0];
  static const alphas = [.70, .58, .38, .16, 0.0];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Theme.of(context);
    final opaque = ref.watch(reduceTransparencyProvider);
    return Stack(children: [
      Positioned.fill(
          child: IgnorePointer(
              child: opaque
                  ? ColoredBox(color: AppColors.pearl)
                  : LayoutBuilder(
                      builder: (context, box) => Stack(children: [
                            for (var i = 0; i < 16; i++)
                              Positioned(
                                  left: 0,
                                  right: 0,
                                  top: box.maxHeight * i / 16,
                                  height: box.maxHeight / 16 + .5,
                                  child: ClipRect(
                                      child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                              sigmaX: 20 *
                                                  (bottom
                                                      ? i / 15
                                                      : 1 - i / 15),
                                              sigmaY: 20 *
                                                  (bottom
                                                      ? i / 15
                                                      : 1 - i / 15)),
                                          child: const SizedBox.expand()))),
                            Positioned.fill(
                                child: DecoratedBox(
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            begin: bottom
                                                ? Alignment.bottomCenter
                                                : Alignment.topCenter,
                                            end: bottom
                                                ? Alignment.topCenter
                                                : Alignment.bottomCenter,
                                            colors: [
                                              for (final a in alphas)
                                                AppColors.background
                                                    .withValues(alpha: a)
                                            ],
                                            stops: stops))))
                          ])))),
      // The material's visual transparency never changes its hit regions.
      child,
    ]);
  }
}
