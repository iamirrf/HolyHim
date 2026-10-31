import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/data/lessons.dart';
import 'package:holyher/features/lesson/lesson_screen.dart';
import 'package:holyher/features/onboarding/personalization.dart';
import 'package:holyher/features/paywall/paywall_screen.dart';
import 'package:holyher/features/settings/settings_screen.dart';
import 'package:holyher/features/support/support_screens.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/paywall_service.dart';
import 'package:holyher/services/profile_service.dart';
import 'package:holyher/services/progress_service.dart';
import 'package:holyher/services/streak_service.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    if (!ref.watch(paywallProvider)) return const PaywallScreen();
    return HolyScaffold(
        body: IndexedStack(
            index: _index,
            children: const [_TodayTab(), _JourneyTab(), _ProfileTab()]),
        bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 5, 22, 12),
                child: ReadingWidth(
                    maxWidth: 520,
                    child: GlassSurface(
                        radius: 28,
                        padding: const EdgeInsets.all(7),
                        child: Row(children: [
                          for (final item in [
                            (0, Icons.wb_twilight_rounded, 'Today'),
                            (1, Icons.route_outlined, 'Journey'),
                            (2, Icons.person_outline_rounded, 'Profile')
                          ])
                            Expanded(
                                child: HolyPressable(
                                    label: item.$3,
                                    selected: _index == item.$1,
                                    onPressed: () {
                                      setState(() => _index = item.$1);
                                      ref
                                          .read(streakProvider.notifier)
                                          .markTodayActive();
                                      ref
                                          .read(progressProvider.notifier)
                                          .refresh();
                                    },
                                    child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 220),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 5),
                                        decoration: BoxDecoration(
                                            color: _index == item.$1
                                                ? AppColors.surfaceLight
                                                    .withValues(alpha: .75)
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(22)),
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(item.$2,
                                                  size: 24,
                                                  color: _index == item.$1
                                                      ? AppColors.accentDark
                                                      : AppColors
                                                          .textSecondary),
                                              if (MediaQuery.textScalerOf(
                                                          context)
                                                      .scale(10) <=
                                                  17) ...[
                                                const SizedBox(height: 4),
                                                Text(item.$3,
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: _index ==
                                                                item.$1
                                                            ? FontWeight.w600
                                                            : FontWeight.w400,
                                                        color: _index == item.$1
                                                            ? AppColors
                                                                .accentDark
                                                            : AppColors
                                                                .textSecondary))
                                              ]
                                            ])))),
                        ]))))));
  }
}

void _openLesson(BuildContext context, DailyLesson lesson) =>
    Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => LessonScreen(lesson: lesson)));

class _BrandHeader extends StatelessWidget {
  final String trailing;
  const _BrandHeader({required this.trailing});
  @override
  Widget build(BuildContext context) => Row(children: [
        const HolyMark(size: 37),
        const SizedBox(width: 11),
        const Expanded(
            child: Text('HolyHer',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.5))),
        Text(trailing,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                letterSpacing: .5))
      ]);
}

class _TodayTab extends ConsumerWidget {
  const _TodayTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final progress = ref.watch(progressProvider);
    final streak = ref.watch(streakProvider);
    final now = ref.watch(accountClockProvider)();
    final lesson = progress.todayLesson;
    final next = progress.nextLesson;
    final completedToday =
        lesson != null && progress.completedDays.contains(lesson.day);
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 18
            ? 'A little pause'
            : 'Good evening';
    return ReadingWidth(
        maxWidth: 940,
        child: RefreshIndicator(
            onRefresh: () async {
              await ref.read(progressProvider.notifier).refresh();
              await ref.read(streakProvider.notifier).markTodayActive();
            },
            child: ListView(
                key: const PageStorageKey('today'),
                padding: const EdgeInsets.fromLTRB(26, 23, 26, 28),
                children: [
                  _BrandHeader(
                      trailing:
                          '${_months[now.month - 1]} ${now.day}'.toUpperCase()),
                  const SizedBox(height: 32),
                  PageHeading(
                      eyebrow: profile.name.isEmpty
                          ? greeting
                          : '$greeting, ${profile.name}',
                      title: 'Make a little room\nfor your soul.',
                      subtitle:
                          'A quiet moment with God, right where you are.'),
                  const SizedBox(height: 28),
                  if (lesson != null)
                    _DailyHero(
                        lesson: lesson,
                        completed: completedToday,
                        focus: focusLabel(profile.focus))
                  else
                    GlassSurface(
                        highlighted: true,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Eyebrow('A year of faith'),
                              const SizedBox(height: 14),
                              Text(
                                  progress.allComplete
                                      ? '365 moments.\nSo much to carry.'
                                      : 'Your next moment\nis on its way.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium),
                              const SizedBox(height: 15),
                              Text(
                                  progress.allComplete
                                      ? 'Your journey is complete. Every message is here whenever you want to return.'
                                      : 'Your daily message will be available when your journey begins.',
                                  style: Theme.of(context).textTheme.bodyMedium)
                            ])),
                  if (completedToday &&
                      !progress.allComplete &&
                      progress.unlockedThrough < lessons.length) ...[
                    const SizedBox(height: 14),
                    const GlassSurface(
                        padding: EdgeInsets.all(18),
                        child: Row(children: [
                          Icon(Icons.nights_stay_outlined,
                              color: AppColors.accent, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  'Today is complete. Another small step awaits tomorrow.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      height: 1.7)))
                        ]))
                  ],
                  if (next != null &&
                      lesson != null &&
                      next.day < lesson.day) ...[
                    const SectionLabel('A little catching up'),
                    MenuRow(
                        title: next.title,
                        subtitle: 'Day ${next.day} · Available to read',
                        icon: Icons.bookmark_border_rounded,
                        onTap: () => _openLesson(context, next))
                  ],
                  const SectionLabel('The rhythm you’re building'),
                  LayoutBuilder(builder: (context, box) {
                    final cards = [
                      _StreakCard(
                          current: streak.current,
                          longest: streak.longest,
                          activeDays: streak.activeDays,
                          now: now),
                      GlassSurface(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Eyebrow('One day at a time'),
                            const SizedBox(height: 18),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${progress.completedCount}',
                                      style: const TextStyle(
                                          fontSize: 35,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: -1)),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                      child: Padding(
                                          padding: EdgeInsets.only(bottom: 5),
                                          child: Text('moments completed',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors
                                                      .textSecondary))))
                                ]),
                            const SizedBox(height: 16),
                            ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                    value: progress.fraction,
                                    minHeight: 5,
                                    backgroundColor: AppColors.divider)),
                            const SizedBox(height: 15),
                            const Text(
                                'Every small return is part of the journey.',
                                style: TextStyle(
                                    fontSize: 11,
                                    height: 1.7,
                                    color: AppColors.textSecondary))
                          ])),
                    ];
                    if (box.maxWidth > 620 &&
                        MediaQuery.textScalerOf(context).scale(16) < 24) {
                      return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: cards[0]),
                            const SizedBox(width: 18),
                            Expanded(child: cards[1])
                          ]);
                    }
                    return Column(children: [
                      cards[0],
                      const SizedBox(height: 14),
                      cards[1]
                    ]);
                  }),
                  const SectionLabel('Your focus'),
                  GlassSurface(
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Icon(Icons.spa_outlined,
                            color: AppColors.accent, size: 25),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  'A little more ${focusLabel(profile.focus).toLowerCase()}.',
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 9),
                              Text(rhythmTip(profile.obstacle),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.8,
                                      color: AppColors.textSecondary))
                            ]))
                      ])),
                ])));
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
}

class _DailyHero extends StatelessWidget {
  final DailyLesson lesson;
  final bool completed;
  final String focus;
  const _DailyHero(
      {required this.lesson, required this.completed, required this.focus});
  @override
  Widget build(BuildContext context) => GlassSurface(
      highlighted: true,
      padding: const EdgeInsets.all(27),
      radius: 32,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Eyebrow('Day ${lesson.day} of 365 · ${lesson.theme}')),
          const SizedBox(width: 10),
          Icon(
              completed
                  ? Icons.check_circle_outline_rounded
                  : Icons.auto_awesome_outlined,
              color: AppColors.accent,
              size: 25)
        ]),
        const SizedBox(height: 23),
        Text(lesson.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 17),
        Text(lesson.confidence,
            style: const TextStyle(
                fontSize: 15, height: 1.85, color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        Wrap(spacing: 10, runSpacing: 8, children: [
          _Chip(text: lesson.verseReference, icon: Icons.menu_book_outlined),
          const _Chip(text: '5 reading cards', icon: Icons.style_outlined)
        ]),
        const SizedBox(height: 26),
        HolyButton(
            label:
                completed ? 'Revisit today’s message' : 'Open today’s message',
            icon:
                completed ? Icons.history_rounded : Icons.arrow_forward_rounded,
            onPressed: () => _openLesson(context, lesson)),
      ]));
}

class _Chip extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Chip({required this.text, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .68),
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppColors.accent),
        const SizedBox(width: 6),
        Flexible(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 10, height: 1.5, color: AppColors.accentDark)))
      ]));
}

class _StreakCard extends StatelessWidget {
  final int current;
  final int longest;
  final Set<String> activeDays;
  final DateTime now;
  const _StreakCard(
      {required this.current,
      required this.longest,
      required this.activeDays,
      required this.now});
  @override
  Widget build(BuildContext context) => GlassSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.local_fire_department_outlined,
              color: AppColors.flame, size: 24),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  '$current day${current == 1 ? '' : 's'} of showing up',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)))
        ]),
        const SizedBox(height: 22),
        Row(
            children: List.generate(7, (index) {
          final date = DateTime(now.year, now.month, now.day - 6 + index);
          final active = activeDays.contains(StreakNotifier.dayKey(date));
          return Expanded(
              child: Semantics(
                  label: '${date.month}/${date.day}${active ? ', active' : ''}',
                  child: Column(children: [
                    Text(
                        const [
                          'M',
                          'T',
                          'W',
                          'T',
                          'F',
                          'S',
                          'S'
                        ][date.weekday - 1],
                        style: const TextStyle(
                            fontSize: 9, color: AppColors.textSecondary)),
                    const SizedBox(height: 9),
                    Container(
                        width: 27,
                        height: 27,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active
                                ? AppColors.accent
                                : AppColors.surfaceLight
                                    .withValues(alpha: .65)),
                        child: Icon(
                            active ? Icons.check_rounded : Icons.remove_rounded,
                            size: 14,
                            color: active
                                ? Colors.white
                                : AppColors.textSecondary))
                  ])));
        })),
        const SizedBox(height: 18),
        Text('Longest rhythm · $longest day${longest == 1 ? '' : 's'}',
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ]));
}

class _JourneyTab extends ConsumerWidget {
  const _JourneyTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    return ReadingWidth(
        maxWidth: 850,
        child: ListView.builder(
            key: const PageStorageKey('journey'),
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 30),
            itemCount: lessons.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _BrandHeader(trailing: 'YOUR YEAR OF FAITH'),
                          const SizedBox(height: 30),
                          const PageHeading(
                              eyebrow: '365 small steps',
                              title: 'A journey worth\nreturning to.',
                              subtitle:
                                  'One new message each calendar day. Earlier lessons are yours to revisit.'),
                          const SizedBox(height: 23),
                          GlassSurface(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${progress.completedCount} of ${lessons.length} messages complete',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 14),
                                    ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                            value: progress.fraction,
                                            minHeight: 5,
                                            backgroundColor:
                                                AppColors.divider)),
                                    const SizedBox(height: 12),
                                    Text(
                                        'Available through Day ${progress.unlockedThrough}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary))
                                  ]))
                        ]));
              }
              final lesson = lessons[index - 1];
              final done = progress.completedDays.contains(lesson.day);
              final unlocked = progress.isUnlocked(lesson.day);
              final firstInTheme =
                  index == 1 || lessons[index - 2].theme != lesson.theme;
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (firstInTheme)
                      Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 14),
                          child: Eyebrow(lesson.theme)),
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: HolyPressable(
                            label:
                                'Day ${lesson.day}, ${lesson.title}, ${done ? 'completed' : unlocked ? 'available' : 'locked'}',
                            onPressed: unlocked
                                ? () => _openLesson(context, lesson)
                                : null,
                            child: GlassSurface(
                                highlighted: unlocked && !done,
                                radius: 23,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 18),
                                child: Row(children: [
                                  Container(
                                      width: 42,
                                      height: 48,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                          color: done
                                              ? AppColors.accent
                                              : unlocked
                                                  ? AppColors.surfaceLight
                                                  : const Color(0xFFF3ECF0),
                                          borderRadius:
                                              BorderRadius.circular(15)),
                                      child: done
                                          ? const Icon(Icons.check_rounded,
                                              size: 19, color: Colors.white)
                                          : Text('${lesson.day}',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  color: unlocked
                                                      ? AppColors.accentDark
                                                      : AppColors.textSecondary,
                                                  fontWeight:
                                                      FontWeight.w500))),
                                  const SizedBox(width: 16),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(lesson.title,
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                height: 1.5,
                                                color: unlocked
                                                    ? AppColors.textPrimary
                                                    : AppColors.textSecondary)),
                                        const SizedBox(height: 5),
                                        Text(
                                            done
                                                ? 'Completed · Read again'
                                                : unlocked
                                                    ? lesson.verseReference
                                                    : 'Ahead in your journey',
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: AppColors.textSecondary,
                                                height: 1.6))
                                      ])),
                                  const SizedBox(width: 12),
                                  Icon(
                                      unlocked
                                          ? Icons.arrow_forward_rounded
                                          : Icons.lock_outline_rounded,
                                      color: unlocked
                                          ? AppColors.accent
                                          : AppColors.textSecondary,
                                      size: 18)
                                ]))))
                  ]);
            }));
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final profile = ref.watch(profileProvider);
    final progress = ref.watch(progressProvider);
    final streak = ref.watch(streakProvider);
    final syncing = progress.pendingDays.isNotEmpty;
    return ReadingWidth(
        child: ListView(
            key: const PageStorageKey('profile'),
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 28),
            children: [
          const _BrandHeader(trailing: 'YOUR SPACE'),
          const SizedBox(height: 28),
          GlassSurface(
              highlighted: true,
              padding: const EdgeInsets.all(26),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HolyMark(size: 68),
                    const SizedBox(height: 22),
                    const Eyebrow('A little faith, every day'),
                    const SizedBox(height: 11),
                    Text(
                        profile.name.isEmpty
                            ? 'Your quiet space.'
                            : '${profile.name}’s\nquiet space.',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 14),
                    Text(user?.email ?? 'Your HolyHer account',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 22),
                    const _Chip(
                        text: 'Lifetime access', icon: Icons.verified_outlined)
                  ])),
          const SectionLabel('Your journey'),
          GlassSurface(
              child: Column(children: [
            _stat('Messages completed',
                '${progress.completedCount} / ${lessons.length}'),
            const Divider(height: 28),
            _stat('Current rhythm', '${streak.current} days'),
            const Divider(height: 28),
            _stat('Longest rhythm', '${streak.longest} days')
          ])),
          const SizedBox(height: 12),
          MenuRow(
              title: progress.syncError != null
                  ? 'Using your saved journey'
                  : syncing
                      ? 'Saved on this device'
                      : 'Your progress is saved',
              subtitle: progress.syncError != null && !syncing
                  ? 'Reconnect to check new daily lessons and sync your journey. Tap to retry.'
                  : syncing
                      ? 'Reconnect to sync ${progress.pendingDays.length} completed message${progress.pendingDays.length == 1 ? '' : 's'}. Tap to retry.'
                      : 'Your account keeps your journey with you.',
              icon: progress.syncError != null || syncing
                  ? Icons.cloud_upload_outlined
                  : Icons.cloud_done_outlined,
              onTap: progress.syncError != null || syncing
                  ? () => ref.read(progressProvider.notifier).refresh()
                  : null),
          const SectionLabel('Your rhythm'),
          MenuRow(
              title: 'Your focus',
              subtitle: focusLabel(profile.focus),
              icon: Icons.spa_outlined,
              onTap: () => openScreen(context, const SettingsScreen())),
          MenuRow(
              title: 'Settings',
              subtitle: 'Your account, reminders, and preferences',
              icon: Icons.tune_rounded,
              onTap: () => openScreen(context, const SettingsScreen())),
          const SectionLabel('Here for you'),
          MenuRow(
              title: 'Help & support',
              icon: Icons.help_outline_rounded,
              onTap: () => openScreen(context, const HelpScreen())),
          MenuRow(
              title: 'About HolyHer',
              icon: Icons.info_outline_rounded,
              onTap: () => openScreen(context, const AboutScreen())),
          const LegalFooter(),
        ]));
  }

  Widget _stat(String label, String value) => Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary))),
        const SizedBox(width: 16),
        Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)))
      ]);
}
