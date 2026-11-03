import 'package:holyher/features/home/verse_image_share.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:holyher/core/widgets/holy_navigation.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/core/widgets/holy_loader.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/features/lesson/lesson_screen.dart';
import 'package:holyher/services/saved_service.dart';

class SavedTab extends ConsumerStatefulWidget {
  final VoidCallback onLearn;
  const SavedTab({super.key, required this.onLearn});
  @override
  ConsumerState<SavedTab> createState() => _SavedTabState();
}

class _SavedTabState extends ConsumerState<SavedTab>
    with AutomaticKeepAliveClientMixin {
  String _query = '', _theme = 'All';
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _recent = true;
  @override
  bool get wantKeepAlive => true;
  Future<void> _remove(int day) async {
    try {
      await ref.read(savedProvider.notifier).setSaved(day, false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          margin: EdgeInsets.fromLTRB(
              16, 0, 16, holyNavigationReservation(context)),
          content: const Text('Removed from Saved'),
          action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                try {
                  await ref.read(savedProvider.notifier).setSaved(day, true);
                } catch (_) {
                  if (mounted) {
                    showNotice(context,
                        'That lesson could not be restored. Please retry saving it.');
                  }
                }
              })));
    } catch (_) {
      if (mounted) {
        showNotice(context, 'Your change could not be saved. Please retry.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    super.build(context);
    final saved = ref.watch(savedProvider);
    final rows = lessons
        .where((l) =>
            saved.days.containsKey(l.day) &&
            (_theme == 'All' || l.theme == _theme) &&
            '${l.title} ${l.verseReference} ${l.theme} ${l.day} ${l.verseText}'
                .toLowerCase()
                .contains(_query.toLowerCase()))
        .toList()
      ..sort((a, b) => _recent
          ? saved.days[b.day]!.compareTo(saved.days[a.day]!)
          : a.day.compareTo(b.day));
    final themes = lessons
        .where((l) => saved.days.containsKey(l.day))
        .map((l) => l.theme)
        .toSet()
        .toList()
      ..sort();
    return ReadingWidth(
        maxWidth: 1000,
        child: CustomScrollView(
            primary: true,
            key: const PageStorageKey('saved'),
            slivers: [
              SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverToBoxAdapter(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('Saved',
                                  style: HolyTypography.heading),
                              if (!saved.loading && saved.days.isNotEmpty)
                                Text('${saved.days.length} kept',
                                    style: HolyTypography.supporting.copyWith(
                                        color: AppColors.textSecondary))
                            ]),
                        const SizedBox(height: 20),
                        TextField(
                            controller: _search,
                            decoration: const InputDecoration(
                                labelText: 'Search saved lessons',
                                prefixIcon: Icon(Icons.search)),
                            onChanged: (v) => setState(() => _query = v)),
                        const SizedBox(height: 12),
                        Wrap(spacing: 12, children: [
                          PopupMenuButton<String>(
                              tooltip: 'Filter saved themes',
                              initialValue:
                                  themes.contains(_theme) ? _theme : 'All',
                              onSelected: (value) =>
                                  setState(() => _theme = value),
                              itemBuilder: (_) => [
                                    for (final theme in ['All', ...themes])
                                      PopupMenuItem(
                                          value: theme,
                                          child: Text(theme == 'All'
                                              ? 'All themes'
                                              : theme))
                                  ],
                              child: Container(
                                  constraints:
                                      const BoxConstraints(minHeight: 44),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                      color:
                                          AppColors.pearl.withValues(alpha: .8),
                                      borderRadius: BorderRadius.circular(22),
                                      border:
                                          Border.all(color: AppColors.divider)),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                            child: Text(
                                                _theme == 'All'
                                                    ? 'All themes'
                                                    : _theme,
                                                style: HolyTypography.action)),
                                        const SizedBox(width: 10),
                                        Icon(Icons.keyboard_arrow_down_rounded,
                                            size: 20,
                                            color: AppColors.textSecondary)
                                      ]))),
                          TextButton.icon(
                              onPressed: () =>
                                  setState(() => _recent = !_recent),
                              icon: const Icon(Icons.sort),
                              label:
                                  Text(_recent ? 'Recent first' : 'Day order'))
                        ]),
                        if (saved.error != null) InlineMessage(saved.error!),
                        if (saved.error != null || saved.pending.isNotEmpty)
                          TextButton(
                              onPressed: () =>
                                  ref.read(savedProvider.notifier).retryLoad(),
                              child: Text(saved.pending.isEmpty
                                  ? 'Retry'
                                  : '${saved.pending.length} changes pending · Retry')),
                        if (saved.loading)
                          const PulsingDotsLoader(
                              semanticsLabel: 'Loading saved lessons'),
                        if (!saved.loading &&
                            !saved.recoveryRequired &&
                            saved.days.isEmpty) ...[
                          const SizedBox(height: 24),
                          const Center(child: ReadingBookObject(width: 156)),
                          const SizedBox(height: 28),
                          const Center(
                              child: Text('Keep a verse close.',
                                  style: HolyTypography.section)),
                          const SizedBox(height: 12),
                          const Text('Save a lesson to find its words here.',
                              textAlign: TextAlign.center),
                          TextButton(
                              onPressed: widget.onLearn,
                              child: const Text('Go to Walk'))
                        ] else if (!saved.loading &&
                            !saved.recoveryRequired &&
                            saved.days.isNotEmpty &&
                            rows.isEmpty)
                          const Text('No saved lessons match your search.')
                      ]))),
              SliverLayoutBuilder(builder: (context, constraints) {
                final readingScale =
                    MediaQuery.textScalerOf(context).scale(22) / 22;
                final columns = ((constraints.crossAxisExtent - 36) /
                        (280 * readingScale + 12))
                    .floor()
                    .clamp(1, 3);
                // Natural-height rows preserve large text rather than forcing an aspect ratio.
                return SliverList.builder(
                    itemCount: (rows.length / columns).ceil(),
                    itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var col = 0; col < columns; col++)
                                Expanded(
                                    child: index * columns + col < rows.length
                                        ? Padding(
                                            padding: EdgeInsets.only(
                                                right:
                                                    col < columns - 1 ? 12 : 0),
                                            child: _row(
                                                rows[index * columns + col]))
                                        : const SizedBox())
                            ])));
              }),
              SliverToBoxAdapter(
                  child: SizedBox(height: holyNavigationReservation(context)))
            ]));
  }

  Widget _row(DailyLesson lesson) => HolyPressable(
        onPressed: () => showSavedVerseDetail(context, lesson,
            onRemove: () => _remove(lesson.day)),
        child: Container(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 24),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.divider))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Eyebrow('Day ${lesson.day} · ${lesson.theme}')),
                PopupMenuButton<String>(
                    tooltip: 'Verse actions',
                    onSelected: (value) {
                      if (value == 'remove') {
                        _remove(lesson.day);
                      } else if (value == 'share-image') {
                        shareVerseImage(context, lesson);
                      } else {
                        shareVerse(context, lesson);
                      }
                    },
                    itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'share', child: Text('Share text')),
                          PopupMenuItem(
                              value: 'share-image', child: Text('Share image')),
                          PopupMenuItem(
                              value: 'remove', child: Text('Remove from Saved'))
                        ])
              ]),
              const SizedBox(height: 12),
              Text(lesson.verseText,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: HolyTypography.scripture),
              const SizedBox(height: 16),
              Text(lesson.verseReference,
                  style: HolyTypography.supporting
                      .copyWith(color: AppColors.accentDark)),
              const SizedBox(height: 6),
              Text(lesson.title,
                  style: HolyTypography.supporting
                      .copyWith(color: AppColors.textSecondary)),
              if (ref.watch(savedProvider).pending.containsKey(lesson.day))
                const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('Saved on this device · waiting to sync',
                        style: HolyTypography.supporting)),
            ])),
      );
}

class SaveLessonButton extends ConsumerWidget {
  final int day;
  const SaveLessonButton({super.key, required this.day});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Theme.of(context);
    final saved = ref.watch(savedProvider).days.containsKey(day);
    return IconButton(
        tooltip: saved ? 'Remove saved lesson' : 'Save lesson',
        isSelected: saved,
        icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
        onPressed: () async {
          try {
            await ref.read(savedProvider.notifier).setSaved(day, !saved);
          } catch (_) {
            if (context.mounted) {
              showNotice(context,
                  'Your saved change could not be stored. Please retry.');
            }
          }
        });
  }
}

void shareVerse(BuildContext context, DailyLesson lesson) {
  final box = context.findRenderObject() as RenderBox?;
  SharePlus.instance.share(ShareParams(
      text:
          '${lesson.verseText}\n${lesson.verseReference}\nWorld English Bible (WEB)\nHolyHer · ${lesson.title}',
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size));
}

void showSavedVerseDetail(BuildContext context, DailyLesson lesson,
    {Future<void> Function()? onRemove}) {
  showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
          child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: .8,
              minChildSize: .4,
              maxChildSize: .95,
              builder: (c, scroll) => SingleChildScrollView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Eyebrow('Day ${lesson.day} · Saved Scripture'),
                        const SizedBox(height: 24),
                        Text(lesson.verseText, style: HolyTypography.scripture),
                        const SizedBox(height: 24),
                        Text(lesson.verseReference,
                            style: HolyTypography.action),
                        const SizedBox(height: 6),
                        const Text('World English Bible (WEB)',
                            style: HolyTypography.supporting),
                        const SizedBox(height: 24),
                        Text(lesson.title, style: HolyTypography.section),
                        const SizedBox(height: 28),
                        HolyButton(
                            label: 'Open lesson',
                            onPressed: () {
                              Navigator.pop(c);
                              final router = GoRouter.maybeOf(context);
                              if (router != null) {
                                router.go('/reading/${lesson.day}?from=saved');
                              } else {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) =>
                                        LessonScreen(lesson: lesson)));
                              }
                            }),
                        const SizedBox(height: 12),
                        HolyButton(
                            label: 'Share text',
                            secondary: true,
                            icon: Icons.ios_share,
                            onPressed: () => shareVerse(c, lesson)),
                        const SizedBox(height: 12),
                        HolyButton(
                            label: 'Share image',
                            secondary: true,
                            icon: Icons.image_outlined,
                            onPressed: () => shareVerseImage(c, lesson)),
                        if (onRemove != null)
                          TextButton(
                              onPressed: () async {
                                Navigator.pop(c);
                                await onRemove();
                              },
                              child: const Text('Remove from Saved')),
                      ])))));
}
