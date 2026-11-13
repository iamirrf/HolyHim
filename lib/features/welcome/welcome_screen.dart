import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/google_mark.dart';
import '../../design/design.dart';
import '../../services/auth_service.dart';
import '../auth/email_screen.dart';
import '../common.dart';

/// Three dawn scenes dissolve behind a paper panel that rises from below.
/// Apple first and black, Google second, email as a quiet link.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  static const scenes = [
    'assets/art/library/scripture-morning.webp',
    'assets/art/library/jesus-path.webp',
    'assets/art/library/symbol-dove.webp',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final last = ref.watch(lastSignInProvider).value;
    final t = HolyThemeScope.of(context);
    final busy = auth.loading;
    final media = MediaQuery.of(context);
    final compact = media.size.height < 700;
    final apple = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    Widget tagged(String method, Widget button) => Stack(
            clipBehavior: Clip.none,
            children: [
              button,
              if (last == method)
                Positioned(
                    top: -9,
                    right: 18,
                    child: _LastUsed(color: t.accent)),
            ]);

    return Scaffold(
        backgroundColor: const Color(0xFF2A1A20),
        body: Stack(fit: StackFit.expand, children: [
          // The photograph fills the space above the panel, bottom-aligned
          // so each scene's subject sits just above the paper.
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: compact ? 300 : 330,
              child: const PhotoStage(
                  images: scenes,
                  expose: true,
                  alignment: Alignment(0, .75),
                  topVeil: .45,
                  bottomVeil: .15)),
          const LightMotes(count: 18),
          // Wordmark and promise over the calm upper sky.
          Positioned(
              top: media.padding.top + (compact ? 28 : 64),
              left: HolySpace.gutter,
              right: HolySpace.gutter,
              child: Column(children: [
                Rise(
                    delay: const Duration(milliseconds: 300),
                    child: LightSweep(
                        delay: const Duration(milliseconds: 900),
                        child: Wordmark(
                            size: compact ? 44 : 52,
                            color: HolyTheme.photoInk))),
                const SizedBox(height: 10),
                Rise(
                    delay: const Duration(milliseconds: 650),
                    child: Text('A quiet word with God,\nevery morning.',
                        textAlign: TextAlign.center,
                        style: HolyTypography.headline.copyWith(
                            color: HolyTheme.photoInk.withValues(alpha: .92),
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            fontSize: compact ? 23 : 26,
                            shadows: const [
                              Shadow(color: Color(0x66000000), blurRadius: 18)
                            ]))),
              ])),
          // The rising paper panel.
          Align(
              alignment: Alignment.bottomCenter,
              child: Rise(
                  delay: const Duration(milliseconds: 900),
                  distance: 60,
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Paper(
                          lift: 2,
                          hairline: false,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(HolyRadius.sheet)),
                          padding: EdgeInsets.fromLTRB(
                              HolySpace.gutter,
                              compact ? 22 : 28,
                              HolySpace.gutter,
                              media.padding.bottom + (compact ? 10 : 16)),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Begin your walk',
                                    textAlign: TextAlign.center,
                                    style: HolyTypography.title.copyWith(
                                        color: t.ink,
                                        fontSize: compact ? 30 : 34)),
                                const SizedBox(height: 6),
                                Text(
                                    'One short lesson a day. Your first week is free.',
                                    textAlign: TextAlign.center,
                                    style: HolyTypography.body
                                        .copyWith(color: t.muted)),
                                SizedBox(height: compact ? 16 : 22),
                                if (apple) ...[
                                  tagged(
                                      'apple',
                                      AppleButton(
                                          white: t.isDark,
                                          loading: busy &&
                                              auth.action == AuthAction.apple,
                                          onPressed: busy
                                              ? null
                                              : () => ref
                                                  .read(authProvider.notifier)
                                                  .signInApple())),
                                  const SizedBox(height: 10),
                                ],
                                tagged(
                                    'google',
                                    HolyButton.secondary('Continue with Google',
                                        leading: const SizedBox.square(
                                            dimension: 20,
                                            child: GoogleMark()),
                                        loading: busy &&
                                            auth.action == AuthAction.google,
                                        onPressed: busy
                                            ? null
                                            : () => ref
                                                .read(authProvider.notifier)
                                                .signInGoogle())),
                                const SizedBox(height: 4),
                                Center(
                                    child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                      TextAction('Continue with email',
                                          color: t.ink,
                                          onPressed: busy
                                              ? null
                                              : () => Navigator.of(context)
                                                  .push(EmailScreen.route())),
                                      if (last == 'email')
                                        Positioned(
                                            top: -4,
                                            right: -64,
                                            child: _LastUsed(color: t.accent)),
                                    ])),
                                AnimatedSize(
                                    duration:
                                        const Duration(milliseconds: 220),
                                    child: auth.error == null ||
                                            auth.error!.isEmpty
                                        ? const SizedBox(width: double.infinity)
                                        : Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Semantics(
                                                liveRegion: true,
                                                child: Text(auth.error!,
                                                    textAlign: TextAlign.center,
                                                    style: HolyTypography
                                                        .caption
                                                        .copyWith(
                                                            color:
                                                                t.accent))))),
                                SizedBox(height: compact ? 6 : 10),
                                _LegalLine(color: t.muted, link: t.ink),
                              ]))))),
        ]));
  }
}

class _LastUsed extends StatelessWidget {
  final Color color;
  const _LastUsed({required this.color});
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: ShapeDecoration(
          color: color,
          shape: const StadiumBorder(
              side: BorderSide(color: Colors.white, width: 1.5))),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          child: Text('Last used',
              style: HolyTypography.caption.copyWith(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700))));
}

class _LegalLine extends StatefulWidget {
  final Color color, link;
  const _LegalLine({required this.color, required this.link});
  @override
  State<_LegalLine> createState() => _LegalLineState();
}

class _LegalLineState extends State<_LegalLine> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () => openLegal(context, 'Terms of Use', 'terms');
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => openLegal(context, 'Privacy', 'privacy');
  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final link = HolyTypography.caption.copyWith(
        color: widget.link,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.underline,
        decorationColor: widget.link.withValues(alpha: .35));
    return Text.rich(
        TextSpan(
            style: HolyTypography.caption.copyWith(color: widget.color),
            children: [
              const TextSpan(text: 'By continuing you agree to the '),
              TextSpan(text: 'Terms', style: link, recognizer: _terms),
              const TextSpan(text: ' and '),
              TextSpan(
                  text: 'Privacy Policy', style: link, recognizer: _privacy),
              const TextSpan(text: '.'),
            ]),
        textAlign: TextAlign.center);
  }
}
