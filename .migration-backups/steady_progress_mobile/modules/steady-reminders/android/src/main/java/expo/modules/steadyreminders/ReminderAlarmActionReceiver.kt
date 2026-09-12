package expo.modules.steadyreminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ReminderAlarmActionReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val id = intent.getStringExtra(EXTRA_ID) ?: return

    when (intent.action) {
      ACTION_SNOOZE -> {
        val serviceIntent = Intent(context, ImportantAlarmService::class.java).apply {
          action = ImportantAlarmService.ACTION_SNOOZE
          putExtra(ImportantAlarmService.EXTRA_ID, id)
        }
        context.startService(serviceIntent)
      }
      ACTION_COMPLETE -> {
        val serviceIntent = Intent(context, ImportantAlarmService::class.java).apply {
          action = ImportantAlarmService.ACTION_COMPLETE
          putExtra(ImportantAlarmService.EXTRA_ID, id)
        }
        context.startService(serviceIntent)
      }
    }
  }

  companion object {
    const val ACTION_SNOOZE = "com.steadyprogress.ACTION_SNOOZE"
    const val ACTION_COMPLETE = "com.steadyprogress.ACTION_COMPLETE"
    const val EXTRA_ID = "extra_id"
  }
}
