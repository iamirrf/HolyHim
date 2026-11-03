import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/services/profile_service.dart';

class ThemeScreen extends ConsumerStatefulWidget {
  const ThemeScreen({super.key});
  @override
  ConsumerState<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends ConsumerState<ThemeScreen> {
  String? _error;
  bool _saving = false;
  Future<void> _select(String id) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(profileProvider.notifier)
          .save(ref.read(profileProvider).copyWith(theme: id));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Saved on this device. Reconnect and Retry to sync your theme.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    return HolyScaffold(
        title: 'Make it your quiet place',
        body: ReadingWidth(
            maxWidth: 640,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              const Text('A different kind of light.',
                  style: HolyTypography.heading),
              const SizedBox(height: 12),
              const Text('Your theme follows you across devices.'),
              const SizedBox(height: 24),
              for (final palette in HolyPalette.all)
                Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Semantics(
                        selected: profile.theme == palette.id,
                        child: HolyPressable(
                            label: '${palette.name} theme',
                            onPressed:
                                _saving ? null : () => _select(palette.id),
                            child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [
                                      palette.background,
                                      palette.blush
                                    ]),
                                    borderRadius: BorderRadius.circular(26),
                                    border: Border.all(
                                        color: profile.theme == palette.id
                                            ? palette.accent
                                            : palette.edge,
                                        width: profile.theme == palette.id
                                            ? 2
                                            : 1)),
                                child: Row(children: [
                                  Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: palette.card,
                                          border:
                                              Border.all(color: palette.edge)),
                                      child: Icon(Icons.light_mode_outlined,
                                          color: palette.accent)),
                                  const SizedBox(width: 16),
                                  Expanded(
                                      child: Text(palette.name,
                                          style: HolyTypography.section
                                              .copyWith(color: palette.ink))),
                                  if (profile.theme == palette.id)
                                    Icon(Icons.check_circle_outline,
                                        color: palette.accent)
                                ]))))),
              if (_error != null) InlineMessage(_error!),
              if (_error != null)
                TextButton(
                    onPressed: () => _select(profile.theme),
                    child: const Text('Retry')),
            ])));
  }
}
