package expo.modules.steadywidget

import android.content.Context
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import org.json.JSONArray
import org.json.JSONObject

class SteadyWidgetModule : Module() {

    private val context: Context
        get() = checkNotNull(appContext.reactContext) { "React context not available" }

    override fun definition() = ModuleDefinition {
        Name("SteadyWidget")
        Events("onWidgetRoute")

        AsyncFunction("updateWidget") { snapshot: Map<String, Any?> ->
            WidgetStore.saveSnapshot(context, snapshot)
            WidgetRenderer.renderAll(context)
            true
        }

        AsyncFunction("clearWidget") {
            WidgetStore.clear(context)
            WidgetRenderer.renderAll(context)
            true
        }

        // Clean Modern API
        AsyncFunction("consumePendingWidgetActions") {
            WidgetStore.consumePendingActions(context)
        }

        AsyncFunction("getPendingWidgetActions") {
            WidgetStore.getPendingActions(context)
        }

        // Backward compatibility surface for existing TypeScript tests and drain hooks
        AsyncFunction("readPendingToggles") {
            val actions = WidgetStore.getPendingActions(context)
            try {
                val rawArr = JSONArray(actions)
                val togglesArr = JSONArray()
                for (i in 0 until rawArr.length()) {
                    val obj = rawArr.getJSONObject(i)
                    if (obj.optString("action") == "toggle") {
                        togglesArr.put(JSONObject().apply {
                            put("id", obj.getString("itemId"))
                            put("kind", obj.optString("kind", "task"))
                            put("done", obj.getBoolean("value"))
                            put("at", obj.optLong("createdAt", System.currentTimeMillis()))
                        })
                    }
                }
                togglesArr.toString()
            } catch (_: Exception) {
                "[]"
            }
        }

        AsyncFunction("readPendingAdds") {
            try {
                val prefs = context.getSharedPreferences("steady_progress_widget_pending_adds", Context.MODE_PRIVATE)
                val raw = prefs.getString("queue", "") ?: ""
                if (raw.isEmpty()) "[]" else raw
            } catch (_: Exception) {
                "[]"
            }
        }

        AsyncFunction("clearPendingToggles") { _: List<String> ->
            WidgetStore.clearPendingActions(context)
            true
        }

        AsyncFunction("clearPendingAdds") { ids: List<String> ->
            try {
                val prefs = context.getSharedPreferences("steady_progress_widget_pending_adds", Context.MODE_PRIVATE)
                val raw = prefs.getString("queue", "") ?: ""
                if (raw.isNotEmpty()) {
                    val array = JSONArray(raw)
                    val idSet = ids.toSet()
                    val newArray = JSONArray()
                    for (i in 0 until array.length()) {
                        val obj = array.optJSONObject(i) ?: continue
                        if (obj.optString("id") !in idSet) {
                            newArray.put(obj)
                        }
                    }
                    prefs.edit().putString("queue", newArray.toString()).apply()
                }
            } catch (_: Exception) {}
            true
        }

        AsyncFunction("acknowledgePendingToggles") { _: List<Map<String, Any?>> ->
            WidgetStore.clearPendingActions(context)
            true
        }

        AsyncFunction("acknowledgePendingAdds") { entries: List<Map<String, Any?>> ->
            try {
                val ids = entries.mapNotNull { it["id"] as? String }.toSet()
                val prefs = context.getSharedPreferences("steady_progress_widget_pending_adds", Context.MODE_PRIVATE)
                val raw = prefs.getString("queue", "") ?: ""
                if (raw.isNotEmpty()) {
                    val array = JSONArray(raw)
                    val newArray = JSONArray()
                    for (i in 0 until array.length()) {
                        val obj = array.optJSONObject(i) ?: continue
                        if (obj.optString("id") !in ids) {
                            newArray.put(obj)
                        }
                    }
                    prefs.edit().putString("queue", newArray.toString()).apply()
                }
            } catch (_: Exception) {}
            true
        }

        AsyncFunction("readSnapshot") {
            val s = WidgetStore.getSnapshot(context)
            JSONObject().apply {
                put("selectedView", s.selectedView)
                put("completed", s.completed)
                put("total", s.total)
                put("bestStreak", s.bestStreak)
                put("hasData", s.hasData)
            }.toString()
        }

        AsyncFunction("takePendingRoute") {
            null
        }

        OnNewIntent {
            sendEvent("onWidgetRoute", emptyMap<String, Any>())
        }
    }
}
