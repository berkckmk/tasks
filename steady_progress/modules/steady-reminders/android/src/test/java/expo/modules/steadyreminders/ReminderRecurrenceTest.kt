package expo.modules.steadyreminders

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.util.Calendar

/**
 * Mirrors src/features/reminders/recurrence.test.ts fixtures (Sep 2026 dates)
 * so ReminderRecurrence.nextDueDate stays provably in lockstep with
 * calculateNextDueDate() — the two must agree, since ReminderCompletionWorker
 * uses this to advance a repeating reminder's dueAt when the app is fully
 * closed, exactly like ReminderRepository.setDone() does when the app is open.
 */
class ReminderRecurrenceTest {

  private fun cal(year: Int, month: Int, day: Int, hour: Int, minute: Int): Calendar =
    Calendar.getInstance().apply {
      clear()
      set(year, month, day, hour, minute, 0)
    }

  @Test
  fun `normalize maps aliases and returns standard rules`() {
    assertEquals("Her gün", ReminderRecurrence.normalize("Her gün"))
    assertEquals("Her gün", ReminderRecurrence.normalize("daily"))
    assertEquals("Hafta içi (Pzt-Cum)", ReminderRecurrence.normalize("Hafta içi"))
    assertEquals("Hafta içi (Pzt-Cum)", ReminderRecurrence.normalize("weekdays"))
    assertEquals("Her hafta", ReminderRecurrence.normalize("Her hafta"))
    assertEquals("Her hafta", ReminderRecurrence.normalize("weekly"))
    assertEquals("Her ay", ReminderRecurrence.normalize("Her ay"))
    assertEquals("Her ay", ReminderRecurrence.normalize("monthly"))
    assertEquals("Her yıl", ReminderRecurrence.normalize("Her yıl"))
    assertEquals("Her yıl", ReminderRecurrence.normalize("yearly"))
    assertNull(ReminderRecurrence.normalize("Tekrarlama"))
    assertNull(ReminderRecurrence.normalize(null))
  }

  @Test
  fun `Her gun advances 1 day preserving time`() {
    val current = cal(2026, 8, 11, 9, 30) // Sep 11, 2026 09:30 (month is 0-indexed)
    val now = cal(2026, 8, 11, 10, 0)
    val next = Calendar.getInstance().apply {
      timeInMillis = ReminderRecurrence.nextDueDate(current.timeInMillis, "Her gün", now.timeInMillis)!!
    }
    assertEquals(2026, next.get(Calendar.YEAR))
    assertEquals(8, next.get(Calendar.MONTH))
    assertEquals(12, next.get(Calendar.DAY_OF_MONTH))
    assertEquals(9, next.get(Calendar.HOUR_OF_DAY))
    assertEquals(30, next.get(Calendar.MINUTE))
  }

  @Test
  fun `Her gun advances past overdue dates to the future`() {
    val current = cal(2026, 8, 8, 9, 30) // 3 days overdue
    val now = cal(2026, 8, 11, 10, 0)
    val next = Calendar.getInstance().apply {
      timeInMillis = ReminderRecurrence.nextDueDate(current.timeInMillis, "Her gün", now.timeInMillis)!!
    }
    assertEquals(12, next.get(Calendar.DAY_OF_MONTH))
    assertEquals(9, next.get(Calendar.HOUR_OF_DAY))
  }

  @Test
  fun `Hafta ici skips weekends from Friday to Monday`() {
    val friday = cal(2026, 8, 11, 14, 0) // Sep 11, 2026 is a Friday
    val now = cal(2026, 8, 11, 15, 0)
    val next = Calendar.getInstance().apply {
      timeInMillis = ReminderRecurrence.nextDueDate(friday.timeInMillis, "Hafta içi (Pzt-Cum)", now.timeInMillis)!!
    }
    assertEquals(14, next.get(Calendar.DAY_OF_MONTH)) // Sep 14, 2026 is Monday
    assertEquals(Calendar.MONDAY, next.get(Calendar.DAY_OF_WEEK))
    assertEquals(14, next.get(Calendar.HOUR_OF_DAY))
  }

  @Test
  fun `Her hafta advances 7 days`() {
    val current = cal(2026, 8, 11, 10, 0)
    val now = cal(2026, 8, 11, 11, 0)
    val next = Calendar.getInstance().apply {
      timeInMillis = ReminderRecurrence.nextDueDate(current.timeInMillis, "Her hafta", now.timeInMillis)!!
    }
    assertEquals(18, next.get(Calendar.DAY_OF_MONTH))
    assertEquals(current.get(Calendar.DAY_OF_WEEK), next.get(Calendar.DAY_OF_WEEK))
  }

  @Test
  fun `Her ay advances 1 month clamping day overflow`() {
    val jan31 = cal(2026, 0, 31, 12, 0)
    val now = cal(2026, 0, 31, 13, 0)
    val next = Calendar.getInstance().apply {
      timeInMillis = ReminderRecurrence.nextDueDate(jan31.timeInMillis, "Her ay", now.timeInMillis)!!
    }
    assertEquals(1, next.get(Calendar.MONTH)) // Feb
    assertEquals(28, next.get(Calendar.DAY_OF_MONTH)) // Feb 28 (2026 not a leap year)
    assertEquals(12, next.get(Calendar.HOUR_OF_DAY))
  }

  @Test
  fun `Her yil advances 1 year`() {
    val current = cal(2026, 8, 11, 8, 0)
    val now = cal(2026, 8, 11, 9, 0)
    val next = Calendar.getInstance().apply {
      timeInMillis = ReminderRecurrence.nextDueDate(current.timeInMillis, "Her yıl", now.timeInMillis)!!
    }
    assertEquals(2027, next.get(Calendar.YEAR))
    assertEquals(8, next.get(Calendar.MONTH))
    assertEquals(11, next.get(Calendar.DAY_OF_MONTH))
    assertEquals(8, next.get(Calendar.HOUR_OF_DAY))
  }

  @Test
  fun `non-repeating rule returns null`() {
    val current = cal(2026, 8, 11, 9, 30)
    assertNull(ReminderRecurrence.nextDueDate(current.timeInMillis, "Tekrarlama"))
    assertNull(ReminderRecurrence.nextDueDate(current.timeInMillis, null))
  }

  @Test
  fun `Her ay keeps the anchor day after a short month`() {
    val feb = cal(2026, 1, 28, 9, 0) // Feb 28, clamped from Jan 31
    val now = cal(2026, 1, 28, 10, 0)
    val next = Calendar.getInstance().apply {
      timeInMillis = ReminderRecurrence.nextDueDate(feb.timeInMillis, "Her ay", now.timeInMillis, 31)!!
    }
    assertEquals(2, next.get(Calendar.MONTH))
    assertEquals(31, next.get(Calendar.DAY_OF_MONTH))
  }

  @Test
  fun `completedOccurrenceMs reads occurrences and ignores malformed entries`() {
    val day28 = cal(2026, 8, 28, 9, 0).time
    val day29 = cal(2026, 8, 29, 9, 0).time
    val raw = listOf(
      mapOf("occurrence" to day28, "completedAt" to day28),
      mapOf("occurrence" to day29),
      "not a map",
      mapOf("completedAt" to day29),
    )
    assertEquals(setOf(day28.time, day29.time), ReminderCompletionWorker.completedOccurrenceMs(raw))
    assertEquals(emptySet<Long>(), ReminderCompletionWorker.completedOccurrenceMs(null))
  }
}
