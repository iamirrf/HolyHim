import 'package:flutter/material.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/features/landing/welcome_scenes.dart';

/// Development studies only. B and C are never product settings.
class DesignStudy extends StatelessWidget {
  final String treatment, screen;
  const DesignStudy({super.key, required this.treatment, required this.screen});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => HolyScaffold(
          body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const HolyMark(size: 36),
                      const SizedBox(width: 8),
                      const Expanded(
                          child:
                              Text('HolyHer', style: HolyTypography.section)),
                      Text(treatment, style: HolyTypography.label)
                    ]),
                    const SizedBox(height: 32),
                    if (screen == 'welcome')
                      ..._welcome(context)
                    else if (screen == 'learn')
                      ..._learn(context)
                    else
                      ..._scripture(context),
                  ]))));
  List<Widget> _welcome(BuildContext context) => switch (treatment) {
        'A' => [
            const SizedBox(height: 30),
            const SizedBox(height: 330, child: WelcomeProductScene(index: 0)),
            const SizedBox(height: 32),
            const Text('A moment with God.',
                textAlign: TextAlign.center, style: HolyTypography.heading),
            const SizedBox(height: 32),
            HolyButton(label: 'Begin your day', onPressed: () {}),
            const SizedBox(height: 12),
            const Text('Pearl light · Floating, optical layers',
                textAlign: TextAlign.center, style: HolyTypography.supporting)
          ],
        'B' => [
            const Text('Make a little\nroom for faith.',
                style: HolyTypography.display),
            const SizedBox(height: 40),
            Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFFEF9),
                    border: Border(
                        left: BorderSide(color: AppColors.accent, width: 3))),
                child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RibbonDetail(height: 52),
                      SizedBox(height: 30),
                      Text('One page.\nOne new day.',
                          style: HolyTypography.heading),
                      SizedBox(height: 24),
                      Text('A daily Bible message, and a thought to carry.',
                          style: HolyTypography.body)
                    ])),
            const SizedBox(height: 40),
            HolyButton(label: 'Open the first page', onPressed: () {})
          ],
        _ => [
            const SizedBox(height: 30),
            const Center(child: PorcelainSeal(size: 154)),
            const SizedBox(height: 52),
            const Text('A quiet place\nto begin.',
                textAlign: TextAlign.center, style: HolyTypography.display),
            const SizedBox(height: 24),
            const Center(
                child: Text('Daily moments with Scripture',
                    style: HolyTypography.supporting)),
            const SizedBox(height: 64),
            HolyButton(label: 'Come in', secondary: true, onPressed: () {})
          ],
      };
  List<Widget> _learn(BuildContext context) => [
        if (treatment == 'A') ...[
          PearlSurface(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.timelapse_rounded,
                          color: AppColors.accent, size: 34),
                      const SizedBox(width: 12),
                      const Text('0 of 365 complete',
                          style: HolyTypography.supporting)
                    ]),
                    const SizedBox(height: 14),
                    Text(lessons.first.title, style: HolyTypography.section),
                    const SizedBox(height: 14),
                    HolyButton(label: 'Continue', onPressed: () {})
                  ])),
          const SizedBox(height: 24),
          const Text('UNIT 01  /  COURAGE', style: HolyTypography.label),
          const SizedBox(height: 12),
          const SizedBox(height: 350, child: WelcomeProductScene(index: 1)),
        ] else if (treatment == 'B') ...[
          const Text('Your next page', style: HolyTypography.heading),
          const SizedBox(height: 28),
          const Align(
              alignment: Alignment.centerLeft, child: RibbonDetail(height: 56)),
          const SizedBox(height: 16),
          Text(lessons.first.title, style: HolyTypography.section),
          const SizedBox(height: 12),
          Text(lessons.first.verseReference, style: HolyTypography.supporting),
          const SizedBox(height: 24),
          HolyButton(label: 'Read Day 1', onPressed: () {}),
          const SizedBox(height: 32),
          for (var i = 1; i < 4; i++)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(children: [
                  Text('0${i + 1}', style: HolyTypography.section),
                  const SizedBox(width: 24),
                  Expanded(child: Text(lessons[i].title)),
                  const Icon(Icons.lock_outline, size: 20)
                ])),
        ] else ...[
          const Text('Your daily rhythm',
              textAlign: TextAlign.center, style: HolyTypography.heading),
          const SizedBox(height: 32),
          const Center(child: LessonMedallion(state: LessonNodeState.current)),
          const SizedBox(height: 20),
          Text(lessons.first.title,
              textAlign: TextAlign.center, style: HolyTypography.section),
          const SizedBox(height: 24),
          HolyButton(label: 'Continue', secondary: true, onPressed: () {}),
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 24),
          const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                LessonMedallion(state: LessonNodeState.future),
                LessonMedallion(state: LessonNodeState.future)
              ]),
          const SizedBox(height: 20),
          const Text('One new lesson, each day.',
              textAlign: TextAlign.center, style: HolyTypography.supporting),
        ]
      ];
  List<Widget> _scripture(BuildContext context) => [
        if (treatment == 'A') ...[
          const Text('A moment in Scripture', style: HolyTypography.heading),
          const SizedBox(height: 32),
          ScripturePage(lesson: lessons.first),
        ] else if (treatment == 'B') ...[
          Container(
              padding: const EdgeInsets.fromLTRB(26, 0, 26, 32),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFFEF9),
                  border: Border(left: BorderSide(color: AppColors.divider))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RibbonDetail(height: 60),
                    const SizedBox(height: 32),
                    const Text('DAY 01', style: HolyTypography.label),
                    const SizedBox(height: 24),
                    Text(lessons.first.verseText,
                        style: HolyTypography.scripture),
                    const SizedBox(height: 32),
                    Text(lessons.first.verseReference,
                        style: HolyTypography.supporting),
                    const Text('World English Bible',
                        style: HolyTypography.supporting)
                  ])),
        ] else ...[
          const Center(child: PorcelainSeal(size: 64)),
          const SizedBox(height: 48),
          Text(lessons.first.verseText,
              textAlign: TextAlign.center, style: HolyTypography.scripture),
          const SizedBox(height: 40),
          const Divider(indent: 120, endIndent: 120),
          const SizedBox(height: 24),
          Text(lessons.first.verseReference,
              textAlign: TextAlign.center, style: HolyTypography.supporting),
          const Text('World English Bible',
              textAlign: TextAlign.center, style: HolyTypography.supporting),
        ],
        const SizedBox(height: 32),
        HolyButton(label: 'Continue', onPressed: () {})
      ];
}

class PorcelainSeal extends StatelessWidget {
  final double size;
  final IconData? icon;
  const PorcelainSeal({super.key, this.size = 104, this.icon});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFEFF), Color(0xFFEADDE4)]),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                    color: AppColors.accentDark.withValues(alpha: .12),
                    blurRadius: size * .16,
                    offset: Offset(size * .04, size * .07)),
                BoxShadow(
                    color: Colors.white.withValues(alpha: .9),
                    blurRadius: size * .10,
                    offset: Offset(-size * .03, -size * .04))
              ]),
          child: Center(
              child: Icon(icon ?? Icons.add_rounded,
                  color: const Color(0xFFC3A8B7),
                  size: size * .42,
                  shadows: const [
                Shadow(color: Colors.white, offset: Offset(0, 1))
              ]))));
}
