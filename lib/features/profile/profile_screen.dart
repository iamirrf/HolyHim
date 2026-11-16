import 'dart:async';
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
import '../../design/widgets/coin_3d.dart';
import '../../design/widgets/glass.dart';
import '../../design/widgets/top_bar.dart';
import '../../domain/milestones.dart';
import '../../domain/onboarding_flow.dart';
import '../../domain/streak.dart';
import '../../services/auth_service.dart';
import '../../services/billing.dart';
import '../../services/narration.dart';
import '../../services/repository.dart';
import '../common.dart';
import '../circle/circle_screen.dart';
import '../support/support_screen.dart';
import 'app_icon_screen.dart';
import 'theme_screen.dart';
import '../notification_access.dart';
import 'dart:math' as math;
import '../../design/widgets/premium_card.dart';
import '../../design/widgets/avatar_cropper.dart';
import '../../services/avatar_service.dart';
import '../../domain/badges.dart';

String _time(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  return '${h % 12 == 0 ? 12 : h % 12}:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

void _open(BuildContext context, Widget screen) => Navigator.of(context)
    .push(CupertinoPageRoute<void>(builder: (_) => screen));

/// Identity, access, and six rows. Each row opens a composed sub-screen.
/// Profile: who she is, how far she has walked, and every setting, in
/// Cognein's glass. Scrolls under a glass bar that gathers as she scrolls.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _scroll = ScrollController();
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final next = _scroll.offset.clamp(0.0, 120.0);
      if ((next - _offset).abs() > .5) setState(() => _offset = next);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Choose, frame and upload a photo, or remove it, as in Cognein.
  Future<void> _photo() async {
    final t = HolyThemeScope.of(context);
    final profile = ref.read(repositoryProvider).profile;
    final uid = ref.read(authProvider).user?.uid;
    if (uid == null || ref.read(avatarBusyProvider)) return;
    final choice = await showCupertinoModalPopup<String>(
        context: context,
        builder: (sheet) => CupertinoActionSheet(
            title: const Text('Profile photo'),
            message: const Text('Only you see your photo.'),
            actions: [
              CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(sheet).pop('pick'),
                  child: const Text('Choose a photo')),
              if (profile.avatarUrl?.isNotEmpty == true)
                CupertinoActionSheetAction(
                    isDestructiveAction: true,
                    onPressed: () => Navigator.of(sheet).pop('remove'),
                    child: const Text('Remove photo')),
            ],
            cancelButton: CupertinoActionSheetAction(
                onPressed: () => Navigator.of(sheet).pop(),
                child: const Text('Cancel'))));
    if (!mounted || choice == null) return;
    final repo = ref.read(repositoryProvider.notifier);
    if (choice == 'remove') {
      repo.updateProfile(
          ref.read(repositoryProvider).profile.copyWith(avatarUrl: ''));
      return;
    }
    final bytes = await pickAndCropAvatar(context, accent: t.accent);
    if (!mounted || bytes == null) return;
    ref.read(avatarBusyProvider.notifier).state = true;
    try {
      final url = await ref.read(avatarServiceProvider).upload(uid, bytes);
      repo.updateProfile(
          ref.read(repositoryProvider).profile.copyWith(avatarUrl: url));
      HolyHaptics.success();
    } catch (_) {
      if (mounted) {
        toast(context, 'Your photo could not be uploaded. Try again.');
      }
    } finally {
      if (mounted) ref.read(avatarBusyProvider.notifier).state = false;
    }
  }

  Future<void> _restore() async {
    final restored = await ref.read(accessProvider.notifier).restore();
    if (!mounted) return;
    toast(
        context,
        restored
            ? 'Your access is restored. Your walk is open.'
            : ref.read(accessProvider).error ?? 'No purchase was found.');
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final state = ref.watch(repositoryProvider);
    final user = ref.watch(authProvider).user;
    final access = ref.watch(accessProvider);
    final owned = access.active;
    final lifetime = access.purchased || access.retained;
    final p = state.profile;
    final name = p.name.trim().isEmpty ? 'Friend' : p.name.trim();
    final media = MediaQuery.of(context);
    final streak =
        streakFor(state.completed, DateTime.now(), state.profile.timeZone);
    final goal = nextMilestone(state.completed.length);
    final latestGoal = dayBadgeTitles.keys
        .where((d) => d <= state.completed.length)
        .fold<int>(0, math.max);
    final nextBadge = goal == null ? null : 'days-${goal.goal}';
    Widget section(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 26, 0, 10),
        child: Eyebrow(label, color: t.muted));
    return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: backdropPaper(context, t),
        appBar: GlassTopBar(
            title: Text('Profile',
                style: HolyTypography.title.copyWith(color: t.ink)),
            centerTitle: false,
            automaticallyImplyLeading: false,
            maxOpacity: .92,
            maxBlurSigma: 18,
            scrollOffset: _offset),
        body: ListView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
                HolySpace.gutter,
                media.padding.top + 72,
                HolySpace.gutter,
                media.padding.bottom + 24),
            children: [
              PremiumCard(
                  child: Row(children: [
                Semantics(
                    button: true,
                    label: 'Change profile photo',
                    child: GestureDetector(
                        onTap: _photo,
                        child: Stack(clipBehavior: Clip.none, children: [
                          _Avatar(
                              name: name,
                              url: p.avatarUrl,
                              busy: ref.watch(avatarBusyProvider)),
                          Positioned(
                              right: -6,
                              bottom: -4,
                              child: _Pill(
                                  owned: owned,
                                  label: lifetime
                                      ? 'LIFETIME'
                                      : access.member
                                          ? 'MEMBER'
                                          : 'FRIEND')),
                        ]))),
                const SizedBox(width: 18),
                Expanded(
                    child: Pressable(
                        semanticLabel: 'Account',
                        onPressed: () => _open(context, const AccountScreen()),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                  header: true,
                                  child: Text(name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: HolyTypography.title.copyWith(
                                          color: t.metalInk,
                                          fontSize: 27,
                                          fontWeight: FontWeight.w700))),
                              if (user?.email.isNotEmpty == true)
                                Text(user!.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: HolyTypography.caption.copyWith(
                                        color:
                                            t.metalInk.withValues(alpha: .62))),
                              if (latestGoal > 0) ...[
                                const SizedBox(height: 10),
                                Row(children: [
                                  Coin3D(
                                      badgeId: 'days-$latestGoal',
                                      earned: true,
                                      size: 30),
                                  const SizedBox(width: 6),
                                  Flexible(
                                      child: Text(dayBadgeTitles[latestGoal]!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: HolyTypography.label.copyWith(
                                              color: Color.lerp(
                                                  t.metalInk, t.metal[2], .3),
                                              fontWeight: FontWeight.w700))),
                                ]),
                              ],
                            ]))),
              ])),
              const SizedBox(height: 14),
              Row(children: [
                _Tile(
                    value: state.completed.length,
                    label: 'lessons read',
                    icon: CupertinoIcons.book_fill,
                    color: t.accent),
                const SizedBox(width: 10),
                _Tile(
                    value: streak.current,
                    label: 'day walk',
                    icon: CupertinoIcons.sun_max_fill,
                    color: t.gold),
                const SizedBox(width: 10),
                _Tile(
                    value: state.saved.length,
                    label: 'verses kept',
                    icon: CupertinoIcons.heart_fill,
                    color: t.olive),
              ]),
              if (goal != null && nextBadge != null) ...[
                const SizedBox(height: 14),
                Pressable(
                    semanticLabel: goal.distance,
                    onPressed: () => context.go('/growth'),
                    child: Glass(
                        radius: HolyRadius.card - 6,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Row(children: [
                          Coin3D(badgeId: nextBadge, earned: false, size: 56),
                          const SizedBox(width: 16),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('Next medallion',
                                    style: HolyTypography.eyebrow
                                        .copyWith(color: t.accent)),
                                const SizedBox(height: 4),
                                Text(goal.title,
                                    style: HolyTypography.headline
                                        .copyWith(color: t.ink, fontSize: 21)),
                                const SizedBox(height: 8),
                                ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                        value: goal.progress,
                                        minHeight: 5,
                                        color: t.gold,
                                        backgroundColor: t.hairline)),
                                const SizedBox(height: 6),
                                Text(goal.distance.split(' to ').first,
                                    style: HolyTypography.caption
                                        .copyWith(color: t.muted)),
                              ])),
                          Icon(CupertinoIcons.chevron_right,
                              size: 14, color: t.muted),
                        ]))),
              ],
              if (state.syncError != null) ...[
                const SizedBox(height: 14),
                Glass(
                    radius: 22,
                    child: Row(children: [
                      Expanded(
                          child: Text(state.syncError!,
                              style: HolyTypography.caption
                                  .copyWith(color: t.muted))),
                      TextAction('Retry',
                          onPressed: () => ref
                              .read(repositoryProvider.notifier)
                              .retrySync()),
                    ])),
              ],
              section('Your walk'),
              RowGroup(rows: [
                HolyRow(
                    icon: owned
                        ? CupertinoIcons.checkmark_seal_fill
                        : CupertinoIcons.sparkles,
                    title: lifetime
                        ? 'Lifetime access'
                        : access.member
                            ? (access.inTrial ? 'Your free week' : 'Membership')
                            : 'Become a member',
                    value: lifetime
                        ? 'Yours'
                        : access.member
                            ? membershipDate(access)
                            : null,
                    // Apple keeps the subscription: she changes or cancels
                    // it in her App Store settings.
                    onPressed: lifetime
                        ? null
                        : access.member
                            ? () => launchUrl(Uri.parse(manageSubscriptionsUrl),
                                mode: LaunchMode.externalApplication)
                            : () => context.push('/offer')),
                HolyRow(
                    icon: CupertinoIcons.heart,
                    title: 'Saved verses',
                    value: '${state.saved.length}',
                    onPressed: () => context.push('/saved')),
                HolyRow(
                    icon: CupertinoIcons.arrow_clockwise,
                    title: access.busy ? 'Restoring…' : 'Restore purchase',
                    onPressed: access.busy ? null : _restore),
              ]),
              section('Settings'),
              RowGroup(rows: [
                HolyRow(
                    icon: CupertinoIcons.bell,
                    title: 'Reminders',
                    value: p.reminderEnabled ? _time(p.reminderMinutes) : 'Off',
                    onPressed: () => _open(context, const RemindersScreen())),
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
                    icon: CupertinoIcons.person_crop_circle,
                    title: 'Account',
                    onPressed: () => _open(context, const AccountScreen())),
                HolyRow(
                    icon: CupertinoIcons.sparkles,
                    title: 'Retake the welcome',
                    onPressed: () {
                      // Onboarding again from her name; her walk is untouched.
                      final profile = ref.read(repositoryProvider).profile;
                      ref
                          .read(repositoryProvider.notifier)
                          .updateProfile(profile.copyWith(onboardingDraft: {
                            'flowVersion': onboardingFlowVersion,
                            'stepId': 'name',
                            'step': 0,
                          }));
                      context.go('/onboarding?redo=1');
                    }),
              ]),
              section('Help'),
              RowGroup(rows: [
                HolyRow(
                    icon: CupertinoIcons.chat_bubble_text,
                    title: 'Help and feedback',
                    onPressed: () => _open(context, const SupportScreen())),
                HolyRow(
                    icon: CupertinoIcons.doc_text,
                    title: 'Privacy and terms',
                    onPressed: () => _open(context, const _LegalIndex())),
              ]),
              const SizedBox(height: 26),
              Center(
                  child: Column(children: [
                Wordmark(size: 24, color: t.muted),
                const SizedBox(height: 4),
                Text(AppConstants.versionLabel,
                    style: HolyTypography.caption.copyWith(color: t.muted)),
              ])),
            ]));
  }
}

class _Tile extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final Color color;
  const _Tile(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Expanded(
        child: Semantics(
            label: '$value $label',
            excludeSemantics: true,
            child: Glass(
                radius: 22,
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(height: 6),
                      RollingNumber(
                          value: value,
                          style: HolyTypography.numeral
                              .copyWith(color: t.ink, fontSize: 30)),
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              HolyTypography.caption.copyWith(color: t.muted)),
                    ]))));
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? url;
  final bool busy;
  const _Avatar({required this.name, this.url, this.busy = false});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final initial = name.isEmpty ? 'H' : name.characters.first.toUpperCase();
    final photo = url != null && url!.isNotEmpty;
    Widget letter() => Center(
        child: Text(initial,
            style: HolyTypography.title.copyWith(
                color: t.metalInk, fontSize: 34, fontWeight: FontWeight.w700)));
    return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(t.metal[0], Colors.white, .4)!,
                  t.metal[1],
                  t.metal[2]
                ]),
            boxShadow: [
              BoxShadow(
                  color: t.metal[2].withValues(alpha: .33),
                  blurRadius: 14,
                  offset: const Offset(0, 6))
            ]),
        child: Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.metalInk.withValues(alpha: .1)),
            clipBehavior: Clip.antiAlias,
            child: Stack(fit: StackFit.expand, children: [
              if (photo)
                Image.network(url!,
                    fit: BoxFit.cover, errorBuilder: (c, e, s) => letter())
              else
                letter(),
              if (busy)
                const ColoredBox(
                    color: Color(0x66000000),
                    child: Center(
                        child:
                            CupertinoActivityIndicator(color: Colors.white))),
              if (!photo && !busy)
                Align(
                    alignment: const Alignment(0, .78),
                    child: Icon(CupertinoIcons.camera_fill,
                        size: 14, color: t.metalInk.withValues(alpha: .6))),
            ])));
  }
}

/// The small metal pill on the avatar, as in SunRize.
class _Pill extends StatelessWidget {
  final bool owned;
  final String label;
  const _Pill({required this.owned, required this.label});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [t.metal[0], t.metal[1]]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                  color: t.metal[1].withValues(alpha: .4),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
              owned
                  ? CupertinoIcons.checkmark_seal_fill
                  : CupertinoIcons.sparkles,
              size: 12,
              color: t.metalInk),
          const SizedBox(width: 3),
          Text(label,
              style: HolyTypography.eyebrow.copyWith(
                  color: t.metalInk,
                  fontSize: 9,
                  letterSpacing: .8,
                  fontWeight: FontWeight.w800)),
        ]));
  }
}

/// Daily reminder: on/off, time, and the note she will see.
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
    _update(ref
        .read(repositoryProvider)
        .profile
        .copyWith(reminderEnabled: enabled));
    if (!enabled) return;
    unawaited(enableNotifications(context, ref).then((granted) {
      if (!mounted || d != decision) return;
      if (!granted) {
        _update(ref
            .read(repositoryProvider)
            .profile
            .copyWith(reminderEnabled: false));
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
        subtitle: 'One quiet note a day with a verse. Never an advert.',
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
          child: Text(
              'God is our refuge and strength, a very present help in trouble.',
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
        const _ReadAloudRow(),
      ]),
      const Spacer(),
    ]);
  }
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
                    side:
                        BorderSide(color: selected ? t.primary : t.hairline))),
            child: Center(
                child: Text(label,
                    style: HolyTypography.label
                        .copyWith(color: selected ? t.onPrimary : t.ink)))));
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
      ref
          .read(repositoryProvider.notifier)
          .updateProfile(p.copyWith(name: name.trim()));
    }
  }

  Future<void> _restore() async {
    final ok = await ref.read(accessProvider.notifier).restore();
    if (!mounted) return;
    toast(
        context,
        ok
            ? 'Your access is restored. Your walk is open.'
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
            'Your profile, completed lessons and saved verses will be permanently deleted. Deleting your account does not cancel a membership: cancel it in your App Store settings. A membership or lifetime purchase stays with your Apple ID and can be restored on a new account.',
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
                    style: HolyTypography.headline
                        .copyWith(color: HolyThemeScope.of(context).ink)),
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
        HolyRow(
            icon: CupertinoIcons.person_crop_circle_badge_xmark,
            title: 'Blocked members',
            onPressed: () => _open(context, const BlockedMembersScreen())),
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
  Widget build(BuildContext context) =>
      ScreenFrame(title: 'Privacy and terms', children: [
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
