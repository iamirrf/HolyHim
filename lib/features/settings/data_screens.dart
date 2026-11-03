import 'package:holyher/services/reading_service.dart';
import 'dart:convert';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/models/learning.dart';
import 'package:holyher/services/learning_service.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/progress_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController(), _next = TextEditingController();
  bool _busy = false;
  String? _message;
  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user?.email == null) {
        throw StateError('Sign in again to change your password.');
      }
      await user!.reauthenticateWithCredential(fb.EmailAuthProvider.credential(
          email: user.email!, password: _current.text));
      await user.updatePassword(_next.text);
      if (mounted) {
        _current.clear();
        _next.clear();
        setState(() => _message = 'Your password was changed.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Your password could not be changed. Check your current password and connection, then retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => HolyScaffold(
          title: 'Change password',
          body: ReadingWidth(
              maxWidth: 560,
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                      key: _form,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                                controller: _current,
                                obscureText: true,
                                autofillHints: const [AutofillHints.password],
                                decoration: const InputDecoration(
                                    labelText: 'Current password'),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Enter your current password.'
                                    : null),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: _next,
                                obscureText: true,
                                autofillHints: const [
                                  AutofillHints.newPassword
                                ],
                                decoration: const InputDecoration(
                                    labelText: 'New password',
                                    helperText: 'At least 8 characters.'),
                                validator: (v) => v == null || v.length < 8
                                    ? 'Use at least 8 characters.'
                                    : v == _current.text
                                        ? 'Choose a different password.'
                                        : null),
                            if (_message != null) InlineMessage(_message!),
                            const SizedBox(height: 24),
                            HolyButton(
                                label: 'Save password',
                                busy: _busy,
                                onPressed: _busy ? null : _save)
                          ]))))));
}

class ResetProgressScreen extends ConsumerStatefulWidget {
  const ResetProgressScreen({super.key});
  @override
  ConsumerState<ResetProgressScreen> createState() => _ResetProgressState();
}

class _ResetProgressState extends ConsumerState<ResetProgressScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    final yes = await showAdaptiveDialog<bool>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
                title: const Text('Reset reading progress?'),
                content: const Text(
                    'Completions, attempts, and reading positions will be cleared. Earned badges stay yours. Your start date, timezone, unlocked lessons, saved items, preferences, and edition access stay with your account.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Reset progress'))
                ]));
    if (yes != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final uid = ref.read(authProvider).user?.uid;
    final store = ref.read(localStoreProvider);
    final gateway = ref.read(learningGatewayProvider);
    bool current() => mounted && ref.read(authProvider).user?.uid == uid;
    Future<void> write(String key, Object value) async {
      if (!current()) throw StateError('Account changed.');
      if (!await store.write(key, value)) {
        throw StateError('Local reset cleanup failed.');
      }
    }

    try {
      if (uid == null || gateway == null) throw StateError('Sign in again.');
      await ref
          .read(authProvider.notifier)
          .reauthenticate(password: _password.text);
      if (!current()) return;
      final existing = await store.read('reset_operation');
      if (!current()) return;
      final operationId = existing is String && existing.isNotEmpty
          ? existing
          : newOperationId();
      await write('reset_operation', operationId);
      final result = await gateway
          .call('resetLearningProgress', {'operationId': operationId});
      if (!current()) return;
      await ref.read(progressProvider.notifier).applyAttemptResult(result);
      if (!current()) return;
      await ref
          .read(attemptSyncProvider.notifier)
          .reconcileReset(result['revision'] as int);
      if (!current()) return;
      await ref
          .read(readingSyncProvider.notifier)
          .reconcileReset(result['revision'] as int);
      // Clear legacy work before advancing its revision marker.
      await write('pending_completions', <String>[]);
      await write('pending_completion_revision', result['revision'] as int);
      for (var day = 1; day <= 365; day++) {
        final raw = await store.read('lesson_resume_$day');
        if (!current()) return;
        if (raw is String && raw.isNotEmpty) {
          final resume =
              LessonResume.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
          if (resume.attempt.journeyRevision < result['revision']) {
            await write('lesson_resume_$day', '');
          }
        }
        final reading = await store.read('reading_checkpoint_$day');
        if (reading is String &&
            reading.isNotEmpty &&
            ((jsonDecode(reading) as Map)['journeyRevision'] as int? ?? 0) <
                result['revision']) {
          await write('reading_checkpoint_$day', '');
        }
        await write('card_position_${uid}_$day', 0);
        await write('card_position_${uid}_${day}_semantic', '');
      }
      if (!current()) return;
      await ref.read(progressProvider.notifier).refresh();
      if (!current()) return;
      await write('reset_operation', '');
      if (mounted && current()) {
        showNotice(context, 'Your reading progress was reset.');
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'The reset could not finish. Sign in again, reconnect, and retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => HolyScaffold(
          title: 'Reset reading progress',
          body: ReadingWidth(
              maxWidth: 560,
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                            'Start practice again while keeping your original calendar availability and edition access. This action requires a recent sign-in.'),
                        const SizedBox(height: 20),
                        if (Firebase.apps.isNotEmpty &&
                            (fb.FirebaseAuth.instance.currentUser?.providerData
                                    .any((p) => p.providerId == 'password') ??
                                false))
                          TextField(
                              controller: _password,
                              obscureText: true,
                              decoration: const InputDecoration(
                                  labelText: 'Current password',
                                  helperText:
                                      'Apple and Google will ask you to sign in again.',
                                  helperMaxLines: 3)),
                        if (_error != null) InlineMessage(_error!, error: true),
                        const SizedBox(height: 24),
                        HolyButton(
                            label: 'Reset reading progress',
                            destructive: true,
                            busy: _busy,
                            onPressed: _busy ? null : _reset)
                      ])))));
}

Future<bool> exportAccountData(BuildContext context, WidgetRef ref) async {
  final uid = ref.read(authProvider).user?.uid;
  final box = context.findRenderObject() as RenderBox?;
  final anchor = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  try {
    final gateway = ref.read(learningGatewayProvider);
    if (gateway == null) throw StateError('Reconnect to export your account.');
    final result = await gateway.call('exportAccountData', {});
    if (!context.mounted || ref.read(authProvider).user?.uid != uid) {
      return false;
    }
    final store = ref.read(localStoreProvider);
    final payload = {
      ...result,
      'schemaVersion': 1,
      'localRecords': store is ExportableLocalStore
          ? await (store as ExportableLocalStore).exportRecords()
          : null,
      'localPending': {
        'attempts': await store.read('attempt_outbox'),
        'saved': await store.read('saved_lessons'),
        'legacyCompletions': await store.read('pending_completions'),
        'profileDraft': await store.read('profile'),
        'profilePending': await store.read('profile_pending'),
        'profileFinalizing': await store.read('profile_finalizing')
      }
    };
    if (!context.mounted || ref.read(authProvider).user?.uid != uid) {
      return false;
    }
    await SharePlus.instance.share(ShareParams(files: [
      XFile.fromData(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)),
          mimeType: 'application/json')
    ], fileNameOverrides: const [
      'holyher-account.json'
    ], sharePositionOrigin: anchor));
    return true;
  } catch (_) {
    if (context.mounted) {
      showNotice(
          context, 'Your export could not be prepared. Reconnect and retry.');
    }
    return false;
  }
}

class ExportDataScreen extends ConsumerStatefulWidget {
  const ExportDataScreen({super.key});
  @override
  ConsumerState<ExportDataScreen> createState() => _ExportDataState();
}

class _ExportDataState extends ConsumerState<ExportDataScreen> {
  bool _busy = false;
  bool? _prepared;
  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await exportAccountData(context, ref);
    if (mounted) {
      setState(() {
        _busy = false;
        _prepared = ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => HolyScaffold(
          title: 'Export my data',
          body: ReadingWidth(
              maxWidth: 488,
              child: ListView(padding: const EdgeInsets.all(24), children: [
                Icon(Icons.file_download_outlined,
                    size: 40, color: AppColors.accent),
                const SizedBox(height: 28),
                const Text('Your journey, a copy to keep.',
                    style: HolyTypography.heading),
                const SizedBox(height: 16),
                const Text(
                    'Prepare a file with your profile, preferences, reading history, saved lessons, and changes waiting to sync.'),
                const SizedBox(height: 24),
                if (_prepared != null)
                  InlineMessage(
                      _prepared!
                          ? 'Your file is ready to share.'
                          : 'Your file could not be prepared. Reconnect and retry.',
                      error: !_prepared!),
                HolyButton(
                    label:
                        _prepared == false ? 'Retry export' : 'Prepare & share',
                    busy: _busy,
                    onPressed: _busy ? null : _export)
              ]))));
}
