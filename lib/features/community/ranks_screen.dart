import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design/design.dart';
import '../../design/widgets/animated_mesh_background.dart';
import '../../design/widgets/coin.dart';
import '../../design/widgets/glass.dart';
import '../../design/widgets/holy_header.dart';
import '../../domain/streak.dart';
import '../../services/auth_service.dart';
import '../../services/community.dart';
import '../../services/repository.dart';
import 'community_widgets.dart';

const _gold = Color(0xFFF0BF4C), _silver = Color(0xFFD5DCE5), _bronze = Color(0xFFC98A55);
Color medalColor(int rank) => switch (rank) { 1 => _gold, 2 => _silver, _ => _bronze };

/// The board, after Cognein's rankings: a podium for the top three, then
/// every brother in order. Streak, or every day ever read.
class RanksScreen extends ConsumerStatefulWidget {
  const RanksScreen({super.key});
  @override
  ConsumerState<RanksScreen> createState() => _RanksScreenState();
}

class _RanksScreenState extends ConsumerState<RanksScreen> {
  Board board = Board.streak;

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final state = ref.watch(repositoryProvider);
    final streak = streakFor(state.completed, DateTime.now(), state.profile.timeZone);
    final me = ref.watch(myMemberProvider);
    final joined = me.valueOrNull != null;
    final members = ref.watch(boardProvider(board));
    final uid = ref.watch(authProvider.select((a) => a.user?.uid));
    final media = MediaQuery.of(context);
    int value(Member m) => board == Board.streak ? m.streak : m.days;

    return Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: HolyHeader(streak: streak.current),
        body: RefreshIndicator.adaptive(
            edgeOffset: HolyHeader.inset(context),
            color: t.accent,
            onRefresh: () async {
              ref.invalidate(boardSourceProvider(board));
              ref.invalidate(myRankProvider(board));
              await Future<void>.delayed(const Duration(milliseconds: 500));
            },
            child: CustomScrollView(
                key: const PageStorageKey('ranks'),
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                      child: SizedBox(height: HolyHeader.inset(context))),
                  SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.list(children: [
                        Center(child: Eyebrow('Iron sharpens iron', color: t.accent)),
                        const SizedBox(height: 6),
                        Text('The board',
                            textAlign: TextAlign.center,
                            style: HolyTypography.title
                                .copyWith(color: t.ink, fontSize: 30)),
                        const SizedBox(height: 14),
                        _BoardSwitch(
                            board: board,
                            onChanged: (b) => setState(() => board = b)),
                        const SizedBox(height: 16),
                      ])),
                  if (!joined)
                    SliverToBoxAdapter(child: _JoinBoard(onJoin: () => showJoinSheet(context, ref)))
                  else
                    ...members.when(
                        loading: () => [
                              const SliverToBoxAdapter(
                                  child: Padding(
                                      padding: EdgeInsets.only(top: 60),
                                      child: Center(child: HolySpinner())))
                            ],
                        error: (_, __) => [
                              SliverToBoxAdapter(
                                  child: Padding(
                                      padding: const EdgeInsets.all(40),
                                      child: Text('The board did not load. Pull to refresh.',
                                          textAlign: TextAlign.center,
                                          style: HolyTypography.body
                                              .copyWith(color: t.muted))))
                            ],
                        data: (list) {
                          final top = list.take(3).toList();
                          final rest = list.length > 3 ? list.sublist(3) : <Member>[];
                          final mineAt = list.indexWhere((m) => m.uid == uid);
                          return [
                            SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                sliver: SliverList.list(children: [
                                  Podium(top: top, me: uid, board: board),
                                  const SizedBox(height: 16),
                                  if (mineAt == -1 || mineAt > 2) ...[
                                    const _Section(icon: CupertinoIcons.person_fill, title: 'Your place'),
                                    _YourRow(board: board, value: value),
                                    const SizedBox(height: 10),
                                  ],
                                  if (rest.isNotEmpty)
                                    const _Section(
                                        icon: CupertinoIcons.list_number,
                                        title: 'The rest of the board'),
                                ])),
                            SliverPadding(
                                padding: EdgeInsets.fromLTRB(
                                    16, 0, 16, media.padding.bottom + 20),
                                sliver: SliverList.builder(
                                    itemCount: rest.length,
                                    itemBuilder: (context, i) => RankRow(
                                        rank: i + 4,
                                        member: rest[i],
                                        value: value(rest[i]),
                                        board: board,
                                        me: rest[i].uid == uid))),
                          ];
                        }),
                ])));
  }
}

class _BoardSwitch extends StatelessWidget {
  final Board board;
  final ValueChanged<Board> onChanged;
  const _BoardSwitch({required this.board, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Center(
        child: SizedBox(
            width: 280,
            height: 42,
            child: Glass(
                radius: 21,
                padding: const EdgeInsets.all(3),
                child: Row(children: [
                  for (final b in Board.values)
                    Expanded(
                        child: Semantics(
                            button: true,
                            selected: b == board,
                            child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  HolyHaptics.chipSelect();
                                  onChanged(b);
                                },
                                child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 240),
                                    curve: Curves.easeOutCubic,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                        gradient: b == board
                                            ? LinearGradient(colors: [
                                                Color.lerp(t.accent, Colors.white, .2)!,
                                                t.accent
                                              ])
                                            : null,
                                        borderRadius: BorderRadius.circular(18)),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(
                                          b == Board.streak
                                              ? CupertinoIcons.flame_fill
                                              : CupertinoIcons.book_fill,
                                          size: 14,
                                          color: b == board ? t.onPrimary : t.muted),
                                      const SizedBox(width: 6),
                                      Text(b.label,
                                          style: HolyTypography.label.copyWith(
                                              color: b == board ? t.onPrimary : t.muted,
                                              fontWeight: FontWeight.w800)),
                                    ]))))),
                ]))));
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  const _Section({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
        child: Row(children: [
          Icon(icon, size: 14, color: t.accent),
          const SizedBox(width: 8),
          Text(title.toUpperCase(),
              style: HolyTypography.eyebrow.copyWith(color: t.muted, fontSize: 11)),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: t.hairline)),
        ]));
  }
}

/// The top three on pedestals of struck metal, the first crowned.
class Podium extends StatefulWidget {
  final List<Member> top;
  final String? me;
  final Board board;
  const Podium({super.key, required this.top, required this.board, this.me});
  @override
  State<Podium> createState() => _PodiumState();
}

class _PodiumState extends State<Podium> with SingleTickerProviderStateMixin {
  late final _rise = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));

  static const _mesh = MeshTheme(
    baseColors: [
      Color(0xFF0A0D12),
      Color(0xFF1A1710),
      Color(0xFF3A2C14),
      Color(0xFF14181F),
      Color(0xFF0A0C10),
    ],
    b1Start: Color(0x99D8A657),
    b1End: Color(0x003A2C14),
    b2Start: Color(0x662B4468),
    b2End: Color(0x000A0D12),
    b3Start: Color(0x55F0BF4C),
    b3End: Color(0x00F0BF4C),
    b4Start: Color(0x88FFE2A0),
    b4Mid: Color(0x33D8A657),
    b4End: Color(0x000A0D12),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _rise.value = 1;
    } else if (!_rise.isAnimating && _rise.value == 0) {
      _rise.forward();
    }
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  Widget _slot(int rank, double pedestal, Interval interval) {
    final m = widget.top.length >= rank ? widget.top[rank - 1] : null;
    if (m == null) return const SizedBox.shrink();
    final curve = CurvedAnimation(parent: _rise, curve: interval);
    return AnimatedBuilder(
        animation: curve,
        builder: (context, child) => Opacity(
            opacity: curve.value.clamp(0.0, 1.0),
            child: Transform.translate(
                offset: Offset(0, (1 - curve.value) * 60), child: child)),
        child: _PodiumSlot(
            member: m,
            rank: rank,
            pedestal: pedestal,
            value: widget.board == Board.streak ? m.streak : m.days,
            board: widget.board,
            me: m.uid == widget.me));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.top.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: .14)),
            boxShadow: [
              BoxShadow(
                  color: _gold.withValues(alpha: .18),
                  blurRadius: 34,
                  offset: const Offset(0, 14)),
            ]),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: Stack(children: [
              const Positioned.fill(
                  child: AnimatedMeshBackground(
                      theme: _mesh, duration: Duration(seconds: 14))),
              Positioned.fill(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                const Color(0xFF07090D).withValues(alpha: .15),
                const Color(0xFF07090D).withValues(alpha: .5),
              ])))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(10, 18, 10, 0),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(child: _slot(2, 86, const Interval(0, .5, curve: Curves.easeOutCubic))),
                    const SizedBox(width: 8),
                    Expanded(child: _slot(1, 116, const Interval(.15, .65, curve: Curves.easeOutCubic))),
                    const SizedBox(width: 8),
                    Expanded(child: _slot(3, 66, const Interval(.3, .8, curve: Curves.easeOutCubic))),
                  ])),
            ])));
  }
}

class _PodiumSlot extends ConsumerWidget {
  final Member member;
  final int rank, value;
  final double pedestal;
  final Board board;
  final bool me;
  const _PodiumSlot(
      {required this.member,
      required this.rank,
      required this.pedestal,
      required this.value,
      required this.board,
      required this.me});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = medalColor(rank);
    final winner = rank == 1;
    return GestureDetector(
        onTap: () => showMemberCard(context, ref, member.uid),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (winner) GlowingCrown(color: color) else const SizedBox(height: 4),
          const SizedBox(height: 6),
          Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(colors: [
                    color,
                    Color.lerp(color, Colors.white, .5)!,
                    color,
                    Color.lerp(color, Colors.black, .3)!,
                    color,
                  ]),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: .55),
                        blurRadius: winner ? 26 : 16,
                        spreadRadius: winner ? 2 : 0),
                  ]),
              child: MemberAvatar(
                  name: member.name,
                  metal: member.metal,
                  photo: member.photo,
                  size: winner ? 66 : 52)),
          const SizedBox(height: 7),
          Text(member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: HolyTypography.ui.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: winner ? 14 : 12.5)),
          if (me)
            Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                    color: HolyTheme.photoBrass,
                    borderRadius: BorderRadius.circular(10)),
                child: Text('YOU',
                    style: HolyTypography.caption.copyWith(
                        color: const Color(0xFF14110B),
                        fontWeight: FontWeight.w900,
                        fontSize: 9.5,
                        letterSpacing: 1))),
          const SizedBox(height: 8),
          _Pedestal(rank: rank, height: pedestal, color: color, value: value, board: board),
        ]));
  }
}

class _Pedestal extends StatelessWidget {
  final int rank, value;
  final double height;
  final Color color;
  final Board board;
  const _Pedestal(
      {required this.rank,
      required this.height,
      required this.color,
      required this.value,
      required this.board});

  Color _shade(double l) => HSLColor.fromColor(color).withLightness(l).toColor();

  @override
  Widget build(BuildContext context) {
    const cap = 16.0;
    return SizedBox(
        height: height + cap / 2,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
          Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                  height: height,
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        _shade(.18),
                        _shade(.45),
                        _shade(.68),
                        _shade(.45),
                        _shade(.18),
                      ], stops: const [0, .24, .5, .76, 1]),
                      border: Border.all(color: color.withValues(alpha: .7), width: 1),
                      boxShadow: [
                        BoxShadow(
                            color: color.withValues(alpha: .4),
                            blurRadius: 24,
                            offset: const Offset(0, -6)),
                      ]),
                  child: Stack(alignment: Alignment.center, children: [
                    Positioned.fill(
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    begin: const Alignment(-1, -1),
                                    end: const Alignment(1, 1),
                                    colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: .26),
                          Colors.transparent,
                        ], stops: const [.3, .48, .66])))),
                    Padding(
                        padding: const EdgeInsets.only(top: cap / 2),
                        child: Text('$rank',
                            style: TextStyle(
                                fontFamily: 'SourceSerif4Display',
                                fontSize: rank == 1 ? 74 : 52,
                                fontWeight: FontWeight.w700,
                                height: 1,
                                color: Colors.white.withValues(alpha: .13)))),
                    Padding(
                        padding: const EdgeInsets.only(top: cap / 2),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('#$rank',
                              style: TextStyle(
                                  fontFamily: 'SourceSerif4Display',
                                  fontSize: rank == 1 ? 26 : 19,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(color: Color(0x66000000), blurRadius: 8)
                                  ])),
                          const SizedBox(height: 3),
                          Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .28),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: .25), width: .7)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(
                                    board == Board.streak
                                        ? CupertinoIcons.flame_fill
                                        : CupertinoIcons.book_fill,
                                    size: 10,
                                    color: Colors.white),
                                const SizedBox(width: 3),
                                Text('$value',
                                    style: HolyTypography.caption.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        fontFeatures: const [FontFeature.tabularFigures()])),
                              ])),
                        ])),
                  ]))),
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LayoutBuilder(
                  builder: (context, box) => Container(
                      height: cap,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(
                              Radius.elliptical(box.maxWidth / 2, cap / 2)),
                          gradient: RadialGradient(
                              center: const Alignment(-.4, -.7),
                              radius: 1.2,
                              colors: [_shade(.95), _shade(.72), _shade(.42)],
                              stops: const [0, .55, 1]),
                          border: Border.all(color: Colors.white.withValues(alpha: .6)),
                          boxShadow: [
                            BoxShadow(
                                color: color.withValues(alpha: .6),
                                blurRadius: 14,
                                spreadRadius: -2),
                          ])))),
        ]));
  }
}

/// Cognein's crown, breathing light.
class GlowingCrown extends StatefulWidget {
  final Color color;
  const GlowingCrown({super.key, required this.color});
  @override
  State<GlowingCrown> createState() => _GlowingCrownState();
}

class _GlowingCrownState extends State<GlowingCrown>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c
        ..stop()
        ..value = .5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
      child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: .15),
                  boxShadow: [
                    BoxShadow(
                        color: widget.color.withValues(alpha: .3 + _c.value * .4),
                        blurRadius: 16 + _c.value * 8,
                        spreadRadius: 2),
                  ]),
              child: child),
          child: Icon(Icons.workspace_premium_rounded, color: widget.color, size: 26)));
}

class RankRow extends ConsumerWidget {
  final int rank, value;
  final Member member;
  final Board board;
  final bool me, summary;
  const RankRow(
      {super.key,
      required this.rank,
      required this.member,
      required this.value,
      required this.board,
      this.me = false,
      this.summary = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = HolyThemeScope.of(context);
    final art = HolyArtAssets.badgePath(member.medal);
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Pressable(
            onPressed: () => showMemberCard(context, ref, member.uid),
            pressedScale: .985,
            semanticLabel:
                'Rank $rank, ${member.name}, $value ${board == Board.streak ? 'day streak' : 'days read'}',
            child: Glass(
                radius: 20,
                tint: me ? t.accent.withValues(alpha: .35) : null,
                padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                child: Row(children: [
                  SizedBox(
                      width: 34,
                      child: Text('$rank',
                          textAlign: TextAlign.center,
                          style: HolyTypography.numeral.copyWith(
                              color: me ? t.accent : t.muted, fontSize: 18))),
                  const SizedBox(width: 6),
                  MemberAvatar(
                      name: member.name,
                      metal: member.metal,
                      photo: member.photo,
                      size: 40,
                      streak: member.streak),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(me ? '${member.name} (you)' : member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HolyTypography.ui
                            .copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                    Text(
                        board == Board.streak
                            ? 'Best ${member.best} · ${member.days} read'
                            : '${member.streak} day streak',
                        style: HolyTypography.caption.copyWith(color: t.muted)),
                  ])),
                  if (art != null) ...[
                    HolyCoin(size: 26, image: art, thickness: .08, turn: -.3),
                    const SizedBox(width: 10),
                  ],
                  Icon(
                      board == Board.streak
                          ? CupertinoIcons.flame_fill
                          : CupertinoIcons.book_fill,
                      size: 14,
                      color: t.accent),
                  const SizedBox(width: 4),
                  Text('$value',
                      style: HolyTypography.ui.copyWith(
                          color: t.ink,
                          fontWeight: FontWeight.w900,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ]))));
  }
}

class _YourRow extends ConsumerWidget {
  final Board board;
  final int Function(Member) value;
  const _YourRow({required this.board, required this.value});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myMemberProvider).valueOrNull;
    final rank = ref.watch(myRankProvider(board)).valueOrNull;
    if (me == null) return const SizedBox.shrink();
    return RankRow(
        rank: rank ?? 0, member: me, value: value(me), board: board, me: true, summary: true);
  }
}

class _JoinBoard extends StatelessWidget {
  final VoidCallback onJoin;
  const _JoinBoard({required this.onJoin});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          const SizedBox(height: 8),
          const SizedBox(
              height: 140,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                    child: Center(
                        child: CoinBadge(
                            size: 70, metal: CoinMetal.silver, idle: true,
                            face: Text('2')))),
                Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  GlowingCrown(color: _gold),
                  SizedBox(height: 8),
                  CoinBadge(size: 88, metal: CoinMetal.gold, idle: true, glow: .6,
                      face: Text('1')),
                ])),
                Expanded(
                    child: Center(
                        child: CoinBadge(
                            size: 62, metal: CoinMetal.bronze, idle: true,
                            face: Text('3')))),
              ])),
          const SizedBox(height: 20),
          Text('Take your place',
              style: HolyTypography.headline.copyWith(color: t.ink, fontSize: 24)),
          const SizedBox(height: 6),
          Text('Join the brothers to see the board and stand on it.',
              textAlign: TextAlign.center,
              style: HolyTypography.body.copyWith(color: t.muted)),
          const SizedBox(height: 18),
          HolyButton('Join the brothers', onPressed: onJoin),
        ]));
  }
}
