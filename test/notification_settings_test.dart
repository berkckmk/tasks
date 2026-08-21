import 'package:flutter_test/flutter_test.dart';
import 'package:steady_progress/features/notifications/domain/notification_settings.dart';

void main() {
  group('NotificationSettings.fromPreferences', () {
    test('a profile written before this feature gets everything on', () {
      // The case that matters most. None of these keys exist on any account
      // created before the settings screen shipped, and a default of `false`
      // anywhere here would silently stop notifications for every existing
      // user the moment it deployed. The backend defaults the same way —
      // functions/src/notifications/preferences.ts.
      final settings = NotificationSettings.fromPreferences(const {
        'theme': 'system',
      });

      expect(settings.masterEnabled, isTrue);
      expect(settings.taskDigestHour, NotificationSettings.defaultDigestHour);
      for (final channel in NotificationChannel.values) {
        expect(settings.isEnabled(channel), isTrue, reason: channel.name);
      }
    });

    test('only an explicit false turns a channel off', () {
      final settings = NotificationSettings.fromPreferences(const {
        'notifyTaskDigest': false,
      });

      expect(settings.isEnabled(NotificationChannel.taskDigest), isFalse);
      expect(settings.isEnabled(NotificationChannel.habitReminders), isTrue);
      expect(settings.isEnabled(NotificationChannel.reminderAlerts), isTrue);
    });

    test('the master switch suppresses channels without forgetting them', () {
      final settings = NotificationSettings.fromPreferences(const {
        'notificationsEnabled': false,
        'notifyHabitReminders': true,
      });

      // Nothing is sent...
      expect(settings.isEnabled(NotificationChannel.habitReminders), isFalse);
      // ...but the choice survives, so switching back on restores it rather
      // than silently resetting everything to the defaults.
      expect(settings.isChannelOn(NotificationChannel.habitReminders), isTrue);
    });

    test('an out-of-range digest hour falls back instead of propagating', () {
      for (final bad in [-1, 24, 99, 'eight', null]) {
        final settings = NotificationSettings.fromPreferences({
          'taskDigestHour': bad,
        });
        expect(
          settings.taskDigestHour,
          NotificationSettings.defaultDigestHour,
          reason: 'taskDigestHour=$bad',
        );
      }
    });

    test('a valid digest hour is kept, including midnight', () {
      expect(
        NotificationSettings.fromPreferences(const {'taskDigestHour': 0})
            .taskDigestHour,
        0,
      );
      expect(
        NotificationSettings.fromPreferences(const {'taskDigestHour': 23})
            .taskDigestHour,
        23,
      );
    });
  });

  group('NotificationSettings.applyTo', () {
    test('keeps unrelated preferences', () {
      // appPreferences is a single map holding more than notifications, and
      // the repository writes the whole field — dropping `theme` here would
      // reset the user's theme every time they touched a switch.
      final written =
          NotificationSettings.fromPreferences(const {'theme': 'dark'})
              .withChannel(NotificationChannel.taskDigest, false)
              .applyTo(const {'theme': 'dark'});

      expect(written['theme'], 'dark');
      expect(written['notifyTaskDigest'], isFalse);
    });

    test('writes every channel explicitly, so nothing stays implicit', () {
      final written = NotificationSettings.fromPreferences(const {})
          .applyTo(const {});

      for (final channel in NotificationChannel.values) {
        expect(written.containsKey(channel.key), isTrue, reason: channel.key);
      }
      expect(written['notificationsEnabled'], isTrue);
      expect(written['taskDigestHour'], NotificationSettings.defaultDigestHour);
    });

    test('survives a round trip', () {
      final original = NotificationSettings.fromPreferences(const {})
          .withChannel(NotificationChannel.habitReminders, false)
          .copyWith(taskDigestHour: 21);

      final restored = NotificationSettings.fromPreferences(
        original.applyTo(const {}),
      );

      expect(restored.masterEnabled, original.masterEnabled);
      expect(restored.taskDigestHour, 21);
      expect(restored.isChannelOn(NotificationChannel.habitReminders), isFalse);
      expect(restored.isChannelOn(NotificationChannel.taskDigest), isTrue);
    });
  });

  test('every channel key is distinct', () {
    // They are map keys in one document; a duplicate would make two switches
    // silently control the same field.
    final keys = NotificationChannel.values.map((c) => c.key).toSet();
    expect(keys.length, NotificationChannel.values.length);
  });
}
