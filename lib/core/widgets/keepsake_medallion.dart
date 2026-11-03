import 'package:flutter/material.dart';
import 'package:holyher/core/theme/app_theme.dart';

/// A permanent milestone: dimensional light, a quiet reveal, no streak penalty.
class KeepsakeMedallion extends StatelessWidget {
  final int milestone;
  final bool earned, reveal;
  final double size;
  const KeepsakeMedallion(
      {super.key,
      required this.milestone,
      this.earned = true,
      this.reveal = false,
      this.size = 88});
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final icon = switch (milestone) {
      1 => Icons.spa_outlined,
      7 => Icons.eco_outlined,
      30 => Icons.local_florist_outlined,
      90 => Icons.auto_awesome_outlined,
      180 => Icons.wb_sunny_outlined,
      _ => Icons.workspace_premium_outlined
    };
    return Semantics(
        image: true,
        label:
            '$milestone distinct readings, ${earned ? 'earned' : 'not yet earned'}',
        child: TweenAnimationBuilder<double>(
            tween: Tween(begin: reveal ? -.18 : 0, end: 0),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 1300),
            curve: Curves.easeOutCubic,
            builder: (context, angle, child) => Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .0015)
                  ..rotateY(angle),
                alignment: Alignment.center,
                child: child),
            child: Container(
                width: size,
                height: size,
                padding: EdgeInsets.all(size * .09),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: earned
                            ? [
                                AppColors.pearl,
                                AppColors.palette.champagne,
                                AppColors.surfaceLight
                              ]
                            : [AppColors.surface, AppColors.background]),
                    border: Border.all(color: AppColors.pearl, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.accentDark
                              .withValues(alpha: earned ? .18 : .06),
                          blurRadius: size * .18,
                          offset: Offset(0, size * .08))
                    ]),
                child: Container(
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.accent
                                .withValues(alpha: earned ? .30 : .1)),
                        gradient: RadialGradient(
                            center: const Alignment(-.4, -.5),
                            colors: [
                              AppColors.pearl.withValues(alpha: .72),
                              AppColors.surface.withValues(alpha: .30)
                            ])),
                    child: Icon(earned ? icon : Icons.lock_outline,
                        size: size * .40,
                        color: earned
                            ? AppColors.accentDark
                            : AppColors.textSecondary
                                .withValues(alpha: .45))))));
  }
}
