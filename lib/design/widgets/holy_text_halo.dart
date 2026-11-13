import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../themes.dart';

/// A sacred, subtle luminous wordmark with a slow-breathing halo,
/// brand-gradient color, and a gentle shiny light sweep.
class HolyTextHalo extends StatefulWidget {
  final String text;
  final TextStyle style;

  const HolyTextHalo({
    super.key,
    required this.text,
    required this.style,
  });

  static const Duration cycle = Duration(milliseconds: 3800);
  static const Color _roseGlow = Color(0xFFE8C766);
  static const Color _goldGlow = Color(0xFFE8C766);

  @override
  State<HolyTextHalo> createState() => _HolyTextHaloState();
}

class _HolyTextHaloState extends State<HolyTextHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: HolyTextHalo.cycle,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.25;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _aura(Color color, double opacity, double blur, EdgeInsets inset) {
    return Positioned(
      left: inset.left,
      right: inset.right,
      top: inset.top,
      bottom: inset.bottom,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: blur / 2,
          sigmaY: blur / 2,
          tileMode: TileMode.decal,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = HolyThemeScope.of(context);
    final gradientColors = [
      theme.accent,
      const Color(0xFFD4AF37),
      const Color(0xFFC9A227),
      const Color(0xFF8C6D1F),
    ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Smooth breathing 0 -> 1 -> 0
        final breath = 0.5 - 0.5 * math.cos(2 * math.pi * t);
        // Kept subtle and not disturbing per user request
        final auraOpacity = 0.10 + 0.14 * breath;
        final blur = 16.0 + 12.0 * breath;

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Ambient soft breathing aura behind wordmark
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _aura(
                      HolyTextHalo._roseGlow,
                      auraOpacity * 0.75,
                      blur * 1.3,
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    _aura(
                      HolyTextHalo._goldGlow,
                      auraOpacity * 0.55,
                      blur * 1.6,
                      const EdgeInsets.symmetric(horizontal: -4, vertical: 2),
                    ),
                  ],
                ),
              ),
            ),

            // Soft glyph shadows
            ExcludeSemantics(
              child: RichText(
                textScaler: MediaQuery.textScalerOf(context),
                text: TextSpan(
                  text: widget.text,
                  style: widget.style.copyWith(
                    color: Colors.white.withValues(alpha: 0.01),
                    shadows: [
                      Shadow(
                        color: HolyTextHalo._roseGlow.withValues(
                          alpha: 0.20 + 0.22 * breath,
                        ),
                        blurRadius: blur * 0.7,
                      ),
                      Shadow(
                        color: HolyTextHalo._goldGlow.withValues(
                          alpha: 0.15 + 0.18 * breath,
                        ),
                        blurRadius: blur * 1.1,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Shiny light sweep across brand gradient text
            ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.60),
                  Colors.white.withValues(alpha: 0),
                ],
                stops: [
                  (t * 1.7 - 0.45).clamp(0.0, 1.0),
                  (t * 1.7 - 0.30).clamp(0.0, 1.0),
                  (t * 1.7 - 0.15).clamp(0.0, 1.0),
                ],
              ).createShader(bounds),
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ).createShader(bounds),
                child: Text(
                  widget.text,
                  style: widget.style.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
