import 'package:flutter/material.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/features/lesson/five_card_reader.dart';

/// Stable entry point retained for old routes and saved-item destinations.
class LessonScreen extends StatelessWidget {
  final DailyLesson lesson;
  final bool openScripture;
  final VoidCallback? onClose;
  const LessonScreen(
      {super.key,
      required this.lesson,
      this.openScripture = false,
      this.onClose});
  @override
  Widget build(BuildContext context) => FiveCardReader(
      lesson: lesson, openScripture: openScripture, onClose: onClose);
}
