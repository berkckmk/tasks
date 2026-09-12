import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Avatars live at `users/{uid}/avatar.jpg` in Firebase Storage — see
/// storage.rules for the matching security rule (owner-writable,
/// publicly-readable so `Image.network(photoUrl)` works without needing an
/// authenticated fetch).
class AvatarRepository {
  AvatarRepository(this._storage);

  final FirebaseStorage _storage;

  Reference _avatarRef(String uid) => _storage.ref('users/$uid/avatar.jpg');

  /// Uploads raw image bytes (from `XFile.readAsBytes()`, which works the
  /// same on web and mobile — no `dart:io` File needed) and returns the
  /// public download URL.
  Future<String> uploadAvatar(String uid, Uint8List bytes) async {
    final ref = _avatarRef(uid);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<void> deleteAvatar(String uid) async {
    try {
      await _avatarRef(uid).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}
