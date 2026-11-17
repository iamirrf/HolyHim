import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/design/widgets/animated_mesh_background.dart';
import 'package:holyhim/domain/onboarding_flow.dart';
import 'package:holyhim/features/onboarding/onboarding_moods.dart';
import 'package:holyhim/features/onboarding/widgets/onboarding_tokens.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + .05 : lb + .05) / (la > lb ? lb + .05 : la + .05);
}

List<Color> _field(MeshTheme m) => [
      ...m.baseColors,
      m.b1Start,
      m.b1End,
      m.b2Start,
      m.b2End,
      m.b3Start,
      m.b3End,
      m.b4Start,
      m.b4Mid,
      m.b4End
    ];

void main() {
  test('words on the welcome\'s dark field stay readable wherever the light drifts',
      () {
    for (final (i, mood) in OnboardingMoods.all.indexed) {
      for (final ground in _field(mood.mesh)) {
        // Questions and the letter are set straight on the field.
        expect(_contrast(OnboardingTokens.ink, ground), greaterThanOrEqualTo(7),
            reason: 'mood $i: ink on $ground');
        expect(_contrast(OnboardingTokens.textSecondary, ground),
            greaterThanOrEqualTo(4.5),
            reason: 'mood $i: secondary text on $ground');
        // Progress dots and rims: the 3:1 floor for parts of a control.
        expect(_contrast(mood.accent, ground), greaterThanOrEqualTo(3),
            reason: 'mood $i: accent on $ground');
      }
    }
  });

  test('cards, chips and the button keep their words readable', () {
    const glass = OnboardingTokens.white;
    expect(_contrast(OnboardingTokens.ink, glass), greaterThanOrEqualTo(7));
    expect(_contrast(OnboardingTokens.textSecondary, glass),
        greaterThanOrEqualTo(7));
    expect(_contrast(OnboardingTokens.textTertiary, glass),
        greaterThanOrEqualTo(4.5));
    expect(_contrast(OnboardingTokens.onPlum, OnboardingTokens.plum),
        greaterThanOrEqualTo(7));
    for (final (i, mood) in OnboardingMoods.all.indexed) {
      // Small headings in the step's colour sit on the glass; a chosen reply
      // is filled with it and carries dark ink.
      expect(_contrast(mood.accent, glass), greaterThanOrEqualTo(4.5),
          reason: 'mood $i: accent on the glass');
      expect(_contrast(OnboardingTokens.onPlum, mood.accent),
          greaterThanOrEqualTo(4.5),
          reason: 'mood $i: dark ink on the accent');
    }
  });

  test('every step of the welcome has its light', () {
    expect(OnboardingMoods.steps, hasLength(onboardingStepIds.length));
    expect(OnboardingMoods.steps.toSet().difference(OnboardingMoods.all.toSet()),
        isEmpty);
  });
}
