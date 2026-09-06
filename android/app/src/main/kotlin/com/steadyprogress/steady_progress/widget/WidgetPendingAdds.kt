package com.steadyprogress.steady_progress.widget

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** One item the widget's quick-add composed that Firestore hasn't seen yet. */
data class PendingAdd(
    /** A local id, `add:<millis>`. It is also the id of the optimistic row in
     *  [WidgetDataStore], which is how the two are matched up on drain. */
    val id: String,
    val kind: WidgetItemKind,
    val label: String,
    /** The moment, or the range's first day, in epoch millis. Null only for a
     *  habit, which recurs and has no date. */
    val startAt: Long?,
    /** The range's last day. Only ever set for a task. */
    val endAt: Long?,
    /** No clock time was chosen — the item is on the day, not at a moment. */
    val allDay: Boolean,
    val at: Long,
)

/**
 * The quick-add queue — the same arrangement as [WidgetPendingToggles], for
 * the same reason.
 *
 * The widget cannot create a reminder, a task or a habit itself. A task in
 * particular *cannot* be written directly at all: `firestore.rules` denies
 * `create` on the collection outright and creation goes through the
 * `createTask` Cloud Function, which is where the plan's active-task limit is
 * enforced. Reimplementing that in Kotlin would put a copy of the plan rules
 * in the widget process and still leave it without an auth session.
 *
 * So the modal records the intent here, drops an optimistic row into
 * [WidgetDataStore] so the launcher shows it at once, and the app creates it
 * for real through the ordinary repositories on its next start or resume —
 * see `HomeWidgetSync._drainPendingAdds`.
 *
 * **The honest limitation** is [WidgetPendingToggles]': until the app runs
 * again the item exists only on this device. It is queued, not lost, and the
 * row is marked as such on the widget.
 */
object WidgetPendingAdds {

    private const val PREFS = "steady_progress_widget_pending_adds"
    private const val KEY_QUEUE = "queue"

    /** Beyond this the oldest are dropped rather than growing an unbounded
     *  prefs string. Nobody composes 50 items without opening the app. */
    private const val MAX = 50

    /** The prefix every optimistic row's id carries. */
    const val ID_PREFIX = "add:"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    @Synchronized
    fun enqueue(context: Context, add: PendingAdd) {
        val queue = read(context).toMutableList()
        queue.add(add)
        while (queue.size > MAX) queue.removeAt(0)
        writeAll(context, queue)
    }

    @Synchronized
    fun read(context: Context): List<PendingAdd> {
        val raw = prefs(context).getString(KEY_QUEUE, "") ?: ""
        if (raw.isEmpty()) return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).mapNotNull { i ->
                val o = array.optJSONObject(i) ?: return@mapNotNull null
                val id = o.optString("id")
                val label = o.optString("label").trim()
                if (id.isEmpty() || label.isEmpty()) return@mapNotNull null
                PendingAdd(
                    id = id,
                    kind = WidgetItemKind.fromKey(o.optString("kind")),
                    label = label,
                    startAt = o.optLong("startAt").takeIf { it > 0L },
                    endAt = o.optLong("endAt").takeIf { it > 0L },
                    // Absent reads as all-day, which is what every entry
                    // queued before the schedule existed was.
                    allDay = o.optBoolean("allDay", true),
                    at = o.optLong("at"),
                )
            }
        } catch (error: Exception) {
            emptyList()
        }
    }

    /** The queue as the JSON string the method channel hands to Flutter. */
    fun readAsJson(context: Context): String = JSONArray().apply {
        for (a in read(context)) {
            put(
                JSONObject()
                    .put("id", a.id)
                    .put("kind", a.kind.key)
                    .put("label", a.label)
                    .put("startAt", a.startAt ?: 0L)
                    .put("endAt", a.endAt ?: 0L)
                    .put("allDay", a.allDay)
                    .put("at", a.at),
            )
        }
    }.toString()

    /** Drops the entries Flutter has now created, by local id. */
    @Synchronized
    fun clear(context: Context, appliedIds: Collection<String>) {
        if (appliedIds.isEmpty()) return
        val applied = appliedIds.toSet()
        writeAll(context, read(context).filterNot { it.id in applied })
    }

    private fun writeAll(context: Context, queue: List<PendingAdd>) {
        val array = JSONArray()
        for (a in queue) {
            array.put(
                JSONObject()
                    .put("id", a.id)
                    .put("kind", a.kind.key)
                    .put("label", a.label)
                    .put("startAt", a.startAt ?: 0L)
                    .put("endAt", a.endAt ?: 0L)
                    .put("allDay", a.allDay)
                    .put("at", a.at),
            )
        }
        prefs(context).edit().putString(KEY_QUEUE, array.toString()).apply()
    }
}
