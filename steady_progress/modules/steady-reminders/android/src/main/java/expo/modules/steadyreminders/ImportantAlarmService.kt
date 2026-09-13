package expo.modules.steadyreminders

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class ImportantAlarmService : Service() {
  private var mediaPlayer: MediaPlayer? = null
  private var vibrator: Vibrator? = null
  private var wakeLock: PowerManager.WakeLock? = null
  private var currentReminderId: String = ""
  private var currentReminderTimestampMs: Long? = null

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    if (intent == null) return START_NOT_STICKY

    val action = intent.action ?: ACTION_START
    val id = intent.getStringExtra(EXTRA_ID).orEmpty()
    val timestampMs = intent.getLongExtra(EXTRA_TIMESTAMP_MS, 0L)
    val title = intent.getStringExtra(EXTRA_TITLE) ?: "Önemli Hatırlatıcı"
    val message = intent.getStringExtra(EXTRA_MESSAGE).orEmpty()

    when (action) {
      ACTION_START -> {
        if (id.isNotEmpty()) {
          currentReminderId = id
          if (timestampMs > 0L) {
            currentReminderTimestampMs = timestampMs
          }
          acquireWakeLock()
          val notification = buildOngoingNotification(id, title, message)
          startInForeground(notificationIdFor(id), notification)
          startAlarmSound()
          startContinuousVibration()
          SteadyRemindersEvents.sendAlarmTriggered(id, title)
        }
      }
      ACTION_SNOOZE -> {
        val targetId = if (id.isNotEmpty()) id else currentReminderId
        if (targetId.isNotEmpty()) {
          val baseTimeMs = if (currentReminderTimestampMs != null && currentReminderTimestampMs!! > 0L) {
            currentReminderTimestampMs!!
          } else {
            ReminderScheduler.getScheduledTimestamp(applicationContext, targetId) ?: System.currentTimeMillis()
          }
          val snoozedUntilMs = baseTimeMs + 10 * 60 * 1000L
          ReminderScheduler.snooze(applicationContext, targetId, 10L, baseTimeMs)
          PendingAlarmActionStore.add(applicationContext, "snooze", targetId, System.currentTimeMillis(), snoozedUntilMs)
          SteadyRemindersEvents.sendAlarmAction("snooze", targetId, snoozedUntilMs)
        }
        stopForegroundService()
      }
      ACTION_COMPLETE -> {
        val targetId = if (id.isNotEmpty()) id else currentReminderId
        if (targetId.isNotEmpty()) {
          ReminderScheduler.cancel(applicationContext, targetId)
          PendingAlarmActionStore.add(applicationContext, "complete", targetId, System.currentTimeMillis())
          SteadyRemindersEvents.sendAlarmAction("complete", targetId)
        }
        stopForegroundService()
      }
      ACTION_STOP -> {
        stopForegroundService()
      }
    }

    return START_NOT_STICKY
  }

  private fun startInForeground(notificationId: Int, notification: Notification) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      startForeground(
        notificationId,
        notification,
        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
      )
    } else {
      startForeground(notificationId, notification)
    }
  }

  private fun buildOngoingNotification(id: String, title: String, message: String): Notification {
    ReminderChannels.ensureCreated(applicationContext)

    val fullScreenIntent = Intent(applicationContext, ImportantAlarmActivity::class.java).apply {
      flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
      putExtra(ImportantAlarmActivity.EXTRA_ID, id)
      putExtra(ImportantAlarmActivity.EXTRA_TITLE, title)
      putExtra(ImportantAlarmActivity.EXTRA_MESSAGE, message)
    }
    val fullScreenPendingIntent = PendingIntent.getActivity(
      applicationContext,
      id.hashCode(),
      fullScreenIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    val snoozeIntent = Intent(applicationContext, ReminderAlarmActionReceiver::class.java).apply {
      action = ReminderAlarmActionReceiver.ACTION_SNOOZE
      putExtra(ReminderAlarmActionReceiver.EXTRA_ID, id)
    }
    val snoozePendingIntent = PendingIntent.getBroadcast(
      applicationContext,
      id.hashCode() + 1,
      snoozeIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    val completeIntent = Intent(applicationContext, ReminderAlarmActionReceiver::class.java).apply {
      action = ReminderAlarmActionReceiver.ACTION_COMPLETE
      putExtra(ReminderAlarmActionReceiver.EXTRA_ID, id)
    }
    val completePendingIntent = PendingIntent.getBroadcast(
      applicationContext,
      id.hashCode() + 2,
      completeIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    val iconRes = applicationContext.resources.getIdentifier("ic_launcher", "mipmap", applicationContext.packageName).let {
      if (it != 0) it else applicationContext.applicationInfo.icon
    }

    return NotificationCompat.Builder(applicationContext, ReminderChannels.IMPORTANT_REMINDER_ALARMS)
      .setSmallIcon(iconRes)
      .setContentTitle(title)
      .setContentText(if (message.isNotBlank()) message else "Önemli hatırlatıcı zamanı geldi")
      .setPriority(NotificationCompat.PRIORITY_MAX)
      .setCategory(NotificationCompat.CATEGORY_ALARM)
      .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
      .setOngoing(true)
      .setAutoCancel(false)
      .setContentIntent(fullScreenPendingIntent)
      .setFullScreenIntent(fullScreenPendingIntent, true)
      .addAction(0, "10 dk Ertele", snoozePendingIntent)
      .addAction(0, "Tamamlandı", completePendingIntent)
      .build()
  }

  private fun startAlarmSound() {
    try {
      mediaPlayer?.release()
      val alertUri: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

      mediaPlayer = MediaPlayer().apply {
        setDataSource(applicationContext, alertUri)
        setAudioAttributes(
          AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        )
        isLooping = true
        setOnPreparedListener { it.start() }
        prepareAsync()
      }
    } catch (e: Exception) {
      android.util.Log.w("ImportantAlarmService", "Failed to start looping alarm media player: $e")
    }
  }

  private fun startContinuousVibration() {
    try {
      vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val manager = getSystemService(VibratorManager::class.java)
        manager?.defaultVibrator
      } else {
        @Suppress("DEPRECATION")
        getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
      }

      val pattern = longArrayOf(0, 800, 400, 800, 400)
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
      } else {
        @Suppress("DEPRECATION")
        vibrator?.vibrate(pattern, 0)
      }
    } catch (e: Exception) {
      android.util.Log.w("ImportantAlarmService", "Failed to start continuous vibration: $e")
    }
  }

  private fun acquireWakeLock() {
    try {
      if (wakeLock == null) {
        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        @Suppress("DEPRECATION")
        wakeLock = powerManager?.newWakeLock(
          PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
          "SteadyProgress:ImportantAlarmService"
        )
      }
      wakeLock?.acquire(60_000)
    } catch (e: Exception) {
      android.util.Log.w("ImportantAlarmService", "Failed to acquire wake lock: $e")
    }
  }

  private fun releaseWakeLock() {
    try {
      if (wakeLock?.isHeld == true) {
        wakeLock?.release()
      }
      wakeLock = null
    } catch (_: Exception) {}
  }

  private fun stopPlaybackAndVibration() {
    try {
      mediaPlayer?.stop()
      mediaPlayer?.release()
      mediaPlayer = null
    } catch (_: Exception) {}

    try {
      vibrator?.cancel()
      vibrator = null
    } catch (_: Exception) {}

    releaseWakeLock()
  }

  private fun stopForegroundService() {
    stopPlaybackAndVibration()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      stopForeground(STOP_FOREGROUND_REMOVE)
    } else {
      @Suppress("DEPRECATION")
      stopForeground(true)
    }
    if (currentReminderId.isNotEmpty()) {
      NotificationManagerCompat.from(applicationContext).cancel(notificationIdFor(currentReminderId))
    }
    stopSelf()
  }

  override fun onDestroy() {
    stopPlaybackAndVibration()
    super.onDestroy()
  }

  companion object {
    const val ACTION_START = "com.steadyprogress.ACTION_START"
    const val ACTION_SNOOZE = "com.steadyprogress.ACTION_SNOOZE"
    const val ACTION_COMPLETE = "com.steadyprogress.ACTION_COMPLETE"
    const val ACTION_STOP = "com.steadyprogress.ACTION_STOP"

    const val EXTRA_ID = "extra_id"
    const val EXTRA_TIMESTAMP_MS = "extra_timestamp_ms"
    const val EXTRA_TITLE = "extra_title"
    const val EXTRA_MESSAGE = "extra_message"

    fun notificationIdFor(id: String) = id.hashCode()
  }
}
