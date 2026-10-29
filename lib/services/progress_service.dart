import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/services/local_store.dart';

class ProgressState {
  final Set<int> completedDays;
  final bool onboardingComplete;
  final List<DailyLesson> catalog;

  const ProgressState({
    this.completedDays = const {},
    this.onboardingComplete = false,
    this.catalog = lessons,
  });

  DailyLesson? get nextLesson {
    for (final lesson in catalog) {
      if (!completedDays.contains(lesson.day)) return lesson;
    }
    return null;
  }

  int get todayDay =>
      nextLesson?.day ?? (catalog.isEmpty ? 1 : catalog.last.day + 1);
  int get completedCount =>
      catalog.where((lesson) => completedDays.contains(lesson.day)).length;
  bool get allComplete => nextLesson == null;
  double get fraction => catalog.isEmpty ? 0 : completedCount / catalog.length;

  ProgressState copyWith({Set<int>? completedDays, bool? onboardingComplete}) =>
      ProgressState(
        completedDays: completedDays ?? this.completedDays,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
        catalog: catalog,
      );
}

/// FUTURE SEAM: SharedPreferences today; Firebase storage at ship time.
/// Keep initialize(), completeDay(int), finishOnboarding(): `Future<void>`, and
/// progressProvider's seeded ProgressState. Progress never controls access.
class ProgressNotifier extends Notifier<ProgressState> {
  static const _kCompleted = 'progress_completed_days';
  static const _kOnboarding = 'progress_onboarding_complete';
  Future<void>? _loaded;
  Future<void> _pending = Future.value();
  bool _alive = true;

  @override
  ProgressState build() {
    ref.onDispose(() => _alive = false);
    return const ProgressState();
  }

  Future<void> initialize() => _loaded ??= _load();

  Future<void> _load() async {
    final store = ref.read(localStoreProvider);
    final raw = await store.read(_kCompleted);
    final onboarding = await store.read(_kOnboarding);
    final available = lessons.map((lesson) => lesson.day).toSet();
    final completed = <int>{};
    if (raw is List && raw.every((value) => value is String)) {
      for (final value in raw.cast<String>()) {
        final day = int.tryParse(value);
        if (day != null && available.contains(day)) completed.add(day);
      }
    }
    if (_alive) {
      state = ProgressState(
        completedDays: Set.unmodifiable(completed),
        onboardingComplete: onboarding is bool ? onboarding : false,
      );
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    return _pending = _pending.then((_) async {
      await initialize();
      if (_alive) await action();
    });
  }

  Future<void> completeDay(int day) => _enqueue(() async {
        if (!lessons.any((lesson) => lesson.day == day) ||
            state.completedDays.contains(day)) {
          return;
        }
        final store = ref.read(localStoreProvider);
        final completed = {...state.completedDays, day};
        await store.write(_kCompleted, completed.map((day) => '$day').toList());
        if (_alive) {
          state = state.copyWith(completedDays: Set.unmodifiable(completed));
        }
      });

  Future<void> finishOnboarding() => _enqueue(() async {
        if (state.onboardingComplete) {
          return;
        }
        final store = ref.read(localStoreProvider);
        await store.write(_kOnboarding, true);
        if (_alive) state = state.copyWith(onboardingComplete: true);
      });
}

final progressProvider =
    NotifierProvider<ProgressNotifier, ProgressState>(ProgressNotifier.new);
