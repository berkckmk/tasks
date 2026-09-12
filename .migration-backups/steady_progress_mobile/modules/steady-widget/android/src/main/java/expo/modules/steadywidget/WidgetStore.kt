package expo.modules.steadywidget

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

data class WidgetItem(
    val id: String,
    val type: String, // "reminder" | "habit" | "task"
    val title: String,
    val time: String = "",
    val completed: Boolean = false,
)

data class WidgetSnapshot(
    val selectedView: String = "today", // "today" | "tasks" | "reminders"
    val completed: Int = 0,
    val total: Int = 0,
    val bestStreak: Int = 0,
    val hasData: Boolean = false,
    val items: List<WidgetItem> = emptyList(),
) {
    val progress: Float
        get() = if (total > 0) (completed.toFloat() / total).coerceIn(0f, 1f) else 0f

    fun itemsForScope(scope: String): List<WidgetItem> {
        val filtered = when (scope.lowercase().trim()) {
            "tasks", "task" -> items.filter { it.type.lowercase().startsWith("task") }
            "reminders", "reminder" -> items.filter { it.type.lowercase().startsWith("reminder") }
            else -> items // "today" shows all
        }
        return filtered.sortedWith(
            compareBy<WidgetItem> { it.completed }
                .thenBy { it.time.isEmpty() }
                .thenBy { it.time }
                .thenBy { it.title }
        )
    }
}

object WidgetStore {
    private const val PREFS_NAME = "steady_widget_store"
    private const val KEY_SNAPSHOT = "active_snapshot"
    private const val KEY_PENDING_ACTIONS = "pending_actions"
    private const val KEY_SELECTED_VIEW = "selected_view"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    @Synchronized
    fun saveSnapshot(context: Context, raw: Map<String, Any?>) {
        val existing = getSnapshot(context)
        val pendingToggles = getPendingToggleMap(context)

        val itemsList = mutableListOf<WidgetItem>()
        var completedCount = 0
        var totalCount = 0
        var streak = 0

        // Parse either new format or contract legacy format
        if (raw.containsKey("items") && raw["items"] is List<*>) {
            // New direct format: items is List<Map<String, Any?>>
            val rawList = raw["items"] as List<*>
            for (elem in rawList) {
                if (elem is Map<*, *>) {
                    val id = elem["id"]?.toString().orEmpty()
                    if (id.isEmpty()) continue
                    val type = elem["type"]?.toString() ?: elem["kind"]?.toString() ?: "task"
                    val title = elem["title"]?.toString() ?: elem["label"]?.toString().orEmpty()
                    val time = elem["time"]?.toString().orEmpty()
                    var isDone = elem["completed"] as? Boolean ?: elem["done"] as? Boolean ?: false

                    // If a pending toggle exists for this item, preserve the local optimistic state
                    if (pendingToggles.containsKey(id)) {
                        isDone = pendingToggles[id]!!
                    }

                    itemsList.add(WidgetItem(id, type, title, time, isDone))
                }
            }
            completedCount = (raw["completed"] as? Number)?.toInt()
                ?: itemsList.count { it.completed }
            totalCount = (raw["total"] as? Number)?.toInt() ?: itemsList.size
            streak = (raw["bestStreak"] as? Number)?.toInt() ?: 0
        } else {
            // Legacy / Contract format: items is JSON string {"habits":[],"tasks":[],"reminders":[]}
            val itemsJsonStr = raw["items"]?.toString().orEmpty()
            if (itemsJsonStr.isNotEmpty()) {
                try {
                    val root = JSONObject(itemsJsonStr)
                    fun parseSection(sectionName: String, defaultType: String) {
                        val arr = root.optJSONArray(sectionName) ?: return
                        for (i in 0 until arr.length()) {
                            val obj = arr.optJSONObject(i) ?: continue
                            val id = obj.optString("id").trim()
                            val label = obj.optString("label").trim()
                            if (id.isEmpty() || label.isEmpty()) continue
                            val type = obj.optString("kind", defaultType)
                            val time = obj.optString("time", "")
                            var isDone = obj.optBoolean("done", false)

                            if (pendingToggles.containsKey(id)) {
                                isDone = pendingToggles[id]!!
                            }

                            itemsList.add(WidgetItem(id, type, label, time, isDone))
                        }
                    }
                    parseSection("habits", "habit")
                    parseSection("tasks", "task")
                    parseSection("reminders", "reminder")
                } catch (_: Exception) {}
            }

            val habitsDone = (raw["habitsDone"] as? Number)?.toInt() ?: 0
            val habitsTotal = (raw["habitsTotal"] as? Number)?.toInt() ?: 0
            val tasksDone = (raw["tasksDone"] as? Number)?.toInt() ?: 0
            val tasksTotal = (raw["tasksTotal"] as? Number)?.toInt() ?: 0
            completedCount = habitsDone + tasksDone
            totalCount = habitsTotal + tasksTotal
            streak = (raw["bestStreak"] as? Number)?.toInt() ?: 0
        }

        val scope = raw["selectedView"]?.toString()
            ?: prefs(context).getString(KEY_SELECTED_VIEW, existing.selectedView)
            ?: "today"

        val snapshot = WidgetSnapshot(
            selectedView = scope,
            completed = completedCount,
            total = totalCount,
            bestStreak = streak,
            hasData = true,
            items = itemsList,
        )

        val json = serializeSnapshot(snapshot)
        prefs(context).edit()
            .putString(KEY_SNAPSHOT, json.toString())
            .putString(KEY_SELECTED_VIEW, scope)
            .apply()
    }

    @Synchronized
    fun getSnapshot(context: Context): WidgetSnapshot {
        val raw = prefs(context).getString(KEY_SNAPSHOT, null) ?: return WidgetSnapshot()
        return try {
            deserializeSnapshot(JSONObject(raw))
        } catch (_: Exception) {
            WidgetSnapshot()
        }
    }

    @Synchronized
    fun toggleItem(context: Context, itemId: String): Boolean? {
        val current = getSnapshot(context)
        var newDoneState: Boolean? = null
        var itemType: String = "task"

        val updatedItems = current.items.map { item ->
            if (item.id == itemId) {
                val toggled = !item.completed
                newDoneState = toggled
                itemType = item.type
                item.copy(completed = toggled)
            } else {
                item
            }
        }

        if (newDoneState == null) return null

        val newCompleted = updatedItems.count { it.completed }
        val updatedSnapshot = current.copy(
            completed = newCompleted,
            items = updatedItems,
        )

        // 1. Save updated snapshot atomically
        prefs(context).edit()
            .putString(KEY_SNAPSHOT, serializeSnapshot(updatedSnapshot).toString())
            .apply()

        // 2. Append action to pendingWidgetActions queue, carrying the item's real
        // kind (habit/reminder/task) so the drain routes the mutation to the
        // matching repository instead of always assuming "task".
        enqueueAction(
            context,
            action = "toggle",
            itemId = itemId,
            value = newDoneState!!,
            itemType = itemType,
        )

        return newDoneState
    }

    @Synchronized
    fun cycleScope(context: Context): String {
        val current = getSnapshot(context)
        val nextScope = when (current.selectedView.lowercase().trim()) {
            "today" -> "reminders"
            "reminders", "reminder" -> "tasks"
            else -> "today"
        }
        val updated = current.copy(selectedView = nextScope)
        prefs(context).edit()
            .putString(KEY_SNAPSHOT, serializeSnapshot(updated).toString())
            .putString(KEY_SELECTED_VIEW, nextScope)
            .apply()
        return nextScope
    }

    @Synchronized
    fun addItem(context: Context, item: WidgetItem) {
        val current = getSnapshot(context)
        val updatedList = current.items.filterNot { it.id == item.id } + item
        val updated = current.copy(
            items = updatedList,
            total = current.total + 1,
            hasData = true,
        )
        prefs(context).edit()
            .putString(KEY_SNAPSHOT, serializeSnapshot(updated).toString())
            .apply()
    }

    @Synchronized
    fun clear(context: Context) {
        prefs(context).edit().clear().apply()
    }

    @Synchronized
    private fun enqueueAction(context: Context, action: String, itemId: String, value: Any, itemType: String? = null) {
        val p = prefs(context)
        val raw = p.getString(KEY_PENDING_ACTIONS, "[]") ?: "[]"
        val array = try { JSONArray(raw) } catch (_: Exception) { JSONArray() }

        val obj = JSONObject().apply {
            put("action", action)
            put("itemId", itemId)
            put("value", value)
            put("createdAt", System.currentTimeMillis())
            if (itemType != null) put("kind", itemType)
        }
        array.put(obj)

        p.edit().putString(KEY_PENDING_ACTIONS, array.toString()).apply()
    }

    @Synchronized
    fun getPendingActions(context: Context): String {
        return prefs(context).getString(KEY_PENDING_ACTIONS, "[]") ?: "[]"
    }

    @Synchronized
    fun clearPendingActions(context: Context): Boolean {
        prefs(context).edit().remove(KEY_PENDING_ACTIONS).apply()
        return true
    }

    @Synchronized
    fun consumePendingActions(context: Context): String {
        val actions = getPendingActions(context)
        clearPendingActions(context)
        return actions
    }

    private fun getPendingToggleMap(context: Context): Map<String, Boolean> {
        val raw = prefs(context).getString(KEY_PENDING_ACTIONS, "[]") ?: "[]"
        val result = mutableMapOf<String, Boolean>()
        try {
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val item = arr.optJSONObject(i) ?: continue
                if (item.optString("action") == "toggle") {
                    result[item.optString("itemId")] = item.optBoolean("value")
                }
            }
        } catch (_: Exception) {}
        return result
    }

    private fun serializeSnapshot(snapshot: WidgetSnapshot): JSONObject {
        val root = JSONObject()
        root.put("selectedView", snapshot.selectedView)
        root.put("completed", snapshot.completed)
        root.put("total", snapshot.total)
        root.put("bestStreak", snapshot.bestStreak)
        root.put("hasData", snapshot.hasData)

        val arr = JSONArray()
        for (item in snapshot.items) {
            arr.put(JSONObject().apply {
                put("id", item.id)
                put("type", item.type)
                put("title", item.title)
                put("time", item.time)
                put("completed", item.completed)
            })
        }
        root.put("items", arr)
        return root
    }

    private fun deserializeSnapshot(root: JSONObject): WidgetSnapshot {
        val itemsList = mutableListOf<WidgetItem>()
        val arr = root.optJSONArray("items")
        if (arr != null) {
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                itemsList.add(
                    WidgetItem(
                        id = o.optString("id"),
                        type = o.optString("type", "task"),
                        title = o.optString("title"),
                        time = o.optString("time", ""),
                        completed = o.optBoolean("completed", false),
                    )
                )
            }
        }
        return WidgetSnapshot(
            selectedView = root.optString("selectedView", "today"),
            completed = root.optInt("completed", 0),
            total = root.optInt("total", 0),
            bestStreak = root.optInt("bestStreak", 0),
            hasData = root.optBoolean("hasData", false),
            items = itemsList,
        )
    }
}
