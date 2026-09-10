package com.steadyprogress.steady_progress.reminders

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build

object NotificationChannels {
    const val CHANNEL_IMPORTANT = "channel_important"
    const val CHANNEL_NORMAL = "channel_normal"
    const val CHANNEL_LOW = "channel_low"

    fun ensureCreated(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return

        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        // 1. Önemli (Dürtücü / Heads-up, Saat & Kulaklık uyarısı, İlaçlar)
        val importantChannel = NotificationChannel(
            CHANNEL_IMPORTANT,
            "Önemli Hatırlatıcılar & İlaçlar",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Ekrana fırlayan, güçlü titreşimli ve saat/kulaklıkta çalan kritik bildirimler."
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 350, 150, 350)
            setSound(soundUri, audioAttributes)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(true)
        }

        // 1b. Önemli Alarm Kanalı (channel_important_alarm_v1)
        val importantAlarmChannel = NotificationChannel(
            CHANNEL_IMPORTANT_ALARM_V1,
            "Önemli Hatırlatıcılar & İlaçlar (Alarm)",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Sessiz modda da alarm ses akışını kullanan önemli hatırlatıcılar."
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 350, 150, 350)
            val alarmSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val alarmAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            setSound(alarmSound, alarmAttributes)
            setBypassDnd(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(true)
        }

        // 2. Normal (Standart bildirimler)
        val normalChannel = NotificationChannel(
            CHANNEL_NORMAL,
            "Standart Hatırlatıcılar",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Klasik ses ve titreşimli standart bildirimler."
            enableVibration(true)
            setSound(soundUri, audioAttributes)
            setShowBadge(true)
        }

        // 3. Düşük (Sessiz bildirimler)
        val lowChannel = NotificationChannel(
            CHANNEL_LOW,
            "Sessiz Bildirimler",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Ses ve titreşim olmadan sessizce gelen özet bildirimler."
            enableVibration(false)
            setSound(null, null)
            setShowBadge(false)
        }

        manager.createNotificationChannels(listOf(importantChannel, importantAlarmChannel, normalChannel, lowChannel))
    }

    const val CHANNEL_IMPORTANT_ALARM_V1 = "channel_important_alarm_v1"
}
