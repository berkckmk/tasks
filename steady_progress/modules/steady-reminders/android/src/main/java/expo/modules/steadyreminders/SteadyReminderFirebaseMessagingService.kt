package expo.modules.steadyreminders

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import expo.modules.steadywidget.WidgetItem
import expo.modules.steadywidget.WidgetRenderer
import expo.modules.steadywidget.WidgetStore
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Native counterpart to the FCM data-message handling in
 * src/background-messaging.native.ts. Firebase auto-registers every declared
 * FirebaseMessagingService, so this runs alongside the RN Firebase headless
 * JS handler rather than replacing it — but unlike that handler, it never
 * needs the JS runtime to spin up, so it also runs when the app has never
 * been opened since boot or when the headless JS task gets throttled.
 *
 * Only handles `reminder_schedule_sync` (sent by
 * functions-sync/src/index.ts:syncReminderScheduleToDevices), which carries
 * everything needed (title/message/priority/timestamp) to keep both the
 * native alarm registry and the widget's reminder row in sync without a
 * Firestore round trip.
 */
class SteadyReminderFirebaseMessagingService : FirebaseMessagingService() {

  override fun onMessageReceived(remoteMessage: RemoteMessage) {
    val data = remoteMessage.data
    if (data["type"] != REMINDER_SYNC_TYPE) return
    val id = data["reminderId"]?.takeIf { it.isNotEmpty() } ?: return
    val context = applicationContext
    val operation = data["operation"] ?: "schedule"

    if (operation == "cancel") {
      ReminderScheduler.cancel(context, id)
      removeReminderFromWidget(context, id)
      return
    }

    val timestampMs = data["timestampMs"]?.toLongOrNull()
    if (timestampMs == null || timestampMs <= System.currentTimeMillis()) {
      ReminderScheduler.cancel(context, id)
      removeReminderFromWidget(context, id)
      return
    }

    val title = data["title"]?.takeIf { it.isNotEmpty() } ?: "Hatırlatıcı"
    val message = data["message"].orEmpty()
    val priority = data["priority"]?.takeIf { it == "important" || it == "low" } ?: "normal"

    ReminderChannels.ensureCreated(context)
    ReminderScheduler.schedule(context, id, timestampMs, title, message, priority)
    upsertReminderInWidget(context, id, title, timestampMs)
  }

  private fun upsertReminderInWidget(context: android.content.Context, id: String, title: String, timestampMs: Long) {
    try {
      val now = System.currentTimeMillis()
      // Mirrors the reminder scope rule in src/features/widget/widget-snapshot.ts:
      // shown if due today, or overdue and not completed. A freshly (re)scheduled
      // reminder is by definition not completed, so only the "due today" half applies.
      if (!isSameLocalDay(timestampMs, now)) {
        removeReminderFromWidget(context, id)
        return
      }
      val time = istanbulTimeFormat().format(Date(timestampMs))
      val current = WidgetStore.getSnapshot(context)
      val updatedItems = current.items.filterNot { it.id == id } +
        WidgetItem(id = id, type = "reminder", title = title, time = time, completed = false)
      val updated = current.copy(
        items = updatedItems,
        total = updatedItems.size,
        completed = updatedItems.count { it.completed },
        hasData = true,
      )
      WidgetStore.replaceSnapshot(context, updated)
      WidgetRenderer.renderAll(context)
    } catch (_: Exception) {
      // Widget refresh is best-effort; the native alarm above already landed.
    }
  }

  private fun removeReminderFromWidget(context: android.content.Context, id: String) {
    try {
      val current = WidgetStore.getSnapshot(context)
      if (current.items.none { it.id == id }) return
      val updatedItems = current.items.filterNot { it.id == id }
      val updated = current.copy(
        items = updatedItems,
        total = updatedItems.size,
        completed = updatedItems.count { it.completed },
      )
      WidgetStore.replaceSnapshot(context, updated)
      WidgetRenderer.renderAll(context)
    } catch (_: Exception) {
      // Best-effort.
    }
  }

  private fun isSameLocalDay(aMs: Long, bMs: Long): Boolean {
    val a = Calendar.getInstance().apply { timeInMillis = aMs }
    val b = Calendar.getInstance().apply { timeInMillis = bMs }
    return a.get(Calendar.YEAR) == b.get(Calendar.YEAR) && a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)
  }

  private fun istanbulTimeFormat(): SimpleDateFormat =
    SimpleDateFormat("HH:mm", Locale("tr", "TR")).apply {
      timeZone = TimeZone.getTimeZone("Europe/Istanbul")
    }

  companion object {
    private const val REMINDER_SYNC_TYPE = "reminder_schedule_sync"
  }
}
