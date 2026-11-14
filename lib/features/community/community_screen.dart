import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../design/design.dart';
import '../../design/widgets/coin.dart';
import '../../design/widgets/glass.dart';
import '../../design/widgets/holy_header.dart';
import '../../domain/streak.dart';
import '../../services/auth_service.dart';
import '../../services/avatar_service.dart';
import '../../services/community.dart';
import '../../services/repository.dart';
import '../common.dart';
import 'community_widgets.dart';

/// The brothers: a feed of words, prayers and wins from men walking the same
/// road, after Cognein's community.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});
  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  FeedQuery query = const FeedQuery();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(repositoryProvider);
    final streak =
        streakFor(state.completed, DateTime.now(), state.profile.timeZone);
    final me = ref.watch(myMemberProvider);
    // Keep his numbers on the board in step with his walk.
    ref.listen(myMemberProvider, (_, next) {
      final member = next.valueOrNull;
      if (member != null) ref.read(communityProvider).syncStats(member).ignore();
    });
    final joined = me.valueOrNull != null;
    return Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: HolyHeader(streak: streak.current, actions: [
          if (joined)
            HeaderButton(
                icon: CupertinoIcons.square_pencil,
                label: 'New post',
                onPressed: () => showComposer(context, ref)),
        ]),
        body: me.isLoading && !me.hasValue
            ? const Center(child: HolySpinner())
            : joined
                ? _Feed(
                    query: query,
                    onQuery: (q) => setState(() => query = q))
                : const _Welcome());
  }
}

class _Feed extends ConsumerWidget {
  final FeedQuery query;
  final ValueChanged<FeedQuery> onQuery;
  const _Feed({required this.query, required this.onQuery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = HolyThemeScope.of(context);
    final posts = ref.watch(feedProvider(query));
    final media = MediaQuery.of(context);
    return RefreshIndicator.adaptive(
        edgeOffset: HolyHeader.inset(context),
        color: t.accent,
        onRefresh: () async {
          ref.invalidate(feedSourceProvider(query));
          await Future<void>.delayed(const Duration(milliseconds: 500));
        },
        child: CustomScrollView(
            key: const PageStorageKey('brothers'),
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                  child: SizedBox(height: HolyHeader.inset(context))),
              SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.list(children: [
                    const _ComposePrompt(),
                    const SizedBox(height: 14),
                    _FilterBar(query: query, onQuery: onQuery),
                    const SizedBox(height: 14),
                  ])),
              ...posts.when(
                  loading: () => [
                        const SliverToBoxAdapter(
                            child: Padding(
                                padding: EdgeInsets.only(top: 60),
                                child: Center(child: HolySpinner())))
                      ],
                  error: (e, _) => [
                        const SliverToBoxAdapter(
                            child: _Empty(
                                icon: CupertinoIcons.wifi_exclamationmark,
                                title: 'The feed did not load',
                                line: 'Check your connection, then pull to refresh.'))
                      ],
                  data: (list) => list.isEmpty
                      ? [
                          SliverToBoxAdapter(
                              child: _Empty(
                                  icon: query.mine
                                      ? CupertinoIcons.square_pencil
                                      : query.prayers
                                          ? CupertinoIcons.hand_raised_fill
                                          : CupertinoIcons.person_2_fill,
                                  title: query.mine
                                      ? 'Make your first post'
                                      : query.prayers
                                          ? 'No prayer requests yet'
                                          : 'Start the conversation',
                                  line: query.mine
                                      ? 'What you share shows up here.'
                                      : 'Be the first brother to share today.'))
                        ]
                      : [
                          SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                  16, 0, 16, media.padding.bottom + 20),
                              sliver: SliverList.separated(
                                  itemCount: list.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, i) => Rise(
                                      index: i.clamp(0, 6),
                                      child: PostCard(post: list[i])))),
                        ]),
            ]));
  }
}

/// "Share a word, a prayer or a win", with his own coin beside it.
class _ComposePrompt extends ConsumerWidget {
  const _ComposePrompt();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = HolyThemeScope.of(context);
    final me = ref.watch(myMemberProvider).valueOrNull;
    return Glass(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(children: [
          Pressable(
              onPressed: () => showComposer(context, ref),
              semanticLabel: 'Write a post',
              pressedScale: .99,
              child: Row(children: [
                MemberAvatar(
                    name: me?.name ?? '',
                    metal: me?.metal ?? 'brass',
                    photo: me?.photo,
                    size: 42),
                const SizedBox(width: 12),
                Expanded(
                    child: Container(
                        height: 42,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                            color: t.ink.withValues(alpha: .05),
                            borderRadius: BorderRadius.circular(21),
                            border: Border.all(color: t.ink.withValues(alpha: .08))),
                        child: Text('Share with the brothers…',
                            style: HolyTypography.body.copyWith(color: t.muted)))),
              ])),
          const SizedBox(height: 10),
          Row(children: [
            for (final k in PostKind.values) ...[
              if (k != PostKind.word) const SizedBox(width: 8),
              Expanded(
                  child: Pressable(
                      onPressed: () => showComposer(context, ref, kind: k),
                      semanticLabel: 'Share a ${k.label.toLowerCase()}',
                      child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: t.ink.withValues(alpha: .04)),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(kindIcon(k), size: 14, color: t.accent),
                                const SizedBox(width: 6),
                                Text(k.label,
                                    style: HolyTypography.label.copyWith(
                                        color: t.ink, fontWeight: FontWeight.w700)),
                              ])))),
            ],
          ]),
        ]));
  }
}

/// Cognein's filter bar: whose posts, in what order, and prayers only.
class _FilterBar extends StatelessWidget {
  final FeedQuery query;
  final ValueChanged<FeedQuery> onQuery;
  const _FilterBar({required this.query, required this.onQuery});

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    Widget segment(String label, bool on, VoidCallback tap) => Expanded(
        child: Semantics(
            button: true,
            selected: on,
            child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HolyHaptics.chipSelect();
                  tap();
                },
                child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: on ? t.accent.withValues(alpha: .18) : null,
                        borderRadius: BorderRadius.circular(14),
                        border: on
                            ? Border.all(color: t.accent.withValues(alpha: .5))
                            : null),
                    child: Text(label,
                        style: HolyTypography.label.copyWith(
                            color: on ? t.ink : t.muted,
                            fontWeight: FontWeight.w800))))));
    return SizedBox(
        height: 42,
        child: Row(children: [
          Expanded(
              flex: 5,
              child: Glass(
                  radius: 18,
                  padding: const EdgeInsets.all(3),
                  child: Row(children: [
                    segment('All', !query.mine,
                        () => onQuery(FeedQuery(sort: query.sort, prayers: query.prayers))),
                    segment('Mine', query.mine,
                        () => onQuery(FeedQuery(sort: query.sort, mine: true))),
                  ]))),
          const SizedBox(width: 8),
          Expanded(
              flex: 5,
              child: PopupMenuButton<FeedSort>(
                  tooltip: 'Sort',
                  color: t.surface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  onSelected: (s) {
                    HolyHaptics.chipSelect();
                    onQuery(FeedQuery(sort: s, mine: query.mine, prayers: query.prayers));
                  },
                  itemBuilder: (_) => [
                        for (final s in FeedSort.values)
                          PopupMenuItem(
                              value: s,
                              child: Row(children: [
                                Icon(_sortIcon(s), size: 17, color: t.accent),
                                const SizedBox(width: 10),
                                Text(s.label,
                                    style: HolyTypography.ui.copyWith(
                                        color: t.ink,
                                        fontWeight: s == query.sort
                                            ? FontWeight.w800
                                            : FontWeight.w500)),
                              ])),
                      ],
                  child: Glass(
                      radius: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox.expand(
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(_sortIcon(query.sort), size: 15, color: t.accent),
                        const SizedBox(width: 6),
                        Flexible(
                            child: Text(query.sort.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HolyTypography.label.copyWith(
                                    color: t.ink, fontWeight: FontWeight.w800))),
                        const SizedBox(width: 2),
                        Icon(CupertinoIcons.chevron_down, size: 12, color: t.muted),
                      ]))))),
          const SizedBox(width: 8),
          Semantics(
              button: true,
              selected: query.prayers,
              label: 'Prayer requests only',
              excludeSemantics: true,
              child: GestureDetector(
                  onTap: () {
                    HolyHaptics.chipSelect();
                    onQuery(FeedQuery(sort: query.sort, prayers: !query.prayers));
                  },
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: query.prayers
                              ? LinearGradient(colors: [
                                  Color.lerp(t.accent, Colors.white, .2)!,
                                  t.accent
                                ])
                              : null,
                          color: query.prayers ? null : t.surface.withValues(alpha: .6),
                          border: Border.all(
                              color: query.prayers
                                  ? Colors.transparent
                                  : t.ink.withValues(alpha: .12))),
                      child: Icon(CupertinoIcons.hand_raised_fill,
                          size: 17,
                          color: query.prayers ? t.onPrimary : t.muted)))),
        ]));
  }

  static IconData _sortIcon(FeedSort s) => switch (s) {
        FeedSort.newest => CupertinoIcons.clock_fill,
        FeedSort.top => CupertinoIcons.hand_raised_fill,
        FeedSort.trending => CupertinoIcons.flame_fill,
      };
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title, line;
  const _Empty({required this.icon, required this.title, required this.line});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Padding(
        padding: const EdgeInsets.fromLTRB(32, 44, 32, 60),
        child: Column(children: [
          Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.accent.withValues(alpha: .12),
                  border: Border.all(color: t.accent.withValues(alpha: .3))),
              child: Icon(icon, size: 32, color: t.accent)),
          const SizedBox(height: 18),
          Text(title,
              textAlign: TextAlign.center,
              style: HolyTypography.headline.copyWith(color: t.ink, fontSize: 22)),
          const SizedBox(height: 6),
          Text(line,
              textAlign: TextAlign.center,
              style: HolyTypography.body.copyWith(color: t.muted)),
        ]));
  }
}

/// Before joining: what the brothers are, and the way in.
class _Welcome extends ConsumerWidget {
  const _Welcome();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = HolyThemeScope.of(context);
    final media = MediaQuery.of(context);
    Widget feature(IconData icon, String title, String line) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Glass(
            radius: 20,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.accent.withValues(alpha: .14),
                      border: Border.all(color: t.accent.withValues(alpha: .32))),
                  child: Icon(icon, size: 18, color: t.accent)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: HolyTypography.ui
                        .copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(line, style: HolyTypography.caption.copyWith(color: t.muted)),
              ])),
            ])));
    return ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            20, HolyHeader.inset(context) + 8, 20, media.padding.bottom + 20),
        children: [
          const SizedBox(
              height: 150,
              child: Stack(alignment: Alignment.center, children: [
                Positioned(
                    left: 24,
                    top: 34,
                    child: CoinBadge(
                        size: 74, metal: CoinMetal.silver, idle: true,
                        face: Icon(CupertinoIcons.hand_raised_fill))),
                Positioned(
                    right: 24,
                    top: 34,
                    child: CoinBadge(
                        size: 74, metal: CoinMetal.bronze, idle: true,
                        face: Icon(CupertinoIcons.flame_fill))),
                CoinBadge(
                    size: 112,
                    glow: .7,
                    idle: true,
                    face: Icon(CupertinoIcons.person_2_fill)),
              ])),
          const SizedBox(height: 12),
          Center(child: Eyebrow('Proverbs 27:17', color: t.accent)),
          const SizedBox(height: 8),
          Text('Iron sharpens iron',
              textAlign: TextAlign.center,
              style: HolyTypography.title.copyWith(color: t.ink, fontSize: 32)),
          const SizedBox(height: 8),
          Text('Men on the same road, keeping each other honest.',
              textAlign: TextAlign.center,
              style: HolyTypography.body.copyWith(color: t.muted)),
          const SizedBox(height: 22),
          feature(CupertinoIcons.book_fill, 'Share a word',
              'What hit you in today’s reading.'),
          feature(CupertinoIcons.hand_raised_fill, 'Ask for prayer',
              'Brothers pray, and tap to say so.'),
          feature(CupertinoIcons.flame_fill, 'Post a win',
              'Big or small, give God the credit.'),
          feature(Icons.emoji_events_rounded, 'Climb the board',
              'Streaks and days read, side by side.'),
          const SizedBox(height: 14),
          HolyButton('Join the brothers', onPressed: () => showJoinSheet(context, ref)),
          const SizedBox(height: 10),
          Text('Your name and coin are public here. Your reading stays private.',
              textAlign: TextAlign.center,
              style: HolyTypography.caption.copyWith(color: t.muted)),
        ]);
  }
}

/// A post on its own, with every reply and a place to answer.
class PostScreen extends ConsumerStatefulWidget {
  final String id;
  const PostScreen({super.key, required this.id});
  @override
  ConsumerState<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends ConsumerState<PostScreen> {
  final _text = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final problem = communityTextProblem(_text.text, max: 400);
    if (problem != null) {
      toast(context, problem);
      HolyHaptics.error();
      return;
    }
    setState(() => busy = true);
    try {
      await ref.read(communityProvider).reply(widget.id, _text.text);
      HolyHaptics.send();
      _text.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final post = ref.watch(postProvider(widget.id));
    final replies = ref.watch(repliesProvider(widget.id));
    final uid = ref.watch(authProvider.select((a) => a.user?.uid));
    final media = MediaQuery.of(context);
    return Scaffold(
        backgroundColor: t.paper,
        appBar: AppBar(
            backgroundColor: t.paper,
            surfaceTintColor: Colors.transparent,
            foregroundColor: t.ink,
            elevation: 0,
            leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(CupertinoIcons.chevron_back),
                onPressed: () => context.canPop() ? context.pop() : context.go('/brothers')),
            title: Text('Post',
                style: HolyTypography.ui
                    .copyWith(color: t.ink, fontWeight: FontWeight.w800))),
        body: Column(children: [
          Expanded(
              child: post.when(
                  loading: () => const Center(child: HolySpinner()),
                  error: (_, __) => const Center(child: Text('This post did not load.')),
                  data: (p) => p == null
                      ? Center(
                          child: Text('This post is gone.',
                              style: HolyTypography.body.copyWith(color: t.muted)))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            PostCard(post: p, expanded: true),
                            const SizedBox(height: 18),
                            Eyebrow(
                                p.comments == 1 ? '1 reply' : '${p.comments} replies',
                                color: t.muted),
                            const SizedBox(height: 10),
                            ...replies.when(
                                loading: () => [const Center(child: HolySpinner())],
                                error: (_, __) => [const SizedBox.shrink()],
                                data: (list) => [
                                      for (final r in list)
                                        _ReplyTile(reply: r, mine: r.authorId == uid,
                                            postAuthor: p.authorId == uid),
                                      if (list.isEmpty)
                                        Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 20),
                                            child: Text('No replies yet. Say something brotherly.',
                                                textAlign: TextAlign.center,
                                                style: HolyTypography.body
                                                    .copyWith(color: t.muted))),
                                    ]),
                          ]))),
          // Replying is for members; the composer asks everyone else to join.
          Container(
              padding: EdgeInsets.fromLTRB(
                  12, 10, 12, 10 + (media.viewInsets.bottom > 0 ? 0 : media.padding.bottom)),
              decoration: BoxDecoration(
                  color: t.surface,
                  border: Border(top: BorderSide(color: t.hairline))),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 400,
                        textCapitalization: TextCapitalization.sentences,
                        style: HolyTypography.body.copyWith(color: t.ink),
                        cursorColor: t.accent,
                        onTap: () {
                          if (ref.read(myMemberProvider).valueOrNull == null) {
                            FocusScope.of(context).unfocus();
                            showJoinSheet(context, ref);
                          }
                        },
                        decoration: InputDecoration(
                            counterText: '',
                            isDense: true,
                            hintText: 'Reply as a brother…',
                            hintStyle: HolyTypography.body.copyWith(color: t.muted),
                            filled: true,
                            fillColor: t.ink.withValues(alpha: .05),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none)))),
                const SizedBox(width: 8),
                IconButton.filled(
                    tooltip: 'Send reply',
                    style: IconButton.styleFrom(
                        backgroundColor: t.accent, foregroundColor: t.onPrimary),
                    onPressed: busy ? null : _send,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(CupertinoIcons.paperplane_fill, size: 18)),
              ])),
        ]));
  }
}

class _ReplyTile extends ConsumerWidget {
  final Reply reply;
  final bool mine, postAuthor;
  const _ReplyTile(
      {required this.reply, required this.mine, required this.postAuthor});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = HolyThemeScope.of(context);
    final uid = ref.watch(authProvider.select((a) => a.user?.uid));
    final amened = reply.amenBy.contains(uid);
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
              onTap: () => showMemberCard(context, ref, reply.authorId),
              child: MemberAvatar(
                  name: reply.authorName,
                  metal: reply.authorMetal,
                  photo: reply.authorPhoto,
                  size: 34)),
          const SizedBox(width: 10),
          Expanded(
              child: GestureDetector(
                  onLongPress: () => HolyDialogs.actions(context, choices: {
                        if (mine || postAuthor)
                          'Delete reply': () async {
                            try {
                              await ref
                                  .read(communityProvider)
                                  .delete(reply.postId, replyId: reply.id);
                            } catch (e) {
                              if (context.mounted) toast(context, '$e');
                            }
                          },
                        if (!mine)
                          'Report reply': () => showReport(context, ref,
                              postId: reply.postId, replyId: reply.id),
                        if (!mine)
                          'Block ${reply.authorName}': () => confirmBlock(
                              context, ref, reply.authorId, reply.authorName),
                      }),
                  child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      decoration: BoxDecoration(
                          color: t.surface.withValues(alpha: .8),
                          borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(18),
                              bottomLeft: Radius.circular(18),
                              bottomRight: Radius.circular(18),
                              topLeft: Radius.circular(6)),
                          border: Border.all(color: t.hairline)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(child: MemberName(name: reply.authorName, size: 13.5)),
                          const SizedBox(width: 6),
                          Text(timeAgo(reply.createdAt),
                              style: HolyTypography.caption.copyWith(color: t.muted)),
                        ]),
                        const SizedBox(height: 4),
                        Text(reply.text,
                            style: HolyTypography.body
                                .copyWith(color: t.ink, height: 1.4)),
                      ])))),
          const SizedBox(width: 4),
          Column(children: [
            IconButton(
                tooltip: amened ? 'Remove your Amen' : 'Say Amen',
                visualDensity: VisualDensity.compact,
                onPressed: () => withMembership(context, ref, () async {
                      HolyHaptics.chipSelect();
                      try {
                        await ref.read(communityProvider).amenReply(reply);
                      } catch (e) {
                        if (context.mounted) toast(context, '$e');
                      }
                    }),
                icon: Icon(CupertinoIcons.hand_raised_fill,
                    size: 16, color: amened ? t.accent : t.muted)),
            if (reply.amens > 0)
              Text('${reply.amens}',
                  style: HolyTypography.caption
                      .copyWith(color: amened ? t.accent : t.muted)),
          ]),
        ]));
  }
}

/// Brothers you have blocked, and the way back.
class BlockedScreen extends ConsumerWidget {
  const BlockedScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = HolyThemeScope.of(context);
    final hidden = ref.watch(hiddenProvider).valueOrNull ?? const Hidden();
    return ScreenFrame(
        title: 'Blocked',
        subtitle: 'They cannot see that you blocked them.',
        scroll: true,
        children: [
          if (hidden.users.isEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text('No one is blocked.',
                    style: HolyTypography.body.copyWith(color: t.muted))),
          for (final uid in hidden.users)
            FutureBuilder<Member?>(
                future: ref.read(communityProvider).member(uid),
                builder: (context, snap) {
                  final m = snap.data;
                  return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Glass(
                          radius: 20,
                          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                          child: Row(children: [
                            MemberAvatar(
                                name: m?.name ?? '?',
                                metal: m?.metal ?? 'steel',
                                photo: m?.photo,
                                size: 38),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(m?.name ?? 'A former member',
                                    style: HolyTypography.ui.copyWith(
                                        color: t.ink, fontWeight: FontWeight.w700))),
                            TextAction('Unblock', onPressed: () async {
                              await ref.read(communityProvider).unblock(uid);
                              if (context.mounted) toast(context, 'Unblocked.');
                            }),
                          ])));
                }),
        ]);
  }
}

/// His public card: the name and coin the brothers see.
class CommunityCardScreen extends ConsumerStatefulWidget {
  const CommunityCardScreen({super.key});
  @override
  ConsumerState<CommunityCardScreen> createState() => _CommunityCardScreenState();
}

class _CommunityCardScreenState extends ConsumerState<CommunityCardScreen> {
  TextEditingController? _name;
  String? metal;
  bool busy = false;

  @override
  void dispose() {
    _name?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final me = ref.watch(myMemberProvider).valueOrNull;
    if (me == null) {
      return ScreenFrame(title: 'Your card', children: [
        Text('Join the brothers to make your card.',
            style: HolyTypography.body.copyWith(color: t.muted)),
        const SizedBox(height: 16),
        HolyButton('Join the brothers', onPressed: () => showJoinSheet(context, ref)),
      ]);
    }
    _name ??= TextEditingController(text: me.name);
    final chosen = metal ?? me.metal;
    final profile = ref.watch(repositoryProvider).profile;
    final auth = ref.watch(authProvider).user;
    final photo = visibleAvatarUrl(profile.avatarUrl, auth?.photoUrl);
    return ScreenFrame(
        title: 'Your card',
        subtitle: 'This is what the brothers see.',
        scroll: true,
        children: [
          Center(
              child: MemberAvatar(
                  name: _name!.text,
                  metal: chosen,
                  photo: me.photo,
                  size: 96,
                  glow: .5)),
          const SizedBox(height: 18),
          HolyField(
              controller: _name!,
              label: 'Name',
              maxLength: 24,
              capitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 14),
          Eyebrow('Coin', color: t.muted),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (final m in memberMetals)
              GestureDetector(
                  onTap: () => setState(() => metal = m),
                  child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: chosen == m ? t.accent : Colors.transparent,
                              width: 2)),
                      child: MemberAvatar(name: _name!.text, metal: m, size: 48))),
          ]),
          const SizedBox(height: 14),
          RowGroup(rows: [
            HolyRow(
                icon: CupertinoIcons.photo,
                title: me.photo == null ? 'Show my profile photo' : 'Hide my profile photo',
                onPressed: photo == null && me.photo == null
                    ? null
                    : () async {
                        await ref
                            .read(communityProvider)
                            .updateCard(photo: me.photo == null ? (photo ?? '') : '');
                      }),
          ]),
          const SizedBox(height: 18),
          HolyButton('Save', loading: busy, onPressed: () async {
            final name = _name!.text.trim();
            final problem = name.length < 2
                ? 'Add the name brothers will see.'
                : communityTextProblem(name, max: 24);
            if (problem != null) {
              toast(context, problem);
              return;
            }
            setState(() => busy = true);
            try {
              await ref.read(communityProvider).updateCard(name: name, metal: chosen);
              if (context.mounted) toast(context, 'Your card is saved.');
            } catch (e) {
              if (context.mounted) toast(context, '$e');
            } finally {
              if (mounted) setState(() => busy = false);
            }
          }),
          const SizedBox(height: 22),
          RowGroup(rows: [
            HolyRow(
                icon: CupertinoIcons.person_crop_circle_badge_minus,
                title: 'Leave the brothers',
                destructive: true,
                onPressed: () async {
                  if (!await confirm(context,
                      title: 'Leave the brothers?',
                      message:
                          'Your card, posts and replies are deleted, and you leave the board. Your own reading is not touched.',
                      action: 'Leave',
                      destructive: true)) {
                    return;
                  }
                  try {
                    await ref.read(communityProvider).leave();
                    if (context.mounted) {
                      toast(context, 'You left the brothers.');
                      context.pop();
                    }
                  } catch (e) {
                    if (context.mounted) toast(context, '$e');
                  }
                }),
          ]),
        ]);
  }
}
