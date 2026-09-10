package com.steadyprogress.steady_progress.reminders

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.steadyprogress.steady_progress.MainActivity
import com.steadyprogress.steady_progress.R

class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.i(TAG, "onReceive triggered with action: $action")

        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON"
        ) {
            NotificationChannels.ensureCreated(context)
            AlarmScheduler.rescheduleAll(context)
            return
        }

        val id = intent.getStringExtra(EXTRA_ID) ?: return
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "Hatırlatıcı"
        val message = intent.getStringExtra(EXTRA_MESSAGE) ?: ""
        val priority = intent.getStringExtra(EXTRA_PRIORITY) ?: "normal"

        Log.i(TAG, "Triggering alarm notification for id=$id, title=$title, priority=$priority")

        NotificationChannels.ensureCreated(context)

        val clickIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("reminder_id", id)
        }
        val clickPendingIntent = PendingIntent.getActivity(
            context,
            id.hashCode(),
            clickIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val channelId = when (priority) {
            "important" -> NotificationChannels.CHANNEL_IMPORTANT_ALARM_V1
            "low" -> NotificationChannels.CHANNEL_LOW
            else -> NotificationChannels.CHANNEL_NORMAL
        }

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(message)
            .setContentIntent(clickPendingIntent)
            .setAutoCancel(true)

        when (priority) {
            "important" -> {
                builder.setPriority(NotificationCompat.PRIORITY_MAX)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setVibrate(longArrayOf(0, 350, 150, 350))
                    // Heads-up banner pops up on screen and rings watch/headphones
                    .setFullScreenIntent(clickPendingIntent, true)
            }
            "low" -> {
                builder.setPriority(NotificationCompat.PRIORITY_LOW)
                    .setVibrate(longArrayOf(0))
            }
            else -> {
                builder.setPriority(NotificationCompat.PRIORITY_DEFAULT)
                    .setCategory(NotificationCompat.CATEGORY_REMINDER)
            }
        }

        try {
            val notificationManager = NotificationManagerCompat.from(context)
            notificationManager.notify(id.hashCode(), builder.build())
            AlarmScheduler.markFired(context, id)
        } catch (e: SecurityException) {
            Log.w(TAG, "Cannot show notification, POST_NOTIFICATIONS permission not granted: $e")
        }
    }

    companion object {
        const val TAG = "AlarmReceiver"
        const val ACTION_ALARM = "com.steadyprogress.ACTION_ALARM"
        const val EXTRA_ID = "extra_id"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_MESSAGE = "extra_message"
        const val EXTRA_PRIORITY = "extra_priority"
    }
}

