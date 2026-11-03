import 'dart:async';
import 'package:holyher/features/lesson/lesson_pause.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:holyher/features/home/lesson_presentation.dart';
import 'package:holyher/features/lesson/reading_parts.dart';
import 'package:holyher/features/lesson/lesson_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/core/widgets/holy_loader.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/data/teaching.dart';
import 'package:holyher/models/learning.dart';
import 'package:holyher/features/settings/data_screens.dart';
import 'package:holyher/features/lesson/lesson_deck.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/feedback_service.dart';
import 'package:holyher/services/learning_service.dart';
import 'package:holyher/services/lesson_audio.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/profile_service.dart';
import 'package:holyher/services/progress_service.dart';

class GuidedLesson extends ConsumerStatefulWidget {
  final DailyLesson lesson;
  const GuidedLesson({super.key, required this.lesson});
  @override
  ConsumerState<GuidedLesson> createState() => _GuidedLessonState();
}

class _GuidedLessonState extends ConsumerState<GuidedLesson>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _deck = LessonDeckController();
  late final LessonAudio _audio;
  late final AnimationController _celebration = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2800));
  LearningAttempt? _attempt;
  int _step = 0, _readingOffset = 0;
  List<ReadingPart> _parts = const [ReadingPart('', 0, 0)];
  int get _partIndex => ReadingLayout.indexAt(_parts, _readingOffset);
  bool _saving = false, _accepted = false, _checkpointing = false;
  String? _error;
  Timer? _cloudTimer;
  Future<void> _localTail = Future.value(), _cloudTail = Future.value();
  LessonResume? _latestResume;
  int _remoteRevision = 0;
  bool _cloudConflict = false;
  String? _uid;
  bool _crest = false, _settled = false, _answerSaveFailed = false;
  TeachingLesson get _teaching => teachingCatalog[widget.lesson.day]!;
  String get _key => 'lesson_resume_${widget.lesson.day}';
  @override
  void initState() {
    super.initState();
    _uid = ref.read(authProvider).user?.uid;
    WidgetsBinding.instance.addObserver(this);
    _audio = LessonAudio(() => mounted && ref.read(profileProvider).sounds);
    unawaited(_audio.warmUp());
    _celebration.addListener(_celebrationTick);
    _restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cloudTimer?.cancel();
    _audio.dispose();
    _celebration.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _audio.stop();
      _crest = true;
      _settled = true;
      _celebration.stop();
      if (_accepted) _celebration.value = 1;
      _cloudTimer?.cancel();
      unawaited(_flush());
    }
  }

  bool get _current => mounted && ref.read(authProvider).user?.uid == _uid;
  Future<void> _restore() async {
    try {
      await _restoreImpl();
    } catch (_) {
      if (_current) {
        setState(() => _error =
            'Your saved lesson could not be read. Retry or contact support before resetting data.');
      }
    }
  }

  Future<void> _restoreImpl() async {
    final revision = ref.read(progressProvider).revision,
        store = ref.read(localStoreProvider);
    LessonResume? resume;
    final raw = await store.read(_key);
    if (!_current) return;
    if (raw != null && raw is! String) throw const FormatException();
    if (raw is String && raw.isNotEmpty) {
      resume =
          LessonResume.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
      if (!semanticSteps.contains(resume.stepId) ||
          resume.renderedPart < 0 ||
          resume.checkpointRevision < 0) {
        throw const FormatException();
      }
    }
    _remoteRevision = resume?.attempt.journeyRevision == revision
        ? resume!.checkpointRevision
        : 0;
    // Adopt another device's checkpoint only at opening. A network failure keeps the local checkpoint.
    try {
      final gateway = ref.read(learningGatewayProvider);
      final remote = gateway == null
          ? null
          : await gateway.read('resumes/day-${widget.lesson.day}').timeout(
              resume == null
                  ? const Duration(seconds: 8)
                  : const Duration(milliseconds: 350));
      if (!_current) return;
      if (remote != null) {
        final candidate =
            remote['cleared'] == true ? null : LessonResume.fromJson(remote);
        final remoteRevision = remote['checkpointRevision'] as int? ?? 0;
        final remoteJourney =
            remote['journeyRevision'] ?? candidate?.attempt.journeyRevision;
        if (remoteJourney == revision) {
          resume = selectLessonResume(resume, candidate,
              serverRevision: remoteRevision,
              cleared: remote['cleared'] == true);
          _remoteRevision = remoteRevision;
        }
      }
    } catch (_) {}
    if (!_current) return;
    if (ref.read(progressProvider).revision != revision) {
      throw StateError('Your journey changed. Reopen the lesson.');
    }
    _latestResume = resume;
    var attempt = resume?.attempt;
    if (attempt == null ||
        attempt.journeyRevision != revision ||
        attempt.contentVersion != teachingVersion ||
        attempt.day != widget.lesson.day ||
        !attempt.validFor(_teaching.questions)) {
      attempt = LearningAttempt.create(
          widget.lesson.day, revision, teachingVersion, _teaching.questions);
      resume = null;
    }
    await ref.read(attemptSyncProvider.notifier).initialize();
    if (!_current) return;
    final alreadyAccepted =
        ref.read(attemptSyncProvider).pending.any((a) => a.id == attempt!.id);
    if (alreadyAccepted) {
      attempt = LearningAttempt.create(
          widget.lesson.day, revision, teachingVersion, _teaching.questions);
      resume = null;
    }
    var step =
        resume == null ? 0 : semanticSteps.indexOf(resume.stepId).clamp(0, 8);
    // Build-1 card positions migrate to semantic steps and stop at the first new unanswered question.
    if (resume == null &&
        !ref.read(progressProvider).completedDays.contains(widget.lesson.day)) {
      final legacy = await store
          .read('card_position_${_uid ?? 'local'}_${widget.lesson.day}');
      if (legacy is int && legacy > 0) {
        step = [1, 4, 2, 5, 7][legacy.clamp(0, 4)];
        _error =
            'This lesson now includes understanding questions. Your earlier progress is preserved.';
      }
    }
    for (var i = 0; i < 2; i++) {
      final questionStep = i == 0 ? 3 : 6;
      if (step > questionStep &&
          !attempt.selected.containsKey(_teaching.questions[i].id)) {
        step = questionStep;
        break;
      }
    }
    if (!_current) return;
    setState(() {
      _attempt = attempt;
      _step = step;
      _readingOffset = resume?.readingOffset ?? 0;
    });
    if (step == 8) unawaited(_complete());
  }

  LessonQuestion? _question(int step) => step == 3
      ? _teaching.questions[0]
      : step == 6
          ? _teaching.questions[1]
          : null;
  bool _canMove(int from, int to) =>
      !_saving &&
      !_checkpointing &&
      to >= 0 &&
      to < 9 &&
      (to < from || !_answerSaveFailed) &&
      (to < from || _partIndex == _parts.length - 1) &&
      (to < from ||
          _question(from) == null ||
          _attempt!.selected.containsKey(_question(from)!.id));
  Future<void> _checkpoint() {
    final attempt = _attempt;
    if (attempt == null || _accepted || _saving || !_current) {
      return Future.value();
    }
    final resume = LessonResume(
        stepId: semanticSteps[_step],
        renderedPart: _partIndex,
        readingOffset: _readingOffset,
        attempt: attempt,
        checkpointId: newOperationId(),
        checkpointRevision: _remoteRevision,
        pending: true);
    _latestResume = resume;
    final store = ref.read(localStoreProvider);
    _localTail = _localTail.catchError((Object _) {}).then((_) async {
      if (!_current || _accepted) return;
      final value = resume.withSync(revision: _remoteRevision, pending: true);
      if (!await store.write(_key, jsonEncode(value.toJson()))) {
        throw StateError('Your reading position could not be saved.');
      }
      ref.read(readingPositionRevisionProvider.notifier).state++;
      if (_latestResume?.checkpointId == resume.checkpointId) {
        _latestResume = value;
      }
    });
    _cloudTimer?.cancel();
    _cloudTimer = Timer(const Duration(milliseconds: 800),
        () => unawaited(_sendResume(resume)));
    return _localTail;
  }

  Future<void> _sendResume(LessonResume resume) {
    return _cloudTail = _cloudTail.catchError((Object _) {}).then((_) async {
      if (!_current ||
          _accepted ||
          _saving ||
          _cloudConflict ||
          _latestResume?.checkpointId != resume.checkpointId) {
        return;
      }
      try {
        await _localTail;
        if (!_current || _accepted || _saving) return;
        final gateway = ref.read(learningGatewayProvider),
            store = ref.read(localStoreProvider);
        if (gateway == null) return;
        final result = await gateway.call('saveLessonResume',
            {'resume': resume.toJson(), 'expectedRevision': _remoteRevision});
        if (!_current || _accepted) return;
        if (result['accepted'] != true) {
          _cloudConflict = true;
          setState(() => _error =
              'The saved position changed on another device. You can keep reading here; reopen the lesson to use the cloud position.');
          return;
        }
        _remoteRevision = result['checkpointRevision'] as int;
        // Rebase newer local edits on this acknowledgment in the same write
        // queue. An old acknowledgment can never replace their answer/step.
        _localTail = _localTail.catchError((Object _) {}).then((_) async {
          if (!_current || _accepted || _saving || _latestResume == null) {
            return;
          }
          final latest = _latestResume!;
          final updated = latest.withSync(
              revision: _remoteRevision,
              pending: latest.checkpointId != resume.checkpointId);
          if (!await store.write(_key, jsonEncode(updated.toJson()))) {
            throw StateError('Checkpoint acknowledgment failed.');
          }
          if (_current && _latestResume?.checkpointId == latest.checkpointId) {
            _latestResume = updated;
          }
        });
        await _localTail;
      } catch (_) {/* Durable local checkpoint remains available for retry. */}
    });
  }

  Future<void> _flush() async {
    if (_attempt == null || _accepted || _saving) return;
    try {
      await _checkpoint();
      _cloudTimer?.cancel();
      if (_current && _latestResume != null) await _sendResume(_latestResume!);
    } catch (_) {
      if (_current) {
        setState(() => _error =
            'Your position could not be saved. Please retry before leaving.');
      }
    }
  }

  void _change(int step) {
    if (!_canMove(_step, step)) return;
    setState(() {
      _step = step;
      _readingOffset = 0;
      _error = null;
    });
    unawaited(_checkpoint().catchError((Object _) {
      if (_current) {
        setState(() =>
            _error = 'Your reading position could not be saved. Tap Retry.');
      }
    }));
    unawaited(_audio.play('lesson_land', .20));
    if (step == 8) unawaited(_complete());
  }

  Future<void> _answer(LessonQuestion question, String option) async {
    if (_attempt!.selected.containsKey(question.id) || _checkpointing) return;
    setState(() {
      _attempt = _attempt!.answer(question.id, option);
      _checkpointing = true;
      _error = null;
    });
    if (option == question.correctOptionId) {
      ref.read(feedbackProvider).light();
      unawaited(_audio.play('lesson_correct', .24));
    } else {
      ref.read(feedbackProvider).selection();
    }
    try {
      await _checkpoint();
    } catch (_) {
      if (_current) {
        setState(() {
          _answerSaveFailed = true;
          _error = 'Your answer is selected but could not be saved. Tap Retry.';
        });
      }
    } finally {
      if (_current) setState(() => _checkpointing = false);
    }
  }

  Future<void> _complete() async {
    if (_saving || _accepted || _step != 8) return;
    if (!_teaching.questions
        .every((q) => _attempt!.selected.containsKey(q.id))) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Finish any older checkpoint write before atomically accepting the
      // attempt and clearing its resume. No delayed position may resurrect it.
      await _localTail.catchError((Object _) {});
      if (!_current) return;
      await ref.read(attemptSyncProvider.notifier).accept(_attempt!);
      if (!_current) return;
      _cloudTimer?.cancel();
      await ref.read(localStoreProvider).write(_key, '');
      if (!mounted || !_current) return;
      setState(() {
        _accepted = true;
        _saving = false;
      });
      ref.read(feedbackProvider).light();
      if (MediaQuery.disableAnimationsOf(context)) {
        _celebration.value = 1;
        ref.read(feedbackProvider).selection();
      } else {
        unawaited(_audio.play('lesson_surge', .50));
        _celebration.forward(from: 0);
      }
    } catch (_) {
      if (_current) {
        setState(() {
          _saving = false;
          _error = 'Your completion could not be saved. Please retry.';
        });
      }
    }
  }

  void _celebrationTick() {
    if (!_current) return;
    final ms = _celebration.value * 2800;
    if (ms >= 800 && !_crest) {
      _crest = true;
      ref.read(feedbackProvider).light();
    }
    if (ms >= 930 && !_settled) {
      _settled = true;
      ref.read(feedbackProvider).selection();
    }
  }

  Future<void> _exit() async {
    if (_saving || _checkpointing) return;
    if (_accepted) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await showLessonPause(context);
    if (leave != true || !mounted || !_current) return;
    try {
      await _checkpoint();
      if (!mounted || !_current) return;
      _cloudTimer?.cancel();
      if (_latestResume != null) unawaited(_sendResume(_latestResume!));
      Navigator.of(context).pop();
    } catch (_) {
      if (_current) {
        setState(
            () => _error = 'Your position could not be saved. Please retry.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    ref.listen(profileProvider.select((p) => p.sounds), (previous, next) {
      if (!next) _audio.stop();
    });
    if (_attempt == null) {
      return HolyScaffold(
          body: LessonRecoveryFrame(
              child: _error == null
                  ? const PulsingDotsLoader(semanticsLabel: 'Restoring lesson')
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      InlineMessage(_error!, error: true),
                      TextButton(
                          onPressed: () {
                            setState(() => _error = null);
                            _restore();
                          },
                          child: const Text('Retry'))
                    ])));
    }
    final sync = ref.watch(attemptSyncProvider);
    final pending = sync.pending.any((a) => a.id == _attempt!.id);
    final rejected = sync.rejected.containsKey(_attempt!.id);
    return PopScope(
        canPop: _accepted,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _exit();
        },
        child: HolyScaffold(body: LayoutBuilder(builder: (context, box) {
          final natural = box.maxHeight < 650 ||
              MediaQuery.textScalerOf(context).scale(16) > 24;
          final readingText = _body(_step);
          _parts = !natural && (_step == 1 || _step == 2 || _step == 5)
              ? ReadingLayout.split(readingText,
                  style: _step == 1
                      ? HolyTypography.scripture
                      : HolyTypography.reading,
                  width: natural
                      ? math.min(560, box.maxWidth - 32) - 64
                      : lessonPageSize(Size(box.maxWidth, box.maxHeight - 180))
                              .width -
                          64,
                  height: math.max(150, box.maxHeight - 390),
                  scaler: MediaQuery.textScalerOf(context),
                  direction: Directionality.of(context))
              : [ReadingPart(readingText, 0, readingText.length)];
          final header = LessonHeader(
              day: widget.lesson.day,
              index: _step,
              count: 9,
              onClose: _saving || _checkpointing ? null : _exit);
          final footer = Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (_step > 0 && !_accepted)
                      IconButton(
                          tooltip: 'Previous card',
                          onPressed: _saving ? null : () => _change(_step - 1),
                          icon: const Icon(Icons.arrow_back)),
                    SizedBox(
                        width: math.min(box.maxWidth - 112, 400),
                        child: HolyButton(
                            label: _step == 8
                                ? (_accepted
                                    ? 'Continue'
                                    : _saving
                                        ? 'Saving…'
                                        : 'Retry saving')
                                : _partIndex < _parts.length - 1
                                    ? 'Next part'
                                    : 'Next',
                            busy: _saving,
                            onPressed: _step == 8
                                ? (_accepted
                                    ? () => Navigator.of(context).pop()
                                    : _saving
                                        ? null
                                        : _complete)
                                : _partIndex < _parts.length - 1
                                    ? () {
                                        setState(() => _readingOffset =
                                            _parts[_partIndex + 1].start);
                                        unawaited(_checkpoint());
                                      }
                                    : _canMove(_step, _step + 1)
                                        ? () => natural
                                            ? _change(_step + 1)
                                            : _deck.advance()
                                        : null)),
                    if (_question(_step) != null &&
                        !_attempt!.selected.containsKey(_question(_step)!.id))
                      const Text('Choose an answer to continue.',
                          style: HolyTypography.supporting),
                    if (_step == 8)
                      Text(
                          _accepted
                              ? (pending
                                  ? (rejected
                                      ? 'Saved on this device · Needs attention'
                                      : 'Saved on this device · Pending sync')
                                  : 'Saved')
                              : _saving
                                  ? 'Saving your completion…'
                                  : 'Retry to save your completion.',
                          style: HolyTypography.supporting,
                          semanticsLabel: _accepted
                              ? (pending
                                  ? (rejected
                                      ? 'Saved on this device. Synchronization needs attention.'
                                      : 'Saved. Pending synchronization.')
                                  : 'Saved.')
                              : _saving
                                  ? 'Saving'
                                  : 'Completion has not been saved. Please retry.')
                  ]));
          final notice = _error == null
              ? const SizedBox()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(children: [
                    InlineMessage(_error!, error: true),
                    TextButton(
                        onPressed: () async {
                          try {
                            await _checkpoint();
                            if (_current) {
                              setState(() {
                                _error = null;
                                _answerSaveFailed = false;
                              });
                            }
                          } catch (_) {}
                        },
                        child: const Text('Retry'))
                  ]));
          if (natural) {
            if (MediaQuery.textScalerOf(context).scale(17) > 42) {
              return ReadingWidth(
                  maxWidth: 560,
                  child: ListView(children: [
                    header,
                    notice,
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: _card(_step, 0, natural: true)),
                    footer,
                  ]));
            }
            return ReadingWidth(
                maxWidth: 560,
                child: Column(children: [
                  header,
                  Expanded(
                      child: ListView(
                          key: ValueKey('reading-$_step-$_readingOffset'),
                          padding: const EdgeInsets.all(16),
                          children: [notice, _card(_step, 0, natural: true)])),
                  footer,
                ]));
          }

          return ReadingWidth(
              maxWidth: 650,
              child: Column(children: [
                header,
                notice,
                Expanded(
                    child: LayoutBuilder(
                        builder: (context, deckBox) => LessonDeck(
                            itemCount: 9,
                            index: _step,
                            cardSize: lessonPageSize(deckBox.biggest),
                            controller: _deck,
                            canMove: _canMove,
                            onIndexChanged: _change,
                            locked: _saving || _checkpointing,
                            onCommit: (direction, intensity) =>
                                _audio.swipe(direction < 0, intensity),
                            itemBuilder: (context, index, lift) =>
                                _card(index, lift)))),
                footer
              ]));
        })));
  }

  String _body(int index) => switch (index) {
        0 => _teaching.objective,
        1 => widget.lesson.verseText,
        2 => '${widget.lesson.reason}\n\n${_teaching.context}',
        4 => widget.lesson.confidence,
        5 => widget.lesson.hope,
        7 => _teaching.takeaway,
        _ => '',
      };
  Widget _card(int index, double lift, {bool natural = false}) {
    final lesson = widget.lesson, q = _question(index);
    final title = [
      lesson.title,
      'The passage',
      'Why these words matter',
      'Check your understanding',
      'A confidence to hold',
      'Hope for today',
      'Put it into practice',
      'Carry this with you',
      'A moment well spent'
    ][index];
    final body = index == _step ? _parts[_partIndex].text : _body(index);
    final content = Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(
                    child: Eyebrow(index == 0
                        ? 'Day ${lesson.day}'
                        : index == 1
                            ? 'Day ${lesson.day} · Scripture'
                            : index == 3
                                ? 'Question 1 of 2'
                                : index == 6
                                    ? 'Question 2 of 2'
                                    : index == 8
                                        ? 'Day ${lesson.day} · Your moment'
                                        : semanticSteps[index]
                                            .replaceAll('-', ' '))),
              ]),
              if (index == _step && _parts.length > 1)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                        'Part ${_partIndex + 1} of ${_parts.length} · ${_partIndex == 0 ? 'Begin here' : 'Continued'}',
                        style: HolyTypography.supporting)),
              const SizedBox(height: 20),
              if (index != 1 && index != 4 && index != 5 && q == null)
                Text(
                    index == 8
                        ? (_accepted
                            ? 'Day ${lesson.day} complete'
                            : _saving
                                ? 'Finishing Day ${lesson.day}'
                                : 'One last step')
                        : title,
                    style: index == 0
                        ? HolyTypography.heading
                        : HolyTypography.section),
              if (index == 0) ...[
                const SizedBox(height: 28),
                const Center(child: ReadingBookObject(width: 156))
              ],
              const SizedBox(height: 24),
              if (body.isNotEmpty)
                Text(body,
                    style: (index == 1 || index == 4 || index == 7
                            ? HolyTypography.scripture
                            : HolyTypography.reading)
                        .copyWith(color: AppColors.textPrimary)),
              if (index == 1) ...[
                const SizedBox(height: 20),
                Text(lesson.verseReference,
                    style: HolyTypography.supporting
                        .copyWith(color: AppColors.accentDark)),
                const SizedBox(height: 6),
                const Text('World English Bible',
                    style: HolyTypography.supporting)
              ],
              if (index == 5 && lesson.devotionalReflection.isNotEmpty) ...[
                const Divider(height: 32),
                const Eyebrow('HolyHer reflection'),
                const SizedBox(height: 12),
                Text(lesson.devotionalReflection),
                const SizedBox(height: 12),
                const Text('Original devotional writing',
                    style: HolyTypography.supporting)
              ],
              if (q != null) ..._questionContent(q),
              if (index == 8) ...[
                Center(
                    child: CompletionOrbit(
                        animation: _celebration, accepted: _accepted)),
                const SizedBox(height: 24),
                Text(_teaching.takeaway, style: HolyTypography.scripture),
                const SizedBox(height: 20),
                Text(
                    '${_teaching.questions.where((q) => _attempt!.selected[q.id] == q.correctOptionId).length} of 2 correct · You can revisit both questions.',
                    style: HolyTypography.supporting
                        .copyWith(color: AppColors.textSecondary)),
                if (ref.watch(attemptSyncProvider).error != null) ...[
                  InlineMessage(ref.watch(attemptSyncProvider).error!,
                      error: true),
                  if (ref.watch(attemptSyncProvider).rejected.isNotEmpty)
                    TextButton(
                        onPressed: () => exportAccountData(context, ref),
                        child: const Text('Export data for support')),
                  TextButton(
                      onPressed: () =>
                          ref.read(attemptSyncProvider.notifier).retryLoad(),
                      child: const Text('Retry synchronization'))
                ]
              ]
            ]));
    return Semantics(
        label: '${semanticSteps[index]}, ${index + 1} of 9',
        container: true,
        child: PearlSurface(
            radius: 24,
            lift: lift,
            ribbon: index == 7,
            child: natural
                ? content
                : SingleChildScrollView(
                    key: ValueKey(
                        'guided-${lesson.day}-$index-${index == _step ? _readingOffset : 0}'),
                    child: content)));
  }

  List<Widget> _questionContent(LessonQuestion q) {
    final selected = _attempt!.selected[q.id];
    return [
      Text(q.prompt, style: HolyTypography.section),
      const SizedBox(height: 20),
      for (final id in _attempt!.optionOrder[q.id]!)
        Builder(builder: (context) {
          final option = q.options.firstWhere((o) => o.id == id),
              correct = selected != null && id == q.correctOptionId,
              chosen = selected == id;
          return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                  selected: chosen,
                  label: correct
                      ? 'Correct answer'
                      : chosen
                          ? 'Your answer'
                          : '',
                  child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.all(16),
                          side: BorderSide(
                              color: correct
                                  ? AppColors.success
                                  : chosen
                                      ? AppColors.error
                                      : AppColors.divider,
                              width: chosen || correct ? 2 : 1),
                          backgroundColor: correct
                              ? const Color(0xFFEAF2EE)
                              : chosen
                                  ? const Color(0xFFFBE9EC)
                                  : Colors.white,
                          foregroundColor: AppColors.textPrimary,
                          disabledForegroundColor: AppColors.textPrimary),
                      onPressed: selected == null ? () => _answer(q, id) : null,
                      child: Row(children: [
                        if (correct || chosen) ...[
                          Icon(
                              correct ? Icons.check_circle : Icons.info_outline,
                              color:
                                  correct ? AppColors.success : AppColors.error,
                              size: 22),
                          const SizedBox(width: 10)
                        ],
                        Expanded(child: Text(option.text))
                      ]))));
        }),
      if (_checkpointing)
        const Padding(
            padding: EdgeInsets.only(top: 12),
            child:
                Text('Saving your answer…', style: HolyTypography.supporting)),
      if (selected != null)
        Semantics(
            liveRegion: true,
            child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                    '${selected == q.correctOptionId ? 'That’s right.' : 'Here’s the explanation.'} ${q.explanation}',
                    style: const TextStyle(fontSize: 17, height: 1.47))))
    ];
  }
}
