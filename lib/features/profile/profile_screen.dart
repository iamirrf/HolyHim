import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../design/design.dart';
import '../../design/widgets/coin.dart';
import '../../design/widgets/glass.dart';
import '../../design/widgets/holy_header.dart';
import '../../domain/badges.dart';
import '../../domain/onboarding_flow.dart';
import '../../domain/streak.dart';
import '../../services/avatar_service.dart';
import '../../services/community.dart';
import '../community/community_screen.dart';
import '../community/community_widgets.dart';
import 'edit_profile_screen.dart';
import '../../services/auth_service.dart';
import '../../services/billing.dart';
import '../../services/narration.dart';
import '../../services/notifications.dart';
import '../../services/repository.dart';
import '../common.dart';
import '../support/support_screen.dart';
import 'app_icon_screen.dart';
import 'theme_screen.dart';

String _time(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  return '${h % 12 == 0 ? 12 : h % 12}:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

void _open(BuildContext context, Widget screen) => Navigator.of(context)
    .push(CupertinoPageRoute<void>(builder: (_) => screen));

/// The profile: who you are, what you have walked, and every setting, in
/// the layout HolyHim began with.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = HolyThemeScope.of(context);
    final state = ref.watch(repositoryProvider);
    final user = ref.watch(authProvider).user;
    final access = ref.watch(accessProvider);
    final owned = access.active;
    final member = ref.watch(myMemberProvider).valueOrNull;
    final hidden = ref.watch(hiddenProvider).valueOrNull;
    final p = state.profile;
    final name = p.name.trim().isEmpty ? 'Brother' : p.name.trim();
    final media = MediaQuery.of(context);
    final streak = streakFor(state.completed, DateTime.now(), p.timeZone);
    final photo = visibleAvatarUrl(p.avatarUrl, user?.photoUrl);
    final next = dayBadgeTitles.keys.firstWhere(
        (n) => n > state.completed.length,
        orElse: () => dayBadgeTitles.keys.last);
    Widget section(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 26, 0, 10),
        child: Eyebrow(label, color: t.muted));
    return Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: HolyHeader(streak: streak.current),
        body: ListView(
            key: const PageStorageKey('profile'),
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.fromLTRB(
                16, HolyHeader.inset(context), 16, media.padding.bottom + 24),
            children: [
              Rise(
                  child: Pressable(
                      semanticLabel: 'Edit profile',
                      pressedScale: .985,
                      onPressed: () => _open(context, const EditProfileScreen()),
                      child: Glass(
                          radius: 28,
                          elevation: 3,
                          padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
                          child: Row(children: [
                            MemberAvatar(
                                name: name,
                                metal: member?.metal ?? 'brass',
                                photo: photo,
                                size: 78,
                                glow: .45),
                            const SizedBox(width: 16),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                  Semantics(
                                      header: true,
                                      child: Text(name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: HolyTypography.title.copyWith(
                                              color: t.ink, fontSize: 26))),
                                  const SizedBox(height: 2),
                                  Text(
                                      p.username.isNotEmpty
                                          ? '@${p.username}'
                                          : user?.email ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: HolyTypography.caption
                                          .copyWith(color: t.muted)),
                                  const SizedBox(height: 10),
                                  _Membership(access: access),
                                ])),
                            Icon(CupertinoIcons.pencil, size: 18, color: t.accent),
                          ])))),
              const SizedBox(height: 12),
              Rise(
                  index: 1,
                  child: Row(children: [
                    _Stat(
                        value: state.completed.length,
                        label: 'Days read',
                        icon: CupertinoIcons.book_fill),
                    const SizedBox(width: 10),
                    _Stat(
                        value: streak.current,
                        label: 'Day streak',
                        icon: CupertinoIcons.flame_fill),
                    const SizedBox(width: 10),
                    _Stat(
                        value: state.saved.length,
                        label: 'Verses kept',
                        icon: CupertinoIcons.bookmark_fill),
                  ])),
              const SizedBox(height: 12),
              Rise(
                  index: 2,
                  child: Pressable(
                      semanticLabel: 'Your next milestone',
                      pressedScale: .985,
                      onPressed: () => context.go('/growth'),
                      child: Glass(
                          radius: 24,
                          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                          child: Row(children: [
                            CoinBadge(
                                size: 66,
                                image: HolyArtAssets.badgePath('days-$next'),
                                muted: true,
                                idle: true),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                  Eyebrow('Your next milestone', color: t.accent),
                                  const SizedBox(height: 3),
                                  Text(dayBadgeTitles[next]!,
                                      style: HolyTypography.headline
                                          .copyWith(color: t.ink, fontSize: 19)),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                          value: (state.completed.length / next)
                                              .clamp(0.0, 1.0),
                                          minHeight: 5,
                                          color: t.accent,
                                          backgroundColor:
                                              t.ink.withValues(alpha: .08))),
                                  const SizedBox(height: 5),
                                  Text('${state.completed.length} of $next days',
                                      style: HolyTypography.caption
                                          .copyWith(color: t.muted)),
                                ])),
                            Icon(CupertinoIcons.chevron_right, size: 14, color: t.muted),
                          ])))),
              if (state.syncError != null) ...[
                const SizedBox(height: 12),
                Glass(
                    radius: 22,
                    padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(state.syncError!,
                          style: HolyTypography.body.copyWith(color: t.muted)),
                      TextAction('Retry sync',
                          onPressed: () =>
                              ref.read(repositoryProvider.notifier).retrySync()),
                    ])),
              ],
              if (!owned) ...[
                const SizedBox(height: 12),
                const _Unlock(),
              ],
              section('Your walk'),
              RowGroup(rows: [
                HolyRow(
                    icon: owned
                        ? CupertinoIcons.checkmark_seal_fill
                        : CupertinoIcons.sparkles,
                    title: access.purchased || access.retained
                        ? 'Lifetime access'
                        : access.member
                            ? (access.inTrial ? 'Your free week' : 'Membership')
                            : 'Become a member',
                    value: access.purchased || access.retained
                        ? 'Yours'
                        : access.member
                            ? membershipDate(access)
                            : null,
                    // Apple keeps the subscription: he changes or cancels it
                    // in his App Store settings.
                    onPressed: access.purchased || access.retained
                        ? null
                        : access.member
                            ? () => launchUrl(Uri.parse(manageSubscriptionsUrl),
                                mode: LaunchMode.externalApplication)
                            : () => context.push('/offer')),
                HolyRow(
                    icon: CupertinoIcons.arrow_clockwise,
                    title: access.busy ? 'Restoring…' : 'Restore purchase',
                    onPressed: access.busy ? null : () => _restore(context, ref)),
                HolyRow(
                    icon: CupertinoIcons.bookmark,
                    title: 'Saved verses',
                    value: '${state.saved.length}',
                    onPressed: () => context.push('/saved')),
                HolyRow(
                    icon: CupertinoIcons.map,
                    title: 'All chapters',
                    onPressed: () => context.push('/journey')),
                HolyRow(
                    icon: CupertinoIcons.bell,
                    title: 'Reminders',
                    value: p.reminderEnabled ? _time(p.reminderMinutes) : 'Off',
                    onPressed: () => _open(context, const RemindersScreen())),
              ]),
              section('Brothers'),
              RowGroup(rows: [
                HolyRow(
                    icon: CupertinoIcons.person_crop_square,
                    title: 'Your card',
                    value: member == null ? 'Not joined' : member.name,
                    onPressed: () =>
                        _open(context, const CommunityCardScreen())),
                HolyRow(
                    icon: CupertinoIcons.nosign,
                    title: 'Blocked',
                    value: '${hidden?.users.length ?? 0}',
                    onPressed: () => _open(context, const BlockedScreen())),
                HolyRow(
                    icon: CupertinoIcons.shield_lefthalf_fill,
                    title: 'Community rules',
                    onPressed: () => openLegal(context, 'Terms of Use', 'terms')),
              ]),
              section('Preferences'),
              RowGroup(rows: [
                HolyRow(
                    icon: CupertinoIcons.paintbrush,
                    title: 'Theme',
                    value: HolyThemes.byId(p.theme).name,
                    onPressed: () => _open(context, const ThemeScreen())),
                HolyRow(
                    icon: CupertinoIcons.app,
                    title: 'App icon',
                    onPressed: () => _open(context, const AppIconScreen())),
                HolyRow(
                    icon: CupertinoIcons.textformat_size,
                    title: 'Reading',
                    value: '${(p.readingScale * 100).round()}%',
                    onPressed: () => _open(context, const ReadingScreen())),
                HolyRow(
                    icon: CupertinoIcons.sunrise,
                    title: 'Retake the welcome',
                    onPressed: () {
                      // The welcome again from his name; his road is untouched.
                      ref.read(repositoryProvider.notifier).updateProfile(
                          p.copyWith(onboardingDraft: {
                            'flowVersion': onboardingFlowVersion,
                            'stepId': 'name',
                            'step': 0,
                          }));
                      context.go('/onboarding?redo=1');
                    }),
              ]),
              section('Support'),
              RowGroup(rows: [
                HolyRow(
                    icon: CupertinoIcons.person_crop_circle,
                    title: 'Account',
                    onPressed: () => _open(context, const AccountScreen())),
                HolyRow(
                    icon: CupertinoIcons.chat_bubble_text,
                    title: 'Help and feedback',
                    onPressed: () => _open(context, const SupportScreen())),
                HolyRow(
                    icon: CupertinoIcons.doc_text,
                    title: 'Privacy and terms',
                    onPressed: () => _open(context, const _LegalIndex())),
              ]),
              const SizedBox(height: 28),
              const Center(
                  child: HolyCoin(
                      size: 34, metal: CoinMetal.steel, turn: math.pi, thickness: .08)),
              const SizedBox(height: 8),
              Center(
                  child: Text('HolyHim ${AppConstants.versionLabel}',
                      style: HolyTypography.caption.copyWith(color: t.muted))),
            ]));
  }
}

/// What he holds: the lifetime unlock sold before membership, a membership
/// (in its free week or paid), or nothing yet.
class _Membership extends StatelessWidget {
  final AccessState access;
  const _Membership({required this.access});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final owned = access.active;
    final lifetime = access.purchased || access.retained;
    return Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        decoration: BoxDecoration(
            gradient: owned
                ? LinearGradient(colors: [
                    Color.lerp(t.accent, Colors.white, .25)!,
                    t.accent,
                  ])
                : null,
            color: owned ? null : t.accent.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(owned ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.sunrise_fill,
              size: 12, color: owned ? t.onPrimary : t.accent),
          const SizedBox(width: 5),
          Flexible(
              child: Text(
                  lifetime
                      ? 'Lifetime member'
                      : access.member
                          ? (access.inTrial ? 'Free week' : 'Member')
                          : 'Not a member yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HolyTypography.caption.copyWith(
                      color: owned ? t.onPrimary : t.accent,
                      fontWeight: FontWeight.w800))),
        ]));
  }
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  const _Stat({required this.value, required this.label, required this.icon});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Expanded(
        child: Semantics(
            label: '$value $label',
            excludeSemantics: true,
            child: Glass(
                radius: 22,
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icon, size: 16, color: t.accent),
                  const SizedBox(height: 6),
                  RollingNumber(
                      value: value,
                      style: HolyTypography.numeral.copyWith(color: t.ink, fontSize: 28)),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HolyTypography.caption.copyWith(color: t.muted)),
                ]))));
  }
}

/// Shown only when membership has lapsed and the offer has not yet covered
/// the screen: the way back in.
class _Unlock extends StatelessWidget {
  const _Unlock();
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Pressable(
        semanticLabel: 'Become a member',
        pressedScale: .985,
        onPressed: () => context.push('/offer'),
        child: DecoratedBox(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(colors: [
                  t.accent.withValues(alpha: .65),
                  t.accent.withValues(alpha: .15),
                  t.accent.withValues(alpha: .55),
                ]),
                boxShadow: [
                  BoxShadow(color: t.accent.withValues(alpha: .25), blurRadius: 24),
                ]),
            child: Padding(
                padding: const EdgeInsets.all(1.2),
                child: Glass(
                    radius: 23,
                    padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                    child: Row(children: [
                      const HolyCoin(
                          size: 52,
                          glow: .5,
                          face: Icon(CupertinoIcons.sunrise_fill)),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Become a member',
                            style: HolyTypography.headline
                                .copyWith(color: t.ink, fontSize: 19)),
                        const SizedBox(height: 2),
                        Text('Every lesson, every morning, all year.',
                            style: HolyTypography.caption.copyWith(color: t.muted)),
                      ])),
                      Icon(CupertinoIcons.chevron_right, size: 14, color: t.accent),
                    ])))));
  }
}

/// Daily reminder: on/off, time, and the note he will see.
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});
  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  int decision = 0;
  void _update(AppProfile p) =>
      ref.read(repositoryProvider.notifier).updateProfile(p);

  void _toggle(bool enabled) {
    final d = ++decision;
    _update(ref.read(repositoryProvider).profile.copyWith(reminderEnabled: enabled));
    if (!enabled) return;
    unawaited(ref.read(notificationServiceProvider).requestPermission().then((granted) {
      if (!mounted || d != decision) return;
      if (!granted) {
        _update(ref.read(repositoryProvider).profile.copyWith(reminderEnabled: false));
        toast(context, 'Allow notifications for HolyHim in iOS Settings.');
      }
    }));
  }

  Future<void> _pickTime() async {
    final t = HolyThemeScope.of(context);
    final p = ref.read(repositoryProvider).profile;
    var picked = DateTime(2026, 1, 1, p.reminderMinutes ~/ 60,
        (p.reminderMinutes % 60) - (p.reminderMinutes % 60) % 5);
    final ok = await showModalBottomSheet<bool>(
        context: context,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                  height: 200,
                  child: CupertinoTheme(
                      data: CupertinoThemeData(
                          brightness:
                              t.isDark ? Brightness.dark : Brightness.light,
                          textTheme: CupertinoTextThemeData(
                              dateTimePickerTextStyle: HolyTypography.ui
                                  .copyWith(color: t.ink, fontSize: 21))),
                      child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.time,
                          minuteInterval: 5,
                          initialDateTime: picked,
                          onDateTimeChanged: (d) => picked = d))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: HolyButton('Set time',
                      onPressed: () => Navigator.pop(context, true))),
            ])));
    if (ok == true && mounted) {
      _update(ref
          .read(repositoryProvider)
          .profile
          .copyWith(reminderMinutes: picked.hour * 60 + picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final p = ref.watch(repositoryProvider).profile;
    return ScreenFrame(
        title: 'Reminders',
        subtitle: 'One short note a day with a verse. Never an ad.',
        children: [
          RowGroup(rows: [
            HolyRow(
                icon: CupertinoIcons.bell,
                title: 'Daily verse',
                trailing: HolySwitch(
                    value: p.reminderEnabled,
                    semanticLabel: 'Daily verse reminder',
                    onChanged: _toggle)),
            HolyRow(
                icon: CupertinoIcons.clock,
                title: 'Time',
                value: _time(p.reminderMinutes),
                onPressed: p.reminderEnabled ? _pickTime : null),
          ]),
          const SizedBox(height: 18),
          AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: p.reminderEnabled ? 1 : .45,
              child: Text(
                  'You may also get a short evening note if today’s lesson is still waiting, a word after a few quiet days, and a blessing on your birthday.',
                  style: HolyTypography.body.copyWith(color: t.muted))),
          const Spacer(),
        ]);
  }
}

/// Text size, sounds and haptics.
class ReadingScreen extends ConsumerWidget {
  const ReadingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = HolyThemeScope.of(context);
    final p = ref.watch(repositoryProvider).profile;
    void update(AppProfile next) =>
        ref.read(repositoryProvider.notifier).updateProfile(next);
    const sizes = [1.0, 1.15, 1.3, 1.5];
    return ScreenFrame(title: 'Reading', children: [
      Paper(
          padding: const EdgeInsets.all(20),
          child: Text('God is our refuge and strength, a very present help in trouble.',
              style: HolyTypography.reading
                  .copyWith(color: t.ink, fontSize: 20 * p.readingScale))),
      const SizedBox(height: 14),
      Row(children: [
        for (final s in sizes) ...[
          Expanded(
              child: ChoiceTileCompact(
                  label: '${(s * 100).round()}%',
                  selected: (p.readingScale - s).abs() < .04,
                  onPressed: () => update(p.copyWith(readingScale: s)))),
          if (s != sizes.last) const SizedBox(width: 8),
        ]
      ]),
      const SizedBox(height: 18),
      RowGroup(rows: [
        HolyRow(
            icon: CupertinoIcons.waveform,
            title: 'Haptics',
            trailing: HolySwitch(
                value: p.haptics,
                semanticLabel: 'Haptics',
                onChanged: (v) => update(p.copyWith(haptics: v)))),
        HolyRow(
            icon: CupertinoIcons.speaker_2,
            title: 'Sounds',
            trailing: HolySwitch(
                value: p.sounds,
                semanticLabel: 'Sounds',
                onChanged: (v) => update(p.copyWith(sounds: v)))),
      ]),
      // Offered once lessons have their recordings.
      FutureBuilder<Map<int, NarrationTrack>>(
          future: NarrationCatalog.load(),
          builder: (context, snapshot) => (snapshot.data ?? const {}).isEmpty
              ? const SizedBox.shrink()
              : const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: RowGroup(rows: [_ReadAloudRow()]))),
      const Spacer(),
    ]);
  }
}

/// "Read lessons aloud": each lesson starts reading itself when it opens.
class _ReadAloudRow extends StatefulWidget {
  const _ReadAloudRow();
  @override
  State<_ReadAloudRow> createState() => _ReadAloudRowState();
}

class _ReadAloudRowState extends State<_ReadAloudRow> {
  bool _on = false;

  @override
  void initState() {
    super.initState();
    NarrationPrefs.autoplay().then((v) {
      if (mounted) setState(() => _on = v);
    });
  }

  @override
  Widget build(BuildContext context) => HolyRow(
      icon: CupertinoIcons.headphones,
      title: 'Read lessons aloud',
      trailing: HolySwitch(
          value: _on,
          semanticLabel: 'Read lessons aloud',
          onChanged: (v) {
            setState(() => _on = v);
            NarrationPrefs.setAutoplay(v);
          }));
}

/// Restore, from Profile: the same as on the offer and in Account.
Future<void> _restore(BuildContext context, WidgetRef ref) async {
  final ok = await ref.read(accessProvider.notifier).restore();
  if (!context.mounted) return;
  toast(
      context,
      ok
          ? 'Restored. Every lesson is open.'
          : ref.read(accessProvider).error ?? 'No purchase was found.');
}

/// When a membership renews or ends, as Profile shows it: "Renews Nov 22".
String membershipDate(AccessState access) {
  final until = access.memberUntil?.toLocal();
  if (until == null) return 'Active';
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
  final day = '${months[until.month - 1]} ${until.day}';
  if (!access.willRenew) return 'Ends $day';
  return access.inTrial ? 'Year starts $day' : 'Renews $day';
}

class ChoiceTileCompact extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  const ChoiceTileCompact(
      {super.key,
      required this.label,
      required this.selected,
      required this.onPressed});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Pressable(
        onPressed: () {
          HolyHaptics.chipSelect();
          onPressed();
        },
        selected: selected,
        semanticLabel: label,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 48,
            decoration: ShapeDecoration(
                color: selected ? t.primary : t.surface,
                shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(HolyRadius.chip),
                    side: BorderSide(
                        color: selected ? t.primary : t.hairline))),
            child: Center(
                child: Text(label,
                    style: HolyTypography.label.copyWith(
                        color: selected ? t.onPrimary : t.ink)))));
  }
}

/// Name, purchases, data, sign out and deletion.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  Future<void> _rename() async {
    final controller =
        TextEditingController(text: ref.read(repositoryProvider).profile.name);
    final name = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (context) => Padding(
            padding: EdgeInsets.fromLTRB(
                24, 0, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              HolyField(
                  controller: controller,
                  label: 'Your name',
                  autofocus: true,
                  maxLength: 60,
                  capitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (v) => Navigator.pop(context, v)),
              const SizedBox(height: 14),
              HolyButton('Save',
                  onPressed: () => Navigator.pop(context, controller.text)),
            ])));
    controller.dispose();
    if (name != null && name.trim().isNotEmpty && mounted) {
      final p = ref.read(repositoryProvider).profile;
      ref.read(repositoryProvider.notifier).updateProfile(p.copyWith(name: name.trim()));
    }
  }

  Future<void> _restore() async {
    final ok = await ref.read(accessProvider.notifier).restore();
    if (!mounted) return;
    toast(
        context,
        ok
            ? 'Restored. Every lesson is open.'
            : ref.read(accessProvider).error ?? 'No purchase was found.');
  }

  Future<void> _export() async {
    final data = ref.read(repositoryProvider.notifier).exportData();
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
        files: [
          XFile.fromData(utf8.encode(data),
              mimeType: 'application/json', name: 'holyhim-my-walk.json')
        ],
        subject: 'My HolyHim walk',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size));
  }

  Future<void> _signOut() async {
    if (!await confirm(context,
        title: 'Sign out?',
        message: 'Your walk stays saved to your account.',
        action: 'Sign out')) {
      return;
    }
    await ref.read(authProvider.notifier).signOut();
  }

  Future<void> _delete() async {
    if (!await confirm(context,
        title: 'Delete your account?',
        message:
            'Your profile, completed lessons and saved verses will be permanently deleted. This does not cancel your membership: Apple bills it until you cancel in Settings, your name, then Subscriptions.',
        action: 'Delete account',
        destructive: true)) {
      return;
    }
    if (!mounted) return;
    final needsPassword = Firebase.apps.isNotEmpty &&
        (firebase.FirebaseAuth.instance.currentUser?.providerData
                .any((p) => p.providerId == 'password') ??
            false);
    String? password;
    if (needsPassword) {
      final controller = TextEditingController();
      password = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          builder: (context) => Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 0, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Confirm your password',
                    style: HolyTypography.headline.copyWith(
                        color: HolyThemeScope.of(context).ink)),
                const SizedBox(height: 14),
                HolyField(
                    controller: controller,
                    label: 'Password',
                    password: true,
                    autofocus: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (v) => Navigator.pop(context, v)),
                const SizedBox(height: 14),
                HolyButton('Delete account',
                    onPressed: () => Navigator.pop(context, controller.text)),
              ])));
      controller.dispose();
      if (password == null || password.isEmpty) return;
    }
    if (!mounted) return;
    await ref.read(authProvider.notifier).deleteAccount(password: password);
    if (mounted) {
      final error = ref.read(authProvider).error;
      if (error != null) toast(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(repositoryProvider).profile;
    final auth = ref.watch(authProvider);
    final busy = ref.watch(accessProvider.select((a) => a.busy));
    return ScreenFrame(title: 'Account', children: [
      RowGroup(rows: [
        HolyRow(
            icon: CupertinoIcons.person,
            title: 'Name',
            value: p.name,
            onPressed: _rename),
        HolyRow(
            icon: CupertinoIcons.mail,
            title: 'Email',
            value: auth.user?.email ?? ''),
      ]),
      const SizedBox(height: 16),
      RowGroup(rows: [
        HolyRow(
            icon: CupertinoIcons.arrow_clockwise,
            title: busy ? 'Restoring…' : 'Restore purchase',
            onPressed: busy ? null : _restore),
        HolyRow(
            icon: CupertinoIcons.square_arrow_up,
            title: 'Export my data',
            onPressed: _export),
      ]),
      const SizedBox(height: 16),
      RowGroup(rows: [
        HolyRow(
            icon: CupertinoIcons.square_arrow_left,
            title: 'Sign out',
            onPressed: auth.loading ? null : _signOut),
        HolyRow(
            icon: CupertinoIcons.trash,
            title: auth.loading && auth.action == AuthAction.deleteAccount
                ? 'Deleting…'
                : 'Delete account',
            destructive: true,
            onPressed: auth.loading ? null : _delete),
      ]),
      const Spacer(),
    ]);
  }
}

class _LegalIndex extends StatelessWidget {
  const _LegalIndex();
  @override
  Widget build(BuildContext context) => ScreenFrame(title: 'Privacy and terms', children: [
        RowGroup(rows: [
          HolyRow(
              icon: CupertinoIcons.lock,
              title: 'Privacy Policy',
              onPressed: () => openLegal(context, 'Privacy', 'privacy')),
          HolyRow(
              icon: CupertinoIcons.doc_text,
              title: 'Terms of Use',
              onPressed: () => openLegal(context, 'Terms of Use', 'terms')),
          const HolyRow(
              icon: CupertinoIcons.book,
              title: 'Scripture: World English Bible',
              value: 'Public domain'),
          HolyRow(
              icon: CupertinoIcons.textformat,
              title: 'Font licences',
              onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'HolyHim',
                  applicationVersion: AppConstants.versionLabel)),
        ]),
        const Spacer(),
      ]);
}
