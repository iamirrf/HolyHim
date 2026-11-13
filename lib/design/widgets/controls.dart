import 'dart:ui' show lerpDouble;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../haptics.dart';
import '../motion.dart';
import '../themes.dart';
import '../tokens.dart';
import '../typography.dart';
import 'pressable.dart';

/// A pill switch with a spring thumb. Replaces the stock Material switch.
class HolySwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;
  const HolySwitch(
      {super.key, required this.value, this.onChanged, this.semanticLabel});
  @override
  State<HolySwitch> createState() => _HolySwitchState();
}

class _HolySwitchState extends State<HolySwitch>
    with SingleTickerProviderStateMixin {
  late final _pos =
      AnimationController.unbounded(vsync: this, value: widget.value ? 1 : 0);
  @override
  void didUpdateWidget(HolySwitch old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _pos.value = widget.value ? 1 : 0;
      } else {
        _pos.animateWith(SpringSimulation(HolyMotion.pressRelease, _pos.value,
            widget.value ? 1 : 0, _pos.velocity));
      }
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Semantics(
        toggled: widget.value,
        label: widget.semanticLabel,
        enabled: widget.onChanged != null,
        child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onChanged == null
                ? null
                : () {
                    HolyHaptics.chipSelect();
                    widget.onChanged!(!widget.value);
                  },
            child: SizedBox(
                width: 56,
                height: 44,
                child: Center(
                    child: AnimatedBuilder(
                        animation: _pos,
                        builder: (context, _) {
                          final p = _pos.value.clamp(-.1, 1.1);
                          final track = Color.lerp(
                              t.sunk, t.accent, p.clamp(0.0, 1.0))!;
                          return Container(
                              width: 52,
                              height: 32,
                              decoration: ShapeDecoration(
                                  color: track,
                                  shape: StadiumBorder(
                                      side: BorderSide(
                                          color: Color.lerp(t.hairline,
                                              t.accent, p.clamp(0.0, 1.0))!,
                                          width: 1))),
                              child: Align(
                                  alignment: Alignment(
                                      lerpDouble(-1, 1, p)!, 0),
                                  child: Container(
                                      margin: const EdgeInsets.all(3),
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: t.isDark
                                              ? t.ink
                                              : Colors.white,
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: .16),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2))
                                          ]))));
                        })))));
  }
}

/// A check mark that draws itself on when [checked] becomes true.
class HolyCheck extends StatefulWidget {
  final bool checked;
  final double size;
  final Color? color;
  final Color? ink;
  const HolyCheck(
      {super.key, required this.checked, this.size = 24, this.color, this.ink});
  @override
  State<HolyCheck> createState() => _HolyCheckState();
}

class _HolyCheckState extends State<HolyCheck>
    with SingleTickerProviderStateMixin {
  late final _draw = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.checked ? 1 : 0);
  @override
  void didUpdateWidget(HolyCheck old) {
    super.didUpdateWidget(old);
    if (old.checked != widget.checked) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _draw.value = widget.checked ? 1 : 0;
      } else {
        widget.checked ? _draw.forward() : _draw.reverse();
      }
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final fill = widget.color ?? t.accent;
    return AnimatedBuilder(
        animation: _draw,
        builder: (context, _) {
          final v = Curves.easeOutCubic.transform(_draw.value);
          return SizedBox.square(
              dimension: widget.size,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(Colors.transparent, fill, v),
                      border: Border.all(
                          color: Color.lerp(t.hairline, fill, v)!,
                          width: 1.4)),
                  child: CustomPaint(
                      painter: _CheckPainter(
                          v, widget.ink ?? t.onPrimary))));
        });
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;
  _CheckPainter(this.progress, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final s = size.width;
    final path = Path()
      ..moveTo(s * .28, s * .52)
      ..lineTo(s * .44, s * .67)
      ..lineTo(s * .73, s * .36);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .09
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}

/// One selectable answer: paper tile, label, optional detail, and a check
/// that draws on when chosen.
class ChoiceTile extends StatelessWidget {
  final String label;
  final String? detail;
  final IconData? icon;
  final bool selected;
  final VoidCallback onPressed;
  final bool multi;
  final bool dense;
  const ChoiceTile(
      {super.key,
      required this.label,
      required this.selected,
      required this.onPressed,
      this.detail,
      this.icon,
      this.multi = false,
      this.dense = false});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Pressable(
        onPressed: () {
          selected ? HolyHaptics.chipDeselect() : HolyHaptics.chipSelect();
          onPressed();
        },
        selected: selected,
        semanticLabel: detail == null ? label : '$label. $detail',
        borderRadius: BorderRadius.circular(HolyRadius.field),
        pressedScale: .98,
        child: AnimatedContainer(
            duration: reduced ? Duration.zero : const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            constraints: BoxConstraints(minHeight: dense ? 52 : 60),
            padding: EdgeInsets.symmetric(
                horizontal: 16, vertical: dense ? 10 : 13),
            decoration: ShapeDecoration(
                color: selected
                    ? Color.alphaBlend(
                        t.accent.withValues(alpha: t.isDark ? .18 : .08),
                        t.surface)
                    : t.surface,
                shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(HolyRadius.field),
                    side: BorderSide(
                        color: selected ? t.accent : t.hairline,
                        width: selected ? 1.4 : 1))),
            child: Row(children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: selected ? t.accent : t.muted),
                const SizedBox(width: 12),
              ],
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Text(label,
                        style: HolyTypography.ui.copyWith(
                            color: t.ink,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600)),
                    if (detail != null) ...[
                      const SizedBox(height: 2),
                      Text(detail!,
                          style:
                              HolyTypography.caption.copyWith(color: t.muted)),
                    ]
                  ])),
              const SizedBox(width: 12),
              HolyCheck(checked: selected, size: 22),
            ])));
  }
}

/// A settings row: icon, title, optional value, then a chevron or a
/// trailing control.
class HolyRow extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onPressed;
  final bool destructive;
  const HolyRow(
      {super.key,
      required this.title,
      this.icon,
      this.value,
      this.trailing,
      this.onPressed,
      this.destructive = false});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final ink = destructive
        ? (t.isDark ? const Color(0xFFF2B8B5) : const Color(0xFFB3261E))
        : t.ink;
    final row = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: destructive ? ink : t.accent),
                const SizedBox(width: 14),
              ],
              Expanded(
                  child: Text(title,
                      style: HolyTypography.ui
                          .copyWith(color: ink, fontWeight: FontWeight.w600))),
              if (value != null) ...[
                const SizedBox(width: 8),
                Flexible(
                    child: Text(value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: HolyTypography.body.copyWith(color: t.muted))),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!
              ] else if (onPressed != null) ...[
                const SizedBox(width: 6),
                Icon(CupertinoIcons.chevron_right, size: 15, color: t.muted),
              ]
            ])));
    if (onPressed == null) {
      return Semantics(
          label: value == null ? title : '$title, $value', child: row);
    }
    return Pressable(
        onPressed: onPressed,
        pressedScale: .985,
        semanticLabel: value == null ? title : '$title, $value',
        child: row);
  }
}

/// A group of [HolyRow]s on one paper card, separated by hairlines.
class RowGroup extends StatelessWidget {
  final List<Widget> rows;
  const RowGroup({super.key, required this.rows});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return DecoratedBox(
        decoration: ShapeDecoration(
            color: t.surface,
            shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(HolyRadius.card - 6),
                side: BorderSide(color: t.hairline, width: .8)),
            shadows: HolyDepth.paper(t, lift: .5)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Padding(
                  padding: const EdgeInsets.only(left: 50),
                  child: SizedBox(
                      height: .8,
                      width: double.infinity,
                      child: ColoredBox(color: t.hairline))),
            rows[i],
          ]
        ]));
  }
}

/// A thin segmented progress bar for multi-step flows.
class StepBar extends StatelessWidget {
  final int steps;
  final int current;
  final Color? color;
  const StepBar(
      {super.key, required this.steps, required this.current, this.color});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final c = color ?? t.accent;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
        label: 'Step ${current + 1} of $steps',
        child: Row(children: [
          for (var i = 0; i < steps; i++)
            Expanded(
                child: Padding(
                    padding: EdgeInsets.only(right: i == steps - 1 ? 0 : 5),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SizedBox(
                            height: 3,
                            child: Stack(fit: StackFit.expand, children: [
                              ColoredBox(color: c.withValues(alpha: .16)),
                              AnimatedFractionallySizedBox(
                                  duration: reduced
                                      ? Duration.zero
                                      : const Duration(milliseconds: 420),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.centerLeft,
                                  widthFactor: i <= current ? 1 : 0,
                                  child: ColoredBox(color: c)),
                            ])))))
        ]));
  }
}

/// Small uppercase label above a section.
class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  const Eyebrow(this.text, {super.key, this.color, this.textAlign});
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      textAlign: textAlign,
      style: HolyTypography.eyebrow
          .copyWith(color: color ?? HolyThemeScope.of(context).accent));
}
