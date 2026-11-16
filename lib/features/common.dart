import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../design/design.dart';
import '../data/legal_documents.dart';

Future<bool> confirm(BuildContext context,
        {required String title,
        required String message,
        String action = 'Continue',
        bool destructive = false}) =>
    HolyDialogs.confirm(context,
        title: title,
        message: message,
        confirm: action,
        destructive: destructive);
void toast(BuildContext context, String message, {VoidCallback? undo}) =>
    GlassToast.show(context, message,
        actionLabel: undo == null ? null : 'Undo', onAction: undo);

void openLegal(BuildContext context, String title, String document) {
  Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LegalScreen(document: document)));
}

class LegalScreen extends StatelessWidget {
  final String document;
  const LegalScreen({super.key, this.document = 'terms'});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return ScreenFrame(
        title: document == 'privacy' ? 'Privacy Policy' : 'Terms of Use',
        scroll: true,
        children: [
          for (final section
              in legalDocuments[document] ?? legalDocuments['terms']!) ...[
            Text(section.$1,
                style: HolyTypography.headline.copyWith(color: t.ink)),
            const SizedBox(height: 8),
            Text(section.$2,
                style: HolyTypography.ui
                    .copyWith(color: t.ink, fontSize: 16, height: 1.6)),
            const SizedBox(height: 24),
          ],
        ]);
  }
}

/// A calm full-screen state: loading failed, a page is missing, a lesson is
/// not open yet. Always offers one way forward.
class StatusScreen extends StatelessWidget {
  final String title, message, action;
  final VoidCallback? onAction;
  const StatusScreen(
      {super.key,
      required this.title,
      required this.message,
      required this.action,
      this.onAction});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Scaffold(
        backgroundColor: t.paper,
        body: HolyBackdrop(
            calm: true,
            child: SafeArea(
                child: FitColumn(children: [
              const Spacer(flex: 3),
              Center(
                  child: ClipOval(
                      child: SizedBox.square(
                          dimension: 120,
                          child: Image.asset(
                              'assets/art/library/sky-stillness-thumb.webp',
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                              errorBuilder: (c, e, s) =>
                                  ColoredBox(color: t.sunk))))),
              const SizedBox(height: 28),
              Text(title,
                  textAlign: TextAlign.center,
                  style: HolyTypography.title.copyWith(color: t.ink)),
              const SizedBox(height: 10),
              Text(message,
                  textAlign: TextAlign.center,
                  style: HolyTypography.body.copyWith(color: t.muted)),
              const Spacer(flex: 4),
              HolyButton(action,
                  onPressed: onAction ?? () => GoRouter.of(context).go('/')),
              const SizedBox(height: 16),
            ]))));
  }
}
