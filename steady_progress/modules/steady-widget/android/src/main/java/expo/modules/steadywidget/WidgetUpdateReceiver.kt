package expo.modules.steadywidget

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class WidgetUpdateReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        Log.d(TAG, "WidgetUpdateReceiver received action: $action at ${System.currentTimeMillis()}")

        when (action) {
            WidgetMidnightScheduler.ACTION_MIDNIGHT_UPDATE,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                val rolled = WidgetStore.rolloverDayIfNeeded(context)
                WidgetRenderer.renderAll(context)
                WidgetMidnightScheduler.scheduleNextMidnight(context)
                Log.d(TAG, "WidgetUpdateReceiver: rollover=$rolled, renderAll completed, rescheduled midnight alarm")
            }
            else -> {
                WidgetRenderer.renderAll(context)
            }
        }
    }

    companion object {
        private const val TAG = "SteadyWidgetReceiver"
    }
}
