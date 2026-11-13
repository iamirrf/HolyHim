import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../../design/design.dart';
import '../common.dart';

class GuideQuestion {
  final String id, prompt;
  final List<String> choices;
  final Map<String, String> responses;
  const GuideQuestion(this.id, this.prompt, this.choices,
      {this.responses = const {}});
}

class GuideChat extends StatefulWidget {
  final List<GuideQuestion> questions;
  final Map<String, dynamic> answers;
  final Future<void> Function(String, String) onAnswer;
  final ValueChanged<bool> onReady;
  const GuideChat(
      {super.key,
      required this.questions,
      required this.answers,
      required this.onAnswer,
      required this.onReady});
  @override
  State<GuideChat> createState() => _GuideChatState();
}

class _GuideChatState extends State<GuideChat> {
  Timer? typing;
  bool busy = false;
  String? editingQuestionId;
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady(done);
    });
  }

  bool get done =>
      widget.questions.every((q) => widget.answers[q.id] is String);
  @override
  void didUpdateWidget(GuideChat old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady(done && !busy && editingQuestionId == null);
    });
  }

  @override
  void dispose() {
    typing?.cancel();
    scroll.dispose();
    super.dispose();
  }

  Future<void> answer(GuideQuestion question, String value) async {
    if (busy) return;
    typing?.cancel();
    setState(() {
      busy = true;
      editingQuestionId = null;
    });
    widget.onReady(false);
    HolyHaptics.send();
    try {
      await widget.onAnswer(question.id, value);
      if (!mounted) return;
      final delay = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 620);
      typing = Timer(delay, () {
        if (!mounted) return;
        setState(() => busy = false);
        widget.onReady(done);
        HolyHaptics.receive();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && scroll.hasClients) {
            if (MediaQuery.disableAnimationsOf(context)) {
              scroll.jumpTo(scroll.position.maxScrollExtent);
              return;
            }
            scroll.animateTo(scroll.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic);
          }
        });
      });
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        widget.onReady(done);
        toast(context, 'That choice could not be saved. Please try again.');
      }
    }
  }

  void edit(GuideQuestion question) {
    if (busy) return;
    setState(() => editingQuestionId = question.id);
    widget.onReady(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = HolyThemeScope.of(context);
    final visible = <GuideQuestion>[];
    for (final question in widget.questions) {
      visible.add(question);
      if (widget.answers[question.id] == null) break;
    }
    final active = editingQuestionId == null
        ? visible.where((q) => widget.answers[q.id] == null).firstOrNull
        : widget.questions.where((q) => q.id == editingQuestionId).firstOrNull;
    return LayoutBuilder(
        builder: (context, bounds) => Column(children: [
              Row(children: [
                Glass(
                    radius: 24,
                    padding: const EdgeInsets.all(12),
                    child: Icon(CupertinoIcons.sparkles,
                        color: theme.accent, size: 22)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('HolyHim Guide',
                          style: HolyTypography.ui
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text('A few questions, at your pace',
                          style: muted(context).copyWith(fontSize: 11)),
                    ]))
              ]),
              const SizedBox(height: 20),
              Expanded(
                  child: ListView(
                      controller: scroll,
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                    for (final question in visible) ...[
                      Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                              padding:
                                  const EdgeInsets.only(right: 24, bottom: 12),
                              child: Glass(
                                  radius: 22,
                                  padding: const EdgeInsets.all(18),
                                  child: Text(question.prompt,
                                      style: ui(context))))),
                      if (widget.answers[question.id] != null)
                        Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                                padding:
                                    const EdgeInsets.only(left: 40, bottom: 22),
                                child: Pressable(
                                    semanticLabel:
                                        'Change answer: ${widget.answers[question.id]}',
                                    onPressed:
                                        busy ? null : () => edit(question),
                                    child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 18, vertical: 13),
                                        decoration: BoxDecoration(
                                            color: theme.accent
                                                .withValues(alpha: .16),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: theme.accent
                                                    .withValues(alpha: .25))),
                                        child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                  child: Text(
                                                      '${widget.answers[question.id]}',
                                                      style: ui(context))),
                                              const SizedBox(width: 8),
                                              const Icon(CupertinoIcons.pencil,
                                                  size: 12)
                                            ]))))),
                      if (widget.answers[question.id] != null && !busy)
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                                padding: const EdgeInsets.only(
                                    right: 24, bottom: 20),
                                child: Glass(
                                    radius: 22,
                                    padding: const EdgeInsets.all(18),
                                    child: Text(
                                        question.responses[
                                                widget.answers[question.id]] ??
                                            'Thank you. We’ll keep that in mind as we shape your routine.',
                                        style: ui(context))))),
                    ],
                    if (busy)
                      Align(
                          alignment: Alignment.centerLeft,
                          child: Glass(
                              radius: 20,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              child: Text('•••',
                                  style: HolyTypography.ui.copyWith(
                                      color: theme.accent, letterSpacing: 5)))),
                  ])),
              if (active != null && !busy) ...[
                const SizedBox(height: 8),
                Text(
                    editingQuestionId == null
                        ? 'Choose an answer'
                        : 'Change your answer',
                    style: muted(context).copyWith(fontSize: 12)),
                const SizedBox(height: 8),
                ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: bounds.maxHeight *
                            (MediaQuery.textScalerOf(context).scale(16) > 24
                                ? .32
                                : .6)),
                    child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 4),
                        children: [
                          for (final choice in active.choices)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ActionButton(choice,
                                    secondary: true,
                                    onPressed: () => answer(active, choice)))
                        ]))
              ],
            ]));
  }
}
