import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../themes.dart';
import '../tokens.dart';
import '../typography.dart';
import 'paper.dart';
import 'pressable.dart';
import 'spinner.dart';

enum HolyButtonStyle {
  /// Filled ink: the one main action on a screen.
  primary,

  /// Paper with a hairline: an alternative action.
  secondary,

  /// Frosted, for a control that sits on a photograph.
  onPhoto,

  /// Solid ivory on a photograph: the main action over an image.
  photoPrimary,
}

/// The app's single button. Every full-width action uses it, so height,
/// corner, type and press physics are identical everywhere.
class HolyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final HolyButtonStyle style;
  final Widget? leading;
  final bool loading;
  final bool expand;
  final double height;
  final String? semanticLabel;
  const HolyButton(this.label,
      {super.key,
      required this.onPressed,
      this.style = HolyButtonStyle.primary,
      this.leading,
      this.loading = false,
      this.expand = true,
      this.height = 56,
      this.semanticLabel});

  const HolyButton.secondary(this.label,
      {super.key,
      required this.onPressed,
      this.leading,
      this.loading = false,
      this.expand = true,
      this.height = 56,
      this.semanticLabel})
      : style = HolyButtonStyle.secondary;

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final enabled = onPressed != null && !loading;
    final (Color fill, Color ink, BorderSide side) = switch (style) {
      HolyButtonStyle.primary => (t.primary, t.onPrimary, BorderSide.none),
      HolyButtonStyle.secondary => (
          t.surface,
          t.ink,
          BorderSide(color: t.hairline, width: 1)
        ),
      HolyButtonStyle.onPhoto => (
          Colors.transparent,
          HolyTheme.photoInk,
          BorderSide.none
        ),
      HolyButtonStyle.photoPrimary => (
          HolyTheme.photoInk,
          HolyTheme.photoShade,
          BorderSide.none
        ),
    };
    final content = SizedBox(
        height: height,
        width: expand ? double.infinity : null,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
                widthFactor: 1,
                child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: loading
                        ? HolySpinner(
                            key: const ValueKey('spinner'),
                            color: ink,
                            size: 20)
                        : Row(
                            key: const ValueKey('label'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                if (leading != null) ...[
                                  IconTheme(
                                      data: IconThemeData(color: ink, size: 20),
                                      child: leading!),
                                  const SizedBox(width: 10),
                                ],
                                Flexible(
                                    child: Text(label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: HolyTypography.button
                                            .copyWith(color: ink))),
                              ])))));
    final shape = RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(HolyRadius.button), side: side);
    final surface = style == HolyButtonStyle.onPhoto
        ? FrostedGlass(radius: HolyRadius.button, onPhoto: true, child: content)
        : DecoratedBox(
            decoration: ShapeDecoration(
                color: fill,
                shape: shape,
                shadows: style == HolyButtonStyle.primary && !t.isDark
                    ? [
                        BoxShadow(
                            color: t.primary.withValues(alpha: .22),
                            blurRadius: 18,
                            offset: const Offset(0, 8))
                      ]
                    : null),
            child: content);
    return Semantics(
        label: semanticLabel ?? label,
        button: true,
        enabled: enabled,
        excludeSemantics: true,
        child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: onPressed == null && !loading ? .45 : 1,
            child: Pressable(
                onPressed: enabled ? onPressed : null,
                borderRadius: BorderRadius.circular(HolyRadius.button),
                child: surface)));
  }
}

/// "Continue with Apple", drawn to Apple's guidance: black on light
/// backgrounds, white on dark, the Apple logo at the label's cap height.
class AppleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final bool white;
  const AppleButton(
      {super.key, required this.onPressed, this.loading = false, this.white = false});
  @override
  Widget build(BuildContext context) {
    final fill = white ? Colors.white : Colors.black;
    final ink = white ? Colors.black : Colors.white;
    return Semantics(
        label: 'Continue with Apple',
        button: true,
        excludeSemantics: true,
        child: Pressable(
            onPressed: loading ? null : onPressed,
            borderRadius: BorderRadius.circular(HolyRadius.button),
            child: DecoratedBox(
                decoration: ShapeDecoration(
                    color: fill,
                    shape: RoundedSuperellipseBorder(
                        borderRadius:
                            BorderRadius.circular(HolyRadius.button))),
                child: SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: Center(
                        child: loading
                            ? HolySpinner(color: ink, size: 20)
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.apple, color: ink, size: 22),
                                const SizedBox(width: 8),
                                Text('Continue with Apple',
                                    style: HolyTypography.button.copyWith(
                                        color: ink, fontSize: 17)),
                              ]))))));
  }
}

/// A circular icon control. On paper it is a soft surface; on a photograph
/// it is frosted.
class IconControl extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String label;
  final bool onPhoto;
  final double size;
  final Color? color;
  const IconControl(
      {super.key,
      required this.icon,
      required this.onPressed,
      required this.label,
      this.onPhoto = false,
      this.size = 44,
      this.color});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final ink = color ?? (onPhoto ? HolyTheme.photoInk : t.ink);
    final glyph = SizedBox.square(
        dimension: size,
        child: Icon(icon, size: size * .45, color: ink));
    return Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Pressable(
            onPressed: onPressed,
            semanticLabel: label,
            borderRadius: BorderRadius.circular(size),
            child: onPhoto
                ? FrostedGlass(onPhoto: true, child: glyph)
                : DecoratedBox(
                    decoration: ShapeDecoration(
                        color: t.surface,
                        shape: CircleBorder(
                            side: BorderSide(color: t.hairline, width: .8))),
                    child: glyph)));
  }
}

/// An inline text action ("Use email instead", "Restore purchase").
class TextAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool underline;
  final TextStyle? style;
  const TextAction(this.label,
      {super.key,
      required this.onPressed,
      this.color,
      this.underline = false,
      this.style});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final ink = color ?? t.accent;
    return Pressable(
        onPressed: onPressed,
        pressedScale: .97,
        semanticLabel: label,
        child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: (style ?? HolyTypography.label).copyWith(
                        color: ink,
                        decoration: underline ? TextDecoration.underline : null,
                        decorationColor: ink.withValues(alpha: .4))))));
  }
}

/// The back chevron used on composed sub-screens.
class BackControl extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool onPhoto;
  const BackControl({super.key, this.onPressed, this.onPhoto = false});
  @override
  Widget build(BuildContext context) => IconControl(
      icon: CupertinoIcons.chevron_left,
      label: 'Back',
      onPhoto: onPhoto,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop());
}
