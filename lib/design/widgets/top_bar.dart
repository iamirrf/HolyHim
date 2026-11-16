// Ported from Cognein AppTopBar; scroll-driven material added for HolyHim.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'backdrop_host.dart';
import '../themes.dart';
import 'glass.dart';

/// The single top navigation surface used throughout the app.
///
/// The bar itself never paints an opaque Material surface. Instead, content
/// behind it remains visible. Full-width blur and edge tints are disabled;
/// glass is confined to the floating controls.
/// Screens should use `Scaffold(extendBodyBehindAppBar: true)` and reserve
/// [overlayInset] before their first non-full-bleed child.
class GlassTopBar extends StatelessWidget implements PreferredSizeWidget {
  static const double defaultMaxOpacity = 0;
  static const double defaultMaxBlurSigma = 0;
  static const double defaultFalloff = 1.2;

  /// Default alpha ramp, exposed so visual tests can pin the shared material.
  static const List<double> tintAlphas = <double>[
    0.70,
    0.58,
    0.38,
    0.16,
    0,
  ];

  /// Positions paired with [tintAlphas], from the top edge to the bottom.
  static const List<double> tintStops = <double>[0, 0.30, 0.60, 0.82, 1];

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final bool? centerTitle;
  final double? titleSpacing;
  final double? leadingWidth;
  final double toolbarHeight;
  final PreferredSizeWidget? bottom;
  final Color? foregroundColor;
  final Color? tintColor;
  final double maxOpacity;
  final double maxBlurSigma;
  final double falloff;
  final double scrollOffset;
  final Widget? trailing;

  const GlassTopBar({
    super.key,
    this.title,
    this.leading,
    this.trailing,
    this.scrollOffset = 0,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.centerTitle,
    this.titleSpacing,
    this.leadingWidth,
    this.toolbarHeight = kToolbarHeight,
    this.bottom,
    this.foregroundColor,
    this.tintColor,
    this.maxOpacity = defaultMaxOpacity,
    this.maxBlurSigma = defaultMaxBlurSigma,
    this.falloff = defaultFalloff,
  })  : assert(maxOpacity >= 0 && maxOpacity <= 1),
        assert(maxBlurSigma >= 0),
        assert(falloff > 0),
        assert(toolbarHeight >= 0);

  /// Top padding for standard content that starts below an overlaid bar.
  ///
  /// Call this from inside the Scaffold body — which is where every caller
  /// sits. A Scaffold with `extendBodyBehindAppBar: true` has already resolved
  /// the bar's full laid-out height (status bar + toolbar + any [bottom]) into
  /// the body's `padding.top`, so that value *is* the inset.
  ///
  /// Deriving it independently, as a status bar plus a nominal toolbar height,
  /// counted the toolbar twice: Scaffold's inflated `padding.top` already
  /// included it. That left 56px of dead space at the top of every screen using
  /// this pattern.
  ///
  /// It stays correct in the neighbouring cases too. Inside a [SafeArea] that
  /// has already consumed the inset it returns 0, because `removePadding`
  /// zeroes what it consumed. Without `extendBodyBehindAppBar` it also returns
  /// 0, because Scaffold lays the body out below the bar itself. With no app
  /// bar at all it returns the status bar, which is what content needs to clear.
  static double overlayInset(BuildContext context) =>
      MediaQuery.paddingOf(context).top;

  /// Resolves readable chrome for the material produced by [tintColor].
  static Color resolveForegroundColor(
    BuildContext context, {
    Color? tintColor,
    double maxOpacity = defaultMaxOpacity,
  }) {
    final theme = Theme.of(context);
    if (maxOpacity == 0) return theme.colorScheme.onSurface;
    final tint = tintColor ?? theme.scaffoldBackgroundColor;
    final materialSample = Color.alphaBlend(
      tint.withValues(alpha: tint.a * maxOpacity),
      theme.scaffoldBackgroundColor,
    );
    final materialBrightness =
        ThemeData.estimateBrightnessForColor(materialSample);
    return materialBrightness == Brightness.dark ? Colors.white : Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    // Falling straight back to `scaffoldBackgroundColor` was the bug behind the
    // white top bar: in light mode that is #F5F5F5, painted at 70% over
    // whatever field the screen actually has. Inside a [BackdropHost] the field
    // publishes its own colour, so prefer that.
    final hostTint = tintColor == null ? BackdropHost.tintOf(context) : null;
    final materialTint = tintColor ??
        hostTint?.value ??
        Theme.of(context).scaffoldBackgroundColor;
    final resolvedForeground = foregroundColor ??
        resolveForegroundColor(
          context,
          tintColor: materialTint,
          maxOpacity: maxOpacity,
        );

    final bar = Stack(
      fit: StackFit.expand,
      children: [
        // Empty chrome still owns its hit-test area; page controls scrolling
        // underneath cannot be activated through the transparent material.
        const Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            child: SizedBox.expand(),
          ),
        ),
        AppBar(
          forceMaterialTransparency: true,
          backgroundColor: Colors.transparent,
          foregroundColor: resolvedForeground,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: _overlayStyleFor(resolvedForeground),
          automaticallyImplyLeading: automaticallyImplyLeading,
          leading: leading ??
              (automaticallyImplyLeading && Navigator.of(context).canPop()
                  ? Padding(
                      padding:
                          const EdgeInsets.only(left: 12, top: 6, bottom: 6),
                      child: GlassCircle(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onPressed: () => Navigator.of(context).maybePop(),
                          label: 'Back',
                          size: 40))
                  : null),
          leadingWidth: leadingWidth,
          title: title,
          titleSpacing: titleSpacing,
          centerTitle: centerTitle,
          toolbarHeight: toolbarHeight,
          bottom: bottom,
          actions: trailing != null
              ? [trailing!, const SizedBox(width: 20)]
              : actions,
        ),
      ],
    );

    // Only the material listens to the host, and `bar` is hoisted out of the
    // builder: a swipe repaints the tint strip, not the header's contents.
    if (hostTint != null) {
      return ValueListenableBuilder<Color>(
        valueListenable: hostTint,
        child: bar,
        builder: (context, tint, child) => HolyProgressiveMaterial(
          tintColor: tint,
          maxOpacity: maxOpacity * (scrollOffset / 64).clamp(0.0, 1.0),
          maxBlurSigma: HolyThemeScope.opaqueOf(context)
              ? 0
              : maxBlurSigma * (scrollOffset / 64).clamp(0.0, 1.0),
          falloff: falloff,
          child: child,
        ),
      );
    }

    return HolyProgressiveMaterial(
      tintColor: materialTint,
      maxOpacity: maxOpacity * (scrollOffset / 64).clamp(0.0, 1.0),
      maxBlurSigma: HolyThemeScope.opaqueOf(context)
          ? 0
          : maxBlurSigma * (scrollOffset / 64).clamp(0.0, 1.0),
      falloff: falloff,
      child: bar,
    );
  }

  static SystemUiOverlayStyle _overlayStyleFor(Color foreground) {
    final usesDarkIcons =
        ThemeData.estimateBrightnessForColor(foreground) == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: usesDarkIcons ? Brightness.light : Brightness.dark,
      statusBarIconBrightness:
          usesDarkIcons ? Brightness.dark : Brightness.light,
      systemStatusBarContrastEnforced: false,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        toolbarHeight + (bottom?.preferredSize.height ?? 0),
      );
}

/// A reusable progressive navigation material for overlaid top and bottom bars.
///
/// The effect is pointer-transparent; callers put their interactive chrome in
/// [child]. A top bar uses [ProgressiveBlurDirection.topToBottom], while a
/// bottom bar mirrors it with [ProgressiveBlurDirection.bottomToTop].
class HolyProgressiveMaterial extends StatelessWidget {
  final Color tintColor;
  final ProgressiveBlurDirection direction;
  final double maxOpacity;
  final double maxBlurSigma;
  final double falloff;
  final Widget? child;

  const HolyProgressiveMaterial({
    super.key,
    required this.tintColor,
    this.direction = ProgressiveBlurDirection.topToBottom,
    this.maxOpacity = GlassTopBar.defaultMaxOpacity,
    this.maxBlurSigma = GlassTopBar.defaultMaxBlurSigma,
    this.falloff = GlassTopBar.defaultFalloff,
    this.child,
  })  : assert(maxOpacity >= 0 && maxOpacity <= 1),
        assert(maxBlurSigma >= 0),
        assert(falloff > 0);

  const HolyProgressiveMaterial.bottom({
    super.key,
    required this.tintColor,
    this.maxOpacity = GlassTopBar.defaultMaxOpacity,
    this.maxBlurSigma = GlassTopBar.defaultMaxBlurSigma,
    this.falloff = GlassTopBar.defaultFalloff,
    this.child,
  })  : direction = ProgressiveBlurDirection.bottomToTop,
        assert(maxOpacity >= 0 && maxOpacity <= 1),
        assert(maxBlurSigma >= 0),
        assert(falloff > 0);

  bool get _isBottom => direction == ProgressiveBlurDirection.bottomToTop;

  @override
  Widget build(BuildContext context) {
    if (maxOpacity == 0 && maxBlurSigma == 0) {
      return child ?? const SizedBox.shrink();
    }
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          // The scrim is chrome, not content: on a desktop window it runs to
          // both edges even though the bar's own controls sit in the column.
          child: SizedBox.expand(
            child: IgnorePointer(
              child: ClipRect(
                child: RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ProgressiveBlurLayer(
                        maxSigma: maxBlurSigma,
                        falloff: falloff,
                        direction: direction,
                      ),
                      _TintGradient(
                        color: tintColor,
                        maxOpacity: maxOpacity,
                        reverse: _isBottom,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}

class _ProgressiveBlurLayer extends StatelessWidget {
  final double maxSigma;
  final double falloff;
  final ProgressiveBlurDirection direction;

  const _ProgressiveBlurLayer({
    required this.maxSigma,
    required this.falloff,
    required this.direction,
  });

  @override
  Widget build(BuildContext context) {
    if (maxSigma == 0) return const SizedBox.expand();

    if (ui.ImageFilter.isShaderFilterSupported) {
      return ProgressiveBlur(
        maxSigma: maxSigma,
        direction: direction,
        falloff: falloff,
      );
    }

    return _BandedProgressiveBlur(
      maxSigma: maxSigma,
      falloff: falloff,
      reverse: direction == ProgressiveBlurDirection.bottomToTop,
    );
  }
}

/// A portable approximation for renderers without shader image filters.
class _BandedProgressiveBlur extends StatelessWidget {
  final double maxSigma;
  final double falloff;
  final bool reverse;

  const _BandedProgressiveBlur({
    required this.maxSigma,
    required this.falloff,
    required this.reverse,
  });

  // Narrower bands near the transparent edge make the final transition to a
  // sharp backdrop effectively invisible without requiring a shader mask.
  static const List<double> _edges = <double>[
    0,
    0.12,
    0.25,
    0.40,
    0.55,
    0.68,
    0.78,
    0.86,
    0.92,
    0.97,
    1,
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < _edges.length - 1; index++)
          _buildBand(index),
      ],
    );
  }

  Widget _buildBand(int index) {
    final start = _edges[index];
    final end = _edges[index + 1];
    final strength = math.pow(reverse ? end : 1 - start, falloff).toDouble();
    final sigma = maxSigma * strength;

    return ClipRect(
      clipper: _HorizontalBandClipper(start, end),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TintGradient extends StatelessWidget {
  final Color color;
  final double maxOpacity;
  final bool reverse;

  const _TintGradient({
    required this.color,
    required this.maxOpacity,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    final opacityScale = maxOpacity / 0.70;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: (reverse
                  ? GlassTopBar.tintAlphas.reversed
                  : GlassTopBar.tintAlphas)
              .map(
                (alpha) => color.withValues(
                  alpha: (color.a * alpha * opacityScale).clamp(0.0, 1.0),
                ),
              )
              .toList(),
          stops: GlassTopBar.tintStops,
        ),
      ),
    );
  }
}

class _HorizontalBandClipper extends CustomClipper<Rect> {
  final double startFraction;
  final double endFraction;

  const _HorizontalBandClipper(this.startFraction, this.endFraction);

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
        0,
        size.height * startFraction,
        size.width,
        size.height * endFraction,
      );

  @override
  bool shouldReclip(_HorizontalBandClipper oldClipper) {
    return oldClipper.startFraction != startFraction ||
        oldClipper.endFraction != endFraction;
  }
}
