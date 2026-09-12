package expo.modules.steadyreminders

internal object SteadyRemindersEvents {
  @Volatile
  var activeModule: SteadyRemindersModule? = null

  fun sendAlarmAction(action: String, reminderId: String, snoozedUntilMs: Long? = null) {
    val payload = mutableMapOf<String, Any>(
      "action" to action,
      "reminderId" to reminderId,
      "timestampMs" to System.currentTimeMillis(),
    )
    if (snoozedUntilMs != null) {
      payload["snoozedUntilMs"] = snoozedUntilMs
    }
    activeModule?.sendAlarmActionEvent(payload)
  }

  fun sendAlarmTriggered(reminderId: String, title: String) {
    activeModule?.sendAlarmTriggeredEvent(
      mapOf(
        "reminderId" to reminderId,
        "title" to title,
        "triggeredAt" to System.currentTimeMillis(),
      )
    )
  }
}
