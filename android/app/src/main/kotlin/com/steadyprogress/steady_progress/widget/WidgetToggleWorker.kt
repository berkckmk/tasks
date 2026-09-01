package com.steadyprogress.steady_progress.widget

import android.content.Context
import androidx.work.Data
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters

/**
 * Applies one widget row tick, off the broadcast thread.
 *
 * An `AppWidgetProvider` gets only a few seconds of broadcast time, so
 * `onReceive` must never do the work itself — it enqueues this and returns.
 * That is the rule the handoff calls out as "the one caveat", and it holds
 * even though the work here is small: SharedPreferences I/O plus a launcher
 * IPC is still I/O plus IPC, and a receiver that runs long is killed rather
 * than slowed.
 *
 * What it does:
 *
 *  1. Flips the item in the local snapshot, so the launcher redraws with the
 *     user's tick immediately.
 *  2. Records the intent in [WidgetPendingToggles] for the app to write
 *     through the real repositories — see that file for why the write does
 *     not happen here.
 *  3. Rebuilds every placed widget, because the same item can appear on more
 *     than one of them.
 */
class WidgetToggleWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    override fun doWork(): Result {
        val id = inputData.getString(KEY_ITEM_ID) ?: return Result.success()
        val kind = WidgetItemKind.fromKey(inputData.getString(KEY_ITEM_KIND))

        val newState = WidgetDataStore.toggleLocally(applicationContext, id, kind)
        if (newState == null) {
            // The item is no longer in the snapshot — deleted on another
            // device, or the snapshot was cleared by a sign-out between the
            // tap and this running. Nothing to queue, and nothing is wrong.
            SteadyProgressWidgetProvider.refreshAll(applicationContext)
            return Result.success()
        }

        WidgetPendingToggles.enqueue(
            applicationContext,
            PendingToggle(
                id = id,
                kind = kind,
                done = newState,
                at = System.currentTimeMillis(),
            ),
        )

        SteadyProgressWidgetProvider.refreshAll(applicationContext)
        return Result.success()
    }

    companion object {
        private const val KEY_ITEM_ID = "itemId"
        private const val KEY_ITEM_KIND = "itemKind"

        fun enqueue(context: Context, itemId: String, kind: WidgetItemKind) {
            val request = OneTimeWorkRequestBuilder<WidgetToggleWorker>()
                .setInputData(
                    Data.Builder()
                        .putString(KEY_ITEM_ID, itemId)
                        .putString(KEY_ITEM_KIND, kind.key)
                        .build(),
                )
                .build()

            // Unique per item, KEEP-less: a second tap on the same row while
            // the first is still queued should replace it, not stack a second
            // flip that would toggle it straight back.
            WorkManager.getInstance(context).enqueueUniqueWork(
                "widget-toggle-${kind.key}-$itemId",
                androidx.work.ExistingWorkPolicy.REPLACE,
                request,
            )
        }
    }
}
