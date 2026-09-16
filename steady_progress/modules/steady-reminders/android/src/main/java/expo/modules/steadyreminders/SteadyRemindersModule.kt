package expo.modules.steadyreminders

import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class SteadyRemindersModule : Module() {
  private fun context() = requireNotNull(appContext.reactContext) {
    "Steady Reminders requires an active Android application context"
  }.applicationContext

  fun sendAlarmActionEvent(payload: Map<String, Any?>) {
    try {
      sendEvent("onAlarmAction", payload)
    } catch (_: Exception) {}
  }

  fun sendAlarmTriggeredEvent(payload: Map<String, Any?>) {
    try {
      sendEvent("onAlarmTriggered", payload)
    } catch (_: Exception) {}
  }

  override fun definition() = ModuleDefinition {
    Name("SteadyReminders")

    Events("onAlarmAction", "onAlarmTriggered")

    OnCreate {
      SteadyRemindersEvents.activeModule = this@SteadyRemindersModule
    }

    OnDestroy {
      if (SteadyRemindersEvents.activeModule == this@SteadyRemindersModule) {
        SteadyRemindersEvents.activeModule = null
      }
    }

    AsyncFunction("ensureChannels") {
      ReminderChannels.ensureCreated(context())
      ReminderScheduler.rescheduleAll(context())
      true
    }

    AsyncFunction("schedule") {
      id: String,
      timestampMs: Double,
      title: String,
      message: String,
      priority: String ->
      require(priority in setOf("low", "normal", "important")) { "Unknown reminder priority" }
      ReminderChannels.ensureCreated(context())
      ReminderScheduler.schedule(context(), id, timestampMs.toLong(), title, message, priority)
    }

    AsyncFunction("cancel") { id: String ->
      ReminderScheduler.cancel(context(), id)
    }

    AsyncFunction("snooze") { id: String, minutes: Double?, baseTimeMs: Double? ->
      val mins = minutes?.toLong() ?: 10L
      val base = baseTimeMs?.toLong()
      val newTimeMs = ReminderScheduler.snooze(context(), id, mins, base)
      mapOf(
        "id" to id,
        "snoozedUntilMs" to newTimeMs,
      )
    }

    AsyncFunction("complete") { id: String ->
      ReminderScheduler.cancel(context(), id)
      true
    }

    AsyncFunction("stopActiveAlarm") { id: String? ->
      val targetId = id.orEmpty()
      val stopIntent = Intent(context(), ImportantAlarmService::class.java).apply {
        action = ImportantAlarmService.ACTION_STOP
        putExtra(ImportantAlarmService.EXTRA_ID, targetId)
      }
      context().startService(stopIntent)
      true
    }

    AsyncFunction("importantChannelStatus") {
      val manager = context().getSystemService(NotificationManager::class.java)
      val channel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        manager?.getNotificationChannel(ReminderChannels.IMPORTANT_REMINDER_ALARMS)
          ?: manager?.getNotificationChannel(ReminderChannels.IMPORTANT_ALARM)
      } else null
      mapOf(
        "channelId" to (channel?.id ?: ReminderChannels.IMPORTANT_REMINDER_ALARMS),
        "created" to (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || channel != null),
        "importance" to channel?.importance,
        "sound" to channel?.sound?.toString(),
        "audioUsage" to channel?.audioAttributes?.usage,
      )
    }

    AsyncFunction("getPermissionStatus") {
      val notifications = NotificationManagerCompat.from(context()).areNotificationsEnabled()
      val exactAlarm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        context().getSystemService(AlarmManager::class.java)?.canScheduleExactAlarms() == true
      } else {
        true
      }
      val fullScreenAlarm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
        context().getSystemService(NotificationManager::class.java)?.canUseFullScreenIntent() == true
      } else {
        true
      }
      val notificationManager = context().getSystemService(NotificationManager::class.java)
      val dndAccess = Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
        notificationManager?.isNotificationPolicyAccessGranted == true
      val audioManager = context().getSystemService(Context.AUDIO_SERVICE) as? AudioManager
      val alarmVolume = (audioManager?.getStreamVolume(AudioManager.STREAM_ALARM) ?: 1) > 0
      val powerManager = context().getSystemService(PowerManager::class.java)
      val batteryOptimizationIgnored = powerManager?.isIgnoringBatteryOptimizations(context().packageName) == true

      mapOf(
        "notifications" to notifications,
        "exactAlarm" to exactAlarm,
        "fullScreenAlarm" to fullScreenAlarm,
        "dndAccess" to dndAccess,
        "alarmVolume" to alarmVolume,
        "batteryOptimizationIgnored" to batteryOptimizationIgnored,
      )
    }

    AsyncFunction("getCapabilities") {
      val notifications = NotificationManagerCompat.from(context()).areNotificationsEnabled()
      val exactAlarm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        context().getSystemService(AlarmManager::class.java)?.canScheduleExactAlarms() == true
      } else {
        true
      }
      val fullScreenAlarm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
        context().getSystemService(NotificationManager::class.java)?.canUseFullScreenIntent() == true
      } else {
        true
      }

      mapOf(
        "notifications" to notifications,
        "exactAlarm" to exactAlarm,
        "fullScreenAlarm" to fullScreenAlarm,
        "canOpenExactAlarmSettings" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S),
        "canOpenFullScreenSettings" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE),
        "canOpenNotificationSettings" to true,
        "canOpenBatterySettings" to true,
      )
    }

    AsyncFunction("canScheduleExactAlarms") {
      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) true
      else context().getSystemService(AlarmManager::class.java)?.canScheduleExactAlarms() == true
    }

    AsyncFunction("openExactAlarmSettings") {
      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return@AsyncFunction true
      context().startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
        data = Uri.parse("package:${context().packageName}")
        flags = Intent.FLAG_ACTIVITY_NEW_TASK
      })
      true
    }

    AsyncFunction("openFullScreenAlarmSettings") {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
        context().startActivity(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
          data = Uri.parse("package:${context().packageName}")
          flags = Intent.FLAG_ACTIVITY_NEW_TASK
        })
        true
      } else {
        true
      }
    }

    AsyncFunction("openNotificationSettings") {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        context().startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
          putExtra(Settings.EXTRA_APP_PACKAGE, context().packageName)
          flags = Intent.FLAG_ACTIVITY_NEW_TASK
        })
      } else {
        context().startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
          data = Uri.parse("package:${context().packageName}")
          flags = Intent.FLAG_ACTIVITY_NEW_TASK
        })
      }
      true
    }

    AsyncFunction("openDndSettings") {
      context().startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK
      })
      true
    }

    AsyncFunction("openBatterySettings") {
      context().startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK
      })
      true
    }

    AsyncFunction("getPendingActions") {
      PendingAlarmActionStore.all(context()).map {
        mapOf(
          "action" to it.action,
          "reminderId" to it.reminderId,
          "timestampMs" to it.timestampMs,
          "snoozedUntilMs" to it.snoozedUntilMs,
        )
      }
    }

    AsyncFunction("clearPendingActions") {
      PendingAlarmActionStore.clear(context())
      true
    }

    AsyncFunction("removePendingAction") { reminderId: String ->
      PendingAlarmActionStore.remove(context(), reminderId)
      true
    }
  }
}
