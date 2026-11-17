// Ported from Cognein; see store/v2-design-ports.json.
import 'package:flutter/material.dart';
import '../../../design/design.dart';
import 'onboarding_tokens.dart';

/// A tappable answer on white glass.
///
/// A flat translucent fill, not a blur per card: the field behind is already
/// soft, so a blur on every card would cost a full render pass each for
/// almost nothing the eye can see.
///
/// Choosing it moves the fill, the border, the emoji's well and a drawn
/// check together, so the change reads as one gesture.
class GlassOptionCard extends StatelessWidget {
  final String label;
  final String? detail, emoji;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  /// Tightens the card so a long step still fits a short screen.
  final bool compact;

  /// Half-width cards in a two-column grid: the label may wrap and the check
  /// moves to the corner.
  final bool tile;
  const GlassOptionCard(
      {super.key,
      required this.label,
      required this.selected,
      required this.accent,
      required this.onTap,
      this.detail,
      this.emoji,
      this.compact = false,
      this.tile = false});

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduced ? Duration.zero : const Duration(milliseconds: 260);
    final radius = BorderRadius.circular(OnboardingTokens.cardRadius);
    final text = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: tile ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: HolyTypography.ui.copyWith(
                  fontSize: 15.5,
                  height: 1.24,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: OnboardingTokens.textPrimary)),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(detail!,
                maxLines: tile ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: HolyTypography.caption.copyWith(
                    fontSize: 12.5,
                    height: 1.28,
                    color: OnboardingTokens.textSecondary)),
          ],
        ]);
    final well = compact ? 32.0 : 36.0;
    final glyph = emoji == null
        ? null
        : AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            width: well,
            height: well,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? accent.withValues(alpha: .14)
                    : OnboardingTokens.plum.withValues(alpha: .05),
                border: Border.all(
                    color: selected
                        ? accent.withValues(alpha: .35)
                        : OnboardingTokens.white)),
            child: AnimatedScale(
                scale: selected ? 1.14 : 1,
                duration:
                    reduced ? Duration.zero : const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                child: Text(emoji!,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(fontSize: compact ? 16 : 18, height: 1))));
    final check = HolyCheck(
        checked: selected,
        size: tile ? 18 : 22,
        color: accent,
        ink: OnboardingTokens.onPlum);
    return Pressable(
        selected: selected,
        onPressed: onTap,
        pressedScale: .975,
        haptic: false,
        semanticLabel: detail == null ? label : '$label. $detail',
        borderRadius: radius,
        child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            constraints: BoxConstraints(minHeight: compact ? 46 : 56),
            padding: EdgeInsets.symmetric(
                horizontal: tile ? 12 : 14, vertical: compact ? 7 : 11),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: selected
                        ? [
                            OnboardingTokens.selectedFillTop(accent),
                            OnboardingTokens.selectedFillBottom(accent)
                          ]
                        : [
                            OnboardingTokens.cardFillTop,
                            OnboardingTokens.cardFillBottom
                          ]),
                borderRadius: radius,
                border: Border.all(
                    color: selected
                        ? OnboardingTokens.selectedBorder(accent)
                        : OnboardingTokens.cardBorder,
                    width: selected ? 1.5 : 1),
                boxShadow: selected
                    ? OnboardingTokens.selectedShadow(accent)
                    : OnboardingTokens.cardShadow),
            child: Row(children: [
              if (glyph != null) ...[glyph, SizedBox(width: tile ? 10 : 12)],
              Expanded(child: text),
              SizedBox(width: tile ? 6 : 10),
              check,
            ])));
  }
}
