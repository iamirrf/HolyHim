// Ported from Cognein; see store/v2-design-ports.json.
import 'package:flutter/widgets.dart';

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

  // The timing scale. Every duration in the app is one of these three, so a
  // press, a step and a moment each have one speed wherever they happen.

  /// A control answering a finger: a press, a toggle, a chip.
  static const micro = Duration(milliseconds: 140);

  /// Moving between two states of a screen: a step, a sheet, a card.
  static const transition = Duration(milliseconds: 320);

  /// The moments people remember: a wordmark arriving, a medallion landing.
  static const hero = Duration(milliseconds: 700);

  /// Things arrive decelerating and leave accelerating.
  static const curveIn = Curves.easeOutCubic;
  static const curveOut = Curves.easeInCubic;

  /// The gap between siblings arriving one after another.
  static const stagger = Duration(milliseconds: 45);

  /// The delay for the [index]th sibling in a staggered entrance.
  static Duration staggered(int index) => stagger * index;

  /// The distance an arriving element travels as it fades in.
  static const rise = 24.0;

  /// True when the person has asked the system for less motion. Screens then
  /// cross-fade only: no sweeps, parallax, particles or slides.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Finger down on a control: fast, and decelerating into the pressed size.
  static const pressIn = micro;
  static const pressInCurve = curveIn;

  /// How far a control shrinks under a finger. 0.97, not 0.9: any deeper and it
  /// looks as if the control is being deleted rather than pressed.
  static const pressedScale = 0.97;

  /// Finger up: the control returns under its own tension, with a light
  /// bounce, settling in roughly 300ms.
  static final pressRelease = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: 0.62,
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
  static const enter = transition;
  static const enterCurve = curveIn;

  /// Something leaving. Always shorter than [enter].
  static const exit = Duration(milliseconds: 180);
  static const exitCurve = curveOut;
}
