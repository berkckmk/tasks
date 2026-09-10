package com.steadyprogress.steady_progress.reminders

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.AlarmManagerCompat
import org.json.JSONArray
import org.json.JSONObject

object AlarmScheduler {
    private const val TAG = "AlarmScheduler"

    fun schedule(
        context: Context,
        id: String,
        timestampMs: Long,
        title: String,
        message: String,
        priority: String,
    ) {
        if (timestampMs <= System.currentTimeMillis()) return
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_ALARM
            putExtra(AlarmReceiver.EXTRA_ID, id)
            putExtra(AlarmReceiver.EXTRA_TITLE, title)
            putExtra(AlarmReceiver.EXTRA_MESSAGE, message)
            putExtra(AlarmReceiver.EXTRA_PRIORITY, priority)
        }

        val requestCode = id.hashCode()
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    AlarmManagerCompat.setExactAndAllowWhileIdle(
                        alarmManager,
                        AlarmManager.RTC_WAKEUP,
                        timestampMs,
                        pendingIntent,
                    )
                } else {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        timestampMs,
                        pendingIntent,
                    )
                }
            } else {
                AlarmManagerCompat.setExactAndAllowWhileIdle(
                    alarmManager,
                    AlarmManager.RTC_WAKEUP,
                    timestampMs,
                    pendingIntent,
                )
            }
            AlarmStore.put(context, id, timestampMs, title, message, priority)
            Log.i(TAG, "Scheduled alarm for id=$id at $timestampMs")
        } catch (e: SecurityException) {
            Log.w(TAG, "SecurityException on exact alarm, falling back: $e")
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                timestampMs,
                pendingIntent,
            )
            AlarmStore.put(context, id, timestampMs, title, message, priority)
        }
    }

    fun cancel(context: Context, id: String) {
        AlarmStore.remove(context, id)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_ALARM
        }
        val requestCode = id.hashCode()
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: return

        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
        Log.i(TAG, "Cancelled alarm for id=$id")
    }

    fun markFired(context: Context, id: String) {
        AlarmStore.remove(context, id)
    }

    fun rescheduleAll(context: Context) {
        val now = System.currentTimeMillis()
        val stored = AlarmStore.all(context)
        Log.i(TAG, "Rescheduling ${stored.size} stored alarms after reboot/update")
        for (item in stored) {
            if (item.timestampMs <= now) {
                AlarmStore.remove(context, item.id)
            } else {
                schedule(context, item.id, item.timestampMs, item.title, item.message, item.priority)
            }
        }
    }
}

internal data class StoredAlarm(
    val id: String,
    val timestampMs: Long,
    val title: String,
    val message: String,
    val priority: String,
)

internal object AlarmStore {
    private const val PREFS = "steady_progress_alarms"
    private const val KEY_ITEMS = "scheduled_items"

    fun put(
        context: Context,
        id: String,
        timestampMs: Long,
        title: String,
        message: String,
        priority: String,
    ) {
        val current = all(context).filterNot { it.id == id } + StoredAlarm(
            id,
            timestampMs,
            title,
            message,
            priority,
        )
        write(context, current)
    }

    fun remove(context: Context, id: String) {
        val filtered = all(context).filterNot { it.id == id }
        write(context, filtered)
    }

    fun all(context: Context): List<StoredAlarm> {
        return try {
            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_ITEMS, "[]") ?: "[]"
            val array = JSONArray(raw)
            (0 until array.length()).map { idx ->
                val obj = array.getJSONObject(idx)
                StoredAlarm(
                    obj.getString("id"),
                    obj.getLong("timestampMs"),
                    obj.getString("title"),
                    obj.optString("message", ""),
                    obj.optString("priority", "normal"),
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun write(context: Context, items: List<StoredAlarm>) {
        val array = JSONArray()
        items.forEach { item ->
            array.put(
                JSONObject().apply {
                    put("id", item.id)
                    put("timestampMs", item.timestampMs)
                    put("title", item.title)
                    put("message", item.message)
                    put("priority", item.priority)
                }
            )
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ITEMS, array.toString())
            .apply()
    }
}

