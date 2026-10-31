import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/features/onboarding/onboarding_screen.dart';
import 'package:holyher/features/onboarding/personalization.dart';
import 'package:holyher/features/support/support_screens.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/paywall_service.dart';
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
  String? _message;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(reminderEnabledProvider);
    }
  }

  Future<void> _reminder() async {
    final profile = ref.read(profileProvider);
    final selection = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: AppColors.background,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Your daily reminder',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 10),
                      Text(reminderLabel(profile.reminderMinutes),
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 20),
                      HolyButton(
                          label: 'Choose a time',
                          onPressed: () => Navigator.pop(context, 'time')),
                      const SizedBox(height: 10),
                      HolyButton(
                          label: 'Turn reminder off',
                          secondary: true,
                          onPressed: () => Navigator.pop(context, 'off'))
                    ]))));
    if (selection == null || !mounted) return;
    int? minutes;
    if (selection == 'time') {
      final initial = profile.reminderMinutes ?? 480;
      final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60));
      if (time == null) return;
      minutes = time.hour * 60 + time.minute;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(profileProvider.notifier).setReminder(minutes);
      ref.invalidate(reminderEnabledProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Your reminder could not be enabled. Check notification permission in your device Settings, then try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final restored = await ref.read(paywallProvider.notifier).restore();
    if (mounted) {
      setState(() {
        _busy = false;
        _message = restored
            ? 'Your lifetime access is active.'
            : ref.read(purchaseProvider).error ??
                'No lifetime purchase was found for this store account.';
      });
    }
  }

  Future<void> _logout() async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Sign out?'),
                content: const Text(
                    'Your synced journey stays with your account. Sign in again to return to it.'),
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
    final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                scrollable: true,
                title: const Text('Delete your account?'),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'This permanently removes your account, setup answers, and cloud lesson progress. This cannot be undone. Your App Store purchase is handled separately by Apple.'),
                      const SizedBox(height: 20),
                      TextField(
                          controller: password,
                          obscureText: true,
                          decoration: const InputDecoration(
                              labelText: 'Password, if you use email',
                              helperText:
                                  'Apple and Google will ask you to sign in again.',
                              helperMaxLines: 3))
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

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final auth = ref.watch(authProvider);
    final reminderEnabled = profile.reminderMinutes != null &&
        ref.watch(reminderEnabledProvider).valueOrNull == true;
    final busy = _busy || auth.loading;
    return HolyScaffold(
        title: 'Settings',
        body: ReadingWidth(
            child: ListView(padding: const EdgeInsets.all(26), children: [
          const PageHeading(
              eyebrow: 'Make yourself at home',
              title: 'Your everyday\npreferences.'),
          if (_message != null) InlineMessage(_message!),
          if (_message?.contains('notification permission') == true)
            TextButton(
                onPressed: () => openExternal(context, 'app-settings:'),
                child: const Text('Open device Settings')),
          if (auth.error != null) InlineMessage(auth.error!, error: true),
          const SectionLabel('Your rhythm'),
          MenuRow(
              title: 'Edit your setup',
              subtitle:
                  '${focusLabel(profile.focus)} · ${familiarityLabel(profile.familiarity)}',
              icon: Icons.spa_outlined,
              onTap: busy
                  ? null
                  : () => openScreen(
                      context, const OnboardingScreen(editing: true))),
          MenuRow(
              title: reminderEnabled
                  ? 'Daily reminder'
                  : 'Preferred reminder time',
              subtitle: profile.reminderMinutes == null
                  ? 'No daily reminder'
                  : '${reminderLabel(profile.reminderMinutes)} · ${reminderEnabled ? 'Enabled on this device' : 'Tap to enable on this device'}',
              icon: Icons.notifications_none_rounded,
              onTap: busy ? null : _reminder),
          MenuRow(
              title: 'Gentle haptics',
              subtitle: 'Small taps as you move through your day',
              icon: Icons.vibration_rounded,
              trailing: Switch.adaptive(
                  value: profile.haptics,
                  onChanged: busy
                      ? null
                      : (value) async {
                          try {
                            await ref
                                .read(profileProvider.notifier)
                                .setHaptics(value);
                          } catch (_) {
                            if (context.mounted) {
                              showNotice(context,
                                  'Your preference could not be saved. Please try again.');
                            }
                          }
                        }),
              onTap: null),
          const SectionLabel('Your account'),
          MenuRow(
              title: 'Signed in',
              subtitle: auth.user?.email ?? 'Your HolyHer account',
              icon: Icons.person_outline_rounded),
          MenuRow(
              title: 'Lifetime access',
              subtitle: 'Restore your App Store purchase',
              icon: Icons.verified_outlined,
              onTap: busy ? null : _restore),
          MenuRow(
              title: 'Sign out',
              icon: Icons.logout_rounded,
              onTap: busy ? null : _logout),
          const SectionLabel('Help & information'),
          MenuRow(
              title: 'Help & support',
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
          const SectionLabel('Account data'),
          MenuRow(
              title: 'Delete account',
              subtitle: 'Permanently remove your account and cloud progress',
              icon: Icons.delete_outline_rounded,
              onTap: busy ? null : _delete),
          if (busy)
            const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                    child: SizedBox.square(
                        dimension: 23,
                        child: CircularProgressIndicator(strokeWidth: 2)))),
          const SizedBox(height: 15),
          const Center(child: Eyebrow('HolyHer · 1.0')),
        ])));
  }
}
