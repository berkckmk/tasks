package expo.modules.steadyreminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

internal class ReminderRescheduleReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action in supportedActions) ReminderScheduler.rescheduleAll(context.applicationContext)
  }

  companion object {
    private val supportedActions = setOf(
      Intent.ACTION_BOOT_COMPLETED,
      Intent.ACTION_MY_PACKAGE_REPLACED,
      Intent.ACTION_TIME_CHANGED,
      Intent.ACTION_TIMEZONE_CHANGED,
    )
  }
}
