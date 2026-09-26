package expo.modules.steadyreminders

import java.util.Calendar
import java.util.Date

/**
 * Kotlin port of src/features/reminders/recurrence.ts (`normalizeRepeatRule` /
 * `calculateNextDueDate`). Kept in lockstep with that file intentionally: this
 * is what lets a WorkManager job advance a repeating reminder's next
 * occurrence with the same contract the JS ReminderRepository.setDone() uses,
 * even when the app process never runs.
 */
internal object ReminderRecurrence {
  private val repeatRules = setOf(
    "Her gün", "Hafta içi (Pzt-Cum)", "Her hafta", "Her ay", "Her yıl",
  )

  fun normalize(rule: String?): String? {
    if (rule.isNullOrBlank()) return null
    val trimmed = rule.trim().lowercase()
    return when {
      trimmed == "tekrarlama" || trimmed == "none" -> null
      trimmed == "her gün" || trimmed == "her gun" || trimmed == "daily" -> "Her gün"
      trimmed == "hafta içi (pzt-cum)" || trimmed == "hafta içi" || trimmed == "hafta ici" || trimmed == "weekdays" -> "Hafta içi (Pzt-Cum)"
      trimmed == "her hafta" || trimmed == "weekly" -> "Her hafta"
      trimmed == "her ay" || trimmed == "monthly" -> "Her ay"
      trimmed == "her yıl" || trimmed == "her yil" || trimmed == "yearly" -> "Her yıl"
      rule in repeatRules -> rule
      else -> null
    }
  }

  /** [anchorDay] mirrors repeatAnchorDay: a series created on the 31st stays at month end. */
  private fun stepForward(cal: Calendar, rule: String, anchorDay: Int?) {
    when (rule) {
      "Her gün" -> cal.add(Calendar.DAY_OF_MONTH, 1)
      "Hafta içi (Pzt-Cum)" -> {
        do {
          cal.add(Calendar.DAY_OF_MONTH, 1)
        } while (cal.get(Calendar.DAY_OF_WEEK) == Calendar.SUNDAY || cal.get(Calendar.DAY_OF_WEEK) == Calendar.SATURDAY)
      }
      "Her hafta" -> cal.add(Calendar.DAY_OF_MONTH, 7)
      "Her ay" -> {
        val targetDay = anchorDay ?: cal.get(Calendar.DAY_OF_MONTH)
        cal.set(Calendar.DAY_OF_MONTH, 1)
        cal.add(Calendar.MONTH, 1)
        val maxDays = cal.getActualMaximum(Calendar.DAY_OF_MONTH)
        cal.set(Calendar.DAY_OF_MONTH, minOf(targetDay, maxDays))
      }
      "Her yıl" -> {
        val targetDay = anchorDay ?: cal.get(Calendar.DAY_OF_MONTH)
        val targetMonth = cal.get(Calendar.MONTH)
        cal.set(Calendar.DAY_OF_MONTH, 1)
        cal.add(Calendar.YEAR, 1)
        cal.set(Calendar.MONTH, targetMonth)
        val maxDays = cal.getActualMaximum(Calendar.DAY_OF_MONTH)
        cal.set(Calendar.DAY_OF_MONTH, minOf(targetDay, maxDays))
      }
    }
  }

  /** Mirrors calculateNextDueDate(currentDueAt, repeatRule, fromDate, anchorDay). */
  fun nextDueDate(
    currentDueAtMs: Long,
    repeatRule: String?,
    fromDateMs: Long = System.currentTimeMillis(),
    anchorDay: Int? = null,
  ): Long? {
    val normalized = normalize(repeatRule) ?: return null
    val cal = Calendar.getInstance()
    cal.time = Date(currentDueAtMs)
    stepForward(cal, normalized, anchorDay)

    var iterations = 0
    while (cal.timeInMillis <= fromDateMs && iterations < 500) {
      stepForward(cal, normalized, anchorDay)
      iterations += 1
    }
    return cal.timeInMillis
  }
}
