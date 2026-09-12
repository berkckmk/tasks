import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/push_notifications_repository.dart';

final firebaseMessagingProvider = Provider<FirebaseMessaging>(
  (ref) => FirebaseMessaging.instance,
);

final pushNotificationsRepositoryProvider =
    Provider<PushNotificationsRepository>((ref) {
      return PushNotificationsRepository(
        ref.watch(firebaseMessagingProvider),
        ref.watch(firestoreProvider),
      );
    });

class PushNotificationsActions {
  PushNotificationsActions(this._ref);

  final Ref _ref;

  /// Requests OS permission (on platforms that need it) and registers this
  /// device's token. Returns false if the user denies permission.
  Future<bool> enable() async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return false;

    final repository = _ref.read(pushNotificationsRepositoryProvider);
    final granted = await repository.requestPermission();
    if (!granted) return false;

    await repository.registerTokenForUser(uid);
    return true;
  }

  /// Silently registers the token if permission is already granted.
  Future<void> syncTokenIfGranted() async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    final repository = _ref.read(pushNotificationsRepositoryProvider);
    final granted = await repository.isPermissionGranted();
    if (granted) {
      await repository.registerTokenForUser(uid);
    }
  }

  Future<void> disable() async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    await _ref
        .read(pushNotificationsRepositoryProvider)
        .unregisterCurrentToken(uid);
  }
}

final pushNotificationsActionsProvider = Provider<PushNotificationsActions>(
  (ref) => PushNotificationsActions(ref),
);
