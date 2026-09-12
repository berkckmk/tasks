package expo.modules.steadyreminders

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

internal data class PendingAlarmAction(
  val action: String,
  val reminderId: String,
  val timestampMs: Long,
  val snoozedUntilMs: Long? = null,
)

internal object PendingAlarmActionStore {
  private const val PREFS = "steady_pending_alarm_actions"
  private const val KEY = "actions"

  fun add(
    context: Context,
    action: String,
    reminderId: String,
    timestampMs: Long = System.currentTimeMillis(),
    snoozedUntilMs: Long? = null,
  ) {
    val current = all(context).toMutableList()
    current.removeAll { it.reminderId == reminderId && it.action == action }
    current.add(PendingAlarmAction(action, reminderId, timestampMs, snoozedUntilMs))
    write(context, current)
  }

  fun all(context: Context): List<PendingAlarmAction> = try {
    val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]") ?: "[]"
    val array = JSONArray(raw)
    (0 until array.length()).map { i ->
      val obj = array.getJSONObject(i)
      PendingAlarmAction(
        action = obj.getString("action"),
        reminderId = obj.getString("reminderId"),
        timestampMs = obj.getLong("timestampMs"),
        snoozedUntilMs = if (obj.has("snoozedUntilMs")) obj.getLong("snoozedUntilMs") else null,
      )
    }
  } catch (_: Exception) {
    emptyList()
  }

  fun remove(context: Context, reminderId: String) {
    val remaining = all(context).filterNot { it.reminderId == reminderId }
    write(context, remaining)
  }

  fun clear(context: Context) {
    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(KEY).apply()
  }

  private fun write(context: Context, items: List<PendingAlarmAction>) {
    val array = JSONArray()
    items.forEach { item ->
      val obj = JSONObject()
        .put("action", item.action)
        .put("reminderId", item.reminderId)
        .put("timestampMs", item.timestampMs)
      if (item.snoozedUntilMs != null) {
        obj.put("snoozedUntilMs", item.snoozedUntilMs)
      }
      array.put(obj)
    }
    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, array.toString()).apply()
  }
}
