import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../design/design.dart';
import '../common.dart';

/// SunRize's full-screen email form, sharing HolyHim's persistent atmosphere.
class EmailSheet extends ConsumerStatefulWidget {
  const EmailSheet({super.key});
  @override
  ConsumerState<EmailSheet> createState() => _EmailSheetState();
}

class _EmailSheetState extends ConsumerState<EmailSheet> {
  final email = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  final form = GlobalKey<FormState>();
  bool create = false, obscure = true;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = ref.read(authProvider.notifier);
    if (create) {
      await auth.signUpEmail(email.text, password.text);
    } else {
      await auth.signInEmail(email.text, password.text);
    }
    if (mounted && ref.read(authProvider).user != null) {
      Navigator.of(context).pop();
    }
  }

  Future<void> reset() async {
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email.text.trim())) {
      toast(context, 'Enter your email address first.');
      return;
    }
    await ref.read(authProvider.notifier).resetPassword(email.text);
    if (mounted) {
      toast(
          context,
          ref.read(authProvider).error ??
              'If an account exists, a reset link is on its way.');
    }
  }

  Widget field(Widget child) => Glass(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: child);
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider), theme = HolyThemeScope.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final strength = [
      password.text.length >= 8,
      password.text.length >= 12,
      RegExp(r'[A-Z]').hasMatch(password.text) &&
          RegExp(r'[a-z]').hasMatch(password.text),
      RegExp(r'[0-9\W]').hasMatch(password.text)
    ].where((v) => v).length;
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(32, 24, 32, 28),
                        child: AutofillGroup(
                            child: Form(
                                key: form,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      AnimatedSize(
                                          duration:
                                              MediaQuery.disableAnimationsOf(
                                                      context)
                                                  ? Duration.zero
                                                  : const Duration(
                                                      milliseconds: 300),
                                          child: keyboard
                                              ? const SizedBox.shrink()
                                              : Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 30),
                                                  child: Center(
                                                      child: Text('HolyHim',
                                                          style: HolyTypography
                                                              .wordmark
                                                              .copyWith(
                                                                  fontSize: 64,
                                                                  color: theme
                                                                      .accent))))),
                                      Text(
                                          create
                                              ? 'Create your account'
                                              : 'Welcome back',
                                          textAlign: TextAlign.center,
                                          style: HolyTypography.title),
                                      const SizedBox(height: 10),
                                      Text('Keep your Scripture walk with you.',
                                          textAlign: TextAlign.center,
                                          style: muted(context)),
                                      const SizedBox(height: 30),
                                      field(TextFormField(
                                          controller: email,
                                          autofillHints: const [
                                            AutofillHints.email
                                          ],
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          textInputAction: TextInputAction.next,
                                          decoration: const InputDecoration(
                                              labelText: 'Email address',
                                              border: InputBorder.none,
                                              prefixIcon:
                                                  Icon(CupertinoIcons.mail)),
                                          validator: (v) => RegExp(
                                                      r'^\S+@\S+\.\S+$')
                                                  .hasMatch(v?.trim() ?? '')
                                              ? null
                                              : 'Enter your email address.')),
                                      const SizedBox(height: 16),
                                      field(TextFormField(
                                          controller: password,
                                          obscureText: obscure,
                                          onChanged: (_) => setState(() {}),
                                          autofillHints: [
                                            create
                                                ? AutofillHints.newPassword
                                                : AutofillHints.password
                                          ],
                                          textInputAction: create
                                              ? TextInputAction.next
                                              : TextInputAction.done,
                                          onFieldSubmitted: (_) {
                                            if (!create) submit();
                                          },
                                          decoration: InputDecoration(
                                              labelText: 'Password',
                                              border: InputBorder.none,
                                              prefixIcon: const Icon(
                                                  CupertinoIcons.lock),
                                              suffixIcon: IconButton(
                                                  tooltip: obscure
                                                      ? 'Show password'
                                                      : 'Hide password',
                                                  onPressed: () => setState(
                                                      () => obscure = !obscure),
                                                  icon: Icon(obscure
                                                      ? CupertinoIcons.eye
                                                      : CupertinoIcons
                                                          .eye_slash))),
                                          validator: (v) => (v?.length ?? 0) >=
                                                  (create ? 8 : 1)
                                              ? null
                                              : create
                                                  ? 'Use at least 8 characters.'
                                                  : 'Enter your password.')),
                                      if (create) ...[
                                        const SizedBox(height: 10),
                                        Row(
                                            children: List.generate(
                                                4,
                                                (i) => Expanded(
                                                    child: Container(
                                                        height: 3,
                                                        margin: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 3),
                                                        decoration: BoxDecoration(
                                                            color: i < strength
                                                                ? const Color(
                                                                    0xFFA67C37)
                                                                : theme.accent
                                                                    .withValues(
                                                                        alpha:
                                                                            .15),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        3)))))),
                                        const SizedBox(height: 16),
                                        field(TextFormField(
                                            controller: confirmation,
                                            obscureText: obscure,
                                            autofillHints: const [
                                              AutofillHints.newPassword
                                            ],
                                            onFieldSubmitted: (_) => submit(),
                                            decoration: const InputDecoration(
                                                labelText: 'Confirm password',
                                                border: InputBorder.none,
                                                prefixIcon:
                                                    Icon(CupertinoIcons.lock)),
                                            validator: (v) => v == password.text
                                                ? null
                                                : 'Your passwords do not match.')),
                                      ] else
                                        Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                                onPressed: state.loading
                                                    ? null
                                                    : reset,
                                                child: const Text(
                                                    'Forgot password?'))),
                                      if (state.error != null)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 16),
                                            child: Semantics(
                                                liveRegion: true,
                                                child: Text(state.error!,
                                                    style: ui(context).copyWith(
                                                        color: theme.accent)))),
                                      const SizedBox(height: 24),
                                      ActionButton(
                                          state.loading
                                              ? 'Just a moment…'
                                              : create
                                                  ? 'Create account'
                                                  : 'Sign in',
                                          onPressed:
                                              state.loading ? null : submit),
                                      const SizedBox(height: 20),
                                      Row(children: [
                                        Expanded(
                                            child: ActionButton('Go back',
                                                secondary: true,
                                                onPressed: state.loading
                                                    ? null
                                                    : () =>
                                                        Navigator.of(context)
                                                            .pop())),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: ActionButton(
                                                create ? 'Sign in' : 'Sign up',
                                                secondary: true,
                                                onPressed: state.loading
                                                    ? null
                                                    : () {
                                                        ref
                                                            .read(authProvider
                                                                .notifier)
                                                            .clearError();
                                                        form.currentState
                                                            ?.reset();
                                                        setState(() =>
                                                            create = !create);
                                                      })),
                                      ]),
                                    ]))))))));
  }
}
