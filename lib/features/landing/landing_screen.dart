import 'package:flutter/material.dart';
import 'package:holyher/core/constants/app_constants.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/features/auth/auth_screen.dart';
import 'package:holyher/features/support/support_screens.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _opening = false;
  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const AuthScreen()));
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) => HolyScaffold(
      body: ReadingWidth(
          maxWidth: 580,
          child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                  child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Center(
                                    child:
                                        Eyebrow('A little faith. Every day.')),
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 30),
                                    child: Column(children: [
                                      const HolyMark(size: 128),
                                      const SizedBox(height: 30),
                                      const Text('HolyHer',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 39,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: -1.5)),
                                      const SizedBox(height: 18),
                                      Text(
                                          'A moment with God.\nSomething to carry.',
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium),
                                      const SizedBox(height: 19),
                                      const Text(
                                          'One verse. One grounded confidence.\n365 small steps into a steadier faith.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 14,
                                              height: 1.8,
                                              color: AppColors.textSecondary)),
                                      const SizedBox(height: 28),
                                      const GlassSurface(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 16),
                                          child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                    Icons.auto_awesome_outlined,
                                                    size: 18,
                                                    color: AppColors.accent),
                                                SizedBox(width: 10),
                                                Flexible(
                                                    child: Text(
                                                        AppConstants.tagline,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            height: 1.6,
                                                            color: AppColors
                                                                .accentDark)))
                                              ])),
                                    ])),
                                Column(children: [
                                  HolyButton(
                                      label: 'Begin your journey',
                                      icon: Icons.arrow_forward_rounded,
                                      onPressed: _opening ? null : _open),
                                  const SizedBox(height: 14),
                                  const Text(
                                      'Your journey, saved across your devices.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 14),
                                  const LegalFooter()
                                ]),
                              ])))))));
}
