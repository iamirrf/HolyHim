// Ported from Cognein; see store/v2-design-ports.json.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../design/design.dart';
import '../widgets/onboarding_tokens.dart';
import 'chat_script.dart';

/// A step asked as a short conversation with HolyHim.
///
/// HolyHim writes a line or two and offers a few replies to tap; nothing is
/// typed. Each reply is stored the moment it is tapped (through [onAnswer]),
/// then HolyHim answers it before asking the next thing. Tapping one of his
/// own earlier replies takes the conversation back to that question.
///
/// When the step is built again (Back, or a relaunch) the conversation is
/// restored from what was stored and shown at once, not replayed.
class OnboardingChatStep extends StatefulWidget {
  final ChatScript script;

  /// What is stored for a question, or null while it is unanswered.
  final ChatAnswer? Function(String questionId) answerOf;

  /// Turns a [ChatReply.deferred] reply into an answer, for example by
  /// opening a time picker. Null means he backed out.
  final Future<ChatAnswer?> Function(String questionId, ChatReply reply)?
      resolve;

  /// Stores an answer and runs whatever it sets off. HolyHim waits for it
  /// before answering: what he says about the daily note depends on what
  /// iOS allowed.
  final Future<void> Function(String questionId, ChatAnswer answer) onAnswer;

  /// Whether every question is answered and the closing line said.
  final ValueChanged<bool> onCompleteChanged;

  /// Something to show under a question's lines, such as a picture of the
  /// note he will receive.
  final Widget? Function(String questionId)? attachment;

  final Color accent;

  const OnboardingChatStep(
      {super.key,
      required this.script,
      required this.answerOf,
      required this.onAnswer,
      required this.onCompleteChanged,
      required this.accent,
      this.resolve,
      this.attachment});

  @override
  State<OnboardingChatStep> createState() => _OnboardingChatStepState();
}

enum _Kind { holyHim, him, attachment }

class _Message {
  final _Kind kind;
  final String text;

  /// For his replies: the reply's emoji.
  final String? emoji;

  /// For his replies and attachments: the question they belong to.
  final String? questionId;

  /// False for messages restored from what was stored; they appear at once.
  final bool animate;
  final Key key;

  _Message(this.kind, this.text,
      {this.questionId, this.emoji, required this.animate, required int serial})
      : key = ValueKey('chat-${kind.name}-$serial');
}

class _OnboardingChatStepState extends State<OnboardingChatStep> {
  final ScrollController _scroll = ScrollController();
  final List<_Message> _messages = [];
  int _serial = 0;

  ChatQuestion? _asking;
  String? _pressed;
  bool _typing = false;
  bool _busy = false;
  bool _complete = false;

  /// Bumped by a rewind or dispose; anything started under an older value
  /// stops at its next pause.
  int _generation = 0;
  bool _reduced = false;

  _Message _line(String text, {required bool animate}) =>
      _Message(_Kind.holyHim, text, animate: animate, serial: _serial++);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reduced = MediaQuery.disableAnimationsOf(context);
      _start();
    });
  }

  @override
  void dispose() {
    _generation++;
    _scroll.dispose();
    super.dispose();
  }

  List<_Message> _asked(ChatQuestion q, {required bool animate}) => [
        for (final line in q.ask()) _line(line, animate: animate),
        if (widget.attachment?.call(q.id) != null)
          _Message(_Kind.attachment, '',
              questionId: q.id, animate: animate, serial: _serial++),
      ];

  /// Restores what was already said, then finishes, waits on the open
  /// question, or (on a fresh start) begins talking.
  void _start() {
    final restored = <_Message>[];
    ChatQuestion? open;
    var answeredAny = false;
    for (final q in widget.script.questions) {
      final answer = widget.answerOf(q.id);
      if (answer == null) {
        open = q;
        break;
      }
      if (!answeredAny) {
        for (final line in widget.script.opening()) {
          restored.add(_line(line, animate: false));
        }
      }
      answeredAny = true;
      restored.addAll(_asked(q, animate: false));
      restored.add(_Message(_Kind.him, answer.label,
          questionId: q.id,
          emoji: answer.emoji,
          animate: false,
          serial: _serial++));
      final reaction = q.react?.call(answer.id);
      if (reaction != null) restored.add(_line(reaction, animate: false));
    }

    if (open == null) {
      for (final line in widget.script.closing()) {
        restored.add(_line(line, animate: false));
      }
      setState(() {
        _messages.addAll(restored);
        _complete = true;
      });
      widget.onCompleteChanged(true);
      _scrollToEnd(jump: true);
      return;
    }

    widget.onCompleteChanged(false);
    if (!answeredAny) {
      unawaited(_begin(open, _generation));
      return;
    }
    // Resumed part-way: the open question appears with the rest.
    restored.addAll(_asked(open, animate: false));
    setState(() {
      _messages.addAll(restored);
      _asking = open;
    });
    _scrollToEnd(jump: true);
  }

  Future<void> _begin(ChatQuestion first, int generation) async {
    // Let the page finish arriving before the first line is written.
    if (!await _pause(const Duration(milliseconds: 520), generation)) return;
    if (!await _say(widget.script.opening(), generation)) return;
    await _ask(first, generation);
  }

  /// How long the dots show before a line. Short lines come quickly; longer
  /// ones take a natural beat, with a little variation so the rhythm is not
  /// mechanical.
  Duration _typingTime(String line) {
    if (line.length <= 28) {
      return Duration(milliseconds: (320 + line.length * 6).clamp(340, 500));
    }
    final jitter = ((line.length * 37 + _serial * 53) % 220) - 110;
    return Duration(
        milliseconds: (400 + line.length * 10 + jitter).clamp(520, 1180));
  }

  Future<bool> _pause(Duration duration, int generation) async {
    if (_reduced) return generation == _generation && mounted;
    await Future<void>.delayed(duration);
    return generation == _generation && mounted;
  }

  Future<bool> _say(List<String> lines, int generation) async {
    for (final line in lines) {
      if (!_reduced) {
        setState(() => _typing = true);
        _scrollToEnd();
        if (!await _pause(_typingTime(line), generation)) return false;
      }
      setState(() {
        _typing = false;
        _messages.add(_line(line, animate: !_reduced));
      });
      HolyHaptics.receive();
      unawaited(HolySounds.lessonLand(intensity: .4));
      _scrollToEnd();
      if (!await _pause(const Duration(milliseconds: 260), generation)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _ask(ChatQuestion q, int generation) async {
    if (!await _say(q.ask(), generation)) return;
    setState(() {
      if (widget.attachment?.call(q.id) != null) {
        _messages.add(_Message(_Kind.attachment, '',
            questionId: q.id, animate: !_reduced, serial: _serial++));
      }
      _asking = q;
    });
    _scrollToEnd();
  }

  ChatQuestion? _nextAfter(ChatQuestion current) {
    final questions = widget.script.questions;
    final index = questions.indexOf(current) + 1;
    return index < questions.length ? questions[index] : null;
  }

  Future<void> _pick(ChatQuestion q, ChatReply reply) async {
    if (_busy || _asking != q) return;
    _busy = true;
    final generation = _generation;
    HolyHaptics.send();
    setState(() => _pressed = reply.id);

    ChatAnswer? answer = ChatAnswer(reply.id, reply.label, emoji: reply.emoji);
    if (reply.deferred) {
      try {
        answer = await widget.resolve?.call(q.id, reply);
      } catch (_) {
        answer = null;
      }
      if (answer == null || generation != _generation || !mounted) {
        // She backed out: the replies are still there.
        if (mounted) setState(() => _pressed = null);
        _busy = false;
        return;
      }
    } else if (!await _pause(const Duration(milliseconds: 160), generation)) {
      _busy = false;
      return;
    }
    unawaited(HolySounds.lessonSwipe(intensity: .36));
    final chosen = answer;
    setState(() {
      _pressed = null;
      _asking = null;
      _messages.add(_Message(_Kind.him, chosen.label,
          questionId: q.id,
          emoji: chosen.emoji ?? reply.emoji,
          animate: !_reduced,
          serial: _serial++));
    });
    _scrollToEnd();

    try {
      await widget.onAnswer(q.id, chosen);
    } catch (_) {
      // The answer is stored either way; something it set off failing must
      // not strand the conversation.
    }
    if (generation != _generation || !mounted) {
      _busy = false;
      return;
    }

    final reaction = q.react?.call(chosen.id);
    if (reaction != null && !await _say([reaction], generation)) {
      _busy = false;
      return;
    }
    final next = _nextAfter(q);
    if (next != null) {
      _busy = false;
      await _ask(next, generation);
      return;
    }
    if (!await _say(widget.script.closing(), generation)) {
      _busy = false;
      return;
    }
    _busy = false;
    setState(() => _complete = true);
    HolyHaptics.stepComplete();
    unawaited(HolySounds.lessonCorrect());
    widget.onCompleteChanged(true);
  }

  /// Takes the conversation back to [questionId]: everything from his reply
  /// onward is cleared and the replies come back.
  void _rewind(String questionId) {
    if (_busy) return;
    final index = _messages.lastIndexWhere(
        (m) => m.kind == _Kind.him && m.questionId == questionId);
    if (index < 0) return;
    ChatQuestion? question;
    for (final q in widget.script.questions) {
      if (q.id == questionId) question = q;
    }
    if (question == null) return;
    _generation++;
    HolyHaptics.chipDeselect();
    final wasComplete = _complete;
    setState(() {
      _messages.removeRange(index, _messages.length);
      _typing = false;
      _complete = false;
      _asking = question;
    });
    if (wasComplete) widget.onCompleteChanged(false);
    _scrollToEnd();
  }

  void _scrollToEnd({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      // The list is reversed: the newest line is at the start.
      final target = _scroll.position.minScrollExtent;
      if (jump || _reduced) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(target,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final asking = _asking;
    final compact = MediaQuery.sizeOf(context).height < 700;
    return Padding(
        padding: OnboardingTokens.pageInsets(context, top: 8),
        child: LayoutBuilder(builder: (context, box) {
          final replies = asking == null
              ? const SizedBox(width: double.infinity)
              : ConstrainedBox(
                  // The replies never push the conversation off the screen:
                  // at very large text they scroll in their own space.
                  constraints: BoxConstraints(maxHeight: box.maxHeight * .58),
                  child: SingleChildScrollView(
                      reverse: true,
                      child: _Replies(
                          key: ValueKey('chat-replies-${asking.id}'),
                          replies: asking.replies(),
                          pressed: _pressed,
                          accent: widget.accent,
                          animate: !_reduced,
                          onPick: (reply) => _pick(asking, reply))));
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                    header: true,
                    label: 'HolyHim',
                    excludeSemantics: true,
                    child: Center(
                        child: GradientFill(
                            colors: RoseGold.fill,
                            child: Wordmark(
                                size: compact ? 26 : 30,
                                color: OnboardingTokens.ink)))),
                SizedBox(height: compact ? 8 : 12),
                Expanded(
                    child: DecoratedBox(
                        decoration: OnboardingTokens.panel(radius: 24),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: ShaderMask(
                                // Older lines fade under the top edge.
                                shaderCallback: (rect) => const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.white],
                                    stops: [0, 0.04]).createShader(rect),
                                blendMode: BlendMode.dstIn,
                                // Anchored to the newest line, as a
                                // messaging app is, and top-aligned so a
                                // short conversation starts under the name.
                                child: Align(
                                    alignment: Alignment.topCenter,
                                    child: ListView(
                                        controller: _scroll,
                                        reverse: true,
                                        shrinkWrap: true,
                                        padding: const EdgeInsets.only(
                                            top: 8, bottom: 6),
                                        children: [
                                          for (var i = 0;
                                              i < _messages.length;
                                              i++)
                                            _bubble(i),
                                          if (_typing) const _TypingBubble(),
                                        ].reversed.toList())))))),
                const SizedBox(height: 10),
                if (_reduced)
                  replies
                else
                  AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.bottomCenter,
                      child: replies),
              ]);
        }));
  }

  Widget _bubble(int index) {
    final message = _messages[index];
    final next = index + 1 < _messages.length ? _messages[index + 1] : null;
    // The tail sits on the last line of a run, the way messages group.
    final lastOfRun = message.kind == _Kind.holyHim &&
        (next == null ? !_typing : next.kind != _Kind.holyHim);
    final Widget bubble = switch (message.kind) {
      _Kind.holyHim => _HolyHimBubble(text: message.text, tail: lastOfRun),
      _Kind.him => _HisBubble(
          text: message.text,
          emoji: message.emoji,
          accent: widget.accent,
          onTap: _busy || message.questionId == null
              ? null
              : () => _rewind(message.questionId!)),
      _Kind.attachment => Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 8),
          child: widget.attachment?.call(message.questionId!) ??
              const SizedBox.shrink()),
    };
    if (!message.animate) return KeyedSubtree(key: message.key, child: bubble);
    return _Arrival(
        key: message.key, fromHim: message.kind == _Kind.him, child: bubble);
  }
}

class _HolyHimBubble extends StatelessWidget {
  final String text;
  final bool tail;
  const _HolyHimBubble({required this.text, this.tail = false});

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
              widthFactor: .9,
              alignment: Alignment.centerLeft,
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                      label: 'HolyHim: $text',
                      excludeSemantics: true,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 11),
                          decoration: BoxDecoration(
                              color: OnboardingTokens.white,
                              border:
                                  Border.all(color: OnboardingTokens.hairline),
                              boxShadow: [
                                BoxShadow(
                                    color: OnboardingTokens.shade
                                        .withValues(alpha: .22),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3)),
                              ],
                              borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomRight: const Radius.circular(20),
                                  bottomLeft: Radius.circular(tail ? 6 : 20))),
                          child: Text(text,
                              style: HolyTypography.ui.copyWith(
                                  fontSize: 15.5,
                                  height: 1.42,
                                  color: OnboardingTokens.textPrimary))))))));
}

class _HisBubble extends StatelessWidget {
  final String text;
  final String? emoji;
  final Color accent;
  final VoidCallback? onTap;
  const _HisBubble(
      {required this.text, required this.accent, this.emoji, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
            // His words in the step's own colour, as his side of a
            // conversation is.
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(accent, Colors.white, .06)!,
                  Color.lerp(accent, OnboardingTokens.plum, .28)!
                ]),
            boxShadow: [
              BoxShadow(
                  color: accent.withValues(alpha: .24),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(6))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (emoji != null) ...[
            Text(emoji!,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(fontSize: 15, height: 1)),
            const SizedBox(width: 7),
          ],
          Flexible(
              child: Text(text,
                  style: HolyTypography.ui.copyWith(
                      fontSize: 15,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: OnboardingTokens.onPlum))),
        ]));
    return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8, left: 44),
        child: Align(
            alignment: Alignment.centerRight,
            child: onTap == null
                ? Semantics(label: 'You: $text', child: bubble)
                : Pressable(
                    semanticLabel: 'Your answer: $text. Tap to change it',
                    borderRadius: BorderRadius.circular(20),
                    haptic: false,
                    onPressed: onTap,
                    child: bubble)));
  }
}

/// A line arriving. HolyHim's lines ease up into place; his own reply
/// springs up from where his finger was.
class _Arrival extends StatelessWidget {
  final Widget child;
  final bool fromHim;
  const _Arrival({super.key, required this.child, this.fromHim = false});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: fromHim ? 460 : 340),
      curve: fromHim ? Curves.easeOutBack : Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
              offset: Offset(0, (1 - t) * (fromHim ? 18 : 10)),
              child: Transform.scale(
                  scale: 0.94 + 0.06 * t,
                  alignment:
                      fromHim ? Alignment.bottomRight : Alignment.bottomLeft,
                  child: child))),
      child: child);
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
      label: 'HolyHim is writing',
      liveRegion: true,
      child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  decoration: BoxDecoration(
                      color: OnboardingTokens.white,
                      border: Border.all(color: OnboardingTokens.hairline),
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                          bottomLeft: Radius.circular(6))),
                  child: AnimatedBuilder(
                      animation: _wave,
                      builder: (context, _) =>
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            for (var i = 0; i < 3; i++)
                              Builder(builder: (context) {
                                final wave = (math.sin(
                                            _wave.value * math.pi * 2 -
                                                i * 0.8) +
                                        1) /
                                    2;
                                return Transform.translate(
                                    offset: Offset(0, -2.5 * wave),
                                    child: Container(
                                        width: 7,
                                        height: 7,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 2.5),
                                        decoration: BoxDecoration(
                                            color: OnboardingTokens.plum
                                                .withValues(
                                                    alpha: 0.18 + wave * 0.42),
                                            shape: BoxShape.circle)));
                              }),
                          ]))))));
}

/// The replies, as pills under the conversation. They arrive one after
/// another, like answers being offered.
class _Replies extends StatefulWidget {
  final List<ChatReply> replies;
  final String? pressed;
  final Color accent;
  final bool animate;
  final ValueChanged<ChatReply> onPick;
  const _Replies(
      {super.key,
      required this.replies,
      required this.pressed,
      required this.accent,
      required this.animate,
      required this.onPick});
  @override
  State<_Replies> createState() => _RepliesState();
}

class _RepliesState extends State<_Replies>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 320 + widget.replies.length * 60),
      value: widget.animate ? 0 : 1);

  @override
  void initState() {
    super.initState();
    if (widget.animate) _in.forward();
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.replies.length;
    final span = 1 / (count + 2);
    return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: SizedBox(
            width: double.infinity,
            // Centred under the conversation, where a thumb finds them.
            child: Wrap(
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < count; i++)
                    _staggered(
                        CurvedAnimation(
                            parent: _in,
                            curve: Interval((i * span).clamp(0.0, 1.0),
                                (i * span + span * 3).clamp(0.0, 1.0),
                                curve: Curves.easeOutCubic)),
                        _ReplyPill(
                            reply: widget.replies[i],
                            accent: widget.accent,
                            selected: widget.pressed == widget.replies[i].id,
                            onTap: () => widget.onPick(widget.replies[i]))),
                ])));
  }

  Widget _staggered(Animation<double> animation, Widget child) =>
      AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) => Opacity(
              opacity: animation.value,
              child: Transform.translate(
                  offset: Offset(0, 12 * (1 - animation.value)),
                  child: child)));
}

class _ReplyPill extends StatelessWidget {
  final ChatReply reply;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;
  const _ReplyPill(
      {required this.reply,
      required this.accent,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
      semanticLabel: reply.label,
      borderRadius: BorderRadius.circular(22),
      haptic: false, // The reply itself gives the tap.
      onPressed: onTap,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
              color: selected ? accent : OnboardingTokens.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: selected ? accent : accent.withValues(alpha: .38),
                  width: 1.2),
              boxShadow: [
                BoxShadow(
                    color: (selected ? accent : OnboardingTokens.shade)
                        .withValues(alpha: selected ? .30 : .22),
                    blurRadius: selected ? 14 : 10,
                    offset: const Offset(0, 4)),
              ]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (reply.emoji != null) ...[
              Text(reply.emoji!,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(fontSize: 16, height: 1)),
              const SizedBox(width: 7),
            ],
            Flexible(
                child: Text(reply.label,
                    style: HolyTypography.ui.copyWith(
                        fontSize: 14.5,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? OnboardingTokens.onPlum
                            : OnboardingTokens.textPrimary))),
          ])));
}
