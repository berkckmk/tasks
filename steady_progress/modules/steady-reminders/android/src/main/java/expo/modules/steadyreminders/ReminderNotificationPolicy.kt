package expo.modules.steadyreminders

import androidx.core.app.NotificationCompat

internal data class ReminderNotificationPolicy(
  val channelId: String,
  val priority: Int,
  val category: String,
  val visibility: Int,
  val localOnly: Boolean,
  val silent: Boolean,
)

internal object ReminderNotificationPolicies {
  fun forPriority(priority: String): ReminderNotificationPolicy = when (priority) {
    "important" -> ReminderNotificationPolicy(
      channelId = ReminderChannels.IMPORTANT_REMINDER_ALARMS,
      priority = NotificationCompat.PRIORITY_MAX,
      category = NotificationCompat.CATEGORY_ALARM,
      visibility = NotificationCompat.VISIBILITY_PUBLIC,
      localOnly = false,
      silent = false,
    )
    "low" -> ReminderNotificationPolicy(
      channelId = ReminderChannels.LOW,
      priority = NotificationCompat.PRIORITY_LOW,
      category = NotificationCompat.CATEGORY_REMINDER,
      visibility = NotificationCompat.VISIBILITY_PUBLIC,
      localOnly = false,
      silent = true,
    )
    else -> ReminderNotificationPolicy(
      channelId = ReminderChannels.NORMAL,
      priority = NotificationCompat.PRIORITY_DEFAULT,
      category = NotificationCompat.CATEGORY_REMINDER,
      visibility = NotificationCompat.VISIBILITY_PUBLIC,
      localOnly = false,
      silent = false,
    )
  }

  fun applyTo(builder: NotificationCompat.Builder, policy: ReminderNotificationPolicy): NotificationCompat.Builder =
    builder
      .setPriority(policy.priority)
      .setCategory(policy.category)
      .setVisibility(policy.visibility)
      .setLocalOnly(policy.localOnly)
      .setSilent(policy.silent)
}
