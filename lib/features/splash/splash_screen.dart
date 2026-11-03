import 'package:flutter/material.dart';
import 'package:holyher/core/widgets/holy_loader.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => Scaffold(
          backgroundColor: AppColors.background,
          body: LayoutBuilder(
              builder: (context, box) => Stack(children: [
                    const Center(child: HolyMark(size: 96, launch: true)),
                    Positioned(
                        left: 24,
                        right: 24,
                        top: box.maxHeight / 2 + 72,
                        child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('HolyHer', style: HolyTypography.heading),
                              SizedBox(height: 28),
                              PulsingDotsLoader(
                                  semanticsLabel: 'Opening your journey')
                            ]))
                  ]))));
}
