import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/data/lessons.dart';

/// The same physical pages and route nodes used in the signed-in experience.
class WelcomeProductScene extends StatelessWidget {
  final int index;
  final double phase;
  const WelcomeProductScene({super.key, required this.index, this.phase = .25});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => LayoutBuilder(builder: (context, box) {
            final width = math.min(290.0, box.maxWidth - 48);
            double measure(String text, TextStyle style, double padding) {
              final painter = TextPainter(
                  text: TextSpan(text: text, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context))
                ..layout(maxWidth: width - padding * 2);
              return painter.height;
            }

            final dayStyle = HolyTypography.label.copyWith(letterSpacing: 1.1);
            final fullHeight = 52 +
                48 +
                measure('DAY 01  /  A FIRST STEP', dayStyle, 26) +
                measure(lessons.first.title, HolyTypography.section, 26) +
                measure('“Be strong and courageous.”', HolyTypography.scripture,
                    26) +
                measure(
                    'Deuteronomy 31:6 · WEB', HolyTypography.supporting, 26);
            final compact = fullHeight > box.maxHeight - 24;
            final compactHeight = 36 +
                14 +
                measure('DAY 01  /  A FIRST STEP', dayStyle, 18) +
                measure(lessons.first.title, HolyTypography.action, 18);
            final showReference = !compact ||
                compactHeight +
                        14 +
                        measure('Deuteronomy 31:6 · WEB',
                            HolyTypography.supporting, 18) <=
                    box.maxHeight - 24;
            final large = MediaQuery.textScalerOf(context).scale(17) > 20;
            if (large && index != 1) {
              return Center(
                  child: SizedBox(
                      width: 220,
                      child: Semantics(
                          label: index == 0
                              ? 'Day 1, ${lessons.first.title}, lesson preview'
                              : 'Saved Scripture, ${lessons[2].verseReference}',
                          child: PearlSurface(
                              ribbon: index == 2,
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                        index == 0
                                            ? Icons.menu_book_outlined
                                            : Icons.bookmark_outline,
                                        color: AppColors.accent,
                                        size: 30),
                                    const SizedBox(height: 16),
                                    Text(index == 0 ? 'Day 01' : 'Saved',
                                        style: HolyTypography.label
                                            .copyWith(color: AppColors.accent))
                                  ])))));
            }
            final drift = MediaQuery.disableAnimationsOf(context)
                ? 0.0
                : math.sin(phase * math.pi * 2) * 4;
            if (index == 1) {
              return CustomPaint(
                  painter: RoseRoutePainter(points: [
                    Offset(.24, box.maxHeight * .32),
                    Offset(.73, box.maxHeight * .50),
                    Offset(.34, box.maxHeight * .76)
                  ], completed: 1),
                  child: Stack(children: [
                    for (var i = 0; i < 3; i++)
                      Positioned(
                          left: box.maxWidth * [.24, .73, .34][i] - 52,
                          top: box.maxHeight * [.32, .50, .76][i] -
                              52 +
                              drift * (i == 1 ? -1 : 1),
                          child: LessonMedallion(
                              state: [
                            LessonNodeState.complete,
                            LessonNodeState.current,
                            LessonNodeState.future
                          ][i])),
                  ]));
            }
            return Center(
                child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, .0012)
                      ..translateByDouble(0, drift, 0, 1)
                      ..rotateZ(index == 0 ? -.025 : .02)
                      ..rotateY(MediaQuery.disableAnimationsOf(context)
                          ? 0
                          : math.sin(phase * math.pi * 2) * .035),
                    child: SizedBox(
                        width: width,
                        child: Stack(clipBehavior: Clip.none, children: [
                          for (var i = 2; i >= 1; i--)
                            Positioned(
                                top: -i * 6,
                                bottom: i * 6,
                                left: i * 6,
                                right: -i * 6,
                                child: Opacity(
                                    opacity: 1 - i * .22,
                                    child: const PearlSurface(
                                        radius: 24, child: SizedBox.expand()))),
                          if (index == 0)
                            PearlSurface(
                                padding: EdgeInsets.all(compact ? 18 : 26),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('DAY 01  /  A FIRST STEP',
                                          style: HolyTypography.label.copyWith(
                                              color: AppColors.accent,
                                              letterSpacing: 1.1)),
                                      const SizedBox(height: 14),
                                      Text(lessons.first.title,
                                          style: compact
                                              ? HolyTypography.action
                                              : HolyTypography.section),
                                      if (!compact) ...[
                                        const SizedBox(height: 20),
                                        const Text(
                                            '“Be strong and courageous.”',
                                            style: HolyTypography.scripture)
                                      ],
                                      if (showReference) ...[
                                        const SizedBox(height: 14),
                                        Text('Deuteronomy 31:6 · WEB',
                                            style: HolyTypography.supporting
                                                .copyWith(
                                                    color: AppColors
                                                        .textSecondary))
                                      ],
                                    ]))
                          else
                            PearlSurface(
                                ribbon: true,
                                padding: EdgeInsets.fromLTRB(
                                    24, compact ? 24 : 36, 24, 26),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('KEPT CLOSE',
                                          style: HolyTypography.label.copyWith(
                                              color: AppColors.accent,
                                              letterSpacing: 1.2)),
                                      SizedBox(
                                          height:
                                              box.maxHeight < 170 ? 12 : 22),
                                      if (box.maxHeight >= 170)
                                        Text(lessons[2].verseText,
                                            maxLines: compact ? 2 : 5,
                                            overflow: TextOverflow.fade,
                                            style: compact
                                                ? HolyTypography.body
                                                : HolyTypography.scripture),
                                      SizedBox(
                                          height:
                                              box.maxHeight < 170 ? 12 : 18),
                                      Text(lessons[2].verseReference,
                                          style: HolyTypography.supporting
                                              .copyWith(
                                                  color:
                                                      AppColors.textSecondary)),
                                    ])),
                        ]))));
          }));
}
