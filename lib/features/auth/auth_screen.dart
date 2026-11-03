import 'package:holyher/core/widgets/google_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/features/support/support_screens.dart';
import 'package:holyher/services/auth_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final bool initialCreateAccount;
  const AuthScreen({super.key, this.initialCreateAccount = false});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  late bool _signUp = widget.initialCreateAccount;
  bool _obscure = true;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(authProvider).loading || !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final auth = ref.read(authProvider.notifier);
    if (_signUp) {
      await auth.signUpEmail(_email.text, _password.text);
    } else {
      await auth.signInEmail(_email.text, _password.text);
    }
    if (mounted && ref.read(authProvider).user != null) {
      TextInput.finishAutofillContext();
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    ref.listen(authProvider, (previous, next) {
      if (next.user != null && previous?.user == null && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
    final auth = ref.watch(authProvider), busy = auth.loading;
    return HolyScaffold(
        title: 'Your account',
        body: ReadingWidth(
            maxWidth: 488,
            child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                children: [
                  const Row(children: [
                    HolyMark(size: 44),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text('HolyHer', style: HolyTypography.section))
                  ]),
                  const SizedBox(height: 32),
                  DecoratedBox(
                      decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: .65),
                          borderRadius: BorderRadius.circular(22)),
                      child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final mode in [false, true])
                                  Expanded(
                                      child: HolyPressable(
                                          selected: _signUp == mode,
                                          onPressed: busy
                                              ? null
                                              : () {
                                                  ref
                                                      .read(
                                                          authProvider.notifier)
                                                      .clearError();
                                                  setState(
                                                      () => _signUp = mode);
                                                },
                                          child: AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 200),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 14),
                                              decoration: BoxDecoration(
                                                  color: _signUp == mode
                                                      ? AppColors.pearl
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                      color: _signUp == mode
                                                          ? AppColors.accent
                                                          : Colors
                                                              .transparent)),
                                              child: Text(
                                                  mode
                                                      ? 'Create account'
                                                      : 'Sign in',
                                                  textAlign: TextAlign.center,
                                                  style:
                                                      HolyTypography.action))))
                              ]))),
                  const SizedBox(height: 28),
                  HolyButton(
                      label: 'Continue with Apple',
                      secondary: true,
                      leading: const Icon(Icons.apple),
                      busy: auth.action == AuthAction.apple && busy,
                      onPressed: busy
                          ? null
                          : () =>
                              ref.read(authProvider.notifier).signInApple()),
                  const SizedBox(height: 12),
                  HolyButton(
                      label: 'Continue with Google',
                      secondary: true,
                      leading: const GoogleMark(),
                      busy: auth.action == AuthAction.google && busy,
                      onPressed: busy
                          ? null
                          : () =>
                              ref.read(authProvider.notifier).signInGoogle()),
                  const SizedBox(height: 24),
                  const Text('or continue with email',
                      textAlign: TextAlign.center,
                      style: HolyTypography.supporting),
                  const SizedBox(height: 24),
                  Form(
                      key: _form,
                      child: AutofillGroup(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            TextFormField(
                                controller: _email,
                                enabled: !busy,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                autocorrect: false,
                                textCapitalization: TextCapitalization.none,
                                decoration:
                                    const InputDecoration(labelText: 'Email'),
                                validator: (v) => v != null &&
                                        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                            .hasMatch(v.trim())
                                    ? null
                                    : 'Enter a valid email address.'),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: _password,
                                enabled: !busy,
                                obscureText: _obscure,
                                autofillHints: [
                                  _signUp
                                      ? AutofillHints.newPassword
                                      : AutofillHints.password
                                ],
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                    labelText: 'Password',
                                    helperText: _signUp
                                        ? 'At least 8 characters.'
                                        : null,
                                    suffixIcon: IconButton(
                                        tooltip: _obscure
                                            ? 'Show password'
                                            : 'Hide password',
                                        onPressed: () => setState(
                                            () => _obscure = !_obscure),
                                        icon: Icon(_obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined))),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Enter your password.'
                                    : _signUp && v.length < 8
                                        ? 'Use at least 8 characters.'
                                        : null),
                            if (!_signUp)
                              Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => openScreen(
                                              context,
                                              PasswordResetScreen(
                                                  initialEmail: _email.text)),
                                      child: const Text('Forgot password?'))),
                            // Account-level errors always occupy the same position in the form.
                            if (auth.error != null)
                              InlineMessage(auth.error!, error: true)
                            else
                              const SizedBox(height: 24),
                            HolyButton(
                                label:
                                    _signUp ? 'Create my account' : 'Sign in',
                                busy: busy,
                                onPressed: busy ? null : _submit),
                          ]))),
                  const SizedBox(height: 24),
                  const Text(
                      'By continuing, you agree to the Terms and acknowledge the Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: HolyTypography.supporting),
                  const SizedBox(height: 8),
                  const LegalFooter(),
                ])));
  }
}

class PasswordResetScreen extends ConsumerStatefulWidget {
  final String initialEmail;
  const PasswordResetScreen({super.key, this.initialEmail = ''});
  @override
  ConsumerState<PasswordResetScreen> createState() => _PasswordResetState();
}

class _PasswordResetState extends ConsumerState<PasswordResetScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _sent = false;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate() || ref.read(authProvider).loading) {
      return;
    }
    await ref.read(authProvider.notifier).resetPassword(_email.text);
    if (mounted && ref.read(authProvider).error == null) {
      setState(() => _sent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final state = ref.watch(authProvider);
    return HolyScaffold(
        title: 'Reset password',
        body: ReadingWidth(
            maxWidth: 488,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              const SizedBox(height: 24),
              if (_sent) ...[
                Align(
                    alignment: Alignment.centerLeft,
                    child: QuietInset(
                        child: Icon(Icons.mark_email_read_outlined,
                            size: 36, color: AppColors.accent))),
                const SizedBox(height: 28),
                const Text('Check your email.', style: HolyTypography.heading),
                const SizedBox(height: 16),
                const Text(
                    'If an account uses that email, a password reset link is on its way.'),
                const SizedBox(height: 28),
                HolyButton(
                    label: 'Return to sign in',
                    onPressed: () => Navigator.pop(context)),
              ] else ...[
                const Text('A fresh start.', style: HolyTypography.heading),
                const SizedBox(height: 12),
                const Text('Enter your account email to request a reset link.'),
                const SizedBox(height: 28),
                Form(
                    key: _form,
                    child: TextFormField(
                        controller: _email,
                        enabled: !state.loading,
                        autofillHints: const [AutofillHints.email],
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) => v != null &&
                                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(v.trim())
                            ? null
                            : 'Enter a valid email address.')),
                if (state.error != null)
                  InlineMessage(state.error!, error: true),
                const SizedBox(height: 24),
                HolyButton(
                    label: 'Send reset link',
                    busy: state.loading,
                    onPressed: state.loading ? null : _send),
              ]
            ])));
  }
}
