import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../design/art_catalog.dart';
import '../../design/design.dart';
import '../../design/widgets/animated_mesh_background.dart';
import '../../design/widgets/coin_3d.dart';
import '../../design/widgets/particle_field.dart';
import '../../domain/onboarding_flow.dart';
import '../../services/auth_service.dart';
import '../../services/billing.dart';
import '../../services/repository.dart';
import '../common.dart';
import '../onboarding/onboarding_moods.dart';
import '../onboarding/widgets/onboarding_scaffold.dart' show OnboardingButton;
import '../onboarding/widgets/onboarding_tokens.dart';
import '../profile/profile_screen.dart' show AccountScreen;

/// True from a purchase made at the gate until she leaves "You're in", so
/// the router keeps the offer on screen while access turns on beneath it.
final paywallThanksProvider = StateProvider<bool>((ref) => false);

/// Membership, on a screen of its own: the welcome's pearl light with the
/// offer in it.
///
/// After the welcome, a person without access sees this and nothing else:
/// [locked] takes away every way past it but the offer itself, and keeps
/// Restore, the Terms, the Privacy Policy, Sign out and Delete account in
/// reach so nobody is trapped. The welcome shows the same [OfferBody] as
/// its last step.
class OfferScreen extends ConsumerWidget {
  /// No close control: the gate after the welcome.
  final bool locked;

  /// The locked lesson that brought her here, if any.
  final int? lockedDay;
  final VoidCallback? onContinue;
  const OfferScreen(
      {super.key, this.locked = false, this.lockedDay, this.onContinue});

  static final _theme = HolyThemeData.build(HolyThemes.blush);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mood = OnboardingMoods.pearl;
    final opaque = HolyThemeScope.opaqueOf(context);
    final media = MediaQuery.of(context);
    void close() {
      if (onContinue != null) {
        onContinue!();
      } else if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    }

    final canClose = !locked;
    return HolyThemeScope(
        theme: HolyThemes.blush,
        reduceTransparency: opaque,
        child: Theme(
            data: _theme,
            child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.dark,
                child: Scaffold(
                    backgroundColor: mood.mesh.baseColors[0],
                    body: Stack(fit: StackFit.expand, children: [
                      if (opaque)
                        ColoredBox(color: mood.mesh.baseColors[4])
                      else ...[
                        AnimatedMeshBackground(theme: mood.mesh),
                        IgnorePointer(
                            child: RepaintBoundary(
                                child: ParticleField(
                                    config: ParticleConfig(
                                        count: 22,
                                        color:
                                            Colors.white.withValues(alpha: .7),
                                        blurSigma: 2.4)))),
                      ],
                      Padding(
                          padding: EdgeInsets.fromLTRB(
                              HolySpace.gutter,
                              media.padding.top + 8,
                              HolySpace.gutter,
                              media.padding.bottom + 6),
                          child: OfferBody(
                              locked: locked, onContinue: onContinue)),
                      // Only a member looking at the offer may close it.
                      if (canClose)
                        Positioned(
                            top: media.padding.top + 16,
                            left: HolySpace.gutter + 10,
                            child: IconControl(
                                icon: CupertinoIcons.xmark,
                                label: 'Close',
                                size: 36,
                                onPhoto: true,
                                onPressed: close)),
                    ])))));
  }
}

/// The offer itself: a photograph and her medallion, one promise, what
/// membership gives, its one price, the free week when the store offers it,
/// and the ways on. It draws no background, so it sits on whatever field
/// holds it.
class OfferBody extends ConsumerStatefulWidget {
  /// The welcome's last step.
  final bool onboarding;

  /// The gate: the account actions are shown, as there is no other way to
  /// them.
  final bool locked;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  const OfferBody(
      {super.key,
      this.onboarding = false,
      this.locked = false,
      this.onContinue,
      this.onBack});
  @override
  ConsumerState<OfferBody> createState() => _OfferBodyState();
}

class _OfferBodyState extends ConsumerState<OfferBody> {
  /// The trial switch. Null until she touches it: on whenever the store can
  /// offer the free week.
  bool? _trialOn;
  bool _thanked = false;

  void _leave() {
    ref.read(paywallThanksProvider.notifier).state = false;
    if (widget.onContinue != null) {
      widget.onContinue!();
    } else if (widget.onBack != null) {
      widget.onBack!();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _buy(MemberPlan plan) async {
    HolyHaptics.buttonPress();
    final ok = await ref.read(accessProvider.notifier).purchase(plan);
    if (ok && mounted) _celebrate();
  }

  Future<void> _restore() async {
    final ok = await ref.read(accessProvider.notifier).restore();
    if (ok && mounted) _celebrate();
  }

  void _celebrate() {
    HolyHaptics.celebration();
    unawaited(HolySounds.purchaseChime());
    if (widget.locked) ref.read(paywallThanksProvider.notifier).state = true;
    setState(() => _thanked = true);
  }

  Future<void> _signOut() async {
    if (!await confirm(context,
        title: 'Sign out?',
        message: 'Your walk stays saved to your account.',
        action: 'Sign out')) {
      return;
    }
    await ref.read(authProvider.notifier).signOut();
  }

  void _account() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const AccountScreen()));

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(accessProvider);
    if (_thanked || access.active) {
      return _Welcome(
          trial: access.inTrial,
          lifetime: access.purchased || access.retained,
          firstDay: widget.onboarding,
          onContinue: _leave);
    }
    final withTrial = (_trialOn ?? true) && access.canTrial;
    final plan = withTrial ? access.trialPlan : access.plainPlan;
    final days = plan?.trialDays ?? access.trialPlan?.trialDays ?? 7;
    final terms = _Terms(
        price: plan?.price, trialDays: withTrial ? plan?.trialDays : null);
    final accountActions = widget.locked || widget.onboarding;

    return LayoutBuilder(builder: (context, box) {
      // Every phone gets the whole offer at a readable size: a small one
      // trims the photograph and shows three promises, not four.
      final compact = box.maxHeight < 640;
      final hero = compact
          ? (box.maxHeight * .13).clamp(66.0, 96.0)
          : (box.maxHeight * .19).clamp(100.0, 190.0);
      final gap = compact ? 10.0 : 14.0;
      return FitColumn(padding: EdgeInsets.zero, children: [
        _Hero(height: hero, onboarding: widget.onboarding),
        SizedBox(height: compact ? 20 : 24),
        _Headline(compact: compact),
        SizedBox(height: compact ? 9 : 14),
        // As many promises as the height holds: four on most phones, five
        // on the tallest, fewer on a small one, one more when the trial
        // switch takes no room.
        _Benefits(
            compact: compact,
            rows: (box.maxHeight < 610
                    ? 2
                    : box.maxHeight < 700
                        ? 3
                        : box.maxHeight < 800
                            ? 4
                            : 5) +
                (access.canTrial && access.plainPlan != null ? 0 : 1)),
        const Spacer(),
        SizedBox(height: gap),
        _PlanCard(
            loading: access.loading && !access.plansReady,
            plan: plan,
            trialDays: withTrial ? days : null,
            switchDays: days,
            showSwitch: access.canTrial && access.plainPlan != null,
            onTrial: access.busy
                ? null
                : (on) {
                    HolyHaptics.chipSelect();
                    setState(() => _trialOn = on);
                  }),
        SizedBox(height: gap),
        OnboardingButton(
            label: plan == null
                ? (access.loading ? 'Loading…' : 'Try again')
                : terms.cta,
            semanticLabel: plan == null ? null : terms.semanticCta,
            busy: access.busy,
            enabled: plan != null || !access.loading,
            token: withTrial,
            onPressed: plan == null
                ? () => ref.read(accessProvider.notifier).load()
                : () => _buy(plan)),
        const SizedBox(height: 7),
        // The two things that let her say yes.
        Text(
            plan != null && withTrial
                ? 'No payment due today. Cancel anytime.'
                : 'Cancel anytime in your App Store settings.',
            textAlign: TextAlign.center,
            style: HolyTypography.label.copyWith(
                fontSize: 12.5, color: OnboardingTokens.textSecondary)),
        AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: access.error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Semantics(
                        liveRegion: true,
                        child: Text(access.error!,
                            textAlign: TextAlign.center,
                            style: HolyTypography.caption.copyWith(
                                color: OnboardingMoods.rose.accent))))),
        const SizedBox(height: 8),
        Text(terms.disclosure,
            textAlign: TextAlign.center,
            style: HolyTypography.caption.copyWith(
                fontSize: 10.5,
                height: 1.35,
                color: OnboardingTokens.textTertiary)),
        const SizedBox(height: 2),
        _Links(
            busy: access.busy,
            onRestore: _restore,
            onSignOut: accountActions ? _signOut : null,
            onDelete: accountActions ? _account : null),
      ]);
    });
  }
}

/// What she is agreeing to, in the words Apple asks for.
class _Terms {
  final String? price;
  final int? trialDays;
  const _Terms({required this.price, required this.trialDays});

  String get cta => trialDays != null
      ? 'Start my $trialDays days free'
      : 'Subscribe for ${price ?? 'one price'} a year';

  String get semanticCta => trialDays != null
      ? 'Start $trialDays days free, then ${price ?? 'the yearly price'} a year'
      : 'Subscribe for ${price ?? 'the yearly price'} a year';

  String get disclosure {
    final p = price ?? 'The yearly price';
    final charge = trialDays != null
        ? '$trialDays days free, then $p per year.'
        : '$p per year, charged when you confirm.';
    final deadline = trialDays != null
        ? 'the trial or current period ends'
        : 'the current period ends';
    return '$charge Renews automatically each year unless cancelled at least '
        '24 hours before $deadline. Cancel any time in your App Store '
        'account settings.';
  }
}

/// The photograph of her first morning, her name in rose gold over it, and
/// the medallion a full year earns turning at its edge.
class _Hero extends ConsumerWidget {
  final double height;
  final bool onboarding;
  const _Hero({required this.height, required this.onboarding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(repositoryProvider.select((s) => s.profile.name));
    final first = name.trim().split(RegExp(r'\s+')).first;
    final radius = BorderRadius.circular(28);
    final coin = (height * .42).clamp(46.0, 84.0);
    // A slim band on a small phone keeps only the wordmark.
    final slim = height < 96;
    return SizedBox(
        height: height,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
              child: DecoratedBox(
                  decoration: BoxDecoration(borderRadius: radius, boxShadow: [
                    BoxShadow(
                        color: OnboardingTokens.plum.withValues(alpha: .22),
                        blurRadius: 30,
                        offset: const Offset(0, 14)),
                  ]),
                  child: ClipRRect(
                      borderRadius: radius,
                      child: Stack(fit: StackFit.expand, children: [
                        BundledArt(
                            asset: HolyArtCatalog.assetForDay(1),
                            alignment: const Alignment(-.4, .25),
                            fallback:
                                const ColoredBox(color: HolyTheme.photoShade)),
                        DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                              HolyTheme.photoShade.withValues(alpha: .05),
                              HolyTheme.photoShade.withValues(alpha: .5),
                            ]))),
                        DecoratedBox(
                            decoration: BoxDecoration(
                                borderRadius: radius,
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: .6),
                                    width: 1.2))),
                        Align(
                            alignment: const Alignment(0, .5),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (first.isNotEmpty && !slim)
                                    Text('FOR ${first.toUpperCase()}',
                                        textScaler: TextScaler.noScaling,
                                        style: HolyTypography.eyebrow.copyWith(
                                            fontSize: 10.5,
                                            color: HolyTheme.photoInk
                                                .withValues(alpha: .9))),
                                  TextHalo(
                                      text: TextHalo.wordmark(),
                                      strength: .7,
                                      style: HolyTypography.wordmark.copyWith(
                                          fontSize: slim
                                              ? 32
                                              : (height * .26)
                                                  .clamp(30.0, 48.0))),
                                  if (!slim)
                                    Text('MEMBERSHIP',
                                        textScaler: TextScaler.noScaling,
                                        style: HolyTypography.eyebrow.copyWith(
                                            fontSize: 10,
                                            letterSpacing: 3,
                                            color: const Color(0xFFF6D9C6))),
                                ])),
                      ])))),
          // A year of mornings, in her hand.
          Positioned(
              right: 16,
              bottom: -coin * .42,
              child: Semantics(
                  label: 'The A Year with God medallion',
                  child:
                      Coin3D(badgeId: 'days-365', earned: true, size: coin))),
        ]));
  }
}

class _Headline extends StatelessWidget {
  final bool compact;
  const _Headline({required this.compact});

  @override
  Widget build(BuildContext context) {
    final style = HolyTypography.title.copyWith(
        fontSize: compact ? 26 : 30, height: 1.04, color: OnboardingTokens.ink);
    return Semantics(
        header: true,
        label: 'Your year with God begins this morning.',
        excludeSemantics: true,
        child: Column(children: [
          Text('Your year with God', textAlign: TextAlign.center, style: style),
          GradientFill(
              colors: RoseGold.ink,
              child: Text('begins this morning.',
                  textAlign: TextAlign.center,
                  style: style.copyWith(fontStyle: FontStyle.italic))),
        ]));
  }
}

/// What membership gives, in four plain lines; one is shaped by what she
/// told us her heart needs.
class _Benefits extends ConsumerWidget {
  final bool compact;

  /// How many of the five to show.
  final int rows;
  const _Benefits({required this.compact, required this.rows});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hearts =
        ref.watch(repositoryProvider.select((s) => s.profile.hearts));
    final heart = labelFor(heartChoices, normalizedHearts(hearts).firstOrNull)
            ?.toLowerCase() ??
        'peace';
    // In order of what matters most when room is short: the voice that
    // reads to her, her own heart, the daily lesson, the medallions, and
    // the themes and icons that make it hers.
    final all = [
      ('🌅', 'A new lesson every morning, all year'),
      ('🎧', 'Read aloud, with soft music beneath'),
      ('💗', 'Written for a heart that needs $heart'),
      ('🏅', 'Medallions to keep as your walk grows'),
      ('🎨', 'Themes and app icons to make it yours'),
    ];
    const priority = [1, 2, 0, 3, 4];
    final keep = priority.take(this.rows.clamp(1, all.length)).toSet();
    final rows = [
      for (var i = 0; i < all.length; i++)
        if (keep.contains(i)) all[i]
    ];
    final glow = OnboardingMoods.rose.glow;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (emoji, text) in rows)
            Padding(
                padding: EdgeInsets.only(bottom: compact ? 5 : 8),
                child: Row(children: [
                  Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                                color: glow.withValues(alpha: .35),
                                blurRadius: 10)
                          ]),
                      child: Text(emoji,
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(fontSize: 14, height: 1))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(text,
                          style: HolyTypography.ui.copyWith(
                              fontSize: compact ? 14.5 : 15.5,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                              color: OnboardingTokens.ink))),
                ])),
        ]));
  }
}

/// The free week's switch and the price, in one clean card. The yearly
/// price is the largest figure on it, as Apple asks.
class _PlanCard extends StatelessWidget {
  final bool loading, showSwitch;
  final MemberPlan? plan;

  /// Days free with the chosen plan; null when it has no trial.
  final int? trialDays;
  final int switchDays;
  final ValueChanged<bool>? onTrial;
  const _PlanCard(
      {required this.loading,
      required this.plan,
      required this.trialDays,
      required this.switchDays,
      required this.showSwitch,
      required this.onTrial});

  @override
  Widget build(BuildContext context) {
    final accent = OnboardingMoods.rose.accent;
    final price = plan?.price;
    final month = plan?.perMonth;
    final under = price == null
        ? (loading
            ? 'Getting the price from the App Store…'
            : 'The price could not load. Try again below.')
        : trialDays != null
            ? '$trialDays days free, then billed yearly'
            : 'Billed once a year';
    return DecoratedBox(
        decoration: OnboardingTokens.panel(radius: 24),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (showSwitch) ...[
                _TrialSwitch(
                    on: trialDays != null,
                    days: switchDays,
                    accent: accent,
                    onChanged: onTrial),
                const SizedBox(height: 12),
              ],
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                const SizedBox(width: 4),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(price ?? '—',
                                style: HolyTypography.numeral.copyWith(
                                    fontSize: 36, color: OnboardingTokens.ink)),
                            const SizedBox(width: 6),
                            Text('/ year',
                                style: HolyTypography.ui.copyWith(
                                    fontSize: 15,
                                    color: OnboardingTokens.textSecondary)),
                          ]),
                      const SizedBox(height: 2),
                      Text(under,
                          style: HolyTypography.caption.copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: OnboardingTokens.textSecondary)),
                    ])),
                if (month != null)
                  DecoratedBox(
                      decoration: ShapeDecoration(
                          color: accent.withValues(alpha: .09),
                          shape: StadiumBorder(
                              side: BorderSide(
                                  color: accent.withValues(alpha: .3)))),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 6),
                          child: Text('$month / month',
                              style: HolyTypography.label
                                  .copyWith(fontSize: 12.5, color: accent)))),
              ]),
            ])));
  }
}

/// "Enable 7-day free trial", as an on and off row.
class _TrialSwitch extends StatelessWidget {
  final bool on;
  final int days;
  final Color accent;
  final ValueChanged<bool>? onChanged;
  const _TrialSwitch(
      {required this.on,
      required this.days,
      required this.accent,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduced ? Duration.zero : const Duration(milliseconds: 220);
    final title = on ? 'Free trial enabled' : 'Enable $days-day free trial';
    return Pressable(
        key: const ValueKey('paywall-trial-switch'),
        onPressed: onChanged == null ? null : () => onChanged!(!on),
        haptic: false,
        selected: on,
        semanticLabel: title,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
            duration: duration,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: on
                    ? accent.withValues(alpha: .08)
                    : OnboardingTokens.plum.withValues(alpha: .04),
                border: Border.all(
                    color: on
                        ? accent.withValues(alpha: .45)
                        : OnboardingTokens.hairline)),
            child: Row(children: [
              Text(on ? '🎁' : '🗓️',
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(fontSize: 16, height: 1)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: HolyTypography.ui.copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: OnboardingTokens.ink))),
              AnimatedContainer(
                  duration: duration,
                  width: 46,
                  height: 28,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: on
                          ? LinearGradient(colors: [
                              accent,
                              Color.lerp(accent, OnboardingTokens.plum, .35)!
                            ])
                          : null,
                      color: on
                          ? null
                          : OnboardingTokens.plum.withValues(alpha: .16)),
                  child: AnimatedAlign(
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      alignment:
                          on ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                    color: Color(0x33000000), blurRadius: 4)
                              ])))),
            ])));
  }
}

class _Links extends StatelessWidget {
  final bool busy;
  final VoidCallback onRestore;
  final VoidCallback? onSignOut, onDelete;
  const _Links(
      {required this.busy,
      required this.onRestore,
      required this.onSignOut,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final style = HolyTypography.caption
        .copyWith(fontSize: 12, fontWeight: FontWeight.w700);
    Widget link(String label, VoidCallback? onPressed) => TextAction(label,
        color: OnboardingTokens.textSecondary,
        style: style,
        onPressed: onPressed);
    Widget dot() => Text('·',
        style: HolyTypography.caption
            .copyWith(color: OnboardingTokens.textTertiary));
    final account = [
      if (onSignOut != null) link('Sign out', busy ? null : onSignOut),
      if (onSignOut != null && onDelete != null) dot(),
      if (onDelete != null) link('Delete account', busy ? null : onDelete),
    ];
    return FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          link('Restore purchases', busy ? null : onRestore),
          dot(),
          link('Terms', () => openLegal(context, 'Terms of Use', 'terms')),
          dot(),
          link('Privacy', () => openLegal(context, 'Privacy', 'privacy')),
          if (account.isNotEmpty) ...[dot(), ...account],
        ]));
  }
}

/// After the purchase: a chime, her first medallion spinning in, and the
/// way on.
class _Welcome extends StatelessWidget {
  final bool trial, lifetime, firstDay;
  final VoidCallback onContinue;
  const _Welcome(
      {required this.trial,
      required this.lifetime,
      required this.firstDay,
      required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final glow = OnboardingMoods.rose.glow;
    final line = lifetime
        ? 'Every lesson is yours, for life.'
        : trial
            ? 'Your free week has begun. Day 1 is waiting for you.'
            : 'Your walk is open. Thank you for walking with us.';
    return Column(children: [
      const Spacer(),
      Stack(alignment: Alignment.center, children: [
        Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  glow.withValues(alpha: .55),
                  glow.withValues(alpha: 0)
                ]))),
        const Coin3D(badgeId: 'days-1', earned: true, size: 160, spinIn: true),
      ]),
      const SizedBox(height: 18),
      Rise(
          delay: const Duration(milliseconds: 700),
          child: Column(children: [
            Semantics(
                header: true,
                liveRegion: true,
                child: Text('You’re in 🤍',
                    textAlign: TextAlign.center,
                    style: HolyTypography.title
                        .copyWith(fontSize: 38, color: OnboardingTokens.ink))),
            const SizedBox(height: 8),
            Text(line,
                textAlign: TextAlign.center,
                style: HolyTypography.ui.copyWith(
                    fontSize: 16, color: OnboardingTokens.textSecondary)),
          ])),
      const Spacer(),
      OnboardingButton(
          label: firstDay ? 'Begin Day 1' : 'Continue', onPressed: onContinue),
      const SizedBox(height: 12),
    ]);
  }
}
