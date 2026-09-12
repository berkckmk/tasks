package expo.modules.steadyreminders

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build

internal object ReminderChannels {
  const val IMPORTANT_REMINDER_ALARMS = "IMPORTANT_REMINDER_ALARMS"
  const val IMPORTANT_ALARM = "channel_important_alarm_v2"
  const val NORMAL = "channel_normal"
  const val LOW = "channel_low"

  fun ensureCreated(context: Context) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    val manager = context.getSystemService(NotificationManager::class.java) ?: return
    val alarmSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
      ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
    val defaultNotificationSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

    val alarmAttributes = AudioAttributes.Builder()
      .setUsage(AudioAttributes.USAGE_ALARM)
      .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
      .build()
    val notificationAttributes = AudioAttributes.Builder()
      .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
      .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
      .build()

    val important = NotificationChannel(
      IMPORTANT_REMINDER_ALARMS,
      "Önemli Hatırlatıcılar (Alarm)",
      NotificationManager.IMPORTANCE_HIGH,
    ).apply {
      description = "Sessiz modda da alarm ses akışını kullanan önemli hatırlatıcılar."
      enableVibration(true)
      vibrationPattern = longArrayOf(0, 500, 250, 500)
      setSound(alarmSound, alarmAttributes)
      setBypassDnd(true)
      lockscreenVisibility = Notification.VISIBILITY_PUBLIC
      setShowBadge(true)
    }

    val legacyImportant = NotificationChannel(
      IMPORTANT_ALARM,
      "Önemli Hatırlatıcılar (Eski Kanal)",
      NotificationManager.IMPORTANCE_HIGH,
    ).apply {
      description = "Geriye dönük uyumluluk için korunan alarm kanalı."
      enableVibration(true)
      vibrationPattern = longArrayOf(0, 400, 200, 400)
      setSound(alarmSound, alarmAttributes)
      setBypassDnd(true)
      lockscreenVisibility = Notification.VISIBILITY_PUBLIC
      setShowBadge(true)
    }

    val normal = NotificationChannel(
      NORMAL,
      "Standart Hatırlatıcılar",
      NotificationManager.IMPORTANCE_DEFAULT,
    ).apply {
      description = "Telefonun bildirim sesini ve standart titreşimi kullanan hatırlatıcılar."
      enableVibration(true)
      setSound(defaultNotificationSound, notificationAttributes)
      setShowBadge(true)
    }

    val low = NotificationChannel(
      LOW,
      "Sessiz Bildirimler",
      NotificationManager.IMPORTANCE_LOW,
    ).apply {
      description = "Ses ve titreşim olmadan bildirim panosunda görünen hatırlatıcılar."
      enableVibration(false)
      setSound(null, null)
      setShowBadge(false)
    }

    manager.createNotificationChannels(listOf(important, legacyImportant, normal, low))
  }

  fun idFor(priority: String) = when (priority) {
    "important" -> IMPORTANT_REMINDER_ALARMS
    "low" -> LOW
    else -> NORMAL
  }
}
