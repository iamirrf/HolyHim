import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design/design.dart';
import '../../services/repository.dart';
import '../common.dart';

/// SunRize's full-width gradient swatches, with account-scoped instant apply.
class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(repositoryProvider).profile;
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: const GlassTopBar(
            title: Text('Your theme', style: HolyTypography.title)),
        body: PageBody(
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.paddingOf(context).top + 86, 24, 40),
            children: [
              const Text('Choose your atmosphere', style: HolyTypography.title),
              const SizedBox(height: 10),
              Text('Your choice follows you through HolyHim.',
                  style: muted(context)),
              const SizedBox(height: 24),
              for (final theme in HolyThemes.all)
                Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Semantics(
                        selected: theme.id == profile.theme,
                        child: Pressable(
                            semanticLabel: '${theme.name} theme',
                            selected: theme.id == profile.theme,
                            onPressed: () {
                              HolyHaptics.chipSelect();
                              ref
                                  .read(repositoryProvider.notifier)
                                  .updateProfile(ref
                                      .read(repositoryProvider)
                                      .profile
                                      .copyWith(theme: theme.id));
                            },
                            child: AspectRatio(
                                aspectRatio: 5,
                                child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: theme.colors),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: theme.id == profile.theme
                                                ? theme.accent
                                                : Colors.white
                                                    .withValues(alpha: .65),
                                            width: theme.id == profile.theme
                                                ? 3
                                                : 1),
                                        boxShadow: [
                                          BoxShadow(
                                              color: theme.accent.withValues(
                                                  alpha:
                                                      theme.id == profile.theme
                                                          ? .25
                                                          : .08),
                                              blurRadius:
                                                  theme.id == profile.theme
                                                      ? 22
                                                      : 10,
                                              offset: const Offset(0, 5))
                                        ]),
                                    child: Stack(children: [
                                      Positioned.fill(
                                          child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              child: IgnorePointer(
                                                  child: ParticleField(
                                                      config: ParticleConfig(
                                                          count: 8,
                                                          color: theme.particle,
                                                          minSize: 1.5,
                                                          maxSize: 3,
                                                          speed: .12))))),
                                      Positioned(
                                          left: 20,
                                          bottom: 14,
                                          child: Text(theme.name,
                                              style: HolyTypography.ui.copyWith(
                                                  color: theme.ink,
                                                  fontWeight:
                                                      FontWeight.w700))),
                                      if (theme.id == profile.theme)
                                        Positioned(
                                            right: 18,
                                            top: 14,
                                            child: Icon(
                                                CupertinoIcons
                                                    .check_mark_circled_solid,
                                                color: theme.accent,
                                                size: 24)),
                                    ])))))),
            ]));
  }
}
