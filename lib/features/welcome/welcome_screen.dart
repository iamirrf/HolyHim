import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/google_mark.dart';
import '../../design/design.dart';
import '../../services/auth_service.dart';
import '../auth/email_sheet.dart';
import '../common.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  Widget _authButton(String label, Widget icon, VoidCallback? onPressed) =>
      Pressable(
        onPressed: () {
          HolyHaptics.buttonPress();
          onPressed?.call();
        },
        semanticLabel: label,
        child: Glass(
          radius: 28,
          borderWidth: 1.2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 24, height: 24, child: icon),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  label,
                  style: HolyTypography.ui.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final theme = HolyThemeScope.of(context);
    final media = MediaQuery.of(context);
    final textScale = media.textScaler.scale(1.0);
    final isCompact = media.size.height < 700 || textScale > 1.2;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            final imageHeight = (availableHeight * 0.35).clamp(100.0, 300.0);

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: availableHeight,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 12),

                              // HolyHim Wordmark with subtle breathing halo, gradient, and shine
                              HolyTextHalo(
                                text: 'HolyHim',
                                style: HolyTypography.wordmark.copyWith(
                                  fontSize: isCompact ? 64 : 82,
                                ),
                              ),

                              const SizedBox(height: 6),

                              // Minimalistic Sketched Back of Jesus Illustration
                              // No background, high faded feathered borders, zero sharp cuts
                              SizedBox(
                                height: imageHeight,
                                child: Center(
                                  child: ShaderMask(
                                    blendMode: BlendMode.dstIn,
                                    shaderCallback: (bounds) =>
                                        const RadialGradient(
                                      center: Alignment.center,
                                      radius: 0.95,
                                      colors: [
                                        Colors.black,
                                        Colors.black,
                                        Colors.transparent,
                                      ],
                                      stops: [0.0, 0.72, 1.0],
                                    ).createShader(bounds),
                                    child: Image.asset(
                                      'assets/artwork/sketch_jesus_back.png',
                                      fit: BoxFit.contain,
                                      alignment: Alignment.center,
                                      excludeFromSemantics: true,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Warm inspiring tagline (No 365 days promise)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  AppConstants.tagline,
                                  textAlign: TextAlign.center,
                                  style: HolyTypography.title.copyWith(
                                    fontSize: 20,
                                    height: 1.3,
                                    color: theme.accent,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Every day, a new lesson in Scripture — written for a man\'s steady walk with God.',
                                  textAlign: TextAlign.center,
                                  style: HolyTypography.verse.copyWith(
                                    fontSize: 15,
                                    height: 1.4,
                                    color: theme.ink.withValues(alpha: 0.82),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Authentication buttons with Cognein-style depth
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _authButton(
                                'Continue with Google',
                                const GoogleMark(),
                                auth.loading
                                    ? null
                                    : () => ref
                                        .read(authProvider.notifier)
                                        .signInGoogle(),
                              ),
                              const SizedBox(height: 10),
                              _authButton(
                                'Continue with Apple',
                                const Icon(Icons.apple, size: 24),
                                auth.loading
                                    ? null
                                    : () => ref
                                        .read(authProvider.notifier)
                                        .signInApple(),
                              ),
                              const SizedBox(height: 10),
                              _authButton(
                                'Continue with Email',
                                const Icon(CupertinoIcons.mail, size: 22),
                                auth.loading
                                    ? null
                                    : () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => const EmailSheet(),
                                          ),
                                        ),
                              ),

                              if (auth.error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    auth.error!,
                                    textAlign: TextAlign.center,
                                    style: muted(context)
                                        .copyWith(color: theme.accent),
                                  ),
                                ),

                              const SizedBox(height: 14),

                              // Terms & Privacy
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'By continuing, you agree to our ',
                                    style:
                                        muted(context).copyWith(fontSize: 11),
                                  ),
                                  InkWell(
                                    onTap: () => openLegal(
                                        context, 'Terms of Use', 'terms'),
                                    child: Text(
                                      'Terms',
                                      style: muted(context).copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(' and ',
                                      style: muted(context)
                                          .copyWith(fontSize: 11)),
                                  InkWell(
                                    onTap: () => openLegal(
                                        context, 'Privacy', 'privacy'),
                                    child: Text(
                                      'Privacy Policy',
                                      style: muted(context).copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
