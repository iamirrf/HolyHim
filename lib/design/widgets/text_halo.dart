// Adapted from Cognein's AnimatedTextHalo and BrandGradient; see
// store/v2-design-ports.json.
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/widgets.dart';

/// HolyHim's brass, for words set on a photograph or a dark field: bone
/// into light brass into brass, left to right, glowing amber and candle
/// gold. The shared engine's name for it is kept so upstream syncs stay
/// clean.
abstract final class RoseGold {
  static const fill = [Color(0xFFF7F1E6), Color(0xFFF3D9A4), Color(0xFFD8A657)];

  /// The two tints of the glow: amber and candle gold.
  static const rose = Color(0xFFE0A35A);
  static const gold = Color(0xFFF0C97E);

  /// The same metal, deepened to read on pale paper.
  static const ink = [Color(0xFF7A5522), Color(0xFF8E6427), Color(0xFF6E4A1C)];
}

/// Fills [child]'s glyphs with a left-to-right gradient.
class GradientFill extends StatelessWidget {
  final List<Color> colors;
  final Widget child;
  const GradientFill({super.key, required this.colors, required this.child});

  @override
  Widget build(BuildContext context) => ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(colors: colors)
          .createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: child);
}

/// Words with a slow-breathing halo, in brass.
///
/// Three layers share one 3.6 second breath, so they stay in step:
///
/// * a soft aura behind the letters whose opacity and blur rise and fall;
/// * the same glow carried by the glyphs as shadows, in rose and gold, kept
///   in a layer of its own because the gradient's mask would recolour them;
/// * a narrow highlight that crosses the letters once a breath.
///
/// With Reduce Motion it holds the middle of the breath and does not move.
class TextHalo extends StatefulWidget {
  final InlineSpan text;
  final TextStyle style;
  final TextAlign textAlign;

  /// The letters' fill, left to right.
  final List<Color> fill;
  final Color glow, glowSecond;

  /// How strong the halo is, from 0 (none) to 1 (the wordmark's).
  final double strength;

  /// Whether the highlight crosses the letters.
  final bool sweep;

  /// Scales with Dynamic Type when true; the wordmark keeps its size.
  final bool scaleText;

  /// A soft dark shadow under the letters, so pale metal still reads on a
  /// bright sky. Null for none.
  final Color? shade;

  const TextHalo(
      {super.key,
      required this.text,
      required this.style,
      this.textAlign = TextAlign.center,
      this.fill = RoseGold.fill,
      this.glow = RoseGold.rose,
      this.glowSecond = RoseGold.gold,
      this.strength = 1,
      this.sweep = true,
      this.scaleText = false,
      this.shade = const Color(0x80080B10)});

  /// The HolyHim wordmark, upright like every First Watch title.
  static InlineSpan wordmark() => const TextSpan(children: [
        TextSpan(text: 'Holy'),
        TextSpan(text: 'Him', style: TextStyle(letterSpacing: -.2)),
      ]);

  static const Duration breath = Duration(milliseconds: 3600);

  @override
  State<TextHalo> createState() => _TextHaloState();
}

class _TextHaloState extends State<TextHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath =
      AnimationController(vsync: this, duration: TextHalo.breath);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath
        ..stop()
        ..value = .25;
    } else if (!_breath.isAnimating) {
      _breath.repeat();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  /// A blurred, filled pill behind the letters. A filled shape is blurred,
  /// not a shadow cast from an empty box: that reads as a hard-edged plate.
  Widget _aura(Color color, double opacity, double blur, EdgeInsets inset) =>
      Positioned(
          left: inset.left,
          right: inset.right,
          top: inset.top,
          bottom: inset.bottom,
          child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                  sigmaX: blur / 2, sigmaY: blur / 2, tileMode: TileMode.decal),
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: opacity),
                      borderRadius: BorderRadius.circular(999)))));

  @override
  Widget build(BuildContext context) {
    final scaler = widget.scaleText
        ? MediaQuery.textScalerOf(context)
        : TextScaler.noScaling;
    final k = widget.strength.clamp(0.0, 1.0);
    return Semantics(
        label: widget.text.toPlainText(),
        excludeSemantics: true,
        child: AnimatedBuilder(
            animation: _breath,
            builder: (context, _) {
              final t = _breath.value;
              // 0 -> 1 -> 0 over the breath, smooth at both ends.
              final breath = .5 - .5 * math.cos(2 * math.pi * t);
              final auraOpacity = (.14 + .20 * breath) * k;
              final blur = 18 + 16 * breath;
              Widget letters(TextStyle style) => RichText(
                  textAlign: widget.textAlign,
                  textScaler: scaler,
                  text: TextSpan(style: style, children: [widget.text]));
              return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (k > 0)
                      Positioned.fill(
                          child: IgnorePointer(
                              child: Stack(clipBehavior: Clip.none, children: [
                        _aura(
                            widget.glow,
                            auraOpacity,
                            blur,
                            const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 8)),
                        _aura(
                            widget.glowSecond,
                            auraOpacity * .7,
                            blur * 1.4,
                            const EdgeInsets.symmetric(
                                horizontal: -10, vertical: 2)),
                      ]))),
                    // The glow carried by the glyphs. The fill is almost
                    // clear so only the shadows read; the letters proper are
                    // the layer above.
                    if (k > 0 || widget.shade != null)
                      letters(widget.style
                          .copyWith(color: const Color(0x03FFFFFF), shadows: [
                        if (widget.shade != null)
                          Shadow(
                              color: widget.shade!,
                              blurRadius: 14,
                              offset: const Offset(0, 2)),
                        if (k > 0) ...[
                          Shadow(
                              color: widget.glow
                                  .withValues(alpha: (.30 + .34 * breath) * k),
                              blurRadius: blur * .55),
                          Shadow(
                              color: widget.glowSecond
                                  .withValues(alpha: (.20 + .28 * breath) * k),
                              blurRadius: blur),
                        ],
                      ])),
                    ShaderMask(
                        blendMode: BlendMode.srcATop,
                        shaderCallback: (bounds) => LinearGradient(
                                // The highlight enters left of the word and
                                // leaves right of it, so it is fully off the
                                // letters at both ends of the breath.
                                colors: [
                                  const Color(0x00FFFFFF),
                                  Color.fromRGBO(
                                      255, 255, 255, widget.sweep ? .6 : 0),
                                  const Color(0x00FFFFFF),
                                ],
                                stops: [
                                  (t * 1.6 - .45).clamp(0.0, 1.0),
                                  (t * 1.6 - .30).clamp(0.0, 1.0),
                                  (t * 1.6 - .15).clamp(0.0, 1.0),
                                ]).createShader(Rect.fromLTWH(
                                0, 0, bounds.width, bounds.height)),
                        child: GradientFill(
                            colors: widget.fill,
                            child: letters(widget.style
                                .copyWith(color: const Color(0xFFFFFFFF))))),
                  ]);
            }));
  }
}
