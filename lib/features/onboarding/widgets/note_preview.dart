import 'package:flutter/material.dart';
import '../../../design/design.dart';
import '../../../design/widgets/hide_region.dart';

/// A faithful picture of the iOS banner she will receive.
class NotePreview extends StatelessWidget {
  final String time, title, body;
  const NotePreview(
      {super.key, required this.time, required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Hideable(child: _build(context));

  Widget _build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final ink = t.isDark ? Colors.white : Colors.black;
    return Semantics(
        label: 'Preview: HolyHim at $time. $title. $body',
        excludeSemantics: true,
        child: DecoratedBox(
            decoration: ShapeDecoration(
                color: t.isDark ? const Color(0xFF2C2C2E) : Colors.white,
                shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(22)),
                shadows: HolyDepth.paper(t, lift: .8)),
            child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset('assets/brand/holyhim-mark.png',
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                  width: 36, height: 36, color: t.accent))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Row(children: [
                              Expanded(
                                  child: Text('HolyHim',
                                      style: HolyTypography.label.copyWith(
                                          color: ink,
                                          fontWeight: FontWeight.w700))),
                              Text(time,
                                  style: HolyTypography.caption.copyWith(
                                      color: ink.withValues(alpha: .6))),
                            ]),
                            const SizedBox(height: 2),
                            Text(title,
                                style:
                                    HolyTypography.label.copyWith(color: ink)),
                            Text(body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: HolyTypography.caption.copyWith(
                                    color: ink.withValues(alpha: .8))),
                          ])),
                    ]))));
  }
}
