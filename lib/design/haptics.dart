// Ported from Cognein; see store/v2-design-ports.json.
import 'package:flutter/services.dart';

/// Haptic patterns mapped to interaction types.
///
/// One vocabulary for the whole app, all of it behind the Haptics switch:
///
/// * selection tick: chips, toggles, segmented controls, pickers, tabs
/// * light impact: a lesson card turning, a sheet opening
/// * medium impact: a primary button
/// * rising light ticks while Amen is held, then a success notification
/// * success notification: a purchase confirmed, a medallion earned
/// * warning notification: anything that went wrong
///
/// Nothing fires on scroll.
class HolyHaptics {
  const HolyHaptics._();

  /// The app-wide switch (Settings → Haptics). Every pattern below goes through
  /// [_fire], and the few widgets that used to call `HapticFeedback` directly
  /// now use [tap] and [detent], so this one flag silences all of it.
  static bool enabled = true;

  static void _fire(Future<void> Function() haptic) {
    if (enabled) haptic();
  }

  /// Standard button press.
  static void buttonPress() => _fire(HapticFeedback.mediumImpact);

  /// A chip, toggle, segmented control, picker or tab changing.
  static void selection() => _fire(HapticFeedback.selectionClick);

  /// Selecting a card or chip.
  static void chipSelect() => _fire(HapticFeedback.selectionClick);

  /// Deselecting a card or chip — lighter than selecting, on purpose.
  static void chipDeselect() => _fire(HapticFeedback.selectionClick);

  /// Something done and kept: a purchase confirmed, a medallion earned, an
  /// Amen held to the end. The platform's own success notification.
  static void success() => _fire(HapticFeedback.successNotification);

  /// One tick of a hold building: Amen fires these at a quarter, a half and
  /// three quarters, so the finger feels the light gathering.
  static void holdTick() => _fire(HapticFeedback.lightImpact);

  /// A light, incidental tap: opening a sheet, copying, tapping a suggestion.
  static void tap() => _fire(HapticFeedback.lightImpact);

  /// The user sent something: a firm-but-short tap.
  static void send() => _fire(HapticFeedback.mediumImpact);

  /// Something arrived (a reply): softer than [send], so it reads as a response.
  static void receive() => _fire(HapticFeedback.selectionClick);

  /// Crossing a threshold while a finger is still down: a pull-to-refresh
  /// arming, a zoom passing 1x. The lightest tick there is, so it marks the
  /// moment without competing with the gesture.
  static void detent() => _fire(HapticFeedback.selectionClick);

  /// Something went wrong: the platform's warning notification.
  static void error() => _fire(HapticFeedback.warningNotification);

  /// Crossing a step boundary: a medium tap, then a light one.
  static Future<void> stepComplete() async {
    if (!enabled) return;
    _fire(HapticFeedback.mediumImpact);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _fire(HapticFeedback.lightImpact);
  }

  /// Reaching a milestone (purchase complete, plan built): the same success
  /// notification as [success], so a milestone feels the same everywhere.
  static Future<void> celebration() async => success();

  // Lesson cards. Deliberately the quietest vocabulary in the app: a lesson is
  // read for minutes, so nothing here may feel like a notification. Only the two
  // lightest things a phone can do are used (the selection tick and the light
  // tap), and each is paired with something that is really happening: a detent
  // under the finger, a small object landing, a mistake being noted.

  /// A card crossing the line where letting go will turn it. The sound of that
  /// (the whoosh) waits for the finger to leave: the tick is the detent, the
  /// whoosh is the card going.
  static void lessonSwipe() => _fire(HapticFeedback.selectionClick);

  /// A swipe the lesson will not allow: the deck pushes back, and so does this,
  /// as softly as the platform lets it.
  static void lessonBlocked() => _fire(HapticFeedback.selectionClick);

  /// A right answer: a light tap, like setting something down.
  static void answerCorrect() => _fire(HapticFeedback.lightImpact);

  /// A wrong answer: one tick, lighter than the right answer's tap. A mistake is
  /// information, not a penalty, so it is noted and nothing more.
  static void answerWrong() => _fire(HapticFeedback.selectionClick);

  /// The lesson is saved: a tap that settles into a tick a moment later, the way
  /// a small thing lands and then rests.
  static Future<void> lessonComplete() async {
    if (!enabled) return;
    _fire(HapticFeedback.lightImpact);
    await Future<void>.delayed(const Duration(milliseconds: 110));
    _fire(HapticFeedback.selectionClick);
  }

  // The finished lesson is the one moment in the lessons allowed to feel like
  // one. It is three separate taps, not a pattern, because the lesson screen
  // fires each on the celebration's own clock (see `LessonCelebration`): they
  // land with the light and the sound, and vanish with the screen if the
  // learner leaves, which a chain of delayed futures would not.

  /// The light leaves on its lap: a light tap, with the whoosh.
  static void lessonSurge() => _fire(HapticFeedback.lightImpact);

  /// The chime lands at the crest of the whoosh: the fullest tap in the lessons.
  static void lessonCrest() => _fire(HapticFeedback.mediumImpact);

  /// And the tick as it starts to settle.
  static void lessonSettle() => _fire(HapticFeedback.selectionClick);
}
