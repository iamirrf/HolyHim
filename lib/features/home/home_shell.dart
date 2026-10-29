import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/constants/app_constants.dart';
import 'package:holyher/features/paywall/paywall_screen.dart';
import 'package:holyher/services/paywall_service.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/features/lesson/lesson_screen.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/streak_service.dart';

/// Home shell with three tabs: Today, Journey, Profile.
/// Streak is marked active on open (see main.dart bootstrap) and again on
/// every tab switch, mirroring Cognein's streak behavior.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  void _onTab(int i) {
    setState(() => _index = i);
    ref.read(streakProvider.notifier).markTodayActive();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(paywallProvider)) return const PaywallScreen();
    final tabs = const [_TodayTab(), _JourneyTab(), _ProfileTab()];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: tabs)),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _onTab,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.today), label: 'Today'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Journey'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _TodayTab extends ConsumerWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final progress = ref.watch(progressProvider);
    final lesson = progress.nextLesson;
    return ListView(
      key: const PageStorageKey('today'),
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                color: AppColors.flame,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${streak.current} day streak',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Longest: ${streak.longest} days',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              )),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "Today's message",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (lesson == null)
          const _AllDoneCard()
        else
          _LessonCard(lesson: lesson),
      ],
    );
  }
}

class _LessonCard extends StatelessWidget {
  final DailyLesson lesson;

  const _LessonCard({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LessonScreen(lesson: lesson),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DAY ${lesson.day}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lesson.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lesson.confidence,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'All available messages are complete. New days arrive as they '
        'are written.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}

class _JourneyTab extends ConsumerWidget {
  const _JourneyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    return ListView(
      key: const PageStorageKey('journey'),
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Journey',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(
            '${progress.completedCount} of ${lessons.length} messages complete',
            style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        for (final lesson in lessons)
          Card(
            color: AppColors.surface,
            elevation: 0,
            child: ListTile(
              minVerticalPadding: 16,
              leading: CircleAvatar(
                radius: MediaQuery.textScalerOf(context).scale(20),
                backgroundColor: progress.completedDays.contains(lesson.day)
                    ? AppColors.accent
                    : AppColors.surfaceLight,
                child: Text('${lesson.day}',
                    style: TextStyle(
                        color: progress.completedDays.contains(lesson.day)
                            ? AppColors.background
                            : AppColors.textPrimary)),
              ),
              title: Text(lesson.title),
              trailing: progress.completedDays.contains(lesson.day)
                  ? const Icon(Icons.check_circle, color: AppColors.accent)
                  : null,
              onTap: () => Navigator.of(context).push<void>(MaterialPageRoute(
                  builder: (_) => LessonScreen(lesson: lesson))),
            ),
          ),
        if (lessons.length < AppConstants.totalDays) ...[
          const SizedBox(height: 16),
          // FUTURE SEAM: append verified lessons; never create fake day cards.
          Text(
              'Days ${lessons.length + 1}–${AppConstants.totalDays} are being written.',
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    return ListView(
      key: const PageStorageKey('profile'),
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Profile',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _StatRow(label: 'Current streak', value: '${streak.current} days'),
        _StatRow(label: 'Longest streak', value: '${streak.longest} days'),
        const _StatRow(label: 'Access', value: 'Premium'),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
              child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.bold),
          )),
        ],
      ),
    );
  }
}
