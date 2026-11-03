import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/features/onboarding/personalization.dart';
import 'package:holyher/features/support/support_screens.dart';
import 'package:holyher/services/profile_service.dart';
import 'package:holyher/services/reminder_service.dart';

class NameEditorScreen extends ConsumerStatefulWidget {
  const NameEditorScreen({super.key});
  @override
  ConsumerState<NameEditorScreen> createState() => _NameEditorState();
}

class _NameEditorState extends ConsumerState<NameEditorScreen> {
  late final String _original = ref.read(profileProvider).name;
  late final _name = TextEditingController(text: _original)
    ..addListener(() => setState(() {}));
  bool _busy = false, _leaving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _changed => _name.text.trim() != _original;
  Future<void> _close() async {
    if (_busy) return;
    final discard = await showAdaptiveDialog<bool>(
        context: context,
        builder: (c) =>
            AlertDialog(title: const Text('Leave your changes?'), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Keep editing')),
              TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Discard changes'))
            ]));
    if (discard == true && mounted) {
      setState(() => _leaving = true);
      Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    if (_busy || !_changed) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(profileProvider.notifier)
          .save(ref.read(profileProvider).copyWith(name: _name.text.trim()));
      if (mounted) {
        setState(() => _leaving = true);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Your name could not finish saving. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => PopScope(
          canPop: _leaving || (!_changed && !_busy),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _close();
          },
          child: HolyScaffold(
              title: 'Preferred name',
              body: ReadingWidth(
                  maxWidth: 488,
                  child: ListView(padding: const EdgeInsets.all(24), children: [
                    const Text('What should we call you?',
                        style: HolyTypography.heading),
                    const SizedBox(height: 28),
                    TextField(
                        controller: _name,
                        enabled: !_busy,
                        maxLength: 40,
                        autofillHints: const [AutofillHints.givenName],
                        textCapitalization: TextCapitalization.words,
                        decoration:
                            const InputDecoration(labelText: 'Preferred name'),
                        onSubmitted: (_) => _save()),
                    if (_error != null) InlineMessage(_error!, error: true),
                    const SizedBox(height: 24),
                    HolyButton(
                        label: 'Save name',
                        busy: _busy,
                        onPressed: _changed && !_busy ? _save : null)
                  ])))));
}

class RhythmScreen extends ConsumerWidget {
  const RhythmScreen({super.key});
  Future<void> _edit(BuildContext context, WidgetRef ref, String field) async {
    final profile = ref.read(profileProvider);
    final choices = switch (field) {
      'Starting point' => <String, String>{
          'new': 'New to the Bible',
          'returning': 'Returning to the Bible',
          'regular': 'Reading regularly'
        },
      'Focus' => <String, String>{
          'peace': 'Peace',
          'confidence': 'Confidence',
          'hope': 'Hope',
          'guidance': 'Guidance',
          'rest': 'Rest'
        },
      _ => <String, String>{
          'busy': 'Busy days',
          'forget': 'I forget',
          'language': 'Unfamiliar wording',
          'apply': 'Putting it into practice'
        }
    };
    final current = field == 'Focus'
        ? profile.focus
        : field == 'Starting point'
            ? profile.familiarity
            : profile.obstacle;
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (c) => _ChoiceEditor(
            title: field,
            choices: choices,
            initial: current,
            onSave: (v) => ref.read(profileProvider.notifier).save(ref
                .read(profileProvider)
                .copyWith(
                    focus: field == 'Focus' ? v : null,
                    familiarity: field == 'Starting point' ? v : null,
                    obstacle: field == 'Obstacle' ? v : null))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Theme.of(context);
    final p = ref.watch(profileProvider);
    return HolyScaffold(
        title: 'My rhythm',
        body: ReadingWidth(
            maxWidth: 720,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              const Text('A moment that fits your day.',
                  style: HolyTypography.heading),
              const SizedBox(height: 24),
              MenuRow(
                  title: 'Preferred name',
                  subtitle: p.name.isEmpty ? 'Add a name' : p.name,
                  icon: Icons.person_outline,
                  onTap: () => openScreen(context, const NameEditorScreen())),
              MenuRow(
                  title: 'Starting point',
                  subtitle: familiarityLabel(p.familiarity),
                  icon: Icons.menu_book_outlined,
                  onTap: () => _edit(context, ref, 'Starting point')),
              MenuRow(
                  title: 'Focus',
                  subtitle: focusLabel(p.focus),
                  icon: Icons.wb_sunny_outlined,
                  onTap: () => _edit(context, ref, 'Focus')),
              MenuRow(
                  title: 'Obstacle',
                  subtitle: const {
                    'busy': 'Busy days',
                    'forget': 'I forget',
                    'language': 'Unfamiliar wording',
                    'apply': 'Putting it into practice'
                  }[p.obstacle],
                  icon: Icons.route_outlined,
                  onTap: () => _edit(context, ref, 'Obstacle')),
              MenuRow(
                  title: 'Reminder',
                  subtitle: p.reminderMinutes == null
                      ? 'Off'
                      : reminderLabel(p.reminderMinutes, context: context),
                  icon: Icons.notifications_none_rounded,
                  onTap: () =>
                      openScreen(context, const ReminderSettingsScreen())),
            ])));
  }
}

class _ChoiceEditor extends StatefulWidget {
  final String title, initial;
  final Map<String, String> choices;
  final Future<void> Function(String) onSave;
  const _ChoiceEditor(
      {required this.title,
      required this.initial,
      required this.choices,
      required this.onSave});
  @override
  State<_ChoiceEditor> createState() => _ChoiceEditorState();
}

class _ChoiceEditorState extends State<_ChoiceEditor> {
  late String _value = widget.initial;
  bool _busy = false;
  String? _error;
  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave(_value);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Your change could not finish saving. Retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.title, style: HolyTypography.heading),
                    const SizedBox(height: 24),
                    for (final entry in widget.choices.entries)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: HolyPressable(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _value = entry.key),
                              selected: _value == entry.key,
                              child: QuietInset(
                                  selected: _value == entry.key,
                                  child: Row(children: [
                                    Expanded(child: Text(entry.value)),
                                    Icon(
                                        _value == entry.key
                                            ? Icons.check_circle
                                            : Icons.circle_outlined,
                                        color: AppColors.accent)
                                  ])))),
                    if (_error != null) InlineMessage(_error!, error: true),
                    const SizedBox(height: 16),
                    HolyButton(
                        label: 'Save',
                        busy: _busy,
                        onPressed: _busy ? null : _save)
                  ]))));
}

class ReminderSettingsScreen extends ConsumerStatefulWidget {
  const ReminderSettingsScreen({super.key});
  @override
  ConsumerState<ReminderSettingsScreen> createState() =>
      _ReminderSettingsState();
}

class _ReminderSettingsState extends ConsumerState<ReminderSettingsScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  String? _error;
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
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) ref.invalidate(reminderEnabledProvider);
  }

  Future<void> _set(int? minutes) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileProvider.notifier).setReminder(minutes);
      ref.invalidate(reminderEnabledProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Reminders are off. Allow notifications in device Settings, then retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
    final m = ref.read(profileProvider).reminderMinutes ??
        ref.read(profileProvider).suggestedReminderMinutes ??
        480;
    final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60));
    if (t != null) await _set(t.hour * 60 + t.minute);
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final p = ref.watch(profileProvider),
        enabled = p.reminderMinutes != null &&
            ref.watch(reminderEnabledProvider).valueOrNull == true;
    return HolyScaffold(
        title: 'Daily reminder',
        body: ReadingWidth(
            maxWidth: 488,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              Icon(Icons.notifications_none_rounded,
                  size: 38, color: AppColors.accent),
              const SizedBox(height: 24),
              Text(
                  enabled
                      ? 'A little space in your day.'
                      : 'Reminders are off.',
                  style: HolyTypography.heading),
              const SizedBox(height: 24),
              Text(
                  p.reminderMinutes == null
                      ? 'Choose a time that feels like yours.'
                      : reminderLabel(p.reminderMinutes, context: context),
                  style: HolyTypography.scripture),
              const SizedBox(height: 12),
              Text(
                  enabled
                      ? 'Enabled on this device.'
                      : 'Notification permission and a scheduled reminder are needed.',
                  style: HolyTypography.supporting),
              if (_error != null) InlineMessage(_error!, error: true),
              const SizedBox(height: 32),
              HolyButton(
                  label: enabled ? 'Change time' : 'Choose a time & enable',
                  busy: _busy,
                  onPressed: _busy ? null : _choose),
              const SizedBox(height: 12),
              if (p.reminderMinutes != null)
                HolyButton(
                    label: 'Turn off',
                    secondary: true,
                    onPressed: _busy ? null : () => _set(null)),
              TextButton(
                  onPressed: () => openExternal(context, 'app-settings:'),
                  child: const Text('Open device Settings'))
            ])));
  }
}
