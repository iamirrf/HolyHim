// Ported from Cognein; see store/v2-design-ports.json.
import 'package:flutter/material.dart';
import '../../../design/design.dart';
import '../onboarding_copy.dart';
import '../widgets/onboarding_tokens.dart';
import '../widgets/ruler_picker.dart';
import '../widgets/step_title.dart';

/// Her birthday, on three rulers: month, day and year.
///
/// It is optional. The rulers open on a plain date and nothing is saved
/// until she taps the button, so skipping leaves no birthday behind.
class BirthdayStep extends StatefulWidget {
  /// A saved `YYYY-MM-DD`, if she has given one before.
  final String? initial;
  final Color accent;
  final ValueChanged<DateTime> onChanged;
  const BirthdayStep(
      {super.key,
      required this.initial,
      required this.accent,
      required this.onChanged});

  static const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  @override
  State<BirthdayStep> createState() => _BirthdayStepState();
}

class _BirthdayStepState extends State<BirthdayStep> {
  late int _month, _day, _year;

  /// What a ruler reads while it is being dragged. The values above change
  /// only once it settles, so without these the label would sit on the old
  /// value until the finger lifted.
  int? _previewMonth, _previewDay, _previewYear;

  @override
  void initState() {
    super.initState();
    final seed =
        DateTime.tryParse(widget.initial ?? '') ?? DateTime(1995, 6, 15);
    _month = seed.month;
    _day = seed.day;
    _year = seed.year;
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  int _daysIn(int year, int month) => DateUtils.getDaysInMonth(year, month);

  void _notify() {
    final max = _daysIn(_year, _month);
    if (_day > max) setState(() => _day = max);
    if (mounted) widget.onChanged(DateTime(_year, _month, _day));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = _previewMonth ?? _month;
    final year = _previewYear ?? _year;
    final days = _daysIn(year, month);
    final day = (_previewDay ?? _day).clamp(1, days);
    Widget ruler(String label, String value, Widget picker) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label,
                  textAlign: TextAlign.center,
                  style: HolyTypography.eyebrow.copyWith(
                      fontSize: 10.5, color: OnboardingTokens.textTertiary)),
              const SizedBox(height: 2),
              // The value under the tick, in the display face: the one thing
              // on this step she is meant to read.
              AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 140),
                  child: Text(value,
                      key: ValueKey(value),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: HolyTypography.headline.copyWith(
                          fontSize: 28,
                          color: widget.accent,
                          fontFeatures: const [FontFeature.liningFigures()]))),
              const SizedBox(height: 2),
              picker,
            ]);
    return Padding(
        padding: OnboardingTokens.pageInsets(context),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const StepTitle(
              text: OnboardingCopy.birthdayTitle,
              subtitle: OnboardingCopy.birthdaySubtitle),
          Expanded(
              child: Semantics(
                  label:
                      'Birthday: ${BirthdayStep.months[month - 1]} $day, $year',
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                          width: MediaQuery.sizeOf(context).width -
                              OnboardingTokens.screenPadding * 2,
                          child: Rise(
                              delay: const Duration(milliseconds: 260),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ruler(
                                        'MONTH',
                                        BirthdayStep.months[month - 1],
                                        RulerPicker(
                                            items: [
                                              for (var m = 1; m <= 12; m++) m
                                            ],
                                            selectedValue: _month,
                                            accent: widget.accent,
                                            onPreview: (v) => setState(
                                                () => _previewMonth = v),
                                            onChange: (v) {
                                              setState(() {
                                                _month = v;
                                                _previewMonth = null;
                                              });
                                              _notify();
                                            })),
                                    const SizedBox(height: 18),
                                    ruler(
                                        'DAY',
                                        '$day',
                                        RulerPicker(
                                            items: [
                                              for (var d = 1; d <= days; d++) d
                                            ],
                                            selectedValue: _day.clamp(1, days),
                                            accent: widget.accent,
                                            onPreview: (v) =>
                                                setState(() => _previewDay = v),
                                            onChange: (v) {
                                              setState(() {
                                                _day = v;
                                                _previewDay = null;
                                              });
                                              _notify();
                                            })),
                                    const SizedBox(height: 18),
                                    ruler(
                                        'YEAR',
                                        '$year',
                                        RulerPicker(
                                            items: [
                                              for (var y = now.year - 100;
                                                  y <= now.year - 13;
                                                  y++)
                                                y
                                            ],
                                            selectedValue: _year,
                                            accent: widget.accent,
                                            onPreview: (v) => setState(
                                                () => _previewYear = v),
                                            onChange: (v) {
                                              setState(() {
                                                _year = v;
                                                _previewYear = null;
                                              });
                                              _notify();
                                            })),
                                  ])))))),
        ]));
  }
}
