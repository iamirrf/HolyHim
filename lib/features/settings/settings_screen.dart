import 'package:holyher/features/settings/theme_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:holyher/features/settings/data_screens.dart';
import 'package:holyher/services/feedback_service.dart';
import 'package:holyher/services/lesson_audio.dart';
import 'package:holyher/services/learning_service.dart';
import 'package:holyher/services/saved_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/features/settings/profile_editors.dart';
import 'package:holyher/core/constants/app_constants.dart';
import 'package:holyher/features/onboarding/personalization.dart';
import 'package:holyher/features/support/support_screens.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/profile_service.dart';
import 'package:holyher/services/reminder_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  late final _audio =
      LessonAudio(() => mounted && ref.read(profileProvider).sounds);
  String? _message;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _audio.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(reminderEnabledProvider);
    }
  }

  Future<void> _logout() async {
    final pending = ref.read(attemptSyncProvider).pending.isNotEmpty ||
        ref.read(savedProvider).pending.isNotEmpty;
    final yes = await showAdaptiveDialog<bool>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
                title: const Text('Sign out?'),
                content: Text(pending
                    ? 'Your latest changes are saved on this device. They will sync when you sign in again and reconnect.'
                    : 'Your saved journey stays with your account.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Stay here')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sign out'))
                ]));
    if (yes != true) return;
    await ref.read(authProvider.notifier).signOut();
    if (mounted && ref.read(authProvider).user == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _delete() async {
    final password = TextEditingController();
    final passwordAccount = Firebase.apps.isNotEmpty &&
        (fb.FirebaseAuth.instance.currentUser?.providerData
                .any((p) => p.providerId == 'password') ??
            false);
    final result = await showAdaptiveDialog<String>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
                scrollable: true,
                title: const Text('Delete your account?'),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'This permanently removes your account, preferences, saved lessons, attempts, progress, and free-edition grant. This cannot be undone.'),
                      const SizedBox(height: 20),
                      if (passwordAccount)
                        TextField(
                            controller: password,
                            obscureText: true,
                            decoration: const InputDecoration(
                                labelText: 'Current password',
                                helperText:
                                    'Confirm your identity to delete your account.',
                                helperMaxLines: 3)),
                      if (!passwordAccount)
                        const Text(
                            'Your sign-in provider will ask you to confirm your identity.')
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Keep my account')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, password.text),
                      child: const Text('Delete account',
                          style: TextStyle(color: Color(0xFF9C263B))))
                ]));
    password.dispose();
    if (result == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    await ref
        .read(authProvider.notifier)
        .deleteAccount(password: result.isEmpty ? null : result);
    if (!mounted) return;
    if (ref.read(authProvider).user == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _busy = false;
        _message = ref.read(authProvider).error ??
            'Your account could not be deleted. Please try again.';
      });
    }
  }

  Future<void> _preference(UserProfile profile) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(profileProvider.notifier).save(profile);
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Your preference could not finish saving. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final auth = ref.watch(authProvider);
    final reminderEnabled = profile.reminderMinutes != null &&
        ref.watch(reminderEnabledProvider).valueOrNull == true;
    final busy = _busy || auth.loading;
    final passwordAccount = Firebase.apps.isNotEmpty &&
        (fb.FirebaseAuth.instance.currentUser?.providerData
                .any((p) => p.providerId == 'password') ??
            false);
    return HolyScaffold(
        title: 'Settings',
        body: ReadingWidth(
            child: ListView(padding: const EdgeInsets.all(24), children: [
          if (_message != null) InlineMessage(_message!, error: true),
          if (auth.error != null) InlineMessage(auth.error!, error: true),
          const SectionLabel('Account'),
          MenuRow(
              title: 'Signed in',
              subtitle: auth.user?.email ?? 'Your HolyHer account',
              icon: Icons.person_outline_rounded),
          MenuRow(
              title: 'Preferred name',
              subtitle: profile.name.isEmpty ? 'Add a name' : profile.name,
              icon: Icons.edit_outlined,
              onTap: busy
                  ? null
                  : () => openScreen(context, const NameEditorScreen())),
          const MenuRow(
              title: 'HolyHer 365 edition',
              subtitle: 'Free enrollment · keep your unlocked lessons',
              icon: Icons.verified_outlined),
          if (passwordAccount)
            MenuRow(
                title: 'Change password',
                icon: Icons.password,
                onTap: busy
                    ? null
                    : () => openScreen(context, const ChangePasswordScreen())),
          MenuRow(
              title: 'Sign out',
              icon: Icons.logout_rounded,
              onTap: busy ? null : _logout),
          const SectionLabel('My rhythm'),
          MenuRow(
              title: 'Edit my rhythm',
              subtitle:
                  '${focusLabel(profile.focus)} · ${familiarityLabel(profile.familiarity)}',
              icon: Icons.wb_twilight_outlined,
              onTap: busy
                  ? null
                  : () => openScreen(context, const RhythmScreen())),
          MenuRow(
              title: 'Daily reminder',
              subtitle: profile.reminderMinutes == null
                  ? 'Off'
                  : '${reminderLabel(profile.reminderMinutes, context: context)} · ${reminderEnabled ? 'On for this device' : 'Off for this device'}',
              icon: Icons.notifications_none_rounded,
              onTap: busy
                  ? null
                  : () => openScreen(context, const ReminderSettingsScreen())),
          const SectionLabel('Reading and feedback'),
          MenuRow(
              title: 'Theme',
              subtitle: HolyPalette.byId(profile.theme).name,
              icon: Icons.palette_outlined,
              onTap: () => openScreen(context, const ThemeScreen())),
          MenuRow(
              title: 'Reading size',
              subtitle:
                  '${(profile.readingScale * 100).round()}% · Adds to your device text size',
              icon: Icons.text_fields,
              trailing: SizedBox(
                  width: 140,
                  child: Slider(
                      min: 1,
                      max: 2,
                      divisions: 4,
                      value: profile.readingScale,
                      onChanged: busy
                          ? null
                          : (v) =>
                              _preference(profile.copyWith(readingScale: v))))),
          MenuRow(
              title: 'Gentle haptics',
              subtitle: 'Small taps as you move through your day',
              icon: Icons.vibration_rounded,
              trailing: Switch.adaptive(
                  value: profile.haptics,
                  onChanged: busy
                      ? null
                      : (value) =>
                          _preference(profile.copyWith(haptics: value)))),
          MenuRow(
              title: 'Sound effects',
              subtitle: 'Soft reading cues · respects the silent switch',
              icon: Icons.volume_up_outlined,
              trailing: Switch.adaptive(
                  value: profile.sounds,
                  onChanged: busy
                      ? null
                      : (value) {
                          if (!value) _audio.stop();
                          _preference(profile.copyWith(sounds: value));
                        })),
          Wrap(spacing: 12, children: [
            TextButton(
                onPressed: !busy && profile.sounds
                    ? () => _audio.play('lesson_correct', .24)
                    : null,
                child: const Text('Preview sound')),
            TextButton(
                onPressed: !busy && profile.haptics
                    ? () => ref.read(feedbackProvider).light()
                    : null,
                child: const Text('Preview haptic'))
          ]),
          MenuRow(
              title: 'Larger reading text',
              subtitle: 'Adds to your device text size',
              icon: Icons.text_fields,
              trailing: Switch.adaptive(
                  value: profile.largerText,
                  onChanged: busy
                      ? null
                      : (v) => _preference(profile.copyWith(largerText: v)))),
          const QuietInset(
              child: Text(
                  'God is our refuge and strength, a very present help in trouble. — Psalm 46:1 (WEB)',
                  style: HolyTypography.reading)),
          MenuRow(
              title: 'Reading tips',
              subtitle: 'Contextual guidance while learning',
              icon: Icons.tips_and_updates_outlined,
              trailing: Switch.adaptive(
                  value: profile.tips,
                  onChanged: busy
                      ? null
                      : (v) => _preference(profile.copyWith(tips: v)))),
          const SectionLabel('Data'),
          MenuRow(
              title: 'Export my data',
              subtitle:
                  'A copy of your profile, reading history, and saved items',
              icon: Icons.file_download_outlined,
              onTap: busy
                  ? null
                  : () => openScreen(context, const ExportDataScreen())),
          MenuRow(
              title: 'Reset reading progress',
              subtitle:
                  'Keep calendar availability, saved items, and edition access',
              icon: Icons.restart_alt,
              onTap: busy
                  ? null
                  : () => openScreen(context, const ResetProgressScreen())),
          if (ref.watch(attemptSyncProvider).pending.isNotEmpty ||
              ref.watch(savedProvider).pending.isNotEmpty)
            MenuRow(
                title: 'Changes waiting to sync',
                subtitle: 'Your latest progress will sync when you’re online.',
                icon: Icons.cloud_upload_outlined,
                onTap: busy
                    ? null
                    : () async {
                        await ref.read(attemptSyncProvider.notifier).sync();
                        await ref.read(savedProvider.notifier).sync();
                      }),
          MenuRow(
              title: 'Delete account',
              subtitle: 'Permanently remove your account and cloud progress',
              icon: Icons.delete_outline_rounded,
              onTap: busy ? null : _delete),
          const SectionLabel('Support'),
          MenuRow(
              title: 'Help',
              icon: Icons.help_outline_rounded,
              onTap: () => openScreen(context, const HelpScreen())),
          MenuRow(
              title: 'About HolyHer',
              icon: Icons.info_outline_rounded,
              onTap: () => openScreen(context, const AboutScreen())),
          MenuRow(
              title: 'Privacy',
              icon: Icons.lock_outline_rounded,
              onTap: () => openScreen(context, const PrivacyScreen())),
          MenuRow(
              title: 'Terms',
              icon: Icons.description_outlined,
              onTap: () => openScreen(context, const TermsScreen())),
          if (busy)
            const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                    child: SizedBox.square(
                        dimension: 23,
                        child: CircularProgressIndicator(strokeWidth: 2)))),
          const SizedBox(height: 24),
          Center(
              child: Text('HolyHer · ${AppConstants.versionLabel}',
                  style: HolyTypography.supporting)),
        ])));
  }
}
