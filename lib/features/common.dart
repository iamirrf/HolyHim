import 'package:flutter/material.dart';
import '../design/design.dart';
import '../data/legal_documents.dart';

const rose = Color(0xFFA67C37);
TextStyle ui(BuildContext context) =>
    HolyTypography.ui.copyWith(color: Theme.of(context).colorScheme.onSurface);
TextStyle muted(BuildContext context) => ui(context).copyWith(
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .62),
    fontSize: 14);

class ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  const ActionButton(this.label,
      {super.key, this.onPressed, this.icon, this.secondary = false});
  @override
  Widget build(BuildContext context) {
    final theme = HolyThemeScope.of(context);
    return Pressable(
        onPressed: onPressed,
        semanticLabel: label,
        child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            decoration: BoxDecoration(
                gradient: secondary
                    ? null
                    : LinearGradient(colors: theme.buttonGradient),
                color: secondary
                    ? Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: .7)
                    : null,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: secondary
                        ? rose.withValues(alpha: .2)
                        : Colors.white.withValues(alpha: .45)),
                boxShadow: secondary
                    ? null
                    : [
                        BoxShadow(
                            color: rose.withValues(alpha: .24),
                            blurRadius: 24,
                            offset: const Offset(0, 10))
                      ]),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 20,
                    color: secondary ? theme.accent : theme.buttonInk),
                const SizedBox(width: 12)
              ],
              Flexible(
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style: HolyTypography.ui.copyWith(
                          color: secondary
                              ? Theme.of(context).colorScheme.onSurface
                              : theme.buttonInk,
                          fontWeight: FontWeight.w700)))
            ])));
  }
}

class CircleControl extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String label;
  const CircleControl(
      {super.key,
      required this.icon,
      required this.onPressed,
      required this.label});
  @override
  Widget build(BuildContext context) => Tooltip(
      message: label,
      child: Pressable(
          onPressed: onPressed,
          semanticLabel: label,
          child: Glass(
              padding: const EdgeInsets.all(13),
              radius: 40,
              child: Icon(icon, size: 21))));
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Text('HolyHim',
      style: HolyTypography.wordmark.copyWith(
          color: HolyThemeScope.of(context).isDark
              ? const Color(0xFFE8C766)
              : const Color(0xFFA67C37),
          shadows: [
            Shadow(
                color: const Color(0xFFD4AF37).withValues(alpha: .25),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ]));
}

class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: HolyTypography.eyebrow.copyWith(color: rose));
}

class PageBody extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  final ScrollController? controller;
  const PageBody(
      {super.key,
      required this.children,
      this.controller,
      this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 140)});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      controller: controller,
      child: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                  padding: padding,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children)))));
}

Future<T?> glassSheet<T>(
        BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(
            alpha: .97),
        shape:
            const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        builder: (context) => Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(26, 8, 26, 32),
                    child: child))));
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
  Widget build(BuildContext context) => Scaffold(
      appBar: GlassTopBar(
          title: Text(document == 'privacy' ? 'Privacy' : 'Terms of Use')),
      body: SafeArea(
          child: PageBody(children: [
        for (final section
            in legalDocuments[document] ?? legalDocuments['terms']!) ...[
          const SizedBox(height: 24),
          Text(section.$1, style: HolyTypography.title),
          const SizedBox(height: 12),
          Text(section.$2, style: HolyTypography.reading),
        ],
        const SizedBox(height: 40),
      ])));
}
