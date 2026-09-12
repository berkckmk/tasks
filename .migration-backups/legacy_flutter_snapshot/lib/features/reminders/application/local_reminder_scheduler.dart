import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/reminder.dart';

class LocalReminderScheduler {
  const LocalReminderScheduler();

  static const MethodChannel _channel = MethodChannel(
    'com.steadyprogress/reminders_alarm',
  );

  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Schedules an exact hardware alarm for the given reminder.
  /// Fires on time even in deep sleep (Doze Mode) and routes to smart watch / headphones.
  Future<void> schedule(ReminderItem reminder) async {
    if (!_isSupported) return;
    if (reminder.status != ReminderStatus.scheduled || reminder.dueAt == null) {
      await cancel(reminder.id);
      return;
    }

    final dueAt = reminder.dueAt!;
    if (dueAt.isBefore(DateTime.now())) {
      return;
    }

    try {
      await _channel.invokeMethod<bool>('scheduleAlarm', {
        'id': reminder.id,
        'timestampMs': dueAt.millisecondsSinceEpoch,
        'title': reminder.title,
        'message': reminder.message.isNotEmpty
            ? reminder.message
            : (reminder.priority == ReminderPriority.important
                  ? 'Zamanı geldi! Lütfen kontrol edin.'
                  : 'Hatırlatıcı zamanı.'),
        'priority': reminder.priority.name,
      });
      debugPrint(
        'Scheduled exact alarm for "${reminder.title}" at $dueAt [Priority: ${reminder.priority.name}]',
      );
    } catch (e) {
      debugPrint('Failed to schedule exact alarm: $e');
    }
  }

  /// Cancels any existing scheduled alarm for this reminder.
  Future<void> cancel(String reminderId) async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<bool>('cancelAlarm', {'id': reminderId});
    } catch (e) {
      debugPrint('Failed to cancel alarm: $e');
    }
  }

  /// Syncs all scheduled upcoming reminders to exact alarms.
  Future<void> syncAll(List<ReminderItem> reminders) async {
    if (!_isSupported) return;
    for (final reminder in reminders) {
      if (reminder.status == ReminderStatus.scheduled &&
          reminder.dueAt != null &&
          reminder.dueAt!.isAfter(DateTime.now())) {
        await schedule(reminder);
      }
    }
  }

  /// Fires a direct test notification through the local notification channels.
  Future<void> testNotification({
    String id = 'test_reminder',
    String title = 'Duxet 30mg',
    String message = 'İlaç vakti geldi! Lütfen alınız.',
    String priority = 'important',
  }) async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<bool>('testNotification', {
        'id': id,
        'title': title,
        'message': message,
        'priority': priority,
      });
    } catch (e) {
      debugPrint('Failed to send test notification: $e');
    }
  }

  /// Retrieves any reminder id from the launch intent that opened the app.
  Future<String?> getInitialReminderId() async {
    if (!_isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('getInitialReminderId');
    } catch (e) {
      debugPrint('Failed to get initial reminder id: $e');
      return null;
    }
  }
}

final localReminderSchedulerProvider = Provider<LocalReminderScheduler>(
  (ref) => const LocalReminderScheduler(),
);
