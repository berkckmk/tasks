import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/firebase/fcm_config.dart';

/// Registers this device for push notifications. Tokens live in
/// `users/{uid}/fcmTokens/{token}` (doc id is the token itself, so
/// re-registering the same device is idempotent and a user with multiple
/// devices just gets multiple docs) — see
/// functions/src/notifications/reminders.ts for what sends to them.
class PushNotificationsRepository {
  PushNotificationsRepository(this._messaging, this._firestore);

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> registerTokenForUser(String uid) async {
    final token = await _messaging.getToken(
      vapidKey: kIsWeb ? FcmConfig.webVapidKey : null,
    );
    if (token == null) return;
    await _saveToken(uid, token);
  }

  Future<void> unregisterCurrentToken(String uid) async {
    final token = await _messaging.getToken(
      vapidKey: kIsWeb ? FcmConfig.webVapidKey : null,
    );
    if (token == null) return;
    await _firestore.collection('users').doc(uid).collection('fcmTokens').doc(token).delete();
    await _messaging.deleteToken();
  }

  Future<void> _saveToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).collection('fcmTokens').doc(token).set({
      'token': token,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'updatedAt': Timestamp.now(),
    });
  }
}
