package com.steadyprogress.steady_progress.widget

import android.content.Context
import android.util.Log
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import expo.modules.steadywidget.WidgetMidnightScheduler
import expo.modules.steadywidget.WidgetRenderer
import expo.modules.steadywidget.WidgetStore
import java.util.concurrent.TimeUnit

/**
 * Periodic WorkManager worker ensuring the widget stays fresh across day boundaries,
 * device idle periods, and app process termination.
 */
class WidgetSyncWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    override fun doWork(): Result {
        Log.d(TAG, "WidgetSyncWorker running periodic check at ${System.currentTimeMillis()}")
        val rolled = WidgetStore.rolloverDayIfNeeded(applicationContext)
        WidgetRenderer.renderAll(applicationContext)
        WidgetMidnightScheduler.scheduleNextMidnight(applicationContext)
        Log.d(TAG, "WidgetSyncWorker completed: rollover=$rolled")
        return Result.success()
    }

    companion object {
        private const val TAG = "SteadyWidgetWorker"
        const val UNIQUE_WORK_NAME = "steady_widget_periodic_sync"

        fun enqueue(context: Context) {
            val request = PeriodicWorkRequestBuilder<WidgetSyncWorker>(1, TimeUnit.HOURS)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                UNIQUE_WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
            Log.d(TAG, "WidgetSyncWorker periodic work enqueued with policy KEEP")
        }
    }
}
