import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../design/design.dart';
import '../../domain/access.dart';
import '../../services/billing.dart';
import '../common.dart';

/// The offer: Days 1 to 7 free to read and keep, then one price, once. Plain and honest: no
/// countdowns, no invented discounts, no testimonials.
class OfferScreen extends ConsumerStatefulWidget {
  /// Shown at the end of onboarding, with "Start with Days 1 to 7 free".
  final bool onboarding;

  /// The locked lesson that brought her here, if any.
  final int? lockedDay;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  const OfferScreen(
      {super.key,
      this.onboarding = false,
      this.lockedDay,
      this.onContinue,
      this.onBack});
  @override
  ConsumerState<OfferScreen> createState() => _OfferScreenState();
}

class _OfferScreenState extends ConsumerState<OfferScreen> {
  bool thanked = false;

  void _leave() {
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

  Future<void> _buy() async {
    final ok = await ref.read(lifetimeProvider.notifier).purchase();
    if (ok && mounted) _celebrate();
  }

  Future<void> _restore() async {
    final ok = await ref.read(lifetimeProvider.notifier).restore();
    if (ok && mounted) _celebrate();
  }

  void _celebrate() {
    HolyHaptics.celebration();
    setState(() => thanked = true);
    Timer(const Duration(milliseconds: 1600), () {
      if (mounted) _leave();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final access = ref.watch(lifetimeProvider);
    final media = MediaQuery.of(context);
    final compact = media.size.height < 720;
    // A blank store price reads as no price, never "Unlock for life · ".
    final storePrice = access.product?.priceString.trim() ?? '';
    final String? price = storePrice.isEmpty ? null : storePrice;
    final owned = access.active;
    final title = owned || thanked
        ? 'Every day is open'
        : widget.onboarding
            ? 'Days 1 to $freeDays are free'
            : 'Keep walking past Day $freeDays';
    final subtitle = owned || thanked
        ? 'Thank you. Every lesson is yours, for life.'
        : widget.onboarding
            ? 'Read and keep them on us. Unlock lifetime access whenever you are ready.'
            : 'Days 1 to $freeDays were free. One payment opens every lesson, for life.';
    final photoHeight = media.size.height * (compact ? .27 : .36);

    return Scaffold(
        backgroundColor: t.paper,
        body: Stack(children: [
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: photoHeight + HolyRadius.sheet,
              child: const PhotoStage(
                  images: ['assets/art/library/sky-rays.webp'],
                  expose: true,
                  alignment: Alignment(0, .25),
                  topVeil: .3,
                  bottomVeil: .1,
                  child: LightMotes(count: 14))),
          Positioned(
              top: media.padding.top + 6,
              left: HolySpace.gutter - 6,
              right: HolySpace.gutter - 6,
              child: Row(children: [
                if (widget.onBack != null || !widget.onboarding)
                  IconControl(
                      icon: widget.onboarding
                          ? CupertinoIcons.chevron_left
                          : CupertinoIcons.xmark,
                      label: widget.onboarding ? 'Back' : 'Close',
                      onPhoto: true,
                      onPressed: widget.onBack ??
                          () => context.canPop()
                              ? context.pop()
                              : context.go('/')),
                const Spacer(),
              ])),
          Positioned(
              top: photoHeight * .38,
              left: 0,
              right: 0,
              child: const Center(
                  child: Wordmark(size: 44, color: HolyTheme.photoInk))),
          Positioned.fill(
              top: photoHeight,
              child: DecoratedBox(
                  decoration: ShapeDecoration(
                      color: t.paper,
                      shape: const RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(HolyRadius.sheet))),
                      shadows: HolyDepth.paper(t, lift: 1.4)),
                  child: FitColumn(
                      padding: EdgeInsets.fromLTRB(
                          HolySpace.gutter,
                          compact ? 22 : 30,
                          HolySpace.gutter,
                          media.padding.bottom + 8),
                      children: [
                        Semantics(
                            header: true,
                            child: Text(title,
                                style: HolyTypography.title.copyWith(
                                    color: t.ink,
                                    fontSize: compact ? 30 : 34))),
                        const SizedBox(height: 6),
                        Text(subtitle,
                            style: HolyTypography.body
                                .copyWith(color: t.muted)),
                        SizedBox(height: compact ? 16 : 24),
                        const _Value(
                            icon: CupertinoIcons.book,
                            text: 'Every lesson, a fresh word every morning, for life'),
                        const _Value(
                            icon: CupertinoIcons.heart,
                            text: 'One price, paid once. No subscription.'),
                        const _Value(
                            icon: CupertinoIcons.bell,
                            text:
                                'Reminders, widgets and saved verses stay free'),
                        const Spacer(),
                        SizedBox(height: compact ? 10 : 16),
                        AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: owned || thanked
                                ? HolyButton('Continue',
                                    key: const ValueKey('continue'),
                                    leading: const Icon(
                                        CupertinoIcons.checkmark_alt),
                                    onPressed: _leave)
                                : HolyButton(
                                    price == null
                                        ? 'Unlock for life'
                                        : 'Unlock for life · $price',
                                    key: const ValueKey('buy'),
                                    semanticLabel: price == null
                                        ? 'Unlock for life'
                                        : 'Unlock for life for $price, one time',
                                    loading: access.busy ||
                                        (access.loading && price == null),
                                    onPressed:
                                        access.product == null ? null : _buy)),
                        if (!(owned || thanked)) ...[
                          const SizedBox(height: 10),
                          HolyButton.secondary(
                              widget.onboarding
                                  ? 'Start with Days 1 to $freeDays free'
                                  : 'Not now',
                              onPressed: access.busy ? null : _leave),
                        ],
                        AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            child: access.error == null || owned || thanked
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Semantics(
                                        liveRegion: true,
                                        child: Row(children: [
                                          Expanded(
                                              child: Text(access.error!,
                                                  style: HolyTypography.caption
                                                      .copyWith(
                                                          color: t.accent))),
                                          if (access.product == null)
                                            TextAction('Try again',
                                                onPressed: () => ref
                                                    .read(lifetimeProvider
                                                        .notifier)
                                                    .load()),
                                        ])))),
                        const SizedBox(height: 4),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          TextAction('Restore purchase',
                              color: t.muted,
                              style: HolyTypography.caption
                                  .copyWith(fontWeight: FontWeight.w700),
                              onPressed: access.busy ? null : _restore),
                          Text('·',
                              style: HolyTypography.caption
                                  .copyWith(color: t.muted)),
                          TextAction('Terms',
                              color: t.muted,
                              style: HolyTypography.caption
                                  .copyWith(fontWeight: FontWeight.w700),
                              onPressed: () =>
                                  openLegal(context, 'Terms of Use', 'terms')),
                          Text('·',
                              style: HolyTypography.caption
                                  .copyWith(color: t.muted)),
                          TextAction('Privacy',
                              color: t.muted,
                              style: HolyTypography.caption
                                  .copyWith(fontWeight: FontWeight.w700),
                              onPressed: () =>
                                  openLegal(context, 'Privacy', 'privacy')),
                        ]),
                      ]))),
        ]));
  }
}

class _Value extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Value({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.sizeOf(context).height < 740 ? 10 : 14),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: ShapeDecoration(
                  color: Color.alphaBlend(
                      t.gold.withValues(alpha: .16), t.surface),
                  shape: const CircleBorder()),
              child: Icon(icon, size: 18, color: t.accent)),
          const SizedBox(width: 14),
          Expanded(
              child: Text(text,
                  style: HolyTypography.ui
                      .copyWith(color: t.ink, fontWeight: FontWeight.w600))),
        ]));
  }
}
