import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../design/design.dart';
import '../../services/auth_service.dart';
import '../../services/notifications.dart';
import '../../services/repository.dart';
import '../../services/avatar_service.dart';
import '../../services/billing.dart';
import '../../domain/streak.dart';
import 'theme_screen.dart';
import 'edit_profile_screen.dart';
import '../common.dart';
import '../support/support_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _scroll = ScrollController();
  double _offset = 0;
  int _reminderDecision = 0;
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
    super.dispose();
  }

  void _update(AppProfile profile) =>
      ref.read(repositoryProvider.notifier).updateProfile(profile);

  Future<void> _time() async {
    final profile = ref.read(repositoryProvider).profile;
    await showCupertinoModalPopup<void>(
        context: context,
        builder: (context) => Container(
            height: 320,
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
                top: false,
                child: Column(children: [
                  Row(children: [
                    const SizedBox(width: 16),
                    Expanded(
                        child: Text('Your daily minute', style: ui(context))),
                    CupertinoButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'))
                  ]),
                  Expanded(
                      child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.time,
                          initialDateTime: DateTime(
                              2026,
                              1,
                              1,
                              profile.reminderMinutes ~/ 60,
                              profile.reminderMinutes % 60),
                          onDateTimeChanged: (date) => _update(ref
                              .read(repositoryProvider)
                              .profile
                              .copyWith(
                                  reminderMinutes:
                                      date.hour * 60 + date.minute))))
                ]))));
  }

  void _reminders(bool enabled) {
    final decision = ++_reminderDecision;
    _update(ref
        .read(repositoryProvider)
        .profile
        .copyWith(reminderEnabled: enabled));
    if (!enabled) return;
    unawaited(ref
        .read(notificationServiceProvider)
        .requestPermission()
        .then((granted) {
      if (!mounted || decision != _reminderDecision) return;
      if (!granted) {
        _update(ref
            .read(repositoryProvider)
            .profile
            .copyWith(reminderEnabled: false));
        toast(context, 'You can allow reminders in your device settings.');
      }
    }));
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

  Future<void> _delete() async {
    if (!await confirm(context,
        title: 'Delete your HolyHim account?',
        message:
            'Your profile, completed lessons and saved verses will be permanently deleted. This cannot be undone.',
        action: 'Delete account',
        destructive: true)) {
      return;
    }
    if (!mounted) return;
    final passwordRequired = Firebase.apps.isNotEmpty &&
        (firebase.FirebaseAuth.instance.currentUser?.providerData
                .any((p) => p.providerId == 'password') ??
            false);
    String? password;
    if (passwordRequired) {
      final controller = TextEditingController();
      password = await showCupertinoDialog<String>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
                  title: const Text('Confirm your password'),
                  content: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: CupertinoTextField(
                          controller: controller,
                          obscureText: true,
                          autofocus: true,
                          placeholder: 'Password',
                          autofillHints: const [AutofillHints.password])),
                  actions: [
                    CupertinoDialogAction(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    CupertinoDialogAction(
                        isDestructiveAction: true,
                        onPressed: () {
                          if (controller.text.isNotEmpty) {
                            Navigator.pop(context, controller.text);
                          }
                        },
                        child: const Text('Delete account'))
                  ]));
      controller.dispose();
      if (password == null) return;
    }
    if (!mounted) return;
    await ref.read(authProvider.notifier).deleteAccount(password: password);
    if (mounted) {
      final error = ref.read(authProvider).error;
      if (error != null) toast(context, error);
    }
  }

  void _about() => glassSheet(
      context,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Brand(),
        const SizedBox(height: 22),
        const Text(AppConstants.tagline, style: HolyTypography.title),
        const SizedBox(height: 8),
        const Text('Stronger in the Word, every day.',
            style: HolyTypography.reading),
        const SizedBox(height: 16),
        Text(
            'HolyHim is your daily walk with God — built for men. Every day, a new lesson in Scripture, understanding, reflection, and prayer.',
            style: ui(context)),
        const SizedBox(height: 18),
        Text(
            'Bible quotations: World English Bible, public domain.\nMade with care by Codellion LLC.\nVersion ${AppConstants.versionLabel}',
            style: muted(context))
      ]));

  void _settings() => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Consumer(builder: (context, ref, _) {
            final profile = ref.watch(repositoryProvider).profile;
            final theme = HolyThemeScope.of(context);
            final time = TimeOfDay(
                    hour: profile.reminderMinutes ~/ 60,
                    minute: profile.reminderMinutes % 60)
                .format(context);
            return Scaffold(
                extendBodyBehindAppBar: true,
                appBar: const GlassTopBar(
                    title: Text('Settings', style: HolyTypography.title)),
                body: PageBody(
                    padding: EdgeInsets.fromLTRB(
                        24, MediaQuery.paddingOf(context).top + 86, 24, 40),
                    children: [
                      Glass(
                          padding: const EdgeInsets.all(20),
                          child: Column(children: [
                            _SettingRow(
                                icon: CupertinoIcons.bell,
                                title: 'Daily reminder',
                                subtitle: 'Your daily call to the Word.',
                                trailing: CupertinoSwitch(
                                    value: profile.reminderEnabled,
                                    onChanged: _reminders)),
                            const SizedBox(height: 15),
                            _ActionRow(
                                icon: CupertinoIcons.clock,
                                label: 'Meet at $time',
                                onPressed: _time),
                            const SizedBox(height: 20),
                            Divider(
                                color: theme.accent.withValues(alpha: .12),
                                height: 1),
                            const SizedBox(height: 20),
                            Row(children: [
                              const Icon(CupertinoIcons.textformat_size,
                                  color: rose, size: 22),
                              const SizedBox(width: 13),
                              Expanded(
                                  child:
                                      Text('Reading size', style: ui(context))),
                              Text('${(profile.readingScale * 100).round()}%',
                                  style: muted(context))
                            ]),
                            Slider.adaptive(
                                value: profile.readingScale,
                                min: 1,
                                max: 2,
                                divisions: 10,
                                label:
                                    '${(profile.readingScale * 100).round()}%',
                                onChanged: (value) => _update(
                                    profile.copyWith(readingScale: value))),
                            Text('Room to read, reflect, and pray.',
                                textAlign: TextAlign.center,
                                style: HolyTypography.reading.copyWith(
                                    fontSize: 16 * profile.readingScale)),
                            const SizedBox(height: 24),
                            _SettingRow(
                                icon: CupertinoIcons.hand_draw,
                                title: 'Haptics',
                                subtitle: 'Subtle feedback as you go.',
                                trailing: CupertinoSwitch(
                                    value: profile.haptics,
                                    onChanged: (value) {
                                      HolyHaptics.enabled = value;
                                      _update(profile.copyWith(haptics: value));
                                    })),
                            const SizedBox(height: 20),
                            _SettingRow(
                                icon: CupertinoIcons.speaker_1,
                                title: 'Sounds',
                                subtitle: 'Always follows your silent switch.',
                                trailing: CupertinoSwitch(
                                    value: profile.sounds,
                                    onChanged: (value) {
                                      HolySounds.enabled = value;
                                      _update(profile.copyWith(sounds: value));
                                    }))
                          ])),
                      const SizedBox(height: 24),
                      const Eyebrow('Your account'),
                      const SizedBox(height: 14),
                      Glass(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          child: Column(children: [
                            _ActionRow(
                                icon: CupertinoIcons.square_arrow_up,
                                label: 'Export my data',
                                onPressed: _export),
                            _ActionRow(
                                icon: CupertinoIcons.trash,
                                label: 'Delete account',
                                destructive: true,
                                onPressed: _delete),
                          ])),
                    ]));
          })));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(repositoryProvider),
        auth = ref.watch(authProvider),
        profile = state.profile;
    final theme = HolyThemeScope.of(context);
    final streak = streakFor(state.completed, DateTime.now(), profile.timeZone);
    final access = ref.watch(lifetimeProvider);
    final photo = visibleAvatarUrl(profile.avatarUrl, auth.user?.photoUrl);
    final nextGoal = [1, 3, 7, 14, 21, 30, 50, 75, 100, 150, 200, 250, 300, 365]
        .firstWhere((n) => n > state.completed.length, orElse: () => 365);
    Widget group(List<Widget> rows) => Glass(
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: Column(children: rows));
    Widget section(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 28, 0, 12),
        child: Eyebrow(label));
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: GlassTopBar(
            title: const Text('Profile', style: HolyTypography.title),
            centerTitle: false,
            automaticallyImplyLeading: false,
            scrollOffset: _offset),
        body: PageBody(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.paddingOf(context).top + 86, 24, 150),
            children: [
              Pressable(
                  semanticLabel: 'Edit profile',
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const EditProfileScreen())),
                  child: Glass(
                      radius: 24,
                      elevation: 3,
                      padding: const EdgeInsets.all(22),
                      child: Row(children: [
                        Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: theme.accent.withValues(alpha: .35),
                                    width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          theme.accent.withValues(alpha: .13),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8))
                                ]),
                            child: CircleAvatar(
                                radius: 35,
                                backgroundColor:
                                    theme.accent.withValues(alpha: .12),
                                backgroundImage:
                                    photo == null ? null : NetworkImage(photo),
                                child: photo == null
                                    ? Text(
                                        profile.name.isEmpty
                                            ? 'H'
                                            : profile.name[0].toUpperCase(),
                                        style: HolyTypography.title
                                            .copyWith(color: theme.accent))
                                    : null)),
                        const SizedBox(width: 18),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  profile.name.isEmpty
                                      ? 'Your profile'
                                      : profile.name,
                                  style: HolyTypography.title
                                      .copyWith(fontSize: 24)),
                              const SizedBox(height: 5),
                              Text(
                                  profile.username.isNotEmpty
                                      ? profile.username
                                      : auth.user?.email ?? '',
                                  style: muted(context).copyWith(fontSize: 11)),
                              const SizedBox(height: 10),
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                      color: theme.accent.withValues(alpha: .1),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Text(
                                      access.active
                                          ? 'Lifetime member'
                                          : 'Your Scripture walk',
                                      style: HolyTypography.ui.copyWith(
                                          fontSize: 10,
                                          color: theme.accent,
                                          fontWeight: FontWeight.w700))),
                            ])),
                        const SizedBox(width: 10),
                        Icon(CupertinoIcons.pencil,
                            size: 18, color: theme.accent),
                      ]))),
              const SizedBox(height: 18),
              Row(children: [
                _stat('${state.completed.length}', 'Days read'),
                const SizedBox(width: 10),
                _stat('${streak.current}', 'Day streak'),
                const SizedBox(width: 10),
                _stat('${state.saved.length}', 'Verses kept')
              ]),
              const SizedBox(height: 18),
              Pressable(
                  semanticLabel: 'View milestones',
                  onPressed: () => context.go('/growth'),
                  child: Glass(
                      radius: 24,
                      child: Row(children: [
                        ProgressRing(
                            progress: state.completed.length / nextGoal,
                            size: 58,
                            child: const Icon(CupertinoIcons.sparkles,
                                color: Color(0xFFAA7C39), size: 23)),
                        const SizedBox(width: 18),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Your next milestone',
                                  style: HolyTypography.ui
                                      .copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text(
                                  '${state.completed.length} of $nextGoal days',
                                  style: muted(context).copyWith(fontSize: 12))
                            ])),
                        const Icon(CupertinoIcons.chevron_right, size: 13),
                      ]))),
              if (state.syncError != null) ...[
                const SizedBox(height: 18),
                Glass(
                    radius: 22,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(state.syncError!, style: muted(context)),
                          TextButton(
                              onPressed: () => ref
                                  .read(repositoryProvider.notifier)
                                  .retrySync(),
                              child: const Text('Retry sync')),
                        ]))
              ],
              section('Your walk'),
              group([
                _ActionRow(
                    icon: CupertinoIcons.book,
                    label:
                        access.active ? 'Lifetime access' : 'HolyHim lifetime',
                    onPressed: () => context.push('/paywall')),
                _ActionRow(
                    icon: CupertinoIcons.arrow_clockwise,
                    label: 'Restore purchases',
                    onPressed: access.busy
                        ? null
                        : () async {
                            final restored = await ref
                                .read(lifetimeProvider.notifier)
                                .restore();
                            if (context.mounted) {
                              toast(
                                  context,
                                  restored
                                      ? 'Your lifetime access is restored.'
                                      : ref.read(lifetimeProvider).error ??
                                          'No purchase was found.');
                            }
                          }),
              ]),
              section('Preferences'),
              group([
                _ActionRow(
                    icon: CupertinoIcons.paintbrush,
                    label: 'Theme · ${theme.name}',
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const ThemeScreen()))),
                _ActionRow(
                    icon: CupertinoIcons.slider_horizontal_3,
                    label: 'Settings',
                    onPressed: _settings),
                _ActionRow(
                    icon: CupertinoIcons.square_grid_2x2,
                    label: 'Verse of the Day widget',
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const WidgetGuideScreen()))),
              ]),
              section('Support'),
              group([
                _ActionRow(
                    icon: CupertinoIcons.bubble_left_bubble_right,
                    label: 'Help & support',
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const SupportScreen()))),
                _ActionRow(
                    icon: CupertinoIcons.info_circle,
                    label: 'About HolyHim',
                    onPressed: _about),
                _ActionRow(
                    icon: CupertinoIcons.hand_raised,
                    label: 'Privacy',
                    onPressed: () => openLegal(context, 'Privacy', 'privacy')),
                _ActionRow(
                    icon: CupertinoIcons.doc_text,
                    label: 'Terms',
                    onPressed: () =>
                        openLegal(context, 'Terms of Use', 'terms')),
              ]),
              const SizedBox(height: 24),
              _ActionRow(
                  icon: CupertinoIcons.arrow_right_square,
                  label: auth.loading ? 'Please wait…' : 'Sign out',
                  onPressed: auth.loading
                      ? null
                      : () async {
                          if (await confirm(context,
                              title: 'Sign out?',
                              message:
                                  'Your walk stays with your account. Sign in again to return.',
                              action: 'Sign out')) {
                            await ref.read(authProvider.notifier).signOut();
                          }
                        }),
              const SizedBox(height: 18),
              Center(
                  child: Text('HolyHim · ${AppConstants.versionLabel}',
                      style: muted(context).copyWith(fontSize: 10))),
            ]));
  }

  Widget _stat(String value, String label) => Expanded(
      child: Glass(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
          child: Column(children: [
            Text(value, style: HolyTypography.title.copyWith(fontSize: 26)),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: muted(context).copyWith(fontSize: 10)),
          ])));
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget trailing;
  const _SettingRow(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.trailing});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: rose, size: 22),
        const SizedBox(width: 13),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: ui(context)),
          const SizedBox(height: 4),
          Text(subtitle, style: muted(context).copyWith(fontSize: 11))
        ])),
        const SizedBox(width: 8),
        trailing
      ]);
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;
  const _ActionRow(
      {required this.icon,
      required this.label,
      required this.onPressed,
      this.destructive = false});
  @override
  Widget build(BuildContext context) => Pressable(
      onPressed: onPressed,
      semanticLabel: label,
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(children: [
            Icon(icon,
                color: destructive ? const Color(0xFFA67C37) : rose, size: 21),
            const SizedBox(width: 13),
            Expanded(
                child: Text(label,
                    style: ui(context).copyWith(
                        color: destructive ? const Color(0xFFA67C37) : null))),
            const SizedBox(width: 8),
            Icon(CupertinoIcons.chevron_right,
                size: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: .35))
          ])));
}

class WidgetGuideScreen extends StatelessWidget {
  const WidgetGuideScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassTopBar(
          title: Text('A word nearby', style: HolyTypography.title)),
      body: PageBody(
          padding: EdgeInsets.fromLTRB(
              24, MediaQuery.paddingOf(context).top + 90, 24, 48),
          children: [
            const Eyebrow('Verse of the Day'),
            const SizedBox(height: 16),
            const Text('A little Scripture,\nright where you are.',
                style: HolyTypography.display),
            const SizedBox(height: 24),
            const Glass(
                elevation: 3,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Brand(),
                      SizedBox(height: 22),
                      Text(
                          'Be strong and courageous. Don’t be afraid or scared of them…',
                          style: HolyTypography.title),
                      SizedBox(height: 16),
                      Eyebrow('Day 1 · Deuteronomy 31:6')
                    ])),
            const SizedBox(height: 28),
            for (final entry in const {
              '01':
                  'Touch and hold an empty place on your iPhone or iPad Home Screen.',
              '02': 'Choose Edit, then Add Widget. Search for HolyHim.',
              '03': 'Choose a size, add your widget, and tap Done.'
            }.entries)
              Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                            width: 42,
                            child: Text(entry.key,
                                style: HolyTypography.eyebrow
                                    .copyWith(color: rose))),
                        Expanded(child: Text(entry.value, style: ui(context)))
                      ])),
            Text(
                'For your Lock Screen, touch and hold it, choose Customize, then Add Widgets. HolyHim offers a small rectangular verse widget.',
                style: muted(context)),
            const SizedBox(height: 20),
            Text(
                'Open HolyHim after installing it so your widget can receive your current verse. Tap the widget any time to return to your walk.',
                style: muted(context))
          ]));
}
