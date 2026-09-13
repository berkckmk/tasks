package expo.modules.steadyreminders

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

internal class ReminderAlarmReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val id = intent.getStringExtra(EXTRA_ID) ?: return
    val timestampMs = intent.getLongExtra(EXTRA_TIMESTAMP_MS, 0L)
    val title = intent.getStringExtra(EXTRA_TITLE) ?: "Hatırlatıcı"
    val message = intent.getStringExtra(EXTRA_MESSAGE).orEmpty()
    val priority = intent.getStringExtra(EXTRA_PRIORITY) ?: "normal"
    android.util.Log.i("ReminderAlarmReceiver", "Triggering alarm notification for id=$id, title=$title, priority=$priority")
    ReminderScheduler.markFired(context, id)

    if (priority == "important") {
      // 1. Acquire temporary screen wake lock to ensure the screen turns on
      try {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        @Suppress("DEPRECATION")
        val wakeLock = powerManager?.newWakeLock(
          PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
          "SteadyProgress:ImportantAlarmReceiver"
        )
        wakeLock?.acquire(3000)
      } catch (e: Exception) {
        android.util.Log.w("ReminderAlarmReceiver", "Failed to acquire wake lock: $e")
      }

      // 2. Start ongoing ImportantAlarmService (Foreground Service)
      val serviceIntent = Intent(context, ImportantAlarmService::class.java).apply {
        action = ImportantAlarmService.ACTION_START
        putExtra(ImportantAlarmService.EXTRA_ID, id)
        putExtra(ImportantAlarmService.EXTRA_TIMESTAMP_MS, timestampMs)
        putExtra(ImportantAlarmService.EXTRA_TITLE, title)
        putExtra(ImportantAlarmService.EXTRA_MESSAGE, message)
      }

      try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
          context.startForegroundService(serviceIntent)
        } else {
          context.startService(serviceIntent)
        }
      } catch (e: Exception) {
        android.util.Log.e("ReminderAlarmReceiver", "Failed to start ImportantAlarmService: $e")
      }
      return
    }

    // Normal and Low Priority Reminders — Preserved original notification behavior
    ReminderChannels.ensureCreated(context)
    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
      ?.apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        putExtra(EXTRA_ROUTE_REMINDER_ID, id)
      }
    val contentIntent = launchIntent?.let {
      PendingIntent.getActivity(
        context,
        id.hashCode(),
        it,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
      )
    }

    val iconRes = context.resources.getIdentifier("ic_launcher", "mipmap", context.packageName).let {
      if (it != 0) it else context.applicationInfo.icon
    }

    val builder = NotificationCompat.Builder(context, ReminderChannels.idFor(priority))
      .setSmallIcon(iconRes)
      .setContentTitle(title)
      .setContentText(message)
      .setAutoCancel(true)
      .setContentIntent(contentIntent)

    if (priority == "low") {
      builder
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .setSilent(true)
    } else {
      builder
        .setPriority(NotificationCompat.PRIORITY_DEFAULT)
        .setCategory(NotificationCompat.CATEGORY_REMINDER)
    }

    try {
      NotificationManagerCompat.from(context).notify(id.hashCode(), builder.build())
      android.util.Log.i("ReminderAlarmReceiver", "Notification posted successfully for normal reminder id=$id")
    } catch (e: SecurityException) {
      android.util.Log.w("ReminderAlarmReceiver", "Failed to post notification: $e")
    }
  }

  companion object {
    const val ACTION_ALARM = "com.steadyprogress.ACTION_ALARM"
    const val EXTRA_ID = "extra_id"
    const val EXTRA_TIMESTAMP_MS = "extra_timestamp_ms"
    const val EXTRA_TITLE = "extra_title"
    const val EXTRA_MESSAGE = "extra_message"
    const val EXTRA_PRIORITY = "extra_priority"
    const val EXTRA_ROUTE_REMINDER_ID = "reminder_id"
  }
}
