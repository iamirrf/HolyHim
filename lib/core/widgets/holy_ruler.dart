import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/services/feedback_service.dart';
import 'package:holyher/core/widgets/holy_ui.dart' show HolyPressable;

class HolyTimeRuler extends StatefulWidget {
  final int minutes;
  final ValueChanged<int> onChanged;
  const HolyTimeRuler(
      {super.key, required this.minutes, required this.onChanged});
  @override
  State<HolyTimeRuler> createState() => _HolyTimeRulerState();
}

class _HolyTimeRulerState extends State<HolyTimeRuler> {
  late int _minutes = widget.minutes;
  void _change(int value) {
    setState(() => _minutes = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final full = MediaQuery.alwaysUse24HourFormatOf(context),
        hour = _minutes ~/ 60;
    return Column(children: [
      Text(TimeOfDay(hour: hour, minute: _minutes % 60).format(context),
          style: HolyTypography.display
              .copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
      const SizedBox(height: 32),
      _Ruler(
          key: ValueKey('hours-$full'),
          label: 'Hour',
          count: full ? 24 : 12,
          index: full ? hour : (hour + 11) % 12,
          format: (i) => '${full ? i : i + 1}',
          onCommit: (i) => _change(
              (full ? i : (i + 1) % 12 + (hour >= 12 ? 12 : 0)) * 60 +
                  _minutes % 60)),
      const SizedBox(height: 20),
      _Ruler(
          label: 'Minute',
          count: 60,
          index: _minutes % 60,
          format: (i) => i.toString().padLeft(2, '0'),
          onCommit: (i) => _change(hour * 60 + i)),
      if (!full) ...[
        const SizedBox(height: 24),
        SizedBox(
          width: 208,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: .6),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white),
            ),
            child: Row(children: [
              for (final pm in [false, true])
                Expanded(
                  child: HolyPressable(
                    selected: (hour >= 12) == pm,
                    onPressed: () => _change(
                        (hour % 12 + (pm ? 12 : 0)) * 60 + _minutes % 60),
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: (hour >= 12) == pm
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: (hour >= 12) == pm
                                ? AppColors.accent.withValues(alpha: .4)
                                : Colors.transparent),
                      ),
                      child: Text(pm ? 'PM' : 'AM',
                          style: HolyTypography.action.copyWith(
                              color: (hour >= 12) == pm
                                  ? AppColors.accentDark
                                  : AppColors.textSecondary)),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ],
    ]);
  }
}

class _Ruler extends ConsumerStatefulWidget {
  final String label;
  final int count, index;
  final String Function(int) format;
  final ValueChanged<int> onCommit;
  const _Ruler(
      {super.key,
      required this.label,
      required this.count,
      required this.index,
      required this.format,
      required this.onCommit});
  @override
  ConsumerState<_Ruler> createState() => _RulerState();
}

class _RulerState extends ConsumerState<_Ruler> {
  late final _controller =
      FixedExtentScrollController(initialItem: widget.index);
  late int _preview = widget.index, _committed = widget.index;
  @override
  void didUpdateWidget(_Ruler old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index && _committed != widget.index) {
      _controller.jumpToItem(widget.index);
      _preview = _committed = widget.index;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    if (_preview == _committed) return;
    _committed = _preview;
    ref.read(feedbackProvider).selection();
    widget.onCommit(_preview);
  }

  void _adjust(int delta) {
    final next = (_committed + delta).clamp(0, widget.count - 1);
    _preview = next;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToItem(next);
    } else {
      _controller.animateToItem(next,
          duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    }
    _commit();
  }

  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => Semantics(
          label: widget.label,
          excludeSemantics: true,
          value: widget.format(_preview),
          increasedValue:
              widget.format((_preview + 1).clamp(0, widget.count - 1)),
          decreasedValue:
              widget.format((_preview - 1).clamp(0, widget.count - 1)),
          onIncrease: () => _adjust(1),
          onDecrease: () => _adjust(-1),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(widget.label,
                  style: HolyTypography.supporting
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              Text(widget.format(_preview),
                  style: HolyTypography.reading
                      .copyWith(fontWeight: FontWeight.w600))
            ]),
            const SizedBox(height: 8),
            SizedBox(
                height: 56,
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                      width: 46,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(colors: [
                            AppColors.surface,
                            Colors.white,
                            AppColors.surface
                          ]))),
                  NotificationListener<ScrollEndNotification>(
                      onNotification: (_) {
                        _commit();
                        return false;
                      },
                      child: RotatedBox(
                          quarterTurns: 3,
                          child: ListWheelScrollView.useDelegate(
                              controller: _controller,
                              itemExtent: 20,
                              diameterRatio: 5,
                              perspective: .001,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (i) =>
                                  setState(() => _preview = i),
                              childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: widget.count,
                                  builder: (context, i) => RotatedBox(
                                      quarterTurns: 1,
                                      child: OverflowBox(
                                          minWidth: 80,
                                          maxWidth: 80,
                                          minHeight: 0,
                                          maxHeight: 56,
                                          child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                    width: 1.5,
                                                    height: i % 5 == 0 ? 16 : 9,
                                                    color: i == _preview
                                                        ? AppColors.accent
                                                        : AppColors
                                                            .textSecondary
                                                            .withValues(
                                                                alpha: .5)),
                                                if (i % 5 == 0)
                                                  Text(widget.format(i),
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: i ==
                                                                  _preview
                                                              ? FontWeight.w600
                                                              : FontWeight.w400,
                                                          color: AppColors
                                                              .textPrimary))
                                              ]))))))),
                ]))
          ])));
}
