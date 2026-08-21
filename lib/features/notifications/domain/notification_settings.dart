/// One kind of notification the app can send.
///
/// Every value here has a real sender behind it in
/// `functions/src/notifications/reminders.ts`. Adding a case without adding
/// the scheduled function that honours it produces a switch the user can
/// toggle that does nothing, which is worse than not offering it.
enum NotificationChannel {
  habitReminders(
    key: 'notifyHabitReminders',
    label: 'Habit reminders',
    description: 'At the time set on each habit.',
  ),
  taskDigest(
    key: 'notifyTaskDigest',
    label: 'Daily task digest',
    description: 'One summary of the tasks due today.',
  ),
  reminderAlerts(
    key: 'notifyReminderAlerts',
    label: 'Reminder alerts',
    description: 'When a reminder you set comes due.',
  );

  const NotificationChannel({
    required this.key,
    required this.label,
    required this.description,
  });

  /// The field name inside `users/{uid}.appPreferences`. Shared with the
  /// backend — `reminders.ts` reads these exact strings.
  final String key;
  final String label;
  final String description;
}

/// The notification half of `users/{uid}.appPreferences`.
///
/// Stored in that existing map rather than in a new collection, deliberately:
/// the backend schedulers already load the user document to read `timezone`
/// and `appPreferences.notificationsEnabled`, so keeping these beside them
/// costs no extra read per user per run. It also means no new Firestore
/// `match` block — every collection needs one and a missing one fails
/// silently at runtime (see CLAUDE.md).
///
/// **Every field defaults to on.** These keys don't exist on any profile
/// written before this feature, and a default of `false` would silently stop
/// notifications for existing users on upgrade.
class NotificationSettings {
  const NotificationSettings({
    required this.masterEnabled,
    required this.disabledChannels,
    required this.taskDigestHour,
  });

  /// The top-level switch. Off means nothing is sent regardless of the
  /// per-channel values, which are kept so they come back as the user left
  /// them when it's switched on again.
  final bool masterEnabled;

  /// Channels explicitly turned off. Stored as the negative so an unknown or
  /// newly added channel defaults to enabled.
  final Set<NotificationChannel> disabledChannels;

  /// Local hour, 0-23, at which the daily digest is sent.
  ///
  /// Interpreted in the user's own IANA timezone by the backend, not in UTC —
  /// 08:00 happens at a different instant in every zone. See
  /// `functions/src/lib/datetime.ts`.
  final int taskDigestHour;

  static const defaultDigestHour = 8;

  bool isEnabled(NotificationChannel channel) =>
      masterEnabled && !disabledChannels.contains(channel);

  /// Whether the channel's own switch is on, ignoring the master switch.
  /// The UI shows these as on-but-inactive rather than flipping them off.
  bool isChannelOn(NotificationChannel channel) =>
      !disabledChannels.contains(channel);

  factory NotificationSettings.fromPreferences(Map<String, dynamic> prefs) {
    return NotificationSettings(
      masterEnabled: prefs['notificationsEnabled'] as bool? ?? true,
      disabledChannels: {
        for (final channel in NotificationChannel.values)
          if (prefs[channel.key] == false) channel,
      },
      taskDigestHour: _readHour(prefs['taskDigestHour']),
    );
  }

  /// Out-of-range or non-integer values fall back rather than propagating.
  /// The backend clamps too, but a bad value written by an older build
  /// shouldn't show as "digest at 47:00" on this screen either.
  static int _readHour(Object? raw) {
    final value = raw is int ? raw : (raw is num ? raw.toInt() : null);
    if (value == null || value < 0 || value > 23) return defaultDigestHour;
    return value;
  }

  /// Merges these settings into an existing preferences map.
  ///
  /// Merged rather than replaced because `appPreferences` also carries
  /// unrelated keys (`theme`), and the repository writes the whole map.
  Map<String, dynamic> applyTo(Map<String, dynamic> prefs) {
    return {
      ...prefs,
      'notificationsEnabled': masterEnabled,
      for (final channel in NotificationChannel.values)
        channel.key: !disabledChannels.contains(channel),
      'taskDigestHour': taskDigestHour,
    };
  }

  NotificationSettings copyWith({
    bool? masterEnabled,
    Set<NotificationChannel>? disabledChannels,
    int? taskDigestHour,
  }) {
    return NotificationSettings(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      disabledChannels: disabledChannels ?? this.disabledChannels,
      taskDigestHour: taskDigestHour ?? this.taskDigestHour,
    );
  }

  NotificationSettings withChannel(NotificationChannel channel, bool enabled) {
    final next = Set<NotificationChannel>.from(disabledChannels);
    if (enabled) {
      next.remove(channel);
    } else {
      next.add(channel);
    }
    return copyWith(disabledChannels: next);
  }
}
