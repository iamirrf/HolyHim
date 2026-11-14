import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design/design.dart';
import '../../design/widgets/avatar_cropper.dart';
import '../../services/account_cache.dart';
import '../../services/auth_service.dart';
import '../../services/avatar_service.dart';
import '../../services/community.dart';
import '../../services/repository.dart';

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
      final card = ref.read(myMemberProvider).valueOrNull;
      if (card?.photo != null && url != null) {
        await ref.read(communityProvider).updateCard(photo: url).catchError((_) {});
      }
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
    final p = ref.watch(repositoryProvider).profile;
    final t = HolyThemeScope.of(context);
    final providerPhoto = ref.watch(authProvider).user?.photoUrl;
    final url = removed ? null : visibleAvatarUrl(p.avatarUrl, providerPhoto);
    final ImageProvider? image = photo != null
        ? MemoryImage(photo!) as ImageProvider
        : url != null
            ? NetworkImage(url) as ImageProvider
            : null;
    final initial = name.text.trim().isEmpty ? 'H' : name.text.trim()[0].toUpperCase();
    return ScreenFrame(
        title: 'Edit profile',
        scroll: true,
        children: [
          Center(
              child: Semantics(
                  button: true,
                  label: 'Change profile photo',
                  child: GestureDetector(
                      onTap: busy ? null : pick,
                      child: Stack(clipBehavior: Clip.none, children: [
                        Container(
                            width: 120,
                            height: 120,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFFF7DFA4), Color(0xFFD8A657), Color(0xFF6E4A19)]),
                                boxShadow: [
                                  BoxShadow(
                                      color: t.accent.withValues(alpha: .35),
                                      blurRadius: 30),
                                  const BoxShadow(
                                      color: Color(0x66000000),
                                      blurRadius: 14,
                                      offset: Offset(0, 6)),
                                ]),
                            child: CircleAvatar(
                                backgroundColor: t.sunk,
                                backgroundImage: image,
                                child: image == null
                                    ? Text(initial,
                                        style: HolyTypography.display
                                            .copyWith(color: t.accent, fontSize: 44))
                                    : null)),
                        Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: t.accent,
                                    border: Border.all(color: t.paper, width: 3)),
                                child: Icon(CupertinoIcons.camera_fill,
                                    size: 16, color: t.onPrimary))),
                      ])))),
          const SizedBox(height: 12),
          if (image != null)
            Center(
                child: TextAction('Remove photo',
                    onPressed: busy
                        ? null
                        : () => setState(() {
                              photo = null;
                              removed = true;
                            }))),
          const SizedBox(height: 18),
          HolyField(
              controller: name,
              label: 'Name',
              capitalization: TextCapitalization.words,
              maxLength: 40,
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          HolyField(
              controller: username,
              label: 'Username',
              hint: 'Optional',
              maxLength: 30),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!,
                style: HolyTypography.label.copyWith(color: const Color(0xFFF2B8B5))),
          ],
          const SizedBox(height: 20),
          HolyButton('Save',
              loading: busy,
              onPressed: name.text.trim().isEmpty ? null : save),
        ]);
  }
}
