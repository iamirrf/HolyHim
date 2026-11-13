import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/lessons.g.dart';
import '../../design/design.dart';
import '../../domain/lesson.dart';
import '../../services/repository.dart';
import '../../services/auth_service.dart';
import '../../services/share_card.dart';
import '../common.dart';

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});
  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  bool _searching = false;
  double _offset = 0;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (mounted) setState(() => _offset = _scroll.offset);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _detail(Lesson lesson) {
    glassSheet<void>(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Eyebrow('Day ${lesson.day} · A word to keep'),
          const SizedBox(height: 20),
          Text(lesson.verse, style: HolyTypography.verse),
          const SizedBox(height: 18),
          Text('${lesson.reference} · WEB',
              style: ui(context).copyWith(color: rose, fontSize: 14)),
          const SizedBox(height: 28),
          ActionButton('Open the lesson', icon: CupertinoIcons.book,
              onPressed: () {
            Navigator.pop(context);
            context.push('/lesson/${lesson.day}');
          }),
          const SizedBox(height: 12),
          ActionButton('Share this word',
              secondary: true,
              icon: CupertinoIcons.square_arrow_up,
              onPressed: () => shareVerseCard(context, lesson)),
          const SizedBox(height: 10),
          Center(
              child: TextButton(
                  onPressed: () {
                    final container =
                        ProviderScope.containerOf(context, listen: false);
                    final account = container.read(authProvider).user?.uid;
                    final repository =
                        container.read(repositoryProvider.notifier);
                    repository.toggleSaved(lesson.day);
                    Navigator.pop(context);
                    toast(context, 'Verse removed from Saved.', undo: () {
                      if (container.read(authProvider).user?.uid == account &&
                          !container
                              .read(repositoryProvider)
                              .saved
                              .containsKey(lesson.day)) {
                        container
                            .read(repositoryProvider.notifier)
                            .toggleSaved(lesson.day);
                      }
                    });
                  },
                  child: const Text('Remove from Saved')))
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(repositoryProvider);
    final query = _search.text.trim().toLowerCase();
    final saved =
        state.saved.keys.map(lessonForDay).whereType<Lesson>().where((lesson) {
      return query.isEmpty ||
          '${lesson.title} ${lesson.reference} ${lesson.verse} ${lesson.theme}'
              .toLowerCase()
              .contains(query);
    }).toList()
          ..sort((a, b) => state.saved[b.day]!.compareTo(state.saved[a.day]!));
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: GlassTopBar(
            automaticallyImplyLeading: false,
            centerTitle: false,
            title: _searching
                ? CupertinoSearchTextField(
                    controller: _search,
                    autofocus: true,
                    placeholder: 'Words, reference or theme',
                    onChanged: (_) => setState(() {}),
                    style: ui(context).copyWith(fontSize: 14))
                : const Text('Saved', style: HolyTypography.title),
            scrollOffset: _offset,
            trailing: IconButton(
                tooltip: _searching ? 'Close search' : 'Search saved verses',
                onPressed: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) _search.clear();
                    }),
                icon: Icon(_searching
                    ? CupertinoIcons.xmark
                    : CupertinoIcons.search))),
        body: PageBody(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.paddingOf(context).top + 86, 24, 150),
            children: [
              const Eyebrow('Words for another day'),
              const SizedBox(height: 12),
              const Text('Keep what\nstays with you.',
                  style: HolyTypography.display),
              const SizedBox(height: 14),
              Text('A little collection of Scripture to return to.',
                  style: muted(context)),
              const SizedBox(height: 30),
              if (state.saved.isEmpty)
                _EmptySaved(onBegin: () => context.go('/'))
              else if (saved.isEmpty)
                Glass(
                    child: Column(children: [
                  const Icon(CupertinoIcons.search, size: 32, color: rose),
                  const SizedBox(height: 16),
                  const Text('No verses found.', style: HolyTypography.title),
                  const SizedBox(height: 10),
                  Text('Try a word, Bible reference or theme.',
                      textAlign: TextAlign.center, style: muted(context))
                ]))
              else ...[
                Text(
                    '${saved.length} ${saved.length == 1 ? 'verse' : 'verses'} kept',
                    style: muted(context)),
                const SizedBox(height: 16),
                for (var index = 0; index < saved.length; index++)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Reveal(
                          index: index.clamp(0, 5),
                          child: _SavedCard(
                              lesson: saved[index],
                              onPressed: () => _detail(saved[index]))))
              ]
            ]));
  }
}

class _SavedCard extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback onPressed;
  const _SavedCard({required this.lesson, required this.onPressed});
  @override
  Widget build(BuildContext context) => Pressable(
      onPressed: onPressed,
      semanticLabel: '${lesson.reference}. Open saved verse.',
      child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
              height:
                  MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 360 : 270,
              child: ArtImage(
                  day: lesson.day,
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Eyebrow(
                                      'Day ${lesson.day} · ${lesson.theme}')),
                              const Icon(CupertinoIcons.heart_fill,
                                  size: 18, color: rose)
                            ]),
                            const SizedBox(height: 22),
                            Expanded(
                                child: Text('“${lesson.verse}”',
                                    maxLines: 5,
                                    overflow: TextOverflow.ellipsis,
                                    style: HolyTypography.reading)),
                            const SizedBox(height: 18),
                            Row(children: [
                              Expanded(
                                  child: Text(lesson.reference,
                                      style: ui(context).copyWith(
                                          fontSize: 13, color: rose))),
                              const Icon(CupertinoIcons.arrow_up_right,
                                  size: 18, color: rose)
                            ])
                          ]))))));
}

class _EmptySaved extends StatelessWidget {
  final VoidCallback onBegin;
  const _EmptySaved({required this.onBegin});
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SceneArt(
          scene: 'saved-empty',
          fallback: const SizedBox.expand(),
          child: Glass(
              elevation: 2,
              child: Column(children: [
                const SizedBox(height: 18),
                Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                            colors: [Color(0xFF171C22), Color(0xFFE8C766)]),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: rose.withValues(alpha: .15),
                              blurRadius: 30,
                              offset: const Offset(0, 12))
                        ]),
                    child: Stack(alignment: Alignment.center, children: [
                      Transform.rotate(
                          angle: -.14,
                          child: const Icon(CupertinoIcons.book_fill,
                              size: 58, color: rose)),
                      const Positioned(
                          right: 22,
                          top: 22,
                          child: Icon(CupertinoIcons.sparkles,
                              size: 20, color: Colors.white))
                    ])),
                const SizedBox(height: 28),
                const Text('A place for words\nyou want to keep.',
                    textAlign: TextAlign.center, style: HolyTypography.title),
                const SizedBox(height: 14),
                Text(
                    'Tap the heart in any lesson. Your saved verses will be waiting here.',
                    textAlign: TextAlign.center,
                    style: muted(context)),
                const SizedBox(height: 28),
                ActionButton('Return to your walk',
                    secondary: true, onPressed: onBegin),
                const SizedBox(height: 8)
              ]))));
}
