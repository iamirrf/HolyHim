import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design/design.dart';
import '../../design/widgets/avatar_cropper.dart';
import '../../services/account_cache.dart';
import '../../services/auth_service.dart';
import '../../services/avatar_service.dart';
import '../../services/repository.dart';
import '../common.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController name, username;
  Uint8List? photo;
  bool removed = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final p = ref.read(repositoryProvider).profile;
    name = TextEditingController(text: p.name);
    username = TextEditingController(text: p.username);
  }

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    try {
      final value = await pickAndCropAvatar(context,
          accent: HolyThemeScope.of(context).accent);
      if (value != null && mounted) {
        setState(() {
          photo = value;
          removed = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => error = 'That photo could not be opened. Try another image.');
      }
    }
  }

  Future<void> save() async {
    if (busy || name.text.trim().isEmpty) return;
    final uid = ref.read(authProvider).user?.uid;
    if (uid == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      var url = removed ? '' : ref.read(repositoryProvider).profile.avatarUrl;
      if (photo != null) {
        url = await ref.read(avatarServiceProvider).upload(uid, photo!);
      }
      if (!mounted || ref.read(authProvider).user?.uid != uid) return;
      ref.read(repositoryProvider.notifier).updateProfile(ref
          .read(repositoryProvider)
          .profile
          .copyWith(
              name: name.text.trim(),
              username: username.text.trim(),
              avatarUrl: url));
      await ref.read(accountCacheProvider).flush();
      // Old files are removed by the trusted profile-update trigger only after
      // Firestore accepts the replacement, so a rejected write cannot break it.
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
            () => error = 'Your profile could not be saved. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(repositoryProvider).profile,
        theme = HolyThemeScope.of(context);
    final providerPhoto = ref.watch(authProvider).user?.photoUrl;
    final url = removed ? null : visibleAvatarUrl(p.avatarUrl, providerPhoto);
    final ImageProvider? image = photo != null
        ? MemoryImage(photo!) as ImageProvider
        : url != null
            ? NetworkImage(url) as ImageProvider
            : null;
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: const GlassTopBar(
            title: Text('Edit profile', style: HolyTypography.title)),
        body: PageBody(
            padding: EdgeInsets.fromLTRB(
                28, MediaQuery.paddingOf(context).top + 100, 28, 40),
            children: [
              Center(
                  child: Pressable(
                      onPressed: busy ? null : pick,
                      semanticLabel: 'Change profile photo',
                      child: Stack(alignment: Alignment.bottomRight, children: [
                        CircleAvatar(
                            radius: 58,
                            backgroundColor:
                                theme.accent.withValues(alpha: .12),
                            backgroundImage: image,
                            child: image == null
                                ? Icon(CupertinoIcons.person,
                                    size: 48, color: theme.accent)
                                : null),
                        Glass(
                            radius: 24,
                            padding: const EdgeInsets.all(11),
                            child: Icon(CupertinoIcons.camera_fill,
                                size: 21, color: theme.accent)),
                      ]))),
              const SizedBox(height: 14),
              Center(
                  child: TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              setState(() {
                                removed = true;
                                photo = null;
                              });
                            },
                      child: const Text('Remove photo'))),
              const SizedBox(height: 26),
              Glass(
                  radius: 22,
                  child: Column(children: [
                    TextField(
                        controller: name,
                        maxLength: 80,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                            labelText: 'Name', counterText: ''),
                        onChanged: (_) => setState(() {})),
                    const SizedBox(height: 20),
                    TextField(
                        controller: username,
                        maxLength: 40,
                        decoration: const InputDecoration(
                            labelText: 'Display name · optional',
                            counterText: '')),
                  ])),
              if (error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(error!, style: muted(context))),
              const SizedBox(height: 28),
              ActionButton(busy ? 'Saving…' : 'Save profile',
                  onPressed: busy || name.text.trim().isEmpty ? null : save),
            ]));
  }
}
