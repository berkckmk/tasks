package expo.modules.steadyreminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

internal class ReminderRescheduleReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action in supportedActions) {
      val appContext = context.applicationContext
      ReminderScheduler.rescheduleAll(appContext)
      // Safety net: re-queue any "complete" action still sitting in the
      // durable local store in case its WorkManager job never ran (e.g. boot
      // happened before WorkManager's own DB was restored).
      ReminderCompletionWorker.enqueuePendingFromStore(appContext)
    }
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
