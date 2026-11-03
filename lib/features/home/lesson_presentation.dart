import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/widgets/holy_objects.dart';
import 'package:holyher/models/learning.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/progress_service.dart';

class LessonNodePresentation {
  final LessonNodeState state;
  final double fraction;
  const LessonNodePresentation(this.state, {this.fraction = 0});
  String get action => state == LessonNodeState.inProgress
      ? 'Resume'
      : state == LessonNodeState.complete
          ? 'Revisit'
          : state == LessonNodeState.future
              ? 'Upcoming'
              : 'Begin here';
}

final readingPositionRevisionProvider = StateProvider<int>((ref) => 0);
final lessonNodePresentationProvider =
    FutureProvider.family<LessonNodePresentation, int>((ref, day) async {
  final uid = ref.watch(authProvider.select((s) => s.user?.uid));
  final progress = ref.watch(progressProvider.select((p) => (
        p.revision,
        p.isUnlocked(day),
        p.completedDays.contains(day),
        p.nextLesson?.day == day
      )));
  ref.watch(readingPositionRevisionProvider);
  if (progress.$3) {
    return const LessonNodePresentation(LessonNodeState.complete, fraction: 1);
  }
  if (!progress.$2) return const LessonNodePresentation(LessonNodeState.future);
  final store = ref.watch(localStoreProvider);
  final reading = await store.read('reading_checkpoint_$day');
  if (reading is String && reading.isNotEmpty) {
    final value = jsonDecode(reading) as Map;
    if (value['journeyRevision'] == progress.$1 && value['completed'] != true) {
      return LessonNodePresentation(LessonNodeState.inProgress,
          fraction: ((value['cardIndex'] as int? ?? 0) + 1) / 5);
    }
  }
  final raw = await store.read('lesson_resume_$day');
  if (raw is String && raw.isNotEmpty) {
    final resume =
        LessonResume.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
    if (resume.attempt.journeyRevision == progress.$1 &&
        semanticSteps.contains(resume.stepId)) {
      return LessonNodePresentation(LessonNodeState.inProgress,
          fraction: (semanticSteps.indexOf(resume.stepId) + 1) / 9);
    }
  }
  final canonical =
      await store.read('card_position_${uid ?? 'local'}_${day}_semantic');
  if (canonical is String && canonical.isNotEmpty) {
    final value = jsonDecode(canonical) as Map;
    final index = ['verse', 'confidence', 'reason', 'hope', 'carry']
        .indexOf(value['stepId']);
    if (index > 0 ||
        (index == 0 && (value['readingOffset'] as int? ?? 0) > 0)) {
      return LessonNodePresentation(LessonNodeState.inProgress,
          fraction: (index + 1) / 5);
    }
  }
  final legacy = await store.read('card_position_${uid ?? 'local'}_$day');
  if (legacy is int && legacy > 0 && legacy < 5) {
    return LessonNodePresentation(LessonNodeState.inProgress,
        fraction: (legacy + 1) / 5);
  }
  return LessonNodePresentation(
      progress.$4 ? LessonNodeState.current : LessonNodeState.available);
});
