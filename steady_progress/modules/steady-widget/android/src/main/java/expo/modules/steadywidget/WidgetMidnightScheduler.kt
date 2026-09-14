package expo.modules.steadywidget

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar

object WidgetMidnightScheduler {
    private const val TAG = "SteadyWidgetMidnight"
    const val ACTION_MIDNIGHT_UPDATE = "expo.modules.steadywidget.ACTION_MIDNIGHT_UPDATE"
    private const val REQUEST_CODE = 42_000

    fun scheduleNextMidnight(context: Context) {
        val manager = context.getSystemService(AlarmManager::class.java) ?: return
        val calendar = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 5)
            set(Calendar.MILLISECOND, 0)
        }
        val triggerAtMs = calendar.timeInMillis

        val intent = Intent(context, WidgetUpdateReceiver::class.java).apply {
            action = ACTION_MIDNIGHT_UPDATE
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val pendingIntent = PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)

        try {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
            Log.d(TAG, "Scheduled next midnight widget update for $triggerAtMs (${calendar.time})")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to schedule midnight alarm: ${e.message}")
        }
    }
}
