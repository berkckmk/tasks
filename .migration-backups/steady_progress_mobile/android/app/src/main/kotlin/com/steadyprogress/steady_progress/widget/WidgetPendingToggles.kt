package com.steadyprogress.steady_progress.widget

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** One tick the widget made that Firestore hasn't been told about yet. */
data class PendingToggle(
    val id: String,
    val kind: WidgetItemKind,
    val done: Boolean,
    val at: Long,
)

/**
 * The durable half of the widget's write-through.
 *
 * ## Why a queue rather than a direct write
 *
 * Ticking a row on the home screen has to reach Firestore. It cannot happen
 * in `onReceive` — an `AppWidgetProvider` gets only a few seconds of
 * broadcast time — so the toggle enqueues a background worker, exactly as the
 * handoff requires. What that worker does is the part worth explaining.
 *
 * It does **not** write to Firestore itself. Two reasons, and the second is
 * the one that decided it:
 *
 *  1. *The widget still never touches Firestore.* That one-way arrangement is
 *     listed under "deliberately kept", and it is what keeps the widget free
 *     of an auth session, a network permission story, and a second copy of
 *     the plan-enforcement rules.
 *
 *  2. *Completing an item is not a field write.* Ticking a habit goes through
 *     `HabitRepository.setCompletionToday`, which writes a `habit_logs`
 *     document that the streak derivation reads back; ticking a reminder
 *     resends the whole document so the repository can clear `notifiedAt` and
 *     re-arm the alert; ticking a task logs an analytics event. A raw Kotlin
 *     `update("status", "completed")` would produce a document that looks
 *     right and behaves wrong — a habit with no log and therefore no streak.
 *     Reimplementing three repositories in Kotlin to avoid one queue is the
 *     worse trade.
 *
 * So the worker records the intent here and flips the local snapshot so the
 * launcher redraws at once. The app drains this queue through the real
 * repositories the next time it runs — see `WidgetPendingSync` on the Flutter
 * side. The widget shows the user's tick immediately; the write happens on
 * the one code path that knows what a tick means.
 *
 * **The honest limitation:** if the user never opens the app again, the tick
 * lives only on the device. It is not lost and it is not silently discarded —
 * it is queued — but it is not in Firestore either. Given the alternative is
 * a habit that shows as complete with no log behind it, queuing is the
 * failure mode worth having.
 */
object WidgetPendingToggles {

    private const val PREFS = "steady_progress_widget_pending"
    private const val KEY_QUEUE = "queue"

    /** Enough for a burst of taps; beyond this the oldest are dropped rather
     *  than growing an unbounded prefs string. */
    private const val MAX = 100

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    @Synchronized
    fun enqueue(context: Context, toggle: PendingToggle) {
        val queue = read(context).toMutableList()
        // One entry per item: tapping twice is a no-op, not two writes, and
        // the last state is the one that counts.
        queue.removeAll { it.id == toggle.id && it.kind == toggle.kind }
        queue.add(toggle)
        while (queue.size > MAX) queue.removeAt(0)
        writeAll(context, queue)
    }

    @Synchronized
    fun read(context: Context): List<PendingToggle> {
        val raw = prefs(context).getString(KEY_QUEUE, "") ?: ""
        if (raw.isEmpty()) return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).mapNotNull { i ->
                val o = array.optJSONObject(i) ?: return@mapNotNull null
                val id = o.optString("id")
                if (id.isEmpty()) return@mapNotNull null
                PendingToggle(
                    id = id,
                    kind = WidgetItemKind.fromKey(o.optString("kind")),
                    done = o.optBoolean("done"),
                    at = o.optLong("at"),
                )
            }
        } catch (error: Exception) {
            emptyList()
        }
    }

    /** The queue as the JSON string the method channel hands to Flutter. */
    fun readAsJson(context: Context): String {
        val array = JSONArray()
        for (t in read(context)) {
            array.put(
                JSONObject()
                    .put("id", t.id)
                    .put("kind", t.kind.key)
                    .put("done", t.done)
                    .put("at", t.at),
            )
        }
        return array.toString()
    }

    /**
     * Drops the entries Flutter has now applied.
     *
     * Takes the ids it actually wrote rather than clearing wholesale: a tick
     * made while the drain was in flight must survive it, and clearing
     * everything is how that tick would quietly disappear.
     */
    @Synchronized
    fun clear(context: Context, appliedIds: Collection<String>) {
        if (appliedIds.isEmpty()) return
        val applied = appliedIds.toSet()
        writeAll(context, read(context).filterNot { it.id in applied })
    }

    private fun writeAll(context: Context, queue: List<PendingToggle>) {
        val array = JSONArray()
        for (t in queue) {
            array.put(
                JSONObject()
                    .put("id", t.id)
                    .put("kind", t.kind.key)
                    .put("done", t.done)
                    .put("at", t.at),
            )
        }
        prefs(context).edit().putString(KEY_QUEUE, array.toString()).apply()
    }
}
