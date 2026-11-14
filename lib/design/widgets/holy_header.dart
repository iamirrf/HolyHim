import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../haptics.dart';
import '../themes.dart';
import 'glass.dart';
import 'rolling_number.dart';
import 'top_bar.dart';

/// The shared header of the five home tabs, after Cognein's: the HolyHim
/// mark and wordmark on the leading edge, the live streak on the trailing
/// one, over a progressive blur that dissolves into the page. The tab bar
/// already names the tab, so the header carries the brand instead.
///
/// Use it with `Scaffold(extendBodyBehindAppBar: true)` and start content at
/// [HolyHeader.inset].
class HolyHeader extends StatelessWidget implements PreferredSizeWidget {
  final int? streak;
  final List<Widget> actions;
  final VoidCallback? onStreak;
  const HolyHeader(
      {super.key, this.streak, this.actions = const [], this.onStreak});

  static double inset(BuildContext context) =>
      MediaQuery.paddingOf(context).top + kToolbarHeight + 6;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return GlassTopBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        foregroundColor: t.ink,
        title: const BrandMark(),
        actions: [
          for (final a in actions) ...[a, const SizedBox(width: 8)],
          if (streak != null) StreakChip(days: streak!, onPressed: onStreak),
          const SizedBox(width: 16),
        ]);
  }
}

/// The mark on its charcoal tile, then HOLYHIM with HIM struck in brass.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 34});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Semantics(
        label: 'HolyHim',
        header: true,
        excludeSemantics: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          DecoratedBox(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * .27),
                  border: Border.all(
                      color: t.accent.withValues(alpha: .35), width: .8),
                  boxShadow: [
                    BoxShadow(
                        color: t.accent.withValues(alpha: t.isDark ? .28 : .16),
                        blurRadius: 14,
                        spreadRadius: -2),
                  ]),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(size * .27),
                  child: Image.asset('assets/brand/holyhim-mark.png',
                      width: size,
                      height: size,
                      filterQuality: FilterQuality.medium))),
          const SizedBox(width: 10),
          Text.rich(
              TextSpan(children: [
                TextSpan(text: 'HOLY', style: TextStyle(color: t.ink)),
                TextSpan(
                    text: 'HIM',
                    style: TextStyle(
                        foreground: Paint()
                          ..shader = LinearGradient(colors: [
                            Color.lerp(t.accent, Colors.white, .28)!,
                            t.accent,
                            Color.lerp(t.accent, Colors.black, .18)!,
                          ]).createShader(const Rect.fromLTWH(0, 0, 44, 20)))),
              ]),
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.6,
                  height: 1)),
        ]));
  }
}

/// Cognein's streak pill: a flame and the count, lit when the streak is
/// alive and quiet when it is not.
class StreakChip extends StatelessWidget {
  final int days;
  final VoidCallback? onPressed;
  const StreakChip({super.key, required this.days, this.onPressed});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final live = days > 0;
    final emphasis = live ? 1.0 : .45;
    final pill = Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              t.accent.withValues(alpha: .22 * emphasis),
              t.accent.withValues(alpha: .10 * emphasis),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: t.accent.withValues(alpha: .42 * emphasis), width: 1),
            boxShadow: live
                ? [
                    BoxShadow(
                        color: t.accent.withValues(alpha: .30),
                        blurRadius: 12,
                        spreadRadius: -2),
                  ]
                : null),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ShaderMask(
              shaderCallback: (r) => LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: live
                          ? [const Color(0xFFE0782F), t.accent, const Color(0xFFFFE2A0)]
                          : [t.muted, t.muted])
                  .createShader(r),
              child: const Icon(CupertinoIcons.flame_fill,
                  size: 17, color: Colors.white)),
          const SizedBox(width: 4),
          RollingNumber(
              value: days,
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: live ? t.ink : t.muted,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]));
    return Semantics(
        label: live
            ? '$days day streak'
            : 'No streak yet. Read today to start one.',
        button: onPressed != null,
        excludeSemantics: true,
        child: GestureDetector(
            onTap: onPressed == null
                ? null
                : () {
                    HolyHaptics.tap();
                    onPressed!();
                  },
            child: pill));
  }
}

/// A round glass control for the header.
class HeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool dot;
  const HeaderButton(
      {super.key,
      required this.icon,
      required this.label,
      required this.onPressed,
      this.dot = false});
  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        GlassCircle(icon: icon, label: label, size: 38, onPressed: () {
          HolyHaptics.tap();
          onPressed();
        }),
        if (dot)
          Positioned(
              right: 1,
              top: 1,
              child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HolyThemeScope.of(context).accent,
                      border: Border.all(
                          color: HolyThemeScope.of(context).paper, width: 1.5)))),
      ]);
}
