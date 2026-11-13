import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../themes.dart';
import '../typography.dart';

/// A Cognein-inspired boxed calendar and daily streak board.
/// Renders the 7 days of the current week with calendar date numbers,
/// weekday indicators, and glowing flame/check highlights for active days.
class WeekStrip extends StatelessWidget {
  final Set<String> completedDates;
  final DateTime? now;
  final int currentStreak;
  final int longestStreak;

  const WeekStrip({
    super.key,
    required this.completedDates,
    this.now,
    this.currentStreak = 0,
    this.longestStreak = 0,
  });

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = HolyThemeScope.of(context);
    final n = now ?? DateTime.now();
    final date = DateTime(n.year, n.month, n.day);
    // Find Monday of the current week
    final monday = date.subtract(Duration(days: n.weekday - 1));

    final effectiveStreak = currentStreak > 0 ? currentStreak : 1;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.accent.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.accent.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.isDark ? 0.35 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colors.first.withValues(alpha: theme.isDark ? 0.85 : 0.92),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colors.first.withValues(alpha: 0.95),
                theme.glassTint.withValues(alpha: 0.70),
                theme.colors[1].withValues(alpha: 0.85),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top info row: Flame badge + Streak status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient:
                                  LinearGradient(colors: theme.accentGradient),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.accent.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.flame_fill,
                              color: Colors.white,
                              size: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$effectiveStreak DAY STREAK',
                            style: HolyTypography.eyebrow.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: theme.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      longestStreak > 0 ? 'BEST: $longestStreak' : 'TODAY ACTIVE',
                      style: HolyTypography.eyebrow.copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: theme.muted,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Top specular line highlight
              Container(
                height: 1.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.65),
                      theme.accent.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 7-day strip with weekday letter, date number, and active glow
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final d = DateTime(monday.year, monday.month, monday.day + i);
                  final today = _key(d) == _key(date);
                  final done = completedDates.contains(_key(d)) || today;

                  return Expanded(
                    child: Semantics(
                      label: '${const [
                        'Monday',
                        'Tuesday',
                        'Wednesday',
                        'Thursday',
                        'Friday',
                        'Saturday',
                        'Sunday'
                      ][i]}${done ? ', active' : today ? ', today' : ''}',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                              style: HolyTypography.eyebrow.copyWith(
                                fontSize: 11,
                                fontWeight:
                                    today ? FontWeight.w800 : FontWeight.w600,
                                color: today ? theme.accent : theme.muted,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: done
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: theme.accentGradient,
                                    )
                                  : null,
                              color: done
                                  ? null
                                  : Colors.white.withValues(
                                      alpha: theme.isDark ? 0.05 : 0.45,
                                    ),
                              border: Border.all(
                                color: today
                                    ? (done ? Colors.white : theme.accent)
                                    : (done
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : theme.accent.withValues(alpha: 0.2)),
                                width: today ? 2.0 : 1.0,
                              ),
                              boxShadow: done
                                  ? [
                                      BoxShadow(
                                        color: theme.accent.withValues(
                                          alpha: today ? 0.40 : 0.22,
                                        ),
                                        blurRadius: today ? 14 : 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: done
                                ? const Icon(
                                    CupertinoIcons.flame_fill,
                                    color: Colors.white,
                                    size: 17,
                                  )
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${d.day}',
                                      style: HolyTypography.ui.copyWith(
                                        fontSize: 12.5,
                                        fontWeight: today
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: today ? theme.accent : theme.muted,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
