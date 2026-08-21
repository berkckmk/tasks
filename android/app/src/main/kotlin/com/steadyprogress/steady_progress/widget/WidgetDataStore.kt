package com.steadyprogress.steady_progress.widget

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * The home-screen widget's copy of the dashboard.
 *
 * The widget process can't read Firestore — it has no auth session and an
 * AppWidgetProvider only gets a few seconds of broadcast time, nowhere near
 * enough for a network round trip. So Flutter pushes a snapshot into
 * SharedPreferences whenever the data changes (see
 * lib/features/home_widget/application/home_widget_service.dart) and the
 * widget renders purely from that.
 *
 * Everything is nullable-safe with sane defaults: the widget can be placed on
 * the home screen before the app has ever run, and must render something
 * calm rather than crash or show zeros as if they were real.
 */
data class WidgetItem(
    val label: String,
    /** Done/undone for habits and tasks; reminders are still list-based without a done flag. */
    val done: Boolean = false,
    /** 0f..1f, reminders only when a progress meter is used. Negative means "no bar". */
    val progress: Float = -1f,
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
}

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
            .putString(KEY_ITEMS, data[KEY_ITEMS] as? String ?: "")
            .putBoolean(KEY_HAS_DATA, true)
            .apply()
    }

    /** Clears the snapshot — called on sign-out so the widget stops showing
     *  the previous account's numbers on a shared device. */
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
                    if (label.isEmpty()) return@mapNotNull null
                    WidgetItem(
                        label = label,
                        done = o.optBoolean("done", false),
                        progress = o.optDouble("progress", -1.0).toFloat(),
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
