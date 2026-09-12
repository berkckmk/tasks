package expo.modules.steadyreminders

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.AlarmManagerCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray
import org.json.JSONObject

internal object ReminderScheduler {
  fun schedule(
    context: Context,
    id: String,
    timestampMs: Long,
    title: String,
    message: String,
    priority: String,
  ): Boolean {
    if (timestampMs <= System.currentTimeMillis()) return false
    val manager = context.getSystemService(AlarmManager::class.java) ?: return false
    val pendingIntent = pendingIntent(context, id, title, message, priority, PendingIntent.FLAG_UPDATE_CURRENT)

    try {
      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager.canScheduleExactAlarms()) {
        AlarmManagerCompat.setExactAndAllowWhileIdle(manager, AlarmManager.RTC_WAKEUP, timestampMs, pendingIntent)
        ReminderScheduleStore.put(context, id, timestampMs, title, message, priority)
        return true
      }
      manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timestampMs, pendingIntent)
      ReminderScheduleStore.put(context, id, timestampMs, title, message, priority)
      return false
    } catch (_: SecurityException) {
      manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timestampMs, pendingIntent)
      ReminderScheduleStore.put(context, id, timestampMs, title, message, priority)
      return false
    }
  }

  fun cancel(context: Context, id: String): Boolean {
    // 1. Stop active foreground alarm service if currently running for this reminder
    try {
      val stopIntent = Intent(context, ImportantAlarmService::class.java).apply {
        action = ImportantAlarmService.ACTION_STOP
        putExtra(ImportantAlarmService.EXTRA_ID, id)
      }
      context.startService(stopIntent)
    } catch (_: Exception) {}

    // 2. Cancel active notification
    try {
      NotificationManagerCompat.from(context).cancel(id.hashCode())
    } catch (_: Exception) {}

    // 3. Cancel scheduled alarm
    ReminderScheduleStore.remove(context, id)
    val manager = context.getSystemService(AlarmManager::class.java) ?: return false
    val existing = PendingIntent.getBroadcast(
      context,
      id.hashCode(),
      Intent(context, ReminderAlarmReceiver::class.java).setAction(ReminderAlarmReceiver.ACTION_ALARM),
      PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
    ) ?: return false
    manager.cancel(existing)
    existing.cancel()
    return true
  }

  fun snooze(context: Context, id: String, minutes: Long = 10L): Long {
    val existing = ReminderScheduleStore.all(context).find { it.id == id }
    val title = existing?.title ?: "Önemli Hatırlatıcı"
    val message = existing?.message.orEmpty()
    val priority = "important"
    val targetTimeMs = System.currentTimeMillis() + minutes * 60 * 1000L

    schedule(context, id, targetTimeMs, title, message, priority)

    try {
      val stopIntent = Intent(context, ImportantAlarmService::class.java).apply {
        action = ImportantAlarmService.ACTION_STOP
        putExtra(ImportantAlarmService.EXTRA_ID, id)
      }
      context.startService(stopIntent)
    } catch (_: Exception) {}

    return targetTimeMs
  }

  fun markFired(context: Context, id: String) = ReminderScheduleStore.remove(context, id)

  fun rescheduleAll(context: Context) {
    val now = System.currentTimeMillis()
    for (item in ReminderScheduleStore.all(context)) {
      if (item.timestampMs <= now) {
        ReminderScheduleStore.remove(context, item.id)
      } else {
        schedule(context, item.id, item.timestampMs, item.title, item.message, item.priority)
      }
    }
  }

  private fun pendingIntent(
    context: Context,
    id: String,
    title: String,
    message: String,
    priority: String,
    creationFlag: Int,
  ) = PendingIntent.getBroadcast(
    context,
    id.hashCode(),
    Intent(context, ReminderAlarmReceiver::class.java).apply {
      action = ReminderAlarmReceiver.ACTION_ALARM
      putExtra(ReminderAlarmReceiver.EXTRA_ID, id)
      putExtra(ReminderAlarmReceiver.EXTRA_TITLE, title)
      putExtra(ReminderAlarmReceiver.EXTRA_MESSAGE, message)
      putExtra(ReminderAlarmReceiver.EXTRA_PRIORITY, priority)
    },
    creationFlag or PendingIntent.FLAG_IMMUTABLE,
  )
}

private data class StoredReminder(val id: String, val timestampMs: Long, val title: String, val message: String, val priority: String)

private object ReminderScheduleStore {
  private const val PREFS = "steady_reminder_schedules"
  private const val KEY = "items"
  fun put(context: Context, id: String, timestampMs: Long, title: String, message: String, priority: String) {
    val items = all(context).filterNot { it.id == id } + StoredReminder(id, timestampMs, title, message, priority)
    write(context, items)
  }
  fun remove(context: Context, id: String) = write(context, all(context).filterNot { it.id == id })
  fun all(context: Context): List<StoredReminder> = try {
    val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]") ?: "[]"
    val array = JSONArray(raw)
    (0 until array.length()).map { index ->
      val value = array.getJSONObject(index)
      StoredReminder(value.getString("id"), value.getLong("timestampMs"), value.getString("title"), value.optString("message"), value.getString("priority"))
    }
  } catch (_: Exception) { emptyList() }
  private fun write(context: Context, items: List<StoredReminder>) {
    val array = JSONArray()
    items.forEach { item -> array.put(JSONObject().put("id", item.id).put("timestampMs", item.timestampMs).put("title", item.title).put("message", item.message).put("priority", item.priority)) }
    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, array.toString()).apply()
  }
}
