import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../domain/notification_settings.dart';
import 'push_notifications_providers.dart';

/// The user's notification settings, derived from their profile document.
///
/// Falls back to the all-on defaults while the profile is loading or absent,
/// which matches what the backend does with a profile that has none of these
/// keys — the screen never shows a state the server wouldn't act on.
final notificationSettingsProvider = Provider<NotificationSettings>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  return NotificationSettings.fromPreferences(
    profile?.appPreferences ?? const {},
  );
});

/// Whether the OS-level permission dance is still in flight, so the screen
/// can disable the master switch instead of letting it be toggled twice.
final notificationPermissionBusyProvider = StateProvider<bool>((ref) => false);

class NotificationSettingsActions {
  NotificationSettingsActions(this._ref);

  final Ref _ref;

  /// Turns notifications on or off as a whole.
  ///
  /// Two things have to happen together and in this order, which is why they
  /// live here rather than in the widget: the preference is what the backend
  /// schedulers read, and the FCM token registration is what gives them
  /// somewhere to send. Persisting the preference first means a denied OS
  /// permission still leaves the stored state truthful.
  ///
  /// Returns false when the user denied the system permission — the caller
  /// is expected to say so, and the switch goes back off.
  Future<bool> setMasterEnabled(bool enabled) async {
    final busy = _ref.read(notificationPermissionBusyProvider.notifier);
    busy.state = true;
    try {
      await _write((settings) => settings.copyWith(masterEnabled: enabled));

      final push = _ref.read(pushNotificationsActionsProvider);
      if (!enabled) {
        await push.disable();
        return true;
      }

      final granted = await push.enable();
      if (!granted) {
        // The OS said no, so there is no token and nothing can arrive.
        // Rolling the preference back keeps the screen from claiming
        // notifications are on when they cannot be.
        await _write((settings) => settings.copyWith(masterEnabled: false));
      }
      return granted;
    } finally {
      busy.state = false;
    }
  }

  Future<void> setChannel(NotificationChannel channel, bool enabled) {
    return _write((settings) => settings.withChannel(channel, enabled));
  }

  /// [hour] is a local wall-clock hour, 0-23, in the user's own timezone.
  Future<void> setTaskDigestHour(int hour) {
    return _write(
      (settings) => settings.copyWith(taskDigestHour: hour.clamp(0, 23)),
    );
  }

  Future<void> setImportantBypassSilent(bool value) {
    return _write(
      (settings) => settings.copyWith(importantBypassSilent: value),
    );
  }

  /// Reads the current preferences map, applies [change], writes it back.
  ///
  /// The whole map is round-tripped because `updateAppPreferences` replaces
  /// the field wholesale — reading the live copy first is what stops this
  /// from dropping unrelated keys like `theme`.
  Future<void> _write(
    NotificationSettings Function(NotificationSettings) change,
  ) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;

    final profile = _ref.read(profileProvider).valueOrNull;
    final preferences = Map<String, dynamic>.from(
      profile?.appPreferences ?? {},
    );
    final next = change(NotificationSettings.fromPreferences(preferences));

    await _ref
        .read(userProfileRepositoryProvider)
        .updateAppPreferences(uid, next.applyTo(preferences));
  }
}

final notificationSettingsActionsProvider =
    Provider<NotificationSettingsActions>(
      (ref) => NotificationSettingsActions(ref),
    );
