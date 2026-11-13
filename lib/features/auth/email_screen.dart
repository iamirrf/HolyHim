import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design/design.dart';
import '../../services/auth_service.dart';

enum _Mode { signIn, create, reset }

/// One screen for email: sign in or create, with an inline reset state.
/// No confirm-password field; the password can be shown instead. The
/// primary button rides above the keyboard.
class EmailScreen extends ConsumerStatefulWidget {
  final bool startWithCreate;
  const EmailScreen({super.key, this.startWithCreate = false});

  static Route<void> route() => PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, a, b) => const EmailScreen(),
      transitionsBuilder: (context, animation, secondary, child) {
        final curve =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
            opacity: curve,
            child: SlideTransition(
                position: Tween(begin: const Offset(0, .04), end: Offset.zero)
                    .animate(curve),
                child: child));
      });

  @override
  ConsumerState<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends ConsumerState<EmailScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final emailFocus = FocusNode();
  final passwordFocus = FocusNode();
  late _Mode mode = widget.startWithCreate ? _Mode.create : _Mode.signIn;
  String? emailError, passwordError;
  bool resetSent = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  bool get _emailValid => RegExp(r'^\S+@\S+\.\S+$').hasMatch(email.text.trim());

  void _switch(_Mode next) {
    ref.read(authProvider.notifier).clearError();
    setState(() {
      mode = next;
      emailError = passwordError = null;
      resetSent = false;
    });
  }

  Future<void> _submit() async {
    final auth = ref.read(authProvider.notifier);
    setState(() {
      emailError = _emailValid ? null : 'Enter an email address like name@example.com.';
      passwordError = mode == _Mode.reset
          ? null
          : password.text.isEmpty
              ? 'Enter your password.'
              : mode == _Mode.create && password.text.length < 8
                  ? 'Use at least 8 characters.'
                  : null;
    });
    if (emailError != null) {
      emailFocus.requestFocus();
      return;
    }
    if (passwordError != null) {
      passwordFocus.requestFocus();
      return;
    }
    switch (mode) {
      case _Mode.signIn:
        await auth.signInEmail(email.text, password.text);
      case _Mode.create:
        await auth.signUpEmail(email.text, password.text);
      case _Mode.reset:
        await auth.resetPassword(email.text);
        if (mounted && ref.read(authProvider).error == null) {
          setState(() => resetSent = true);
          HolyHaptics.success();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final auth = ref.watch(authProvider);
    ref.listen(authProvider, (before, after) {
      if (before?.user == null && after.user != null && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
    final busy = auth.loading;
    final title = switch (mode) {
      _Mode.signIn => 'Welcome back',
      _Mode.create => 'Create your account',
      _Mode.reset => 'Reset your password',
    };
    final subtitle = switch (mode) {
      _Mode.signIn => 'Sign in to pick up where you left off.',
      _Mode.create => 'Your walk, saved to your account on every device.',
      _Mode.reset => 'We will email you a link to choose a new one.',
    };
    final action = switch (mode) {
      _Mode.signIn => 'Sign in',
      _Mode.create => 'Create account',
      _Mode.reset => resetSent ? 'Back to sign in' : 'Send reset link',
    };
    return KeyboardLift(
        safeTop: false,
        footer: HolyButton(action,
            loading: busy,
            onPressed: mode == _Mode.reset && resetSent
                ? () => _switch(_Mode.signIn)
                : _submit),
        builder: (context, keyboard) {
          final reduced = MediaQuery.disableAnimationsOf(context);
          final top = MediaQuery.paddingOf(context).top;
          return Column(children: [
            // A band of morning that folds away when the keyboard rises.
            AnimatedContainer(
                duration:
                    reduced ? Duration.zero : const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                height: keyboard ? top + 64 : top + 170,
                child: Stack(fit: StackFit.expand, children: [
                  const PhotoStage(
                      images: ['assets/art/library/scripture-lamp.webp'],
                      alignment: Alignment(0, .35),
                      parallax: false,
                      topVeil: .35,
                      bottomVeil: 0),
                  DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [.55, 1],
                              colors: [t.paper.withValues(alpha: 0), t.paper]))),
                  Positioned(
                      top: top + 4,
                      left: HolySpace.gutter - 6,
                      child: BackControl(
                          onPhoto: true,
                          onPressed: () {
                            ref.read(authProvider.notifier).clearError();
                            Navigator.of(context).maybePop();
                          })),
                ])),
            Expanded(
                child: FitColumn(
                    padding: const EdgeInsets.symmetric(
                        horizontal: HolySpace.gutter),
                    children: [
                  SizedBox(height: keyboard ? 4 : 10),
                  AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Column(
                          key: ValueKey(mode),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                                header: true,
                                child: Text(title,
                                    style: HolyTypography.title.copyWith(
                                        color: t.ink,
                                        fontSize: keyboard ? 28 : 34))),
                            if (!keyboard) ...[
                              const SizedBox(height: 6),
                              Text(subtitle,
                                  style: HolyTypography.body
                                      .copyWith(color: t.muted)),
                            ],
                          ])),
                  SizedBox(height: keyboard ? 14 : 22),
                  if (mode != _Mode.reset)
                    _ModeToggle(
                        create: mode == _Mode.create,
                        onChanged: (create) =>
                            _switch(create ? _Mode.create : _Mode.signIn)),
                  if (mode != _Mode.reset) const SizedBox(height: 16),
                  AutofillGroup(
                      child: Column(children: [
                    HolyField(
                        controller: email,
                        focusNode: emailFocus,
                        label: 'Email',
                        error: emailError,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: mode == _Mode.reset
                            ? TextInputAction.send
                            : TextInputAction.next,
                        onChanged: (_) {
                          if (emailError != null) {
                            setState(() => emailError = null);
                          }
                        },
                        onSubmitted: (_) => mode == _Mode.reset
                            ? _submit()
                            : passwordFocus.requestFocus()),
                    if (mode != _Mode.reset) ...[
                      const SizedBox(height: 12),
                      HolyField(
                          controller: password,
                          focusNode: passwordFocus,
                          label: 'Password',
                          password: true,
                          error: passwordError,
                          hint: mode == _Mode.create ? 'At least 8 characters' : null,
                          autofillHints: [
                            mode == _Mode.create
                                ? AutofillHints.newPassword
                                : AutofillHints.password
                          ],
                          textInputAction: TextInputAction.done,
                          onChanged: (_) {
                            if (passwordError != null) {
                              setState(() => passwordError = null);
                            }
                          },
                          onSubmitted: (_) => _submit()),
                    ],
                  ])),
                  if (auth.error != null && auth.error!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Semantics(
                        liveRegion: true,
                        child: Text(auth.error!,
                            style: HolyTypography.caption.copyWith(
                                color: t.isDark
                                    ? const Color(0xFFF2B8B5)
                                    : const Color(0xFFB3261E)))),
                  ],
                  if (mode == _Mode.reset && resetSent) ...[
                    const SizedBox(height: 16),
                    Paper(
                        lift: 0,
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          HolyCheck(checked: true, color: t.olive),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  'If there is an account for ${email.text.trim()}, a reset link is on its way.',
                                  style: HolyTypography.body
                                      .copyWith(color: t.ink))),
                        ])),
                  ],
                  const SizedBox(height: 4),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: mode == _Mode.signIn
                          ? TextAction('Forgot your password?',
                              onPressed: () => _switch(_Mode.reset))
                          : mode == _Mode.reset && !resetSent
                              ? TextAction('Back to sign in',
                                  onPressed: () => _switch(_Mode.signIn))
                              : const SizedBox.shrink()),
                  const Spacer(),
                ])),
          ]);
        });
  }
}

class _ModeToggle extends StatelessWidget {
  final bool create;
  final ValueChanged<bool> onChanged;
  const _ModeToggle({required this.create, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    Widget option(String label, bool value) => Expanded(
        child: Semantics(
            button: true,
            selected: create == value,
            child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (create != value) {
                    HolyHaptics.chipSelect();
                    onChanged(value);
                  }
                },
                child: SizedBox(
                    height: 44,
                    child: Center(
                        child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: HolyTypography.label.copyWith(
                                color: create == value ? t.ink : t.muted,
                                fontWeight: create == value
                                    ? FontWeight.w700
                                    : FontWeight.w600),
                            child: Text(label)))))));
    return DecoratedBox(
        decoration: ShapeDecoration(
            color: t.sunk,
            shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(16))),
        child: Padding(
            padding: const EdgeInsets.all(4),
            child: Stack(children: [
              AnimatedAlign(
                  duration:
                      reduced ? Duration.zero : const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  alignment:
                      create ? Alignment.centerRight : Alignment.centerLeft,
                  child: FractionallySizedBox(
                      widthFactor: .5,
                      child: Container(
                          height: 44,
                          decoration: ShapeDecoration(
                              color: t.surface,
                              shape: RoundedSuperellipseBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              shadows: HolyDepth.paper(t, lift: .35))))),
              Row(children: [
                option('Sign in', false),
                option('Create account', true),
              ]),
            ])));
  }
}
