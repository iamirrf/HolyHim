import 'package:flutter/material.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';

Future<bool?> showLessonPause(BuildContext context) =>
    showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (c) => SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Pause here?', style: HolyTypography.section),
                      const SizedBox(height: 12),
                      const Text('Your place will be saved.'),
                      const SizedBox(height: 24),
                      HolyButton(
                          label: 'Continue learning',
                          onPressed: () => Navigator.pop(c, false)),
                      const SizedBox(height: 12),
                      HolyButton(
                          label: 'Save and exit',
                          secondary: true,
                          onPressed: () => Navigator.pop(c, true))
                    ]))));
