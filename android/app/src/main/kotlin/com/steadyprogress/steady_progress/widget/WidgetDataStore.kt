package com.steadyprogress.steady_progress.widget

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Which pillar a row came from. Mirrors `TodayKind` on the Flutter side.
 */
enum class WidgetItemKind(val key: String, val label: String) {
    REMINDER("reminder", "Reminder"),
    TASK("task", "Task"),
    HABIT("habit", "Habit");

    companion object {
        fun fromKey(key: String?): WidgetItemKind =
            entries.firstOrNull { it.key == key } ?: REMINDER
    }
}

/**
 * One row on the widget.
 *
 * [id] and [kind] are new, and they are what make the row *tappable in a
 * useful way*: the toggle has to name a document to write back to, and the
 * row's own tap has to open the right editor. The old shape carried only a
 * label and a done flag, which is all a static bitmap needed.
 */
data class WidgetItem(
    val id: String,
    val kind: WidgetItemKind,
    val label: String,
    val done: Boolean = false,
    /** "9:15" / "14:30", already formatted by Flutter in the device's own
     *  locale and clock convention. Empty means "no time". */
    val time: String = "",
)

data class WidgetData(
    val habitsDone: Int,
    val habitsTotal: Int,
    val tasksDone: Int,
    val tasksTotal: Int,
    val bestStreak: Int,
    val hasData: Boolean,
    val habits: List<WidgetItem> = emptyList(),
    val tasks: List<WidgetItem> = emptyList(),
    val reminders: List<WidgetItem> = emptyList(),
) {
    /** 0f..1f share of today's habits + tasks that are done. */
    val progress: Float
        get() {
            val total = habitsTotal + tasksTotal
            if (total <= 0) return 0f
            return ((habitsDone + tasksDone).toFloat() / total).coerceIn(0f, 1f)
        }

    val doneCount: Int get() = habitsDone + tasksDone
    val totalCount: Int get() = habitsTotal + tasksTotal

    /**
     * The rows for one widget, after its scope and its Include set.
     *
     * Ordering is the app's rule, applied here so the widget and the Today
     * rail cannot disagree: **incomplete first, then by time, untimed last.**
     * A ticked row sorts to the bottom and stays there.
     */
    fun itemsFor(config: WidgetConfig): List<WidgetItem> {
        val pool = when (config.scope) {
            WidgetScope.REMINDERS -> reminders
            WidgetScope.TASKS -> tasks
            WidgetScope.TODAY -> buildList {
                if (config.includes(WidgetInclude.REMINDERS)) addAll(reminders)
                if (config.includes(WidgetInclude.TASKS)) addAll(tasks)
                if (config.includes(WidgetInclude.HABITS)) addAll(habits)
            }
        }

        return pool
            .filter { config.showsCompleted || !it.done }
            .sortedWith(
                compareBy<WidgetItem> { it.done }
                    .thenBy { it.time.isEmpty() }
                    .thenBy { it.time }
                    .thenBy { it.label },
            )
    }
}

/**
 * The home-screen widget's copy of today.
 *
 * The widget process can't read Firestore — it has no auth session and an
 * `AppWidgetProvider` gets a few seconds of broadcast time, nowhere near
 * enough for a network round trip. So Flutter pushes a snapshot into
 * SharedPreferences whenever the data changes (see
 * `lib/features/home_widget/application/home_widget_service.dart`) and the
 * widget renders purely from that. That one-way arrangement is deliberately
 * kept.
 *
 * Everything is nullable-safe with sane defaults: the widget can be placed on
 * the home screen before the app has ever run, and must render something calm
 * rather than crash or show zeros as if they were real.
 */
object WidgetDataStore {

    private const val PREFS = "steady_progress_widget"
    private const val KEY_HABITS_DONE = "habitsDone"
    private const val KEY_HABITS_TOTAL = "habitsTotal"
    private const val KEY_TASKS_DONE = "tasksDone"
    private const val KEY_TASKS_TOTAL = "tasksTotal"
    private const val KEY_BEST_STREAK = "bestStreak"
    private const val KEY_HAS_DATA = "hasData"
    private const val KEY_ITEMS = "items"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /**
     * Persists a snapshot pushed from Flutter. Values arrive as `Any?` across
     * the method channel — Dart ints can decode as Int or Long depending on
     * magnitude, so each is read through [asInt] rather than cast directly.
     *
     * The per-item lists arrive as a JSON string rather than nested maps:
     * SharedPreferences has no list-of-objects type, and one opaque string is
     * simpler to version than a scatter of indexed keys.
     */
    fun write(context: Context, data: Map<String, Any?>) {
        prefs(context).edit()
            .putInt(KEY_HABITS_DONE, asInt(data[KEY_HABITS_DONE]))
            .putInt(KEY_HABITS_TOTAL, asInt(data[KEY_HABITS_TOTAL]))
            .putInt(KEY_TASKS_DONE, asInt(data[KEY_TASKS_DONE]))
            .putInt(KEY_TASKS_TOTAL, asInt(data[KEY_TASKS_TOTAL]))
            .putInt(KEY_BEST_STREAK, asInt(data[KEY_BEST_STREAK]))
            .putString(
                KEY_ITEMS,
                // Rows the quick-add modal composed or checkboxes toggled before
                // sync drains them are folded back in. Without this, an incoming
                // snapshot push would prematurely overwrite pending optimistic states.
                withPendingActions(context, data[KEY_ITEMS] as? String ?: ""),
            )
            .putBoolean(KEY_HAS_DATA, true)
            .apply()
    }

    /**
     * Adds one composed-but-not-yet-created row to the local snapshot.
     *
     * The optimistic half of the quick-add, exactly as [toggleLocally] is the
     * optimistic half of the toggle: the launcher shows the row the moment
     * the modal closes, and [WidgetPendingAdds] is the durable half the app
     * drains into the real repositories.
     */
    fun addLocally(context: Context, item: WidgetItem) {
        val p = prefs(context)
        val raw = p.getString(KEY_ITEMS, "") ?: ""
        val root = try {
            if (raw.isEmpty()) JSONObject() else JSONObject(raw)
        } catch (error: Exception) {
            JSONObject()
        }
        appendItem(root, item)
        p.edit()
            .putString(KEY_ITEMS, root.toString())
            // A widget that has only ever been written to by its own modal
            // still has data to show; without this it would render the empty
            // state over the row it just added.
            .putBoolean(KEY_HAS_DATA, true)
            .apply()
    }

    /**
     * Drops the optimistic rows whose real documents now exist.
     *
     * Called when the app clears the quick-add queue. The rows would
     * otherwise survive until the *next* push — and a push that lands before
     * the drain finishes, which is the ordinary ordering, leaves the widget
     * showing the item twice: once as the composed row and once as the real
     * one.
     */
    fun dropLocalAdds(context: Context, ids: Collection<String>) {
        if (ids.isEmpty()) return
        val p = prefs(context)
        val raw = p.getString(KEY_ITEMS, "") ?: ""
        if (raw.isEmpty()) return
        val drop = ids.toSet()
        try {
            val root = JSONObject(raw)
            var changed = false
            for (section in root.keys().asSequence().toList()) {
                val array = root.optJSONArray(section) ?: continue
                val kept = JSONArray()
                for (i in 0 until array.length()) {
                    val o = array.optJSONObject(i) ?: continue
                    if (o.optString("id") in drop) {
                        changed = true
                    } else {
                        kept.put(o)
                    }
                }
                root.put(section, kept)
            }
            if (changed) p.edit().putString(KEY_ITEMS, root.toString()).apply()
        } catch (error: Exception) {
            // A malformed snapshot is the next push's problem, not this call's.
        }
    }

    /** Which section of the pushed JSON a kind belongs in. */
    private fun sectionFor(kind: WidgetItemKind): String = when (kind) {
        WidgetItemKind.HABIT -> "habits"
        WidgetItemKind.TASK -> "tasks"
        WidgetItemKind.REMINDER -> "reminders"
    }

    private fun appendItem(root: JSONObject, item: WidgetItem) {
        val section = sectionFor(item.kind)
        val array = root.optJSONArray(section) ?: JSONArray().also { root.put(section, it) }
        array.put(
            JSONObject()
                .put("id", item.id)
                .put("kind", item.kind.key)
                .put("label", item.label)
                .put("done", item.done)
                .put("time", item.time),
        )
    }

    /**
     * The pushed snapshot with every still-queued quick-add folded back in.
     *
     * Matched by id, so a queued add whose real document has already arrived
     * in the push is not duplicated — the drain clears the queue and the next
     * push carries the real row, but the two can overlap by one frame.
     */
    private fun withPendingAdds(context: Context, itemsJson: String): String {
        val pending = WidgetPendingAdds.read(context)
        if (pending.isEmpty()) return itemsJson
        return try {
            val root = if (itemsJson.isEmpty()) JSONObject() else JSONObject(itemsJson)
            val known = buildSet {
                for (key in root.keys().asSequence().toList()) {
                    val array = root.optJSONArray(key) ?: continue
                    for (i in 0 until array.length()) {
                        add(array.optJSONObject(i)?.optString("id").orEmpty())
                    }
                }
            }
            for (add in pending) {
                if (add.id in known) continue
                appendItem(
                    root,
                    WidgetItem(id = add.id, kind = add.kind, label = add.label),
                )
            }
            root.toString()
        } catch (error: Exception) {
            itemsJson
        }
    }

    private fun withPendingActions(context: Context, itemsJson: String): String {
        val withAdds = withPendingAdds(context, itemsJson)
        val pendingToggles = WidgetPendingToggles.read(context)
        if (pendingToggles.isEmpty()) return withAdds
        return try {
            val root = if (withAdds.isEmpty()) JSONObject() else JSONObject(withAdds)
            val toggleMap = pendingToggles.associateBy({ it.id to it.kind }, { it.done })
            for (section in root.keys().asSequence().toList()) {
                val array = root.optJSONArray(section) ?: continue
                for (i in 0 until array.length()) {
                    val o = array.optJSONObject(i) ?: continue
                    val id = o.optString("id")
                    val kind = WidgetItemKind.fromKey(o.optString("kind"))
                    val pendingDone = toggleMap[id to kind]
                    if (pendingDone != null) {
                        o.put("done", pendingDone)
                    }
                }
            }
            root.toString()
        } catch (error: Exception) {
            withAdds
        }
    }

    /** Clears the snapshot — called on sign-out so the widget stops showing
     *  the previous account's items on a shared device. */
    fun clear(context: Context) {
        prefs(context).edit().clear().apply()
    }

    fun read(context: Context): WidgetData {
        val p = prefs(context)
        val items = parseItems(p.getString(KEY_ITEMS, "") ?: "")
        return WidgetData(
            habitsDone = p.getInt(KEY_HABITS_DONE, 0),
            habitsTotal = p.getInt(KEY_HABITS_TOTAL, 0),
            tasksDone = p.getInt(KEY_TASKS_DONE, 0),
            tasksTotal = p.getInt(KEY_TASKS_TOTAL, 0),
            bestStreak = p.getInt(KEY_BEST_STREAK, 0),
            hasData = p.getBoolean(KEY_HAS_DATA, false),
            habits = items["habits"].orEmpty(),
            tasks = items["tasks"].orEmpty(),
            reminders = items["reminders"].orEmpty(),
        )
    }

    /**
     * Flips one item's `done` in the local snapshot.
     *
     * This is the **optimistic half** of the widget toggle: the launcher
     * redraws immediately instead of waiting for a Firestore round trip that
     * a broadcast receiver has no time for anyway. The durable half is
     * [WidgetPendingToggles], drained by the app.
     *
     * Returns the new state, or null if the item is no longer in the
     * snapshot — which is normal, not exceptional: the row is whatever the
     * last push contained, and a tap can land after the item was deleted on
     * another device.
     */
    fun toggleLocally(context: Context, itemId: String, kind: WidgetItemKind): Boolean? {
        val p = prefs(context)
        val raw = p.getString(KEY_ITEMS, "") ?: ""
        if (raw.isEmpty()) return null

        return try {
            val root = JSONObject(raw)
            var newState: Boolean? = null
            for (section in root.keys().asSequence().toList()) {
                val array = root.optJSONArray(section) ?: continue
                for (i in 0 until array.length()) {
                    val o = array.optJSONObject(i) ?: continue
                    if (o.optString("id") != itemId) continue
                    if (WidgetItemKind.fromKey(o.optString("kind")) != kind) continue
                    val next = !o.optBoolean("done", false)
                    o.put("done", next)
                    newState = next
                }
            }
            if (newState != null) {
                p.edit().putString(KEY_ITEMS, root.toString()).apply()
            }
            newState
        } catch (error: Exception) {
            // Runs inside a worker; a malformed snapshot must not take the
            // widget down with it.
            null
        }
    }

    /**
     * Parses the pushed item lists.
     *
     * Malformed input yields empty lists rather than throwing: this runs
     * inside a broadcast receiver and a `RemoteViewsService`, where an
     * uncaught exception takes down the whole widget rather than one row.
     */
    private fun parseItems(json: String): Map<String, List<WidgetItem>> {
        if (json.isEmpty()) return emptyMap()
        return try {
            val root = JSONObject(json)
            root.keys().asSequence().associateWith { key ->
                val array = root.optJSONArray(key) ?: JSONArray()
                (0 until array.length()).mapNotNull { i ->
                    val o = array.optJSONObject(i) ?: return@mapNotNull null
                    val label = o.optString("label").trim()
                    val id = o.optString("id").trim()
                    // A row with no id can't be toggled and can't be opened,
                    // so it is not a row.
                    if (label.isEmpty() || id.isEmpty()) return@mapNotNull null
                    WidgetItem(
                        id = id,
                        kind = WidgetItemKind.fromKey(o.optString("kind")),
                        label = label,
                        done = o.optBoolean("done", false),
                        time = o.optString("time"),
                    )
                }
            }
        } catch (error: Exception) {
            emptyMap()
        }
    }

    private fun asInt(value: Any?): Int = when (value) {
        is Int -> value
        is Long -> value.toInt()
        is Number -> value.toInt()
        else -> 0
    }
}
