import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';

/// Debug-only entrypoint that answers one question: **can a push actually
/// reach this device?**
///
/// It prints the three things that have to line up, and nothing else:
///
///  1. the OS-level permission — Android 13+ will silently drop a notification
///     for an app that was never granted `POST_NOTIFICATIONS`;
///  2. this device's FCM token — no token, nothing to address;
///  3. how many token documents `users/{uid}/fcmTokens` holds, because that
///     collection is what `sendToUserTokens` reads, and it returns early when
///     it is empty (`functions/src/notifications/reminders.ts`).
///
/// A separate entrypoint for the same reason `seed_main.dart` is one: this
/// never ships in the real UI and `main.dart` stays untouched.
///
///   `flutter run -t lib/debug/fcm_check_main.dart -d <device>`
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const _FcmCheckApp());
}

class _FcmCheckApp extends StatefulWidget {
  const _FcmCheckApp();

  @override
  State<_FcmCheckApp> createState() => _FcmCheckAppState();
}

class _FcmCheckAppState extends State<_FcmCheckApp> {
  final List<String> _lines = [];

  @override
  void initState() {
    super.initState();
    _check();
  }

  void _log(String line) {
    debugPrint('FCM >> $line');
    if (mounted) setState(() => _lines.add(line));
  }

  Future<void> _check() async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.getNotificationSettings();
    _log('permission: ${settings.authorizationStatus.name}');

    // Auth persistence restores asynchronously; the first authStateChanges
    // event can still be null on a cold start.
    User? user = FirebaseAuth.instance.currentUser;
    user ??= await FirebaseAuth.instance
        .authStateChanges()
        .firstWhere((u) => u != null)
        .timeout(const Duration(seconds: 15), onTimeout: () => null);
    if (user == null) {
      _log('signed out — sign in in the app first');
      return;
    }
    _log('uid: ${user.uid} (${user.email})');

    String? token;
    try {
      token = await messaging.getToken();
      _log('token: ${token == null ? 'NULL' : '${token.substring(0, 24)}…'}');
    } catch (error) {
      _log('token: FAILED ($error)');
    }

    try {
      final tokens = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .get();
      _log('fcmTokens docs: ${tokens.size}');
      for (final doc in tokens.docs) {
        final platform = doc.data()['platform'];
        final isThisDevice = doc.id == token;
        _log('  - $platform ${doc.id.substring(0, 16)}…'
            '${isThisDevice ? ' (this device)' : ''}');
      }
    } catch (error) {
      _log('fcmTokens: FAILED ($error)');
    }

    // The scheduler reads these off the user document, not the client.
    try {
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final prefs = profile.data()?['appPreferences'] as Map<String, dynamic>?;
      _log('timezone: ${profile.data()?['timezone'] ?? '(unset)'}');
      _log('prefs: ${prefs ?? '(none — defaults are all-on)'}');
    } catch (error) {
      _log('profile: FAILED ($error)');
    }

    _log('DONE');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('FCM check')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final line in _lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SelectableText(line),
              ),
          ],
        ),
      ),
    );
  }
}
