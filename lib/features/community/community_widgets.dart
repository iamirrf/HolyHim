import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/lessons.g.dart';
import '../../design/design.dart';
import '../../design/widgets/coin.dart';
import '../../design/widgets/glass.dart';
import '../../domain/daily_verse.dart';
import '../../services/auth_service.dart';
import '../../services/community.dart';
import '../../services/repository.dart';
import '../common.dart';

CoinMetal metalOf(String id) => switch (id) {
      'silver' => CoinMetal.silver,
      'bronze' => CoinMetal.bronze,
      'steel' => CoinMetal.steel,
      'pine' => CoinMetal.pine,
      _ => CoinMetal.brass,
    };

String timeAgo(DateTime at, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(at);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[at.month - 1]} ${at.day}';
}

/// A brother's face: his photo in a struck rim, or his initial engraved on
/// the coin he chose. A live streak lights a small flame on the rim.
class MemberAvatar extends StatelessWidget {
  final String name, metal;
  final String? photo;
  final double size;
  final int streak;
  final double glow;
  const MemberAvatar(
      {super.key,
      required this.name,
      this.metal = 'brass',
      this.photo,
      this.size = 40,
      this.streak = 0,
      this.glow = 0});

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final finish = CoinFinish.of(metalOf(metal));
    final initial = name.trim().isEmpty ? 'H' : name.trim()[0].toUpperCase();
    final face = photo == null
        ? HolyCoin(
            size: size,
            metal: metalOf(metal),
            thickness: .06,
            glow: glow,
            face: Text(initial, style: TextStyle(fontSize: size * .44)))
        : Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(size * .055),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [finish.hi, finish.mid, finish.edge]),
                boxShadow: [
                  if (glow > 0)
                    BoxShadow(
                        color: finish.mid.withValues(alpha: .5 * glow),
                        blurRadius: size * .4),
                  BoxShadow(
                      color: Colors.black.withValues(alpha: .35),
                      blurRadius: size * .12,
                      offset: Offset(0, size * .05)),
                ]),
            child: ClipOval(
                child: Image.network(photo!,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (c, e, s) => ColoredBox(
                        color: t.sunk,
                        child: Center(
                            child: Text(initial,
                                style: HolyTypography.label
                                    .copyWith(color: t.ink)))))));
    if (streak <= 0 || size < 30) return face;
    return Stack(clipBehavior: Clip.none, children: [
      face,
      Positioned(
          right: -3,
          bottom: -3,
          child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.paper,
                  border: Border.all(color: t.accent.withValues(alpha: .5))),
              child: Icon(CupertinoIcons.flame_fill,
                  size: size * .26, color: t.accent))),
    ]);
  }
}

/// A brother's name with his medal beside it.
class MemberName extends StatelessWidget {
  final String name, medal;
  final double size;
  const MemberName(
      {super.key, required this.name, this.medal = '', this.size = 15});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final art = HolyArtAssets.badgePath(medal);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HolyTypography.ui.copyWith(
                  color: t.ink, fontWeight: FontWeight.w800, fontSize: size))),
      if (art != null) ...[
        const SizedBox(width: 5),
        HolyCoin(size: size + 3, image: art, thickness: .08),
      ],
    ]);
  }
}

class _KindChip extends StatelessWidget {
  final PostKind kind;
  const _KindChip(this.kind);
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final color = kind == PostKind.prayer ? const Color(0xFF8FA9D6) : t.olive;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: .4), width: .8)),
        child: Text(kind.label.toUpperCase(),
            style: HolyTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 9.5,
                letterSpacing: 1)));
  }
}

IconData kindIcon(PostKind kind) => switch (kind) {
      PostKind.word => CupertinoIcons.book_fill,
      PostKind.prayer => CupertinoIcons.hand_raised_fill,
      PostKind.win => CupertinoIcons.flame_fill,
    };

/// One post, after Cognein's card: who, when, what he said, the verse he
/// carried in, and the Amen, reply and share actions.
class PostCard extends ConsumerWidget {
  final Post post;

  /// Inside the post's own page: full text, no tap through.
  final bool expanded;
  const PostCard({super.key, required this.post, this.expanded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = HolyThemeScope.of(context);
    final uid = ref.watch(authProvider.select((a) => a.user?.uid));
    final mine = post.authorId == uid;
    final amened = post.amenedBy(uid);
    void open() => context.push('/post/${post.id}');
    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        GestureDetector(
            onTap: () => showMemberCard(context, ref, post.authorId),
            child: MemberAvatar(
                name: post.authorName,
                metal: post.authorMetal,
                photo: post.authorPhoto,
                streak: post.authorStreak)),
        const SizedBox(width: 11),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              GestureDetector(
                  onTap: () => showMemberCard(context, ref, post.authorId),
                  child: MemberName(name: post.authorName, medal: post.authorMedal)),
              const SizedBox(height: 3),
              Row(children: [
                if (post.kind != PostKind.word) ...[
                  _KindChip(post.kind),
                  const SizedBox(width: 6),
                ],
                if (post.authorStreak > 0) ...[
                  Icon(CupertinoIcons.flame_fill, size: 11, color: t.accent),
                  const SizedBox(width: 2),
                  Text('${post.authorStreak}',
                      style: HolyTypography.caption.copyWith(
                          color: t.accent, fontWeight: FontWeight.w800)),
                  Text('  ·  ', style: HolyTypography.caption.copyWith(color: t.muted)),
                ],
                Text(
                    '${timeAgo(post.createdAt)}${post.editedAt != null ? ' · edited' : ''}',
                    style: HolyTypography.caption.copyWith(color: t.muted)),
                if (post.hidden && mine) ...[
                  Text('  ·  ', style: HolyTypography.caption.copyWith(color: t.muted)),
                  Text('Under review',
                      style: HolyTypography.caption.copyWith(
                          color: const Color(0xFFE59A7A),
                          fontWeight: FontWeight.w800)),
                ],
              ]),
            ])),
        _MenuButton(post: post, mine: mine),
      ]),
      const SizedBox(height: 12),
      Text(post.text,
          maxLines: expanded ? null : 8,
          overflow: expanded ? null : TextOverflow.ellipsis,
          style: HolyTypography.reading
              .copyWith(color: t.ink, fontSize: 17, height: 1.45)),
      if (post.verseRef != null && post.verseText != null) ...[
        const SizedBox(height: 12),
        _VerseQuote(reference: post.verseRef!, text: post.verseText!),
      ],
      const SizedBox(height: 14),
      Row(children: [
        _ActionPill(
            icon: CupertinoIcons.hand_raised_fill,
            label: post.kind == PostKind.prayer
                ? (post.amens == 0 ? 'Praying' : '${post.amens} praying')
                : (post.amens == 0 ? 'Amen' : '${post.amens}'),
            active: amened,
            semantic: amened ? 'Remove your Amen' : 'Say Amen',
            onPressed: () => withMembership(context, ref, () async {
                  HolyHaptics.chipSelect();
                  try {
                    await ref.read(communityProvider).amen(post);
                  } catch (e) {
                    if (context.mounted) toast(context, '$e');
                  }
                })),
        const SizedBox(width: 8),
        _ActionPill(
            icon: CupertinoIcons.chat_bubble_fill,
            label: post.comments == 0 ? 'Reply' : '${post.comments}',
            semantic: 'Replies',
            onPressed: expanded ? null : open),
        const Spacer(),
        _ActionPill(
            icon: CupertinoIcons.square_arrow_up,
            label: '',
            semantic: 'Share',
            onPressed: () {
              HolyHaptics.tap();
              SharePlus.instance.share(ShareParams(
                  text:
                      '“${post.text}”${post.verseRef == null ? '' : '\n\n${post.verseText} (${post.verseRef})'}\n\nShared from HolyHim'));
            }),
      ]),
    ]);
    final card = Glass(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: body);
    if (expanded) return card;
    return Semantics(
        container: true,
        child: Pressable(onPressed: open, pressedScale: .99, child: card));
  }
}

class _VerseQuote extends StatelessWidget {
  final String reference, text;
  const _VerseQuote({required this.reference, required this.text});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
        decoration: BoxDecoration(
            color: t.accent.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.accent.withValues(alpha: .22))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 3,
              height: 38,
              margin: const EdgeInsets.only(top: 3),
              decoration: BoxDecoration(
                  color: t.accent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: HolyTypography.verse
                    .copyWith(color: t.ink, fontSize: 16, height: 1.3)),
            const SizedBox(height: 5),
            Text(reference,
                style: HolyTypography.caption
                    .copyWith(color: t.accent, fontWeight: FontWeight.w800)),
          ])),
        ]));
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label, semantic;
  final bool active;
  final VoidCallback? onPressed;
  const _ActionPill(
      {required this.icon,
      required this.label,
      required this.semantic,
      this.active = false,
      this.onPressed});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Pressable(
        onPressed: onPressed,
        semanticLabel: semantic,
        selected: active,
        haptic: false,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
                horizontal: label.isEmpty ? 10 : 12, vertical: 7),
            decoration: BoxDecoration(
                gradient: active
                    ? LinearGradient(colors: [
                        Color.lerp(t.accent, Colors.white, .2)!,
                        t.accent
                      ])
                    : null,
                color: active ? null : t.ink.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: active
                        ? Colors.transparent
                        : t.ink.withValues(alpha: .08))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 15, color: active ? t.onPrimary : t.muted),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(label,
                    style: HolyTypography.label.copyWith(
                        color: active ? t.onPrimary : t.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
              ],
            ])));
  }
}

class _MenuButton extends ConsumerWidget {
  final Post post;
  final bool mine;
  const _MenuButton({required this.post, required this.mine});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = HolyThemeScope.of(context);
    return IconButton(
        tooltip: 'More',
        icon: Icon(CupertinoIcons.ellipsis, size: 18, color: t.muted),
        onPressed: () {
          HolyHaptics.tap();
          HolyDialogs.actions(context, choices: {
            'Copy text': () => Clipboard.setData(ClipboardData(text: post.text)),
            if (mine && DateTime.now().difference(post.createdAt).inHours < 24)
              'Edit': () => showComposer(context, ref, editing: post),
            if (mine)
              'Delete': () async {
                if (!await confirm(context,
                    title: 'Delete this post?',
                    message: 'It and its replies will be gone for good.',
                    action: 'Delete',
                    destructive: true)) {
                  return;
                }
                try {
                  await ref.read(communityProvider).delete(post.id);
                  if (context.mounted) {
                    toast(context, 'Post deleted.');
                    if (GoRouterState.of(context).uri.path.startsWith('/post/')) {
                      context.pop();
                    }
                  }
                } catch (e) {
                  if (context.mounted) toast(context, '$e');
                }
              },
            if (!mine) 'Report post': () => showReport(context, ref, postId: post.id),
            if (!mine)
              'Block ${post.authorName}': () =>
                  confirmBlock(context, ref, post.authorId, post.authorName),
          });
        });
  }
}

/// Runs [action] for members; asks everyone else to join first.
Future<void> withMembership(
    BuildContext context, WidgetRef ref, Future<void> Function() action) async {
  final me = ref.read(myMemberProvider).valueOrNull;
  if (me == null) {
    final joined = await showJoinSheet(context, ref);
    if (joined != true || !context.mounted) return;
  }
  await action();
}

Future<void> confirmBlock(
    BuildContext context, WidgetRef ref, String uid, String name) async {
  if (!await confirm(context,
      title: 'Block $name?',
      message:
          'You will not see his posts, replies or place on the board. You can unblock him from your profile.',
      action: 'Block',
      destructive: true)) {
    return;
  }
  try {
    await ref.read(communityProvider).block(uid);
    if (context.mounted) toast(context, '$name is blocked.');
  } catch (e) {
    if (context.mounted) toast(context, '$e');
  }
}

const reportReasons = {
  'spam': 'Spam or selling',
  'harassment': 'Bullying or harassment',
  'hate': 'Hate or slurs',
  'sexual': 'Sexual content',
  'violence': 'Violence or self-harm',
  'false': 'Twisting Scripture to harm',
  'other': 'Something else',
};

Future<void> showReport(BuildContext context, WidgetRef ref,
    {required String postId, String? replyId}) async {
  final reason = await HolyDialogs.sheet<String>(context,
      builder: (context) {
        final t = HolyThemeScope.of(context);
        return SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Report',
                          style: HolyTypography.title
                              .copyWith(color: t.ink, fontSize: 26)),
                      const SizedBox(height: 6),
                      Text(
                          'It disappears for you now. We review every report within 24 hours.',
                          style: HolyTypography.body.copyWith(color: t.muted)),
                      const SizedBox(height: 14),
                      RowGroup(rows: [
                        for (final e in reportReasons.entries)
                          HolyRow(
                              title: e.value,
                              onPressed: () => Navigator.pop(context, e.key)),
                      ]),
                    ])));
      });
  if (reason == null || !context.mounted) return;
  try {
    await ref.read(communityProvider).report(postId, replyId: replyId, reason: reason);
    if (context.mounted) toast(context, 'Thanks. We will look at it.');
  } catch (e) {
    if (context.mounted) toast(context, '$e');
  }
}

/// Before anyone reads or writes here: the rules, his name and his coin.
Future<bool?> showJoinSheet(BuildContext context, WidgetRef ref) =>
    HolyDialogs.sheet<bool>(context, builder: (_) => const _JoinSheet());

class _JoinSheet extends ConsumerStatefulWidget {
  const _JoinSheet();
  @override
  ConsumerState<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends ConsumerState<_JoinSheet> {
  late final _name = TextEditingController(
      text: ref.read(repositoryProvider).profile.name.trim().split(RegExp(r'\s+')).first);
  String metal = 'brass';
  bool agreed = false, busy = false;
  String? error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final name = _name.text.trim();
    final problem = name.length < 2
        ? 'Add the name brothers will see.'
        : name.length > 24
            ? 'Keep your name under 24 characters.'
            : communityTextProblem(name, max: 24);
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(communityProvider).join(name: name, metal: metal);
      HolyHaptics.success();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = '$e'.contains('permission')
              ? 'That did not go through. Try again.'
              : '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    Widget rule(IconData icon, String title, String line) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.accent.withValues(alpha: .14),
                  border: Border.all(color: t.accent.withValues(alpha: .35))),
              child: Icon(icon, size: 16, color: t.accent)),
          const SizedBox(width: 12),
          Expanded(
              child: Text.rich(TextSpan(children: [
            TextSpan(
                text: '$title ',
                style: TextStyle(color: t.ink, fontWeight: FontWeight.w800)),
            TextSpan(text: line, style: TextStyle(color: t.muted)),
          ]), style: HolyTypography.body)),
        ]));
    return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Center(
                  child: SizedBox(
                      height: 74,
                      width: 180,
                      child: Stack(alignment: Alignment.center, children: [
                        Positioned(
                            left: 18,
                            child: HolyCoin(size: 52, metal: CoinMetal.silver, turn: .5,
                                face: Icon(CupertinoIcons.person_fill))),
                        Positioned(
                            right: 18,
                            child: HolyCoin(size: 52, metal: CoinMetal.bronze, turn: -.5,
                                face: Icon(CupertinoIcons.person_fill))),
                        HolyCoin(size: 70, glow: .6,
                            face: Icon(CupertinoIcons.person_2_fill)),
                      ]))),
              const SizedBox(height: 14),
              Text('Join the brothers',
                  style: HolyTypography.title.copyWith(color: t.ink, fontSize: 28)),
              const SizedBox(height: 6),
              Text('Iron sharpens iron. Four rules keep it that way.',
                  style: HolyTypography.body.copyWith(color: t.muted)),
              const SizedBox(height: 18),
              rule(CupertinoIcons.person_fill, 'Be real.', 'Share what is true for you.'),
              rule(CupertinoIcons.heart_fill, 'Be kind.', 'No mocking, no bullying, no slurs.'),
              rule(CupertinoIcons.shield_lefthalf_fill, 'Keep it clean.',
                  'No sexual content, no selling, no links.'),
              rule(CupertinoIcons.hand_raised_fill, 'Protect each other.',
                  'Report what breaks the rules. If someone may be in danger, call 911 or 988.'),
              Text(
                  'There is no room here for objectionable content or abusive users. We remove both, and review every report within 24 hours.',
                  style: HolyTypography.caption.copyWith(color: t.muted, height: 1.4)),
              const SizedBox(height: 18),
              HolyField(
                  controller: _name,
                  label: 'Your name on the board',
                  maxLength: 24,
                  capitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done),
              const SizedBox(height: 14),
              Eyebrow('Your coin', color: t.muted),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                for (final m in memberMetals)
                  Semantics(
                      button: true,
                      selected: metal == m,
                      label: '$m coin',
                      excludeSemantics: true,
                      child: GestureDetector(
                          onTap: () {
                            HolyHaptics.chipSelect();
                            setState(() => metal = m);
                          },
                          child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: metal == m ? t.accent : Colors.transparent,
                                      width: 2)),
                              child: MemberAvatar(
                                  name: _name.text, metal: m, size: 48)))),
              ]),
              const SizedBox(height: 16),
              Semantics(
                  checked: agreed,
                  child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => agreed = !agreed),
                      child: Row(children: [
                        HolyCheck(checked: agreed, size: 24, color: t.accent),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text.rich(TextSpan(children: [
                          const TextSpan(text: 'I agree to the rules and the '),
                          WidgetSpan(
                              child: GestureDetector(
                                  onTap: () =>
                                      openLegal(context, 'Terms of Use', 'terms'),
                                  child: Text('Terms of Use',
                                      style: HolyTypography.body.copyWith(
                                          color: t.accent,
                                          fontWeight: FontWeight.w800)))),
                          const TextSpan(text: '.'),
                        ]), style: HolyTypography.body.copyWith(color: t.ink))),
                      ]))),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!,
                    style: HolyTypography.label
                        .copyWith(color: const Color(0xFFF2B8B5))),
              ],
              const SizedBox(height: 18),
              HolyButton('Join the brothers',
                  loading: busy, onPressed: agreed ? _join : null),
            ])));
  }
}

/// A brother's card: his coin, his numbers and what you can do about him.
Future<void> showMemberCard(BuildContext context, WidgetRef ref, String uid) async {
  HolyHaptics.tap();
  final member = await ref.read(communityProvider).member(uid).catchError((_) => null);
  if (member == null || !context.mounted) return;
  final me = ref.read(authProvider).user?.uid == uid;
  await HolyDialogs.sheet<void>(context, scrollControlled: false, builder: (context) {
    final t = HolyThemeScope.of(context);
    Widget stat(String value, String label) => Expanded(
        child: Column(children: [
          Text(value, style: HolyTypography.numeral.copyWith(color: t.ink, fontSize: 26)),
          const SizedBox(height: 2),
          Text(label, style: HolyTypography.caption.copyWith(color: t.muted)),
        ]));
    final art = HolyArtAssets.badgePath(member.medal);
    return SafeArea(
        child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              MemberAvatar(
                  name: member.name,
                  metal: member.metal,
                  photo: member.photo,
                  size: 86,
                  glow: .5),
              const SizedBox(height: 12),
              Text(member.name,
                  style: HolyTypography.title.copyWith(color: t.ink, fontSize: 26)),
              if (member.joinedAt != null)
                Text('Joined ${timeAgo(member.joinedAt!)} ago'.replaceAll(' now ago', ' today'),
                    style: HolyTypography.caption.copyWith(color: t.muted)),
              const SizedBox(height: 18),
              Glass(
                  radius: 22,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(children: [
                    stat('${member.streak}', 'Streak'),
                    stat('${member.best}', 'Best'),
                    stat('${member.days}', 'Days read'),
                  ])),
              if (art != null) ...[
                const SizedBox(height: 16),
                CoinBadge(size: 72, image: art, idle: true, glow: .4),
              ],
              if (!me) ...[
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                      child: HolyButton.secondary('Block',
                          onPressed: () {
                            Navigator.pop(context);
                            confirmBlock(context, ref, member.uid, member.name);
                          })),
                ]),
              ],
            ])));
  });
}

/// Write a post, or edit one of yours.
Future<void> showComposer(BuildContext context, WidgetRef ref,
    {Post? editing, PostKind kind = PostKind.word}) async {
  await withMembership(context, ref, () async {
    await HolyDialogs.sheet<void>(context,
        builder: (_) => _Composer(editing: editing, kind: kind));
  });
}

class _Composer extends ConsumerStatefulWidget {
  final Post? editing;
  final PostKind kind;
  const _Composer({this.editing, this.kind = PostKind.word});
  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  late final _text = TextEditingController(text: widget.editing?.text ?? '');
  late PostKind kind = widget.editing?.kind ?? widget.kind;
  bool withVerse = false, busy = false;
  String? error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final problem = communityTextProblem(_text.text);
    if (problem != null) {
      setState(() => error = problem);
      HolyHaptics.error();
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final c = ref.read(communityProvider);
    try {
      if (widget.editing != null) {
        await c.edit(widget.editing!.id, _text.text);
      } else {
        final state = ref.read(repositoryProvider);
        final verse =
            dailyVerse(lessons, DateTime.now(), state.profile.timeZone);
        await c.post(_text.text, kind,
            verseRef: withVerse ? verse.reference : null,
            verseText: withVerse ? verse.verse : null);
      }
      HolyHaptics.send();
      if (mounted) {
        Navigator.pop(context);
        toast(context, widget.editing != null ? 'Post updated.' : 'Posted.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final state = ref.watch(repositoryProvider);
    final verse = dailyVerse(lessons, DateTime.now(), state.profile.timeZone);
    final editing = widget.editing != null;
    final hint = switch (kind) {
      PostKind.word => 'What spoke to you today?',
      PostKind.prayer => 'What can the brothers pray for?',
      PostKind.win => 'What did God do? Big or small.',
    };
    return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(editing ? 'Edit post' : 'Share with the brothers',
                  style: HolyTypography.title.copyWith(color: t.ink, fontSize: 26)),
              const SizedBox(height: 14),
              if (!editing)
                Row(children: [
                  for (final k in PostKind.values) ...[
                    if (k != PostKind.word) const SizedBox(width: 8),
                    Expanded(
                        child: Pressable(
                            onPressed: () => setState(() => kind = k),
                            selected: kind == k,
                            semanticLabel: k.label,
                            child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 44,
                                decoration: BoxDecoration(
                                    color: kind == k
                                        ? t.accent.withValues(alpha: .16)
                                        : t.ink.withValues(alpha: .05),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: kind == k
                                            ? t.accent
                                            : t.ink.withValues(alpha: .08),
                                        width: kind == k ? 1.4 : 1)),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(kindIcon(k),
                                          size: 15,
                                          color: kind == k ? t.accent : t.muted),
                                      const SizedBox(width: 6),
                                      Text(k.label,
                                          style: HolyTypography.label.copyWith(
                                              color: kind == k ? t.ink : t.muted,
                                              fontWeight: FontWeight.w800)),
                                    ])))),
                  ],
                ]),
              const SizedBox(height: 12),
              Glass(
                  radius: 20,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: TextField(
                      controller: _text,
                      autofocus: true,
                      minLines: 4,
                      maxLines: 9,
                      maxLength: 600,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) {
                        if (error != null) setState(() => error = null);
                      },
                      style: HolyTypography.reading
                          .copyWith(color: t.ink, fontSize: 17),
                      cursorColor: t.accent,
                      decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: hint,
                          hintStyle: HolyTypography.reading
                              .copyWith(color: t.muted, fontSize: 17),
                          counterStyle:
                              HolyTypography.caption.copyWith(color: t.muted)))),
              if (!editing) ...[
                const SizedBox(height: 12),
                Pressable(
                    onPressed: () => setState(() => withVerse = !withVerse),
                    selected: withVerse,
                    semanticLabel: 'Add today’s verse',
                    child: Glass(
                        radius: 18,
                        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                        child: Row(children: [
                          Icon(CupertinoIcons.book_fill, size: 17, color: t.accent),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('Add today’s verse',
                                    style: HolyTypography.label.copyWith(
                                        color: t.ink, fontWeight: FontWeight.w800)),
                                Text(verse.reference,
                                    style: HolyTypography.caption
                                        .copyWith(color: t.muted)),
                              ])),
                          HolySwitch(
                              value: withVerse,
                              onChanged: (v) => setState(() => withVerse = v)),
                        ]))),
              ],
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!,
                    style: HolyTypography.label
                        .copyWith(color: const Color(0xFFF2B8B5))),
              ],
              const SizedBox(height: 16),
              HolyButton(editing ? 'Save' : 'Post',
                  loading: busy,
                  leading: Icon(
                      editing ? CupertinoIcons.checkmark_alt : CupertinoIcons.paperplane_fill,
                      size: 17,
                      color: t.onPrimary),
                  onPressed: _send),
              const SizedBox(height: 8),
              Center(
                  child: Text('Be real. Be kind. Keep it clean.',
                      style: HolyTypography.caption.copyWith(color: t.muted))),
            ])));
  }
}
