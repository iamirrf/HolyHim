// Ported from Cognein; see store/v2-design-ports.json.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../design/design.dart';
import '../../../design/widgets/animated_mesh_background.dart';
import '../../../design/widgets/particle_field.dart';
import '../../../design/widgets/progress_dots.dart';
import '../../../design/widgets/top_bar.dart';
import '../onboarding_moods.dart';
import 'onboarding_tokens.dart';

/// The frame every step of the welcome sits in.
///
/// It owns the field, the progress dots, the pages and the button, so a step
/// only draws its own question and says whether it is answered. Steps never
/// touch the [PageController].
///
/// The field moves with the page: while a page turns, the light is blended
/// between the two steps' moods by how far the turn has gone, so a step
/// change is one continuous movement of colour, not a cut.
class OnboardingScaffold extends StatefulWidget {
  final List<Widget> pages;

  /// One mood per page.
  final List<OnboardingMood> moods;
  final int currentIndex;

  /// Whether the current page's answer is complete.
  final bool canContinue;
  final String continueLabel;
  final VoidCallback onContinue;

  /// Shows a spinner in the button and holds it.
  final bool busy;

  /// Null hides the back control.
  final VoidCallback? onBack;

  /// Null hides the close control. Shown when she is retaking the welcome.
  final VoidCallback? onClose;

  /// False for steps that bring their own actions.
  final bool showContinue;

  /// A quiet second action under the button, such as "Skip".
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// A small line under the button.
  final String? microcopy;

  /// Pages that dissolve into the next one where they stand, with no travel
  /// or turn: for two steps that share one card.
  final Set<int> dissolve;

  const OnboardingScaffold(
      {super.key,
      required this.pages,
      required this.moods,
      required this.currentIndex,
      required this.canContinue,
      required this.continueLabel,
      required this.onContinue,
      this.busy = false,
      this.onBack,
      this.onClose,
      this.showContinue = true,
      this.secondaryLabel,
      this.onSecondary,
      this.microcopy,
      this.dissolve = const {}})
      : assert(pages.length == moods.length, 'Every page needs a mood');

  @override
  State<OnboardingScaffold> createState() => _OnboardingScaffoldState();
}

class _OnboardingScaffoldState extends State<OnboardingScaffold> {
  late final PageController _pages =
      PageController(initialPage: widget.currentIndex);

  /// The fractional page. A notifier, not `setState`, on purpose: it changes
  /// on every frame of a turn, and only the field needs to hear it.
  late final ValueNotifier<double> _page =
      ValueNotifier<double>(widget.currentIndex.toDouble());

  @override
  void initState() {
    super.initState();
    _pages.addListener(_onScroll);
  }

  void _onScroll() {
    if (_pages.hasClients && _pages.page != null) _page.value = _pages.page!;
  }

  @override
  void didUpdateWidget(OnboardingScaffold old) {
    super.didUpdateWidget(old);
    if (old.currentIndex == widget.currentIndex || !_pages.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context) ||
        (old.currentIndex - widget.currentIndex).abs() > 1) {
      _pages.jumpToPage(widget.currentIndex);
    } else {
      _pages.animateToPage(widget.currentIndex,
          duration: OnboardingTokens.pageTransition,
          curve: OnboardingTokens.pageCurve);
    }
  }

  @override
  void dispose() {
    _pages.removeListener(_onScroll);
    _pages.dispose();
    _page.dispose();
    super.dispose();
  }

  OnboardingMood _moodAt(double value) {
    final last = widget.moods.length - 1;
    final lower = value.floor().clamp(0, last);
    final upper = value.ceil().clamp(0, last);
    if (lower == upper) return widget.moods[lower];
    return OnboardingMood.lerp(
        widget.moods[lower], widget.moods[upper], value - lower);
  }

  @override
  Widget build(BuildContext context) {
    final mood = widget.moods[widget.currentIndex];
    final tint = mood.mesh.baseColors[0];
    final opaque = HolyThemeScope.opaqueOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
            backgroundColor: mood.mesh.baseColors[0],
            extendBodyBehindAppBar: true,
            extendBody: true,
            resizeToAvoidBottomInset: false,
            appBar: GlassTopBar(
                automaticallyImplyLeading: false,
                titleSpacing: 0,
                centerTitle: false,
                tintColor: tint,
                foregroundColor: OnboardingTokens.ink,
                maxOpacity: .86,
                maxBlurSigma: 14,
                scrollOffset: 64,
                title: _topBar(mood.accent)),
            // Always present, so the bar fades when a step brings its own
            // actions instead of vanishing mid-turn.
            bottomNavigationBar: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                child: widget.showContinue
                    ? KeyedSubtree(
                        key: const ValueKey('bar'), child: _bottomBar(tint))
                    : const SizedBox(
                        key: ValueKey('none'), width: double.infinity)),
            body: GestureDetector(
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                behavior: HitTestBehavior.opaque,
                child: Stack(fit: StackFit.expand, children: [
                  if (opaque)
                    ColoredBox(color: mood.mesh.baseColors[4])
                  else ...[
                    RepaintBoundary(
                        child: ValueListenableBuilder<double>(
                            valueListenable: _page,
                            builder: (context, value, _) =>
                                AnimatedMeshBackground(
                                    theme: _moodAt(value).mesh))),
                    // Motes of light rising through the morning.
                    IgnorePointer(
                        child: RepaintBoundary(
                            child: ValueListenableBuilder<double>(
                                valueListenable: _page,
                                builder: (context, value, _) => ParticleField(
                                    config: ParticleConfig(
                                        count: 24,
                                        color: Color.lerp(_moodAt(value).glow,
                                                Colors.white, .35)!
                                            .withValues(alpha: .62),
                                        blurSigma: 2.4))))),
                  ],
                  _SmoothInsets(
                      child: PageView(
                          controller: _pages,
                          // The button moves her on; a swipe past an
                          // unanswered question would leave the answer
                          // missing.
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                        for (var i = 0; i < widget.pages.length; i++)
                          _PageMotion(
                              controller: _pages,
                              index: i,
                              fallbackPage: widget.currentIndex,
                              dissolve: widget.dissolve,
                              child: widget.pages[i]),
                      ])),
                ]))));
  }

  Widget _topBar(Color accent) {
    Widget slot(Widget? control) => SizedBox(
        width: 44,
        child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: control ?? const SizedBox.shrink()));
    return Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: OnboardingTokens.screenPadding - 6),
        child: Row(children: [
          slot(widget.onBack == null
              ? null
              : IconControl(
                  key: const ValueKey('back'),
                  icon: CupertinoIcons.chevron_left,
                  label: 'Back',
                  size: 38,
                  color: OnboardingTokens.ink,
                  onPressed: widget.onBack)),
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ProgressDots(
                      totalSteps: widget.pages.length,
                      currentStep: widget.currentIndex,
                      accentColor: accent))),
          // Balances the back control so the dots stay centred.
          slot(widget.onClose == null
              ? null
              : IconControl(
                  key: const ValueKey('close'),
                  icon: CupertinoIcons.xmark,
                  label: 'Close',
                  size: 38,
                  color: OnboardingTokens.ink,
                  onPressed: widget.onClose)),
        ]));
  }

  Widget _bottomBar(Color tint) {
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
    final opaque = HolyThemeScope.opaqueOf(context);
    return HolyProgressiveMaterial.bottom(
        tintColor: tint,
        maxOpacity: .9,
        maxBlurSigma: opaque ? 0 : 14,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(height: typing ? 8 : 28),
          SafeArea(
              top: false,
              bottom: !typing,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _continue(),
                if (!typing) _underButton(),
              ])),
        ]));
  }

  Widget _continue() => Padding(
      // Rides the keyboard: the inset is read on every frame of its rise.
      padding: EdgeInsets.fromLTRB(
          OnboardingTokens.screenPadding,
          8,
          OnboardingTokens.screenPadding,
          8 + MediaQuery.viewInsetsOf(context).bottom),
      child: OnboardingButton(
          label: widget.continueLabel,
          enabled: widget.canContinue,
          busy: widget.busy,
          // A new step that opens already answered still gets its one pass
          // of light.
          token: widget.currentIndex,
          onPressed: widget.onContinue));

  Widget _underButton() {
    final line = widget.microcopy == null
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 4),
            child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                child: Text(widget.microcopy!,
                    key: ValueKey(widget.microcopy),
                    textAlign: TextAlign.center,
                    style: HolyTypography.caption.copyWith(
                        fontSize: 12.5,
                        color: OnboardingTokens.textTertiary))));
    if (widget.secondaryLabel != null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        if (line != null) line,
        TextAction(widget.secondaryLabel!,
            color: OnboardingTokens.textSecondary,
            onPressed: widget.onSecondary),
      ]);
    }
    return line ?? const SizedBox(height: 14);
  }
}

/// The welcome's button: solid brass with light turning round its
/// edge, a spring under the finger, and one pass of light each time it
/// becomes ready. The offer uses it too.
class OnboardingButton extends StatelessWidget {
  final String label;
  final bool enabled, busy;
  final Object token;
  final VoidCallback onPressed;
  final String? semanticLabel;
  const OnboardingButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.enabled = true,
      this.busy = false,
      this.token = 0,
      this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final ready = enabled && !busy;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final radius = BorderRadius.circular(OnboardingTokens.ctaRadius);
    return Pressable(
        onPressed: ready ? onPressed : null,
        semanticLabel: semanticLabel ?? label,
        borderRadius: radius,
        child: AnimatedContainer(
            duration:
                reduced ? Duration.zero : const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: ready ? OnboardingTokens.ctaShadow : const []),
            child: ClipRRect(
                borderRadius: radius,
                child: _ReadySweep(
                    ready: ready,
                    token: token,
                    child: AnimatedContainer(
                        duration: reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        width: double.infinity,
                        height: OnboardingTokens.ctaHeight,
                        color: ready || busy
                            ? OnboardingTokens.plum
                            : OnboardingTokens.ctaDisabledFill,
                        child: Stack(fit: StackFit.expand, children: [
                          // The light only turns while there is something
                          // to press.
                          AnimatedOpacity(
                              opacity: ready ? 1 : 0,
                              duration: reduced
                                  ? Duration.zero
                                  : const Duration(milliseconds: 320),
                              child: EdgeGlow(
                                  corners: radius,
                                  scale: .42,
                                  intensity: .9,
                                  inset: 2,
                                  animate: ready)),
                          // A glassy rim along the top edge.
                          Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 26),
                                  child: Container(
                                      height: 1.2,
                                      decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [
                                        Colors.white.withValues(alpha: 0),
                                        Colors.white
                                            .withValues(alpha: ready ? .5 : .2),
                                        Colors.white.withValues(alpha: 0),
                                      ]))))),
                          Center(
                              child: busy
                                  ? const HolySpinner(
                                      color: OnboardingTokens.onPlum,
                                      size: 20,
                                      stroke: 2)
                                  : AnimatedSwitcher(
                                      duration: reduced
                                          ? Duration.zero
                                          : const Duration(milliseconds: 220),
                                      child: Padding(
                                          key: ValueKey(label),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20),
                                          child: Text(label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: HolyTypography.button.copyWith(
                                                  fontSize: 16.5,
                                                  color: ready
                                                      ? OnboardingTokens.onPlum
                                                      : OnboardingTokens
                                                          .ctaDisabledLabel))))),
                        ]))))));
  }
}

/// One pass of light across the button each time it becomes ready.
class _ReadySweep extends StatefulWidget {
  final bool ready;
  final Object token;
  final Widget child;
  const _ReadySweep(
      {required this.ready, required this.token, required this.child});
  @override
  State<_ReadySweep> createState() => _ReadySweepState();
}

class _ReadySweepState extends State<_ReadySweep>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  void _play() {
    if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
    _sweep.forward(from: 0);
  }

  @override
  void didUpdateWidget(_ReadySweep old) {
    super.didUpdateWidget(old);
    final becameReady = widget.ready && !old.ready;
    final newStep = widget.ready && widget.token != old.token;
    if (becameReady || newStep) {
      // After the page has turned, so the light is seen.
      Future<void>.delayed(Duration(milliseconds: newStep ? 560 : 120), _play);
    } else if (!widget.ready) {
      _sweep.value = 0;
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _sweep,
      child: widget.child,
      builder: (context, child) {
        if (_sweep.value == 0 || _sweep.value == 1) return child!;
        final x = Curves.easeInOut.transform(_sweep.value) * 3 - 1.5;
        return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment(x - .5, -.4),
                    end: Alignment(x + .5, .4),
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      const Color(0xFFFFE9D6).withValues(alpha: .38),
                      Colors.white.withValues(alpha: 0)
                    ],
                    stops: const [
                      .3,
                      .5,
                      .7
                    ]).createShader(bounds),
            child: child);
      });
}

/// The step change: a page leaving or arriving swings on its vertical axis,
/// settles back and fades, and travels less far than the scroll does, so the
/// next step reads as turning in out of the same light, not being pushed in
/// from the side. Twice the swing of the first version, for depth. It follows the page position itself, so it keeps time with
/// the field's colour change frame for frame.
class _PageMotion extends StatelessWidget {
  final PageController controller;
  final int index;

  /// Used before the controller has a position (the first frame).
  final int fallbackPage;
  final Set<int> dissolve;
  final Widget child;
  const _PageMotion(
      {required this.controller,
      required this.index,
      required this.fallbackPage,
      required this.dissolve,
      required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final width = MediaQuery.sizeOf(context).width;
    return AnimatedBuilder(
        animation: controller,
        child: child,
        builder: (context, child) {
          final position =
              controller.hasClients && controller.position.hasContentDimensions
                  ? controller.page ?? fallbackPage.toDouble()
                  : fallbackPage.toDouble();
          final delta = (position - index).clamp(-1.0, 1.0);
          final distance = delta.abs();
          // At rest this is the same tree with neutral values, never the
          // bare child: swapping the type here would rebuild the whole step
          // just as it landed, and its entrance would play twice.
          final eased =
              distance < 0.001 ? 0.0 : Curves.easeIn.transform(distance);
          // Between two pages that share a card, neither travels: each is
          // held where it rests and they cross-fade, so the card stays put
          // and only what is in it changes.
          final between = position.floor();
          if (distance >= 0.001 &&
              dissolve.contains(between) &&
              (index == between || index == between + 1)) {
            return Opacity(
                opacity: 1 - Curves.easeInOut.transform(distance),
                child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..translateByDouble(delta * width, 0, 0, 1),
                    child: child));
          }
          return Opacity(
              opacity: (1 - eased * 1.15).clamp(0.0, 1.0),
              child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0011)
                    // Counter part of the scroll: the page covers less ground.
                    ..translateByDouble(delta * width * 0.32, 0, 0, 1)
                    ..rotateY(-delta * 0.34)
                    ..scaleByDouble(1 - 0.08 * eased, 1 - 0.08 * eased, 1, 1),
                  child: child));
        });
  }
}

/// Holds the safe-area insets steady while the bottom bar comes and goes.
///
/// The bar leaves on the steps that bring their own actions, and with it the
/// padding every step reads from [MediaQuery]. Passed straight through, the
/// page would snap by the bar's height mid-turn; this glides to the new
/// insets over the time the page takes to arrive.
class _SmoothInsets extends StatelessWidget {
  final Widget child;
  const _SmoothInsets({required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // While the keyboard moves, follow it exactly: it has its own curve. The
    // tree stays the same shape either way, so a step never loses its state
    // (a focused field, a half-drawn entrance) when the keyboard opens.
    final direct =
        MediaQuery.disableAnimationsOf(context) || media.viewInsets.bottom > 0;
    return TweenAnimationBuilder<EdgeInsets>(
        tween: EdgeInsetsTween(end: media.padding),
        duration: direct ? Duration.zero : OnboardingTokens.pageTransition,
        curve: OnboardingTokens.pageCurve,
        child: child,
        builder: (context, padding, child) =>
            MediaQuery(data: media.copyWith(padding: padding), child: child!));
  }
}
