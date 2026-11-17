import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../design/art_catalog.dart';
import '../../design/design.dart';
import '../../domain/lesson.dart';
import '../../services/share_card.dart';

/// Opens the share sheet for [lesson]'s verse.
Future<void> showShareSheet(BuildContext context, Lesson lesson) {
  HolyHaptics.tap();
  return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0x00000000),
      barrierColor: const Color(0x73000000),
      builder: (_) => ShareSheet(lesson: lesson));
}

/// His keepsake, shown exactly as it will be sent: three looks, two shapes
/// and one button. The HolyHim icon and wordmark travel on every card, so a
/// verse passed to a friend also tells him where it came from.
class ShareSheet extends StatefulWidget {
  final Lesson lesson;
  final KeepsakeLook initialLook;
  final KeepsakeStyle initialStyle;
  const ShareSheet(
      {super.key,
      required this.lesson,
      this.initialLook = KeepsakeLook.photo,
      this.initialStyle = KeepsakeStyle.story});
  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  late KeepsakeLook look = widget.initialLook;
  late KeepsakeStyle style = widget.initialStyle;
  bool busy = false;

  Future<void> share() async {
    if (busy) return;
    setState(() => busy = true);
    HolyHaptics.buttonPress();
    try {
      await shareVerseCard(context, widget.lesson, style: style, look: look);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final media = MediaQuery.of(context);
    final story = style == KeepsakeStyle.story;
    return Container(
        height: media.size.height * .92,
        decoration: BoxDecoration(
            color: t.paper,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 30)
            ]),
        child: Padding(
            padding: EdgeInsets.fromLTRB(HolySpace.gutter, 10, HolySpace.gutter,
                media.padding.bottom + 14),
            child: Column(children: [
              Container(
                  width: 38,
                  height: 5,
                  decoration: BoxDecoration(
                      color: t.hairline,
                      borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: Semantics(
                        header: true,
                        child: Text('Share today’s word',
                            style: HolyTypography.title
                                .copyWith(color: t.ink, fontSize: 28)))),
                IconControl(
                    icon: CupertinoIcons.xmark,
                    label: 'Close',
                    onPressed: () => Navigator.of(context).pop()),
              ]),
              const SizedBox(height: 4),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      'Every share puts a word in another man’s hands.',
                      style: HolyTypography.ui
                          .copyWith(color: t.muted, fontSize: 14.5))),
              const SizedBox(height: 16),
              Expanded(child: LayoutBuilder(builder: (context, box) {
                final ratio = story ? 9 / 16 : 1.0;
                var w = box.maxWidth, h = w / ratio;
                if (h > box.maxHeight) {
                  h = box.maxHeight;
                  w = h * ratio;
                }
                return Center(
                    child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        child: _Preview(
                            key: ValueKey('$look-$style'),
                            lesson: widget.lesson,
                            look: look,
                            style: style,
                            width: w,
                            height: h)));
              })),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final option in KeepsakeLook.values) ...[
                  _LookChip(
                      look: option,
                      day: widget.lesson.day,
                      selected: option == look,
                      onPressed: () {
                        HolyHaptics.chipSelect();
                        setState(() => look = option);
                      }),
                  if (option != KeepsakeLook.values.last)
                    const SizedBox(width: 14),
                ],
              ]),
              const SizedBox(height: 14),
              SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<KeepsakeStyle>(
                      groupValue: style,
                      thumbColor: t.surface,
                      backgroundColor: t.sunk,
                      children: {
                        KeepsakeStyle.story: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text('Story',
                                style: HolyTypography.label.copyWith(
                                    color: t.ink,
                                    fontWeight: FontWeight.w700))),
                        KeepsakeStyle.square: Text('Post',
                            style: HolyTypography.label.copyWith(
                                color: t.ink, fontWeight: FontWeight.w700)),
                      },
                      onValueChanged: (value) {
                        if (value == null) return;
                        HolyHaptics.chipSelect();
                        setState(() => style = value);
                      })),
              const SizedBox(height: 14),
              HolyButton('Share',
                  loading: busy,
                  leading: const Icon(CupertinoIcons.square_arrow_up, size: 20),
                  semanticLabel: 'Share this keepsake',
                  onPressed: busy ? null : share),
            ])));
  }
}

/// The keepsake at its real size, scaled into the sheet, so the preview is
/// the picture that is sent.
class _Preview extends StatelessWidget {
  final Lesson lesson;
  final KeepsakeLook look;
  final KeepsakeStyle style;
  final double width, height;
  const _Preview(
      {super.key,
      required this.lesson,
      required this.look,
      required this.style,
      required this.width,
      required this.height});
  @override
  Widget build(BuildContext context) {
    final logical = style == KeepsakeStyle.story
        ? const Size(360, 640)
        : const Size(360, 360);
    return Semantics(
        image: true,
        label: 'Keepsake of ${lesson.reference}',
        child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 28,
                      offset: Offset(0, 14))
                ]),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: FittedBox(
                    child: SizedBox.fromSize(
                        size: logical,
                        child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                                size: logical,
                                textScaler: TextScaler.noScaling),
                            child: KeepsakeCard(
                                lesson: lesson, style: style, look: look)))))));
  }
}

class _LookChip extends StatelessWidget {
  final KeepsakeLook look;
  final int day;
  final bool selected;
  final VoidCallback onPressed;
  const _LookChip(
      {required this.look,
      required this.day,
      required this.selected,
      required this.onPressed});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final label = switch (look) {
      KeepsakeLook.photo => 'Photo',
      KeepsakeLook.paper => 'Stone',
      KeepsakeLook.night => 'Night',
    };
    final swatch = switch (look) {
      KeepsakeLook.photo => Image.asset(HolyArtCatalog.thumbnailForDay(day),
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => ColoredBox(color: t.sunk)),
      KeepsakeLook.paper => const DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF3F0EA), Color(0xFFE2DDD3)]))),
      KeepsakeLook.night => const DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1C2A3D), Color(0xFF0A0E14)]))),
    };
    return Pressable(
        onPressed: onPressed,
        selected: selected,
        semanticLabel: '$label look',
        child: Column(children: [
          AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 58,
              height: 58,
              padding: EdgeInsets.all(selected ? 3 : 0),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: selected ? t.accent : t.hairline,
                      width: selected ? 2 : 1)),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(selected ? 14 : 17),
                  child: swatch)),
          const SizedBox(height: 6),
          Text(label,
              style: HolyTypography.caption.copyWith(
                  color: selected ? t.ink : t.muted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        ]));
  }
}
