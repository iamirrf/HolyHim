import 'package:flutter/material.dart';
import 'package:holyher/core/constants/app_constants.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/glass_button.dart';
import 'package:holyher/features/onboarding/onboarding_screen.dart';

/// Landing, adapted from Cognein's initial screen: mark, wordmark, tagline,
/// one action. No auth stack in v1: the app needs no account.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _opening = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _Mark(),
                    const SizedBox(height: 40),
                    Text(
                      AppConstants.appName.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent),
                    ),
                    const SizedBox(height: 16),
                    const Text(AppConstants.tagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16, color: AppColors.textSecondary)),
                    const SizedBox(height: 40),
                    GlassButton(
                      label: 'Get Started',
                      onPressed: _opening
                          ? null
                          : () async {
                              setState(() => _opening = true);
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                    builder: (_) => const OnboardingScreen()),
                              );
                              if (mounted) setState(() => _opening = false);
                            },
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceLight,
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.25),
          ),
        ),
        child: Center(
          child: Semantics(
            label: 'Cross',
            child: const SizedBox(
                width: 56,
                height: 72,
                child: CustomPaint(painter: _CrossPainter())),
          ),
        ),
      ),
    );
  }
}

/// Draw the existing flat cross without relying on a system fallback glyph.
class _CrossPainter extends CustomPainter {
  const _CrossPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.accent;
    canvas.drawRect(
        Rect.fromLTWH(size.width / 2 - 4, 0, 8, size.height), paint);
    canvas.drawRect(Rect.fromLTWH(0, size.height / 4, size.width, 8), paint);
  }

  @override
  bool shouldRepaint(_CrossPainter oldDelegate) => false;
}
