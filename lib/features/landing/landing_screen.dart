import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/core/widgets/lesson_artwork.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/features/auth/auth_screen.dart';
import 'package:holyher/features/support/support_screens.dart';

class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => useHolyPalette(
      context,
      () => HolyScaffold(
          body: ReadingWidth(
              maxWidth: 1000,
              child: LayoutBuilder(builder: (context, box) {
                final wide = box.maxWidth > 740;
                final brand =
                    const Row(mainAxisSize: MainAxisSize.min, children: [
                  HolyMark(size: 34),
                  SizedBox(width: 10),
                  Flexible(
                      child: Text('HolyHer', style: HolyTypography.section))
                ]);
                final promise = Text('A quieter moment.\nA closer walk.',
                    textAlign: wide ? TextAlign.left : TextAlign.center,
                    style: HolyTypography.display.copyWith(
                        fontSize: wide ? 52 : 32,
                        height: 1.12,
                        color: AppColors.textPrimary));
                final description = Text(
                    'Walk with God, one day at a time. Five quiet cards. Two to three minutes, just for you.',
                    textAlign: wide ? TextAlign.left : TextAlign.center,
                    style: HolyTypography.body.copyWith(
                        fontSize: wide ? 20 : 16,
                        color: AppColors.textSecondary));
                final actions = Column(children: [
                  HolyButton(
                      label: 'Begin',
                      onPressed: () => openScreen(context,
                          const AuthScreen(initialCreateAccount: true)),
                      icon: Icons.arrow_forward_rounded),
                  const SizedBox(height: 6),
                  TextButton(
                      onPressed: () => openScreen(context, const AuthScreen()),
                      child: const Text('Already walking with us? Sign in')),
                  const SizedBox(height: 6),
                  const Text('365 days of Scripture · Free access',
                      style: HolyTypography.supporting),
                ]);
                final preview = Transform.rotate(
                    angle: wide ? .035 : .012,
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: LessonArtwork(
                            day: 1,
                            child: Padding(
                                padding: EdgeInsets.all(wide ? 30 : 20),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Eyebrow('A glimpse of Day 1'),
                                      SizedBox(height: wide ? 22 : 10),
                                      Text(lessons.first.title,
                                          style: HolyTypography.heading
                                              .copyWith(
                                                  fontSize: wide ? 28 : 20,
                                                  color:
                                                      AppColors.textPrimary)),
                                      SizedBox(height: wide ? 24 : 12),
                                      Text('“Be strong and courageous.”',
                                          style: HolyTypography.scripture
                                              .copyWith(
                                                  fontSize: wide ? 30 : 24,
                                                  color:
                                                      AppColors.textPrimary)),
                                      const SizedBox(height: 12),
                                      Text('Deuteronomy 31:6 · WEB',
                                          style: HolyTypography.supporting
                                              .copyWith(
                                                  color:
                                                      AppColors.textSecondary)),
                                      SizedBox(height: wide ? 30 : 14),
                                      Row(
                                          children: List.generate(
                                              5,
                                              (i) => Expanded(
                                                  child: Container(
                                                      height: 3,
                                                      margin:
                                                          const EdgeInsets.only(
                                                              right: 5),
                                                      color: i == 0
                                                          ? AppColors.accent
                                                          : AppColors
                                                              .divider)))),
                                      if (wide) ...[
                                        const SizedBox(height: 22),
                                        Text('You do not walk alone.',
                                            style: HolyTypography.supporting
                                                .copyWith(
                                                    color: AppColors.accent)),
                                        const SizedBox(height: 28),
                                      ],
                                    ])))));
                return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: wide ? 40 : 24, vertical: wide ? 60 : 18),
                    child: Column(children: [
                      if (wide)
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    brand,
                                    const SizedBox(height: 30),
                                    const Eyebrow(
                                        'A little Scripture. A little closer.'),
                                    const SizedBox(height: 18),
                                    promise,
                                    const SizedBox(height: 22),
                                    description,
                                    const SizedBox(height: 28),
                                    actions,
                                  ])),
                              const SizedBox(width: 64),
                              Expanded(child: preview)
                            ])
                      else ...[
                        brand,
                        const SizedBox(height: 20),
                        promise,
                        const SizedBox(height: 12),
                        description,
                        const SizedBox(height: 22),
                        preview,
                        const SizedBox(height: 24),
                        actions,
                      ],
                      const SizedBox(height: 22),
                      const LegalFooter(),
                    ]));
              }))));
}
