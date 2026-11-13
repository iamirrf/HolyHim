// Ported from Cognein; see store/v2-design-ports.json.
import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// The app's shared motion vocabulary.
///
/// Two rules explain every value here:
///
/// * Motion a finger caused (a press, a drag, a release) is a spring, or starts
///   from the finger's own velocity. A finger never starts from rest, so a curve
///   that accelerates from a standstill reads as lag. Reserve `Curves.easeInOut`
///   for motion the app starts on its own.
/// * Exits are shorter than entrances. On arrival the eye needs time to register
///   what a thing is; on exit it has already moved on and the animation is tax.
class HolyMotion {
  const HolyMotion._();

  /// Finger down on a control: fast, and decelerating into the pressed size.
  static const pressIn = Duration(milliseconds: 100);
  static const pressInCurve = Curves.easeOut;

  /// How far a control shrinks under a finger. 0.96, not 0.9: any deeper and it
  /// looks as if the control is being deleted rather than pressed.
  static const pressedScale = 0.96;

  /// Finger up: the control returns under its own tension, with a little
  /// bounce, settling in roughly 350ms.
  static final pressRelease = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 400,
    ratio: 0.55,
  );

  /// A dragged card that is not leaving comes home: a hint of overshoot, not a
  /// wobble.
  static final snapBack = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 380,
    ratio: 0.72,
  );

  /// A card leaving the deck. Critically damped and stiff so the exit is quick
  /// and clean; the release velocity does the rest.
  static final flyOff = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 900,
    ratio: 1,
  );

  /// Pixel-space springs stop once they are half a pixel from home. The default
  /// tolerance (a thousandth of a pixel) would keep the ticker running for
  /// another fifth of a second for no visible change.
  static const pixelTolerance = Tolerance(distance: 0.5, velocity: 20);

  /// Something arriving on its own.
  static const enter = Duration(milliseconds: 420);
  static const enterCurve = Curves.easeOutCubic;

  /// Something leaving. Always shorter than [enter].
  static const exit = Duration(milliseconds: 180);
  static const exitCurve = Curves.easeIn;
}
