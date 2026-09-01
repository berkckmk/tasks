import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'seed_dev.dart';
import '../core/widgets/app_top_bar.dart';
import '../core/widgets/app_button.dart';
import '../core/constants/app_icons.dart';

/// Small debug screen reachable in debug builds. Exposes a single button to
/// seed the development Firestore for the chosen email address.
class DevSeedScreen extends StatefulWidget {
  const DevSeedScreen({super.key});

  @override
  State<DevSeedScreen> createState() => _DevSeedScreenState();
}

class _DevSeedScreenState extends State<DevSeedScreen> {
  bool _inProgress = false;
  String? _lastMessage;

  Future<void> _seed() async {
    if (!kDebugMode) return;
    setState(() {
      _inProgress = true;
      _lastMessage = null;
    });

    try {
      await seedOneWeekPlanForEmail('ekmekarasitutun@gmail.com');
      setState(() => _lastMessage = 'Seed başarılı: ekmekarasitutun@gmail.com');
    } catch (e) {
      setState(() => _lastMessage = 'Seed hata: $e');
    } finally {
      setState(() => _inProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: const Text('Dev seed')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Bu ekran yalnızca debug modunda kullanılmalıdır.'),
            const SizedBox(height: 16),
            AppButton(
              onPressed: _inProgress ? null : _seed,
              icon: AppIcons.listPlus,
              expand: true,
              label: _inProgress
                  ? 'Çalışıyor...'
                  : 'Seed ekmekarasitutun@gmail.com',
            ),
            const SizedBox(height: 12),
            if (_lastMessage != null) Text(_lastMessage!),
          ],
        ),
      ),
    );
  }
}
