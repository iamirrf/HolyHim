import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/features/lesson/lesson_cards.dart';
import 'package:holyher/services/progress_service.dart';

/// Lesson view as learning cards: Verse, Confidence, Reason, Hope,
/// Carry — swiped in order. Completing marks the day done and returns
/// to home, exactly as the previous single-scroll view did.
class LessonScreen extends ConsumerStatefulWidget {
  final DailyLesson lesson;

  const LessonScreen({super.key, required this.lesson});

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final done = ref.watch(progressProvider).completedDays.contains(lesson.day);
    return Scaffold(
      appBar: AppBar(title: Text('Day ${lesson.day}')),
      body: LessonCards(
        lesson: lesson,
        done: done,
        saving: _saving,
        onComplete: () async {
          setState(() => _saving = true);
          await ref.read(progressProvider.notifier).completeDay(lesson.day);
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}
