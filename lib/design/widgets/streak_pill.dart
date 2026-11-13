import 'package:flutter/material.dart';
import '../themes.dart';
import '../typography.dart';
import 'glass.dart';

class StreakPill extends StatelessWidget {
  final int days;
  const StreakPill({super.key, required this.days});
  @override
  Widget build(BuildContext context) => Semantics(
      label: '$days day streak',
      child: Glass(
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_fire_department_rounded,
                color: HolyThemeScope.of(context).accent, size: 20),
            const SizedBox(width: 5),
            Text('$days',
                style: HolyTypography.ui.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: HolyThemeScope.of(context).ink))
          ])));
}
