import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../design/design.dart';
import '../../services/billing.dart';
import '../../services/navigation_state.dart';
import '../../services/repository.dart';
import '../common.dart';

class PaywallScreen extends ConsumerWidget {
  final VoidCallback? onContinue;
  const PaywallScreen({super.key, this.onContinue});

  void leave(BuildContext context, WidgetRef ref, {bool testing = false}) {
    if (testing) ref.read(lifetimeProvider.notifier).dismissForTesting();
    if (onContinue != null) {
      onContinue!();
    } else {
      final pending = ref.read(pendingDestinationProvider);
      ref.read(pendingDestinationProvider.notifier).state = null;
      context.go(pending ?? '/');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(lifetimeProvider);
    final profile = ref.watch(repositoryProvider).profile;
    final theme = HolyThemeScope.of(context);
    final name = profile.name.trim().split(' ').first;
    final goal = profile.hearts.isEmpty
        ? 'make room for Scripture'
        : 'find ${profile.hearts.first.toLowerCase()} in your daily walk';

    const roseAccent = Color(0xFFC9A227);
    const goldAccent = Color(0xFFD4AF37);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Single cohesive background image behind the entire paywall
          Positioned.fill(
            child: Image.asset(
              'assets/artwork/paywall_bible_mountain.jpg',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) =>
                  Container(color: theme.colors.first),
            ),
          ),
          // Ambient soft blur + frosted veil over background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.colors.first.withValues(alpha: 0.72),
                      theme.colors[1].withValues(alpha: 0.86),
                      theme.colors.last.withValues(alpha: 0.94),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top header brand wordmark
                      Center(
                        child: Text(
                          'HolyHim',
                          style: HolyTypography.wordmark.copyWith(
                            fontSize: 42,
                            color: theme.accent,
                            shadows: [
                              Shadow(
                                color: theme.accent.withValues(alpha: 0.25),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // TOP FEATURE CARD (Cognein "Learn AI to Upgrade Your Life" Equivalent)
                      // Top opening shows the Bible and rugged landscape clearly,
                      // fading into blur downward with high-contrast text on top.
                      _buildInspiringOfferCard(
                        context,
                        name: name,
                        goal: goal,
                        roseAccent: roseAccent,
                        goldAccent: goldAccent,
                        theme: theme,
                      ),

                      const SizedBox(height: 18),

                      // BOTTOM PRICE / PLAN CARD (Cognein depth style)
                      _buildPriceCard(
                        context,
                        access: access,
                        roseAccent: roseAccent,
                        theme: theme,
                      ),

                      if (access.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            access.error!,
                            textAlign: TextAlign.center,
                            style: muted(context).copyWith(color: theme.accent),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // CTA BUTTON WITH EDGE GLOW
                      EdgeGlow(
                        radius: 28,
                        child: ActionButton(
                          access.busy
                              ? 'Just a moment…'
                              : access.active
                                  ? 'Continue to HolyHim'
                                  : kIsWeb
                                      ? 'Purchase in the iPhone app'
                                      : access.loading
                                          ? 'Loading store price…'
                                          : access.product == null
                                              ? 'Try App Store again'
                                              : 'Get Lifetime Access · ${access.product!.priceString}',
                          onPressed: access.busy || (kIsWeb && !access.active)
                              ? null
                              : access.active
                                  ? () => leave(context, ref)
                                  : access.product == null
                                      ? () => ref
                                          .read(lifetimeProvider.notifier)
                                          .load()
                                      : () async {
                                          HolyHaptics.buttonPress();
                                          final purchased = await ref
                                              .read(lifetimeProvider.notifier)
                                              .purchase();
                                          if (purchased && context.mounted) {
                                            HolyHaptics.celebration();
                                            leave(context, ref);
                                          }
                                        },
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'Payment is charged once to your Apple account. No subscription, no recurring fees.',
                        textAlign: TextAlign.center,
                        style: muted(context).copyWith(fontSize: 11),
                      ),

                      const SizedBox(height: 12),

                      // Legal & Navigation links
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => context.go('/account'),
                            child: const Text('Account',
                                style: TextStyle(fontSize: 12)),
                          ),
                          TextButton(
                            onPressed: () => context.go('/support'),
                            child: const Text('Support',
                                style: TextStyle(fontSize: 12)),
                          ),
                          TextButton(
                            onPressed: access.busy
                                ? null
                                : () async {
                                    HolyHaptics.buttonPress();
                                    final restored = await ref
                                        .read(lifetimeProvider.notifier)
                                        .restore();
                                    if (restored && context.mounted) {
                                      HolyHaptics.celebration();
                                      leave(context, ref);
                                    }
                                  },
                            child: const Text('Restore purchases',
                                style: TextStyle(fontSize: 12)),
                          ),
                          TextButton(
                            onPressed: () =>
                                openLegal(context, 'Terms of Use', 'terms'),
                            child: const Text('Terms',
                                style: TextStyle(fontSize: 12)),
                          ),
                          TextButton(
                            onPressed: () =>
                                openLegal(context, 'Privacy', 'privacy'),
                            child: const Text('Privacy',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (testingPaywallExit)
            Positioned(
              top: 12,
              right: 18,
              child: CircleControl(
                icon: CupertinoIcons.xmark,
                label: 'Close paywall for testing',
                onPressed: () => leave(context, ref, testing: true),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInspiringOfferCard(
    BuildContext context, {
    required String name,
    required String goal,
    required Color roseAccent,
    required Color goldAccent,
    required HolyTheme theme,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: roseAccent.withValues(alpha: 0.45),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: roseAccent.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Stack(
          children: [
            // Background Artwork (Real Photography — Ocean Cliffs)
            Positioned.fill(
              child: Image.asset(
                'assets/artwork/paywall_bible_mountain.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),

            // Progressive Blur and Gradient Veil:
            // Top ~115px remains clear showing the sea and cliffs;
            // then progressively blurs and fades into frosted glass veil for the text.
            Positioned.fill(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black,
                    Colors.black,
                  ],
                  stops: [0.0, 0.22, 0.42, 1.0],
                ).createShader(bounds),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          theme.colors.first.withValues(alpha: 0.72),
                          theme.colors.first.withValues(alpha: 0.94),
                        ],
                        stops: const [0.0, 0.35, 0.75],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Card Content Overlaid on the lower blurred area
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              child: Column(
                children: [
                  // Top Pill Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          roseAccent.withValues(alpha: 0.30),
                          goldAccent.withValues(alpha: 0.18),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: roseAccent.withValues(alpha: 0.55),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      '✝ HOLYHIM PRO',
                      style: HolyTypography.eyebrow.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: theme.ink,
                      ),
                    ),
                  ),

                  // Thin opening space where the Bible & pink nature shine through cleanly
                  const SizedBox(height: 72),

                  // Headline: Walk with God to Renew Your Heart
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Be Strong and',
                      style: HolyTypography.display.copyWith(
                        fontSize: 30,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          roseAccent,
                          const Color(0xFFC9A227),
                          goldAccent,
                        ],
                      ).createShader(bounds),
                      child: Text(
                        'Courageous',
                        style: HolyTypography.display.copyWith(
                          fontSize: 32,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Subheadline & Personalized Need
                  Text(
                    'Every day, a new lesson in Scripture, reflection, and prayer.',
                    textAlign: TextAlign.center,
                    style: HolyTypography.ui.copyWith(
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: theme.ink.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${name.isEmpty ? 'Your' : '$name, your'} quiet place to $goal.',
                    textAlign: TextAlign.center,
                    style: HolyTypography.ui.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: roseAccent,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Cognein-Style Timeline Features
                  _buildTimelineRow(
                    context,
                    badge: 'TODAY',
                    title: 'Begin strong, from day one',
                    subtitle:
                        'Scripture, plain meaning, honest reflection, and prayer.',
                    icon: CupertinoIcons.sparkles,
                    accentColor: roseAccent,
                  ),
                  _buildTimelineRow(
                    context,
                    badge: 'EVERY DAY',
                    title: 'A new lesson & fresh verse',
                    subtitle:
                        'Home screen widgets and reminders at your chosen hour.',
                    icon: CupertinoIcons.sun_max,
                    accentColor: goldAccent,
                  ),
                  _buildTimelineRow(
                    context,
                    badge: 'IN 30 DAYS',
                    title: 'Peace under pressure',
                    subtitle:
                        'Saved verses, hard-won milestones, and a steady rhythm.',
                    icon: CupertinoIcons.heart_fill,
                    accentColor: roseAccent,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow(
    BuildContext context, {
    required String badge,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    bool isLast = false,
  }) {
    return Stack(
      children: [
        // Left timeline line and icon positioned to stretch vertically
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accentColor.withValues(alpha: 0.4),
                          accentColor.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Right side content
        Padding(
          padding: EdgeInsets.fromLTRB(52, 0, 0, isLast ? 0 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: accentColor,
                      ),
                    ),
                  ),
                  Text(
                    title,
                    style: HolyTypography.ui.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: muted(context).copyWith(fontSize: 12, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCard(
    BuildContext context, {
    required LifetimeState access,
    required Color roseAccent,
    required HolyTheme theme,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: roseAccent.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: roseAccent.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Glass(
        radius: 24,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Lifetime Access',
                        style: HolyTypography.title.copyWith(fontSize: 20),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: roseAccent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'ONE-TIME',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: roseAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Full unlimited access forever. Never billed again.',
                    style: muted(context).copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                access.product?.priceString ?? '\$1.99',
                style: HolyTypography.title.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: theme.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
