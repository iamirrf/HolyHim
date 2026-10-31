import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/core/widgets/google_mark.dart';
import 'package:holyher/features/support/support_screens.dart';
import 'package:holyher/services/auth_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _emailMode = false;
  bool _signUp = false;
  bool _obscure = true;
  bool _resetting = false;
  String? _notice;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _notice = null);
    final auth = ref.read(authProvider.notifier);
    if (_signUp) {
      await auth.signUpEmail(_email.text.trim(), _password.text);
    } else {
      await auth.signInEmail(_email.text.trim(), _password.text);
    }
  }

  Future<void> _reset() async {
    if (!_email.text.contains('@')) {
      setState(
          () => _notice = 'Enter your email above, then tap Forgot password.');
      return;
    }
    setState(() {
      _resetting = true;
      _notice = null;
    });
    await ref.read(authProvider.notifier).resetPassword(_email.text.trim());
    if (mounted) {
      setState(() {
        _resetting = false;
        if (ref.read(authProvider).error == null) {
          _notice =
              'If an account uses that email, a password reset link is on its way.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user != null && previous?.user == null && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
    final state = ref.watch(authProvider);
    final busy = state.loading || _resetting;
    return HolyScaffold(
        title: 'Welcome to HolyHer',
        body: ReadingWidth(
            maxWidth: 520,
            child: ListView(
                padding: const EdgeInsets.fromLTRB(26, 20, 26, 30),
                children: [
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: HolyMark(size: 72)),
                  const SizedBox(height: 28),
                  PageHeading(
                      eyebrow: 'A place for your daily faith',
                      title: _emailMode
                          ? (_signUp
                              ? 'Start something\nbeautiful.'
                              : 'Welcome back.')
                          : 'Your next chapter\nstarts here.',
                      subtitle:
                          'Create an account to keep your progress and daily rhythm with you.'),
                  const SizedBox(height: 28),
                  if (!_emailMode) ...[
                    HolyButton(
                        label: 'Continue with Apple',
                        icon: Icons.apple,
                        foregroundColor: Colors.black,
                        secondary: true,
                        busy: state.loading,
                        onPressed: busy
                            ? null
                            : () =>
                                ref.read(authProvider.notifier).signInApple()),
                    const SizedBox(height: 12),
                    HolyButton(
                        label: 'Continue with Google',
                        leading: const GoogleMark(),
                        foregroundColor: const Color(0xFF1F1F1F),
                        secondary: true,
                        onPressed: busy
                            ? null
                            : () =>
                                ref.read(authProvider.notifier).signInGoogle()),
                    const SizedBox(height: 12),
                    HolyButton(
                        label: 'Continue with email',
                        icon: Icons.mail_outline_rounded,
                        onPressed: busy
                            ? null
                            : () => setState(() => _emailMode = true)),
                  ] else ...[
                    GlassSurface(
                        child: Form(
                            key: _form,
                            child: AutofillGroup(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  SegmentedButton<bool>(
                                      segments: const [
                                        ButtonSegment(
                                            value: false,
                                            label: Text('Sign in')),
                                        ButtonSegment(
                                            value: true,
                                            label: Text('Create account'))
                                      ],
                                      selected: {
                                        _signUp
                                      },
                                      onSelectionChanged: busy
                                          ? null
                                          : (value) {
                                              ref
                                                  .read(authProvider.notifier)
                                                  .clearError();
                                              setState(() {
                                                _signUp = value.first;
                                                _notice = null;
                                              });
                                            },
                                      showSelectedIcon: false),
                                  const SizedBox(height: 22),
                                  TextFormField(
                                      controller: _email,
                                      enabled: !busy,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.email
                                      ],
                                      autocorrect: false,
                                      decoration: const InputDecoration(
                                          labelText: 'Email'),
                                      validator: (value) => value != null &&
                                              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                                  .hasMatch(value.trim())
                                          ? null
                                          : 'Enter a valid email address.'),
                                  const SizedBox(height: 14),
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
                                      onFieldSubmitted: (_) =>
                                          busy ? null : _submit(),
                                      decoration: InputDecoration(
                                          labelText: 'Password',
                                          helperText: _signUp
                                              ? 'At least 8 characters.'
                                              : null,
                                          helperMaxLines: 2,
                                          suffixIcon: IconButton(
                                              tooltip: _obscure
                                                  ? 'Show password'
                                                  : 'Hide password',
                                              onPressed: () => setState(
                                                  () => _obscure = !_obscure),
                                              icon: Icon(_obscure
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                      .visibility_off_outlined))),
                                      validator: (value) =>
                                          value == null || value.isEmpty
                                              ? 'Enter your password.'
                                              : _signUp && value.length < 8
                                                  ? 'Use at least 8 characters.'
                                                  : null),
                                  if (!_signUp)
                                    Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                            onPressed: busy ? null : _reset,
                                            child: const Text(
                                                'Forgot password?'))),
                                  const SizedBox(height: 20),
                                  HolyButton(
                                      label: _signUp
                                          ? 'Create my account'
                                          : 'Sign in',
                                      busy: busy,
                                      onPressed: busy ? null : _submit),
                                ])))),
                    TextButton(
                        onPressed: busy
                            ? null
                            : () {
                                ref.read(authProvider.notifier).clearError();
                                setState(() => _emailMode = false);
                              },
                        child: const Text('Other sign-in options')),
                  ],
                  if (state.error != null)
                    InlineMessage(state.error!, error: true),
                  if (_notice != null) InlineMessage(_notice!),
                  const SizedBox(height: 24),
                  const Text(
                      'By continuing, you agree to HolyHer’s Terms and acknowledge the Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, height: 1.7)),
                  const SizedBox(height: 8),
                  const LegalFooter(),
                ])));
  }
}
