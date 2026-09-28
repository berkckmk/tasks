package expo.modules.steadyreminders

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkRequest
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.google.android.gms.tasks.Tasks
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import expo.modules.steadywidget.WidgetRenderer
import expo.modules.steadywidget.WidgetStore
import java.util.Date
import java.util.concurrent.TimeUnit

/**
 * Durable, idempotent completion of an "important" reminder alarm.
 *
 * Runs as a WorkManager job so the "Tamamla" action from the alarm/notification
 * keeps working when the app process is not running: it never depends on the
 * React Native JS runtime or on the app being reopened. It writes the same
 * Firestore contract as ReminderRepository.setDone() in
 * src/features/reminders/reminder-repository.ts (status/lastCompletedAt/dueAt
 * advance for repeating reminders), so the two paths never disagree.
 */
internal class ReminderCompletionWorker(appContext: Context, params: WorkerParameters) : Worker(appContext, params) {

  override fun doWork(): Result {
    val reminderId = inputData.getString(KEY_REMINDER_ID) ?: return Result.failure()
    val occurrenceMs = inputData.getLong(KEY_OCCURRENCE_MS, 0L)
    val context = applicationContext
    android.util.Log.i(TAG, "doWork start id=$reminderId occurrenceMs=$occurrenceMs attempt=$runAttemptCount")

    val uid = FirebaseAuth.getInstance().currentUser?.uid
    if (uid == null) {
      // No native Firebase Auth session yet (cold boot before auth restore, or
      // signed out). Keep the entry in the durable local queue and retry later
      // rather than lose the completion.
      android.util.Log.i(TAG, "No native FirebaseAuth session for id=$reminderId, attempt=$runAttemptCount")
      return if (runAttemptCount < MAX_AUTH_WAIT_ATTEMPTS) Result.retry() else Result.failure()
    }

    val docRef = FirebaseFirestore.getInstance()
      .collection("users").document(uid)
      .collection("reminders").document(reminderId)

    val snapshot = try {
      Tasks.await(docRef.get(), 20, TimeUnit.SECONDS)
    } catch (e: Exception) {
      android.util.Log.w(TAG, "Firestore read failed for id=$reminderId, retrying: $e")
      return Result.retry()
    }

    if (!snapshot.exists()) {
      // Reminder was deleted; nothing left to complete.
      android.util.Log.i(TAG, "Reminder id=$reminderId no longer exists; treating as done")
      PendingAlarmActionStore.remove(context, reminderId)
      return Result.success()
    }

    val status = snapshot.getString("status")
    if (status == "completed") {
      // Already applied (e.g. the app was opened and drained the pending
      // action before this job ran). Idempotent no-op.
      android.util.Log.i(TAG, "Reminder id=$reminderId already completed; no-op")
      PendingAlarmActionStore.remove(context, reminderId)
      refreshWidgetLocally(context, reminderId)
      return Result.success()
    }

    val dueAtMs = snapshot.getTimestamp("dueAt")?.toDate()?.time
    if (occurrenceMs > 0 && dueAtMs != null && dueAtMs > occurrenceMs) {
      // The reminder already moved past the occurrence this job was queued
      // for (handled through another path). Applying our write would
      // double-advance a repeating reminder, so skip it. A dueAt *behind* the
      // occurrence (a missed earlier day) is still completed: nextDueDate
      // advances past now either way.
      android.util.Log.i(TAG, "Reminder id=$reminderId occurrence stale (doc dueAt=$dueAtMs, job=$occurrenceMs); skipping")
      PendingAlarmActionStore.remove(context, reminderId)
      return Result.success()
    }

    val now = System.currentTimeMillis()
    val lastCompletedMs = snapshot.getTimestamp("lastCompletedAt")?.toDate()?.time
    if (lastCompletedMs != null && lastCompletedMs >= now - ALREADY_COMPLETED_WINDOW_MS && occurrenceMs <= 0) {
      // Same contract as ReminderRepository.completeAction: a completion
      // recorded moments ago is this action, already applied by the app.
      android.util.Log.i(TAG, "Reminder id=$reminderId completed moments ago; no-op")
      PendingAlarmActionStore.remove(context, reminderId)
      refreshWidgetLocally(context, reminderId)
      return Result.success()
    }

    val repeatRule = snapshot.getString("repeatRule")
    val normalizedRule = ReminderRecurrence.normalize(repeatRule)
    // Same fields as ReminderRepository.setDone(): a snoozed occurrence
    // advances from its original time, monthly/yearly series keep their
    // anchor day, each completed occurrence is appended to `completions`
    // (Geçmiş rows and per-day undo), and days already ticked ahead are skipped.
    val occurrenceDueMs = snapshot.getTimestamp("snoozedFromDueAt")?.toDate()?.time ?: dueAtMs
    val anchorDay = snapshot.getLong("repeatAnchorDay")?.toInt()
    val completedOccurrences = completedOccurrenceMs(snapshot.get("completions")).toMutableSet()
    if (occurrenceDueMs != null) completedOccurrences.add(occurrenceDueMs)
    val nextDueMs = if (normalizedRule != null && occurrenceDueMs != null) {
      var next = ReminderRecurrence.nextDueDate(occurrenceDueMs, repeatRule, now, anchorDay)
      var guard = 0
      while (next != null && next in completedOccurrences && guard < 500) {
        next = ReminderRecurrence.nextDueDate(next, repeatRule, next, anchorDay)
        guard += 1
      }
      next
    } else {
      null
    }

    val updates: Map<String, Any> = if (nextDueMs != null && occurrenceDueMs != null) {
      mapOf(
        "dueAt" to Timestamp(Date(nextDueMs)),
        "completions" to FieldValue.arrayUnion(
          mapOf(
            "occurrence" to Timestamp(Date(occurrenceDueMs)),
            "completedAt" to Timestamp(Date(now)),
          )
        ),
        "previousDueAt" to FieldValue.delete(),
        "status" to "scheduled",
        "lastCompletedAt" to Timestamp(Date(now)),
        "snoozedFromDueAt" to FieldValue.delete(),
        "notifiedAt" to FieldValue.delete(),
        "updatedAt" to FieldValue.serverTimestamp(),
      )
    } else {
      mapOf(
        "status" to "completed",
        "lastCompletedAt" to Timestamp(Date(now)),
        "notifiedAt" to FieldValue.delete(),
        "updatedAt" to FieldValue.serverTimestamp(),
      )
    }

    try {
      Tasks.await(docRef.update(updates), 20, TimeUnit.SECONDS)
      android.util.Log.i(TAG, "Firestore completion written for id=$reminderId (repeating=${nextDueMs != null})")
    } catch (e: Exception) {
      android.util.Log.w(TAG, "Firestore completion write failed for id=$reminderId, retrying: $e")
      return Result.retry()
    }

    if (nextDueMs != null) {
      val title = snapshot.getString("title") ?: "Hatırlatıcı"
      val message = snapshot.getString("message") ?: ""
      val priority = snapshot.getString("priority")
        ?.takeIf { it == "low" || it == "normal" || it == "important" }
        ?: "normal"
      try {
        ReminderScheduler.schedule(context, reminderId, nextDueMs, title, message, priority)
      } catch (_: Exception) {
        // Best-effort: cloud push (syncReminderScheduleToDevices) will also
        // reconcile the device alarm once the Firestore write above lands.
      }
    }

    PendingAlarmActionStore.remove(context, reminderId)
    refreshWidgetLocally(context, reminderId)
    return Result.success()
  }

  companion object {
    private const val TAG = "ReminderCompletionWork"

    /** Occurrence times (ms) from the Firestore `completions` array. */
    internal fun completedOccurrenceMs(raw: Any?): Set<Long> {
      val list = raw as? List<*> ?: return emptySet()
      return list.mapNotNull { entry ->
        when (val occurrence = (entry as? Map<*, *>)?.get("occurrence")) {
          is Timestamp -> occurrence.toDate().time
          is Date -> occurrence.time
          else -> null
        }
      }.toSet()
    }
    private const val KEY_REMINDER_ID = "reminder_id"
    private const val KEY_OCCURRENCE_MS = "occurrence_ms"
    private const val MAX_AUTH_WAIT_ATTEMPTS = 15
    private const val ALREADY_COMPLETED_WINDOW_MS = 60_000L

    /** Marks the reminder item done in the local widget snapshot (if present)
     * and forces an immediate AppWidget redraw. Pure local read/write — no
     * network, no Firestore, no RN JS — so this is safe to call from the
     * BroadcastReceiver/Service path directly for instant feedback. */
    fun refreshWidgetLocally(context: Context, reminderId: String) {
      try {
        val current = WidgetStore.getSnapshot(context)
        val item = current.items.find { it.id == reminderId }
        if (item != null && !item.completed) {
          WidgetStore.toggleItem(context, reminderId)
        }
        WidgetRenderer.renderAll(context)
      } catch (_: Exception) {
        // Widget refresh is best-effort; completion has already been persisted.
      }
    }

    fun enqueue(context: Context, reminderId: String, occurrenceTimestampMs: Long) {
      val data = Data.Builder()
        .putString(KEY_REMINDER_ID, reminderId)
        .putLong(KEY_OCCURRENCE_MS, occurrenceTimestampMs)
        .build()
      val constraints = Constraints.Builder()
        .setRequiredNetworkType(NetworkType.CONNECTED)
        .build()
      val request = OneTimeWorkRequestBuilder<ReminderCompletionWorker>()
        .setInputData(data)
        .setConstraints(constraints)
        .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, WorkRequest.MIN_BACKOFF_MILLIS, TimeUnit.MILLISECONDS)
        .build()
      val uniqueName = "reminder_complete_${reminderId}_$occurrenceTimestampMs"
      WorkManager.getInstance(context).enqueueUniqueWork(uniqueName, ExistingWorkPolicy.KEEP, request)
      android.util.Log.i(TAG, "Enqueued $uniqueName")
    }

    /** Re-queues any "complete" actions still sitting in the local durable
     * queue. Safety net for boot/app-update, in case a previous WorkManager
     * job never got the chance to run (e.g. WorkManager DB was cleared). */
    fun enqueuePendingFromStore(context: Context) {
      PendingAlarmActionStore.all(context)
        .filter { it.action == "complete" }
        .forEach { enqueue(context, it.reminderId, it.occurrenceMs ?: 0L) }
    }
  }
}
