import 'package:flutter/material.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => HolyScaffold(
      body: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const HolyMark(size: 108),
                const SizedBox(height: 25),
                const Text('HolyHer',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1)),
                const SizedBox(height: 12),
                const Text('A little faith. Every day.',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 32),
                Semantics(
                    label: 'Opening your journey',
                    child: const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2)))
              ]))));
}
