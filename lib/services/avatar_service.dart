import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';

final avatarServiceProvider = Provider<AvatarService>((ref) => AvatarService());

/// Null keeps a provider photo; an empty saved URL explicitly removes it.
String? visibleAvatarUrl(String? saved, String? provider) =>
    saved == '' ? null : saved ?? provider;

class AvatarService {
  Future<String> upload(String uid, Uint8List bytes) async {
    final path =
        'users/$uid/avatars/${DateTime.now().microsecondsSinceEpoch}.jpg';
    final object = FirebaseStorage.instance.ref(path);
    await object.putData(
        bytes,
        SettableMetadata(
            contentType: 'image/jpeg', cacheControl: 'private,max-age=3600'));
    return object.getDownloadURL();
  }

  Future<void> remove(String uid, String? url) async {
    if (url == null || url.isEmpty) return;
    final object = FirebaseStorage.instance.refFromURL(url);
    if (!object.fullPath.startsWith('users/$uid/avatars/')) return;
    try {
      await object.delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}

final avatarBusyProvider = StateProvider<bool>((ref) {
  ref.watch(authProvider.select((s) => s.user?.uid));
  return false;
});
