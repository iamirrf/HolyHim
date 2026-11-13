import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_constants.dart';
import '../../design/design.dart';
import '../../domain/access.dart';
import '../../services/auth_service.dart';
import '../../services/billing.dart';
import '../../services/notifications.dart';
import '../../services/repository.dart';
import '../common.dart';
import '../support/support_screen.dart';
import 'theme_screen.dart';

String _time(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  return '${h % 12 == 0 ? 12 : h % 12}:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

void _open(BuildContext context, Widget screen) => Navigator.of(context)
    .push(CupertinoPageRoute<void>(builder: (_) => screen));

/// Identity, access, and six rows. Each row opens a composed sub-screen.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = HolyThemeScope.of(context);
    final state = ref.watch(repositoryProvider);
    final user = ref.watch(authProvider).user;
    final owned = ref.watch(lifetimeProvider.select((a) => a.active));
    final p = state.profile;
    final name = p.name.trim().isEmpty ? 'Friend' : p.name.trim();
    final media = MediaQuery.of(context);
    final left = freeDaysLeft(state.completed);
    return ColoredBox(
        color: t.paper,
        child: Padding(
            padding: EdgeInsets.only(top: media.padding.top),
            child: FitColumn(
                padding: EdgeInsets.fromLTRB(HolySpace.gutter, 16,
                    HolySpace.gutter, media.padding.bottom),
                children: [
                  Row(children: [
                    _Avatar(name: name, url: p.avatarUrl),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Semantics(
                              header: true,
                              child: Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: HolyTypography.title
                                      .copyWith(color: t.ink, fontSize: 30))),
                          if (user?.email.isNotEmpty == true)
                            Text(user!.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HolyTypography.caption
                                    .copyWith(color: t.muted)),
                        ])),
                  ]),
                  SizedBox(height: media.size.height < 740 ? 12 : 18),
                  Paper(
                      radius: HolyRadius.card - 6,
                      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                      color: owned
                          ? null
                          : Color.alphaBlend(
                              t.gold.withValues(alpha: .10), t.surface),
                      child: Row(children: [
                        Icon(
                            owned
                                ? CupertinoIcons.checkmark_seal_fill
                                : CupertinoIcons.sun_haze,
                            color: owned ? t.olive : t.gold),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  owned
                                      ? 'Lifetime access'
                                      : left > 0
                                          ? 'Free week · $left ${left == 1 ? 'day' : 'days'} left'
                                          : 'Free week complete',
                                  style: HolyTypography.label
                                      .copyWith(color: t.ink)),
                              Text(
                                  owned
                                      ? 'All 365 days are yours.'
                                      : 'Unlock every day with one payment.',
                                  style: HolyTypography.caption
                                      .copyWith(color: t.muted)),
                            ])),
                        if (!owned)
                          TextAction('Unlock',
                              onPressed: () => context.push('/offer')),
                      ])),
                  SizedBox(height: media.size.height < 740 ? 12 : 18),
                  RowGroup(rows: [
                    HolyRow(
                        icon: CupertinoIcons.bell,
                        title: 'Reminders',
                        value: p.reminderEnabled
                            ? _time(p.reminderMinutes)
                            : 'Off',
                        onPressed: () =>
                            _open(context, const RemindersScreen())),
                    HolyRow(
                        icon: CupertinoIcons.paintbrush,
                        title: 'Theme',
                        value: HolyThemes.byId(p.theme).name,
                        onPressed: () => _open(context, const ThemeScreen())),
                    HolyRow(
                        icon: CupertinoIcons.textformat_size,
                        title: 'Reading',
                        value: '${(p.readingScale * 100).round()}%',
                        onPressed: () =>
                            _open(context, const ReadingScreen())),
                    HolyRow(
                        icon: CupertinoIcons.person_crop_circle,
                        title: 'Account',
                        onPressed: () =>
                            _open(context, const AccountScreen())),
                    HolyRow(
                        icon: CupertinoIcons.chat_bubble_text,
                        title: 'Help and feedback',
                        onPressed: () =>
                            _open(context, const SupportScreen())),
                    HolyRow(
                        icon: CupertinoIcons.doc_text,
                        title: 'Privacy and terms',
                        onPressed: () => _open(context, const _LegalIndex())),
                  ]),
                  const Spacer(),
                  const SizedBox(height: 16),
                  Center(
                      child: Text('HolyHim ${AppConstants.versionLabel}',
                          style:
                              HolyTypography.caption.copyWith(color: t.muted))),
                  const SizedBox(height: 8),
                ])));
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? url;
  const _Avatar({required this.name, this.url});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final initial = name.isEmpty ? 'H' : name.characters.first.toUpperCase();
    return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.alphaBlend(t.accent.withValues(alpha: .12), t.surface),
            border: Border.all(color: t.hairline)),
        clipBehavior: Clip.antiAlias,
        child: url != null && url!.isNotEmpty
            ? Image.network(url!,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => _letter(initial, t))
            : _letter(initial, t));
  }

  Widget _letter(String initial, HolyTheme t) => Center(
      child: Text(initial,
          style: HolyTypography.title.copyWith(color: t.accent, fontSize: 30)));
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
    final ok = await ref.read(lifetimeProvider.notifier).restore();
    if (!mounted) return;
    toast(
        context,
        ok
            ? 'Lifetime access restored. Every day is open.'
            : ref.read(lifetimeProvider).error ?? 'No purchase was found.');
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
            'Your profile, completed lessons and saved verses will be permanently deleted. A lifetime purchase stays with your Apple ID and can be restored on a new account.',
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
    final busy = ref.watch(lifetimeProvider.select((a) => a.busy));
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
