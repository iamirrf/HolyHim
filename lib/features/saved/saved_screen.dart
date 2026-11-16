import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/lessons.g.dart';
import '../../design/design.dart';
import '../../domain/pacing.dart';
import '../../services/repository.dart';
import '../../services/share_card.dart';
import '../share/share_sheet.dart';
import '../common.dart';

/// Saved verses as keepsake cards on a snap carousel.
class SavedScreen extends ConsumerStatefulWidget {
  /// Opened from Profile rather than as a tab: shows a way back.
  final VoidCallback? onBack;
  const SavedScreen({super.key, this.onBack});
  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  final pages = PageController(viewportFraction: .84);
  int page = 0;
  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  Future<void> _share(int day) => showShareSheet(context, lessons[day - 1]);

  void _remove(int day) {
    final repo = ref.read(repositoryProvider.notifier);
    repo.toggleSaved(day);
    HolyHaptics.chipDeselect();
    toast(context, 'Removed from Saved.', undo: () => repo.toggleSaved(day));
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final state = ref.watch(repositoryProvider);
    final media = MediaQuery.of(context);
    final days = state.saved.keys.toList()
      ..sort((a, b) => state.saved[b]!.compareTo(state.saved[a]!));
    final pacing =
        pacingFor(state.completed, DateTime.now(), state.profile.timeZone);
    if (page >= days.length && days.isNotEmpty) page = days.length - 1;
    return ColoredBox(
        color: backdropPaper(context, t),
        child: Padding(
            padding: EdgeInsets.only(
                top: media.padding.top + 16, bottom: media.padding.bottom),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: HolySpace.gutter),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (widget.onBack != null) ...[
                          IconControl(
                              icon: CupertinoIcons.chevron_left,
                              label: 'Back',
                              onPressed: widget.onBack!),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Eyebrow(days.isEmpty
                                  ? 'Keepsakes'
                                  : '${days.length} kept ${days.length == 1 ? 'verse' : 'verses'}'),
                              const SizedBox(height: 4),
                              Semantics(
                                  header: true,
                                  child: Text('Saved',
                                      style: HolyTypography.title
                                          .copyWith(color: t.ink))),
                            ])),
                        if (days.length > 1)
                          Text('${page + 1} of ${days.length}',
                              style: HolyTypography.label
                                  .copyWith(color: t.muted)),
                      ])),
              const SizedBox(height: 18),
              Expanded(
                  child: days.isEmpty
                      ? _Empty(onToday: () => context.push('/lesson/today'))
                      : PageView.builder(
                          controller: pages,
                          itemCount: days.length,
                          onPageChanged: (i) {
                            HolyHaptics.detent();
                            setState(() => page = i);
                          },
                          itemBuilder: (context, i) {
                            final day = days[i];
                            return AnimatedBuilder(
                                animation: pages,
                                builder: (context, child) {
                                  final p = pages.hasClients &&
                                          pages.position.haveDimensions
                                      ? (pages.page ?? 0) - i
                                      : (page - i).toDouble();
                                  final scale =
                                      1 - (p.abs() * .06).clamp(0.0, .06);
                                  return Transform.scale(
                                      scale: scale, child: child);
                                },
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 4),
                                    child: _Keepsake(
                                        day: day,
                                        saved: state.saved[day]!,
                                        canOpen: pacing.canRead(
                                            day, state.completed),
                                        onShare: () => _share(day),
                                        onRemove: () => _remove(day))));
                          })),
              const SizedBox(height: 12),
            ])));
  }
}

class _Keepsake extends StatelessWidget {
  final int day;
  final DateTime saved;
  final bool canOpen;
  final VoidCallback onShare, onRemove;
  const _Keepsake(
      {required this.day,
      required this.saved,
      required this.canOpen,
      required this.onShare,
      required this.onRemove});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final lesson = lessons[day - 1];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return Paper(
        padding: EdgeInsets.zero,
        lift: 1.3,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
              child: Stack(fit: StackFit.expand, children: [
            KeepsakeCard(lesson: lesson),
          ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Day $day · ${lesson.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HolyTypography.label.copyWith(color: t.ink)),
                      Text('Kept ${months[saved.month - 1]} ${saved.day}',
                          style:
                              HolyTypography.caption.copyWith(color: t.muted)),
                    ])),
                if (canOpen)
                  IconControl(
                      icon: CupertinoIcons.book,
                      label: 'Open Day $day',
                      size: 42,
                      onPressed: () => context.push('/lesson/$day')),
                const SizedBox(width: 6),
                IconControl(
                    icon: CupertinoIcons.square_arrow_up,
                    label: 'Share',
                    size: 42,
                    onPressed: onShare),
                const SizedBox(width: 6),
                IconControl(
                    icon: CupertinoIcons.heart_slash,
                    label: 'Remove from Saved',
                    size: 42,
                    onPressed: onRemove),
              ])),
        ]));
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onToday;
  const _Empty({required this.onToday});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return FitColumn(children: [
      const Spacer(),
      Center(
          child: ClipRRect(
              borderRadius: BorderRadius.circular(HolyRadius.photo),
              child: SizedBox(
                  width: 200,
                  height: 250,
                  child: Image.asset(
                      'assets/art/library/scripture-morning.webp',
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (c, e, s) => ColoredBox(color: t.sunk))))),
      const SizedBox(height: 26),
      Text('Words worth keeping',
          textAlign: TextAlign.center,
          style: HolyTypography.headline.copyWith(color: t.ink)),
      const SizedBox(height: 8),
      Text(
          'When a verse speaks to you, tap the heart in the lesson. It will wait for you here.',
          textAlign: TextAlign.center,
          style: HolyTypography.body.copyWith(color: t.muted)),
      const SizedBox(height: 22),
      HolyButton.secondary('Open today’s lesson', onPressed: onToday),
      const Spacer(),
    ]);
  }
}
