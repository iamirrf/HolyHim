import 'package:flutter/material.dart';
import '../../design/design.dart';
import '../../domain/onboarding_flow.dart';

/// A short letter built from her answers. Plain words, no promises the app
/// cannot keep.
class PersonalLetter extends StatelessWidget {
  final String name;
  final OnboardingAnswers answers;
  final bool reminderOn;
  final int reminderMinutes;

  /// False when the letter is set on a surface of its own, such as the
  /// glass panel in the welcome.
  final bool framed;
  const PersonalLetter(
      {super.key,
      required this.name,
      required this.answers,
      required this.reminderOn,
      required this.reminderMinutes,
      this.framed = true});

  static String heartLine(String? heart) => switch (heart) {
        'strength' =>
          'You asked for strength. Some days ask a lot of you. Each morning we will put one strong promise in your hands before the day begins.',
        'hope' =>
          'You asked for hope. Each morning we will hold up one thing God has said and kept, so you have something good to carry.',
        'guidance' =>
          'You asked for guidance. Each lesson ends with one small step, so what you read can help with the choice in front of you.',
        'rest' =>
          'You asked for rest. These lessons are short on purpose. Come as you are, read for five minutes, and breathe.',
        'joy' =>
          'You asked for joy. We will look for God’s goodness in ordinary places, one morning at a time.',
        _ =>
          'You asked for peace. Each morning starts with one verse and a few quiet minutes, so the noise does not get the first word.',
      };

  static String seasonLine(String? season) => switch (season) {
        'change' =>
          'Change can make the ground feel soft under your feet. God’s word does not move.',
        'hurting' =>
          'If you are hurting, you do not have to pretend here. God stays close to the brokenhearted.',
        'waiting' =>
          'Waiting is hard. We will walk through it together, one day at a time.',
        'growing' =>
          'You want to grow. Small steps, taken every day, go a long way.',
        'steady' =>
          'A steady season is a gift. It is a good time to put down deep roots.',
        _ =>
          'Your days are full, so each lesson takes about five minutes. That is enough.',
      };

  String stepLine() {
    final h = reminderMinutes ~/ 60, m = reminderMinutes % 60;
    final time =
        '${h % 12 == 0 ? 12 : h % 12}:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
    return switch (answers.obstacle) {
      'understanding' =>
        'Every verse comes with a plain explanation, so you never have to guess what it means.',
      'forgetting' => reminderOn
          ? 'We will send you one quiet note at $time, and your place is always saved.'
          : 'Your place is always saved, so you can come back whenever you remember.',
      'starting' => 'You do not have to start big. Day 1 takes five minutes.',
      'busy' => reminderOn
          ? 'We will bring today’s word to you at $time. Five minutes is enough.'
          : 'Five minutes is enough. Your place is saved if you are interrupted.',
      _ => reminderOn
          ? 'Your first note arrives at $time. Day 1 is ready now.'
          : 'Day 1 is ready whenever you are.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final compact = MediaQuery.sizeOf(context).height < 720;
    final prose = HolyTypography.ui.copyWith(
        color: t.ink,
        fontSize: compact ? 15.5 : 16.5,
        height: 1.52,
        fontWeight: FontWeight.w500);
    final letter = LineReveal(step: const Duration(milliseconds: 650), lines: [
      Text(name.isEmpty ? 'Dear friend,' : 'Dear $name,',
          style: HolyTypography.headline
              .copyWith(color: t.ink, fontStyle: FontStyle.italic)),
      SizedBox(height: compact ? 10 : 14),
      Text(heartLine(answers.hearts.firstOrNull), style: prose),
      SizedBox(height: compact ? 8 : 12),
      Text('${seasonLine(answers.season)} ${stepLine()}', style: prose),
      SizedBox(height: compact ? 12 : 16),
      Row(children: [
        Flourish(color: t.gold, width: 36),
        const SizedBox(width: 12),
        Text('Walking with you, HolyHim',
            style: HolyTypography.label.copyWith(color: t.muted)),
      ]),
    ]);
    if (!framed) return letter;
    return Paper(
        padding:
            EdgeInsets.fromLTRB(24, compact ? 20 : 26, 24, compact ? 20 : 24),
        child: letter);
  }
}
