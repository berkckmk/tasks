package expo.modules.steadyreminders

import androidx.core.app.NotificationCompat
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class ReminderNotificationPolicyTest {
  @Test
  fun `normal reminders can mirror to smart watches`() {
    val policy = ReminderNotificationPolicies.forPriority("normal")

    assertMirrorsToSmartWatch(policy)
    assertEquals(ReminderChannels.NORMAL, policy.channelId)
    assertEquals(NotificationCompat.PRIORITY_DEFAULT, policy.priority)
    assertEquals(NotificationCompat.CATEGORY_REMINDER, policy.category)
    assertFalse(policy.silent)
  }

  @Test
  fun `low priority reminders stay silent but can mirror to smart watches`() {
    val policy = ReminderNotificationPolicies.forPriority("low")

    assertMirrorsToSmartWatch(policy)
    assertEquals(ReminderChannels.LOW, policy.channelId)
    assertEquals(NotificationCompat.PRIORITY_LOW, policy.priority)
    assertEquals(NotificationCompat.CATEGORY_REMINDER, policy.category)
    assertEquals(true, policy.silent)
  }

  @Test
  fun `important alarms can mirror to smart watches`() {
    val policy = ReminderNotificationPolicies.forPriority("important")

    assertMirrorsToSmartWatch(policy)
    assertEquals(ReminderChannels.IMPORTANT_REMINDER_ALARMS, policy.channelId)
    assertEquals(NotificationCompat.PRIORITY_MAX, policy.priority)
    assertEquals(NotificationCompat.CATEGORY_ALARM, policy.category)
    assertFalse(policy.silent)
  }

  private fun assertMirrorsToSmartWatch(policy: ReminderNotificationPolicy) {
    assertFalse("Notifications must not be phone-only; Wear OS mirrors non-local notifications.", policy.localOnly)
    assertEquals(NotificationCompat.VISIBILITY_PUBLIC, policy.visibility)
  }
}
