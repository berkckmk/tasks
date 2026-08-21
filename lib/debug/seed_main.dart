import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import 'seed_all.dart';
import '../core/widgets/app_glass_app_bar.dart';

/// Debug-only entrypoint that seeds every module for the signed-in user.
///
/// It is a separate entrypoint rather than a button inside the app so that
/// seeding never ships in the real UI, and so running it doesn't require
/// touching `main.dart`. It reuses the app's own Firebase config and the
/// session already persisted on the device, so whatever account is signed in
/// in the app is the account that gets seeded.
///
///   `flutter run -t lib/debug/seed_main.dart -d <device>`
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const _SeedApp());
}

class _SeedApp extends StatelessWidget {
  const _SeedApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _SeedScreen(),
    );
  }
}

class _SeedScreen extends StatefulWidget {
  const _SeedScreen();

  @override
  State<_SeedScreen> createState() => _SeedScreenState();
}

class _SeedScreenState extends State<_SeedScreen> {
  String _status = 'Oturum bekleniyor...';
  List<SeedResult> _results = const [];
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _seed();
  }

  Future<void> _seed() async {
    // Auth persistence restores asynchronously; the first authStateChanges
    // event can still be null on a cold start.
    User? user = FirebaseAuth.instance.currentUser;
    user ??= await FirebaseAuth.instance
        .authStateChanges()
        .firstWhere((u) => u != null)
        .timeout(const Duration(seconds: 20), onTimeout: () => null);

    if (user == null) {
      _report('HATA: Cihazda oturum açık değil. Önce uygulamada giriş yapın.');
      return;
    }

    _report('Seed başlıyor — ${user.email} (${user.uid})');

    final results = await seedAllModulesForCurrentUser();

    for (final r in results) {
      debugPrint('SEED >> $r');
    }
    final okCount = results.where((r) => r.ok).length;
    final total = results.fold<int>(0, (sum, r) => sum + r.written);
    debugPrint('SEED >> BİTTİ: $okCount/${results.length} modül, $total kayıt');

    if (!mounted) return;
    setState(() {
      _results = results;
      _status =
          '${user!.email}\n$okCount/${results.length} modül · $total kayıt';
      _done = true;
    });
  }

  void _report(String message) {
    debugPrint('SEED >> $message');
    if (!mounted) return;
    setState(() => _status = message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppGlassAppBar(title: const Text('Seed — gerçek DB')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_status, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (!_done) const LinearProgressIndicator(),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final r = _results[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      r.ok ? Icons.check_circle : Icons.error,
                      color: r.ok ? Colors.green : Colors.red,
                    ),
                    title: Text('${r.module} — ${r.written}'),
                    subtitle: r.error == null ? null : Text(r.error!),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
