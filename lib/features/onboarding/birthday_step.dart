import 'package:flutter/material.dart';
import '../../design/design.dart';

/// Cognein/SunRize ruler geometry, adapted to HolyHim's inherited theme.
class BirthdayStep extends StatefulWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  const BirthdayStep({super.key, this.value, required this.onChanged});
  static bool eligible(String? value) {
    final date = DateTime.tryParse(value ?? '');
    if (date == null || date.isAfter(DateTime.now())) return false;
    final now = DateTime.now();
    return now.year -
            date.year -
            (now.month < date.month ||
                    now.month == date.month && now.day < date.day
                ? 1
                : 0) >=
        13;
  }

  @override
  State<BirthdayStep> createState() => _BirthdayStepState();
}

class _BirthdayStepState extends State<BirthdayStep> {
  late DateTime date =
      DateTime.tryParse(widget.value ?? '') ?? DateTime(2000, 6, 15);
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
  void update({int? year, int? month, int? day}) {
    final y = year ?? date.year, m = month ?? date.month;
    setState(() => date = DateTime(
        y, m, (day ?? date.day).clamp(1, DateUtils.getDaysInMonth(y, m))));
    widget.onChanged(
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
    HolyHaptics.chipSelect();
  }

  @override
  void initState() {
    super.initState();
    if (widget.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) update();
      });
    }
  }

  Widget ruler(String value, List<int> items, int selected,
          ValueChanged<int> onChanged) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(children: [
            _RulerSection(
                displayValue: value, accent: HolyThemeScope.of(context).accent),
            _RulerPicker(
                items: items,
                selectedValue: selected,
                accent: HolyThemeScope.of(context).accent,
                onChange: onChanged,
                onPreview: (_) {}),
          ]));
  @override
  Widget build(BuildContext context) => Column(children: [
        ruler(months[date.month - 1], List.generate(12, (i) => i + 1),
            date.month, (v) => update(month: v)),
        ruler(
            '${date.day}',
            List.generate(
                DateUtils.getDaysInMonth(date.year, date.month), (i) => i + 1),
            date.day,
            (v) => update(day: v)),
        ruler(
            '${date.year}',
            List.generate(DateTime.now().year - 1899, (i) => 1900 + i),
            date.year,
            (v) => update(year: v)),
        if (!BirthdayStep.eligible(widget.value))
          const Text('You need to be at least 13 to use HolyHim.'),
      ]);
}

/// The value a ruler currently reads, centred above it.
class _RulerSection extends StatelessWidget {
  final String displayValue;
  final Color accent;

  const _RulerSection({required this.displayValue, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Center(
        child: Text(
          displayValue,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
      ),
    );
  }
}

/// Horizontal scroll-ruler with a centred selection tick, ported unchanged
/// from SunRize's `birthday_step.dart` — the geometry (tick height falloff,
/// centre snap, edge fade) is what makes it read as a physical dial rather
/// than a list, and none of that is theme-specific.
class _RulerPicker extends StatefulWidget {
  final List<int> items;
  final int selectedValue;
  final Color accent;
  final ValueChanged<int> onChange;

  /// The value under the centre tick while dragging, or null once the ruler
  /// has settled and [onChange] has taken over. Never persisted.
  final ValueChanged<int?> onPreview;

  static const double itemWidth = 20;

  const _RulerPicker({
    required this.items,
    required this.selectedValue,
    required this.accent,
    required this.onChange,
    required this.onPreview,
  });

  @override
  State<_RulerPicker> createState() => _RulerPickerState();
}

class _RulerPickerState extends State<_RulerPicker> {
  late ScrollController _scrollController;
  double _exactValue = 0;
  late int _lastCommittedValue;
  late int _lastPreviewedValue;

  @override
  void initState() {
    super.initState();
    final idx = widget.items.indexOf(widget.selectedValue);
    _exactValue = (idx >= 0 ? idx : 0).toDouble();
    _lastCommittedValue = widget.selectedValue;
    _lastPreviewedValue = widget.selectedValue;
    _scrollController = ScrollController(
      initialScrollOffset: _exactValue * _RulerPicker.itemWidth,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _RulerPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedValue != widget.selectedValue) {
      _lastCommittedValue = widget.selectedValue;
      _lastPreviewedValue = widget.selectedValue;
    }
    if (oldWidget.items.length != widget.items.length) {
      final idx = widget.items.indexOf(widget.selectedValue);
      if (idx >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              idx * _RulerPicker.itemWidth,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  void _onScroll() {
    final scrollLeft = _scrollController.offset;
    final exact = scrollLeft / _RulerPicker.itemWidth;
    setState(() => _exactValue = exact);

    if (widget.items.isEmpty) return;
    final value = widget.items[exact.round().clamp(0, widget.items.length - 1)];
    if (value != _lastPreviewedValue) {
      _lastPreviewedValue = value;
      widget.onPreview(value);
    }
  }

  void _snapToNearest() {
    if (!_scrollController.hasClients || widget.items.isEmpty) return;
    final exact = _scrollController.offset / _RulerPicker.itemWidth;
    final nearestIndex = exact.round().clamp(0, widget.items.length - 1);
    final targetOffset = nearestIndex * _RulerPicker.itemWidth;
    if ((_scrollController.offset - targetOffset).abs() > 0.5) {
      _scrollController.animateTo(
        targetOffset.toDouble(),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
      // The snap animation emits its own ScrollEndNotification. Commit from
      // that notification so one gesture produces one persisted value.
      return;
    }

    final newValue = widget.items[nearestIndex];
    if (newValue != _lastCommittedValue) {
      _lastCommittedValue = newValue;
      widget.onChange(newValue);
    } else {
      // Back on the value it started from: nothing to commit, but the label
      // may still be showing a preview of somewhere the drag passed through.
      widget.onPreview(null);
    }
    _lastPreviewedValue = newValue;
  }

  void _onTickTap(int index) {
    _scrollController.animateTo(
      index * _RulerPicker.itemWidth,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentWidth = MediaQuery.of(context).size.width - 28 * 2;
    final halfScreen = parentWidth / 2;
    final halfItem = _RulerPicker.itemWidth / 2;

    return SizedBox(
      height: 56,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _onScroll();
          if (notification is ScrollEndNotification) {
            Future.microtask(_snapToNearest);
          }
          return false;
        },
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0.0, 0.12, 0.88, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const _CappedFlingPhysics(),
            itemCount: widget.items.length + 2, // leading + trailing spacer
            itemBuilder: (context, index) {
              if (index == 0) return SizedBox(width: halfScreen - halfItem);
              if (index == widget.items.length + 1) {
                return SizedBox(width: halfScreen - halfItem);
              }

              final itemIndex = index - 1;
              final distance = (itemIndex - _exactValue).abs();
              final isCenter = distance < 0.5;

              const maxHeight = 38.0;
              const minHeight = 4.0;

              // Normalize the falloff to the available range: the twelve-month
              // ruler reaches the same circular end points as day/year.
              final endDistance = (_exactValue > (widget.items.length - 1) / 2
                  ? _exactValue
                  : widget.items.length - 1 - _exactValue);
              final falloff = endDistance.clamp(1.0, 8.5);
              final normalized = (38.0 - distance * 34.0 / falloff)
                  .clamp(minHeight, maxHeight);
              final height = isCenter ? 46.0 : normalized;
              final isDot = !isCenter && height <= 6;
              final width = isCenter ? 4.0 : (isDot ? height : 2.5);
              final opacity = (1 - distance * 0.08).clamp(0.15, 1.0);

              return GestureDetector(
                onTap: () => _onTickTap(itemIndex),
                child: SizedBox(
                  width: _RulerPicker.itemWidth,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      height: height,
                      width: width,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(height / 2),
                        color: isCenter
                            ? widget.accent
                            : HolyThemeScope.of(context)
                                .muted
                                .withValues(alpha: opacity),
                        boxShadow: isCenter
                            ? [
                                BoxShadow(
                                  color: widget.accent.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Caps how far a single flick can carry the ruler.
///
/// [ClampingScrollSimulation]'s travel distance grows with the initial
/// velocity, so on the year ruler — well over a hundred items wide — an
/// accidental hard flick could fling the selection by decades in one gesture,
/// tripping [AgeStep.isEligible] and interrupting onboarding. Clamping only
/// changed what happens at the list's edges (a hard stop instead of an
/// overscroll spring); it never limited mid-list travel. Capping the velocity
/// fed into the simulation bounds that travel to a handful of items even at
/// the fastest recorded flick, while ordinary slower drags — already well
/// under the cap — are untouched.
class _CappedFlingPhysics extends ClampingScrollPhysics {
  const _CappedFlingPhysics({super.parent});

  static const double _maxFlingVelocity = 700.0;

  @override
  _CappedFlingPhysics applyTo(ScrollPhysics? ancestor) =>
      _CappedFlingPhysics(parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final capped = velocity.clamp(-_maxFlingVelocity, _maxFlingVelocity);
    return super.createBallisticSimulation(position, capped);
  }
}
