import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/avatar_repository.dart';
import 'profile_providers.dart';

final avatarRepositoryProvider = Provider<AvatarRepository>((ref) {
  return AvatarRepository(ref.watch(firebaseStorageProvider));
});

class AvatarActions {
  AvatarActions(this._ref);

  final Ref _ref;

  /// Opens the system image picker, uploads the chosen image to Storage,
  /// and updates the profile doc's photoUrl. No-op if the user cancels the
  /// picker or isn't signed in.
  Future<void> pickAndUploadAvatar() async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final photoUrl = await _ref.read(avatarRepositoryProvider).uploadAvatar(uid, bytes);

    // Avatars always live at the same Storage path, so getDownloadURL()
    // returns a byte-identical URL after a re-upload — and Flutter's
    // ImageCache is keyed by URL, so the old picture stayed on screen until
    // the app was restarted. The version parameter is ignored by Storage but
    // makes the URL (and therefore the cache key) new.
    final versioned = Uri.parse(photoUrl).replace(
      queryParameters: {
        ...Uri.parse(photoUrl).queryParameters,
        'v': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    ).toString();
    await _ref.read(userProfileRepositoryProvider).updatePhotoUrl(uid, versioned);
  }
}

final avatarActionsProvider = Provider<AvatarActions>((ref) => AvatarActions(ref));
