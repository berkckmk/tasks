package com.steadyprogress.steady_progress.widget

import android.app.Activity
import android.app.AlertDialog
import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.appwidget.AppWidgetManager
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import com.steadyprogress.steady_progress.R
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * The quick-add modal behind the widget's `+`.
 *
 * ## Why the `+` no longer opens the app
 *
 * It used to fire a `PendingIntent` at `MainActivity` with `/reminders/new`.
 * That is a cold start, a route push and a full-screen form for what is
 * usually one line of text — and it takes the home screen away, which is the
 * surface the user was already looking at. This is the same intent as a
 * translucent Activity over a 50% scrim.
 *
 * ## What it collects
 *
 * A title, an area, and a schedule — and the schedule rules are the app's, not
 * a simplified copy of them:
 *
 *  - **Reminder: a date *and* a time, both required.** A reminder with no
 *    moment cannot fire, and because `watchReminders` orders by `dueAt` and
 *    Firestore omits documents missing the field a query orders on, one saved
 *    without it would not even be listed.
 *  - **Task: a date range, time optional.** Start and end are picked in turn;
 *    picking the same day twice is an ordinary single-day task. No time means
 *    all day, which is what the row then says.
 *  - **Habit: time only, optional.** A habit has no date — it recurs.
 *
 * Times are pinned to AM/PM (`is24HourView = false`), matching the app.
 *
 * ## Why it queues rather than writes
 *
 * The widget process has no auth session and never touches Firestore. A task
 * in particular *cannot* be created directly at all: `firestore.rules` denies
 * `create` on the collection and creation goes through the `createTask` Cloud
 * Function, which is where the plan's active-task limit lives.
 *
 * So this writes a durable intent to [WidgetPendingAdds] and an optimistic row
 * to [WidgetDataStore], and the app creates it for real on its next start or
 * resume — see `HomeWidgetSync`. The toast says as much rather than implying
 * the item has reached the account, because until then it has not.
 */
class WidgetQuickAddActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var kind = WidgetItemKind.REMINDER
    private val chips = mutableMapOf<WidgetItemKind, View>()

    /** The moment, or the range's first day. Null until picked. */
    private var startAt: Calendar? = null

    /** The range's last day. Only ever set for a task. */
    private var endAt: Calendar? = null

    /** No clock time was chosen. Always true for an untimed task. */
    private var allDay = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        appWidgetId = intent?.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        setContentView(R.layout.widget_quick_add)

        // The default area follows the widget's own scope, so a Tasks widget's
        // `+` composes a task. Today defaults to a reminder for the same
        // reason the old route did.
        kind = when (WidgetConfigStore.read(this, appWidgetId).scope) {
            WidgetScope.TASKS -> WidgetItemKind.TASK
            WidgetScope.REMINDERS -> WidgetItemKind.REMINDER
            WidgetScope.TODAY -> WidgetItemKind.REMINDER
        }

        val input = findViewById<EditText>(R.id.add_input)
        val kinds = findViewById<LinearLayout>(R.id.add_kinds)

        for (entry in WidgetItemKind.entries) {
            val chip = chip(entry)
            chips[entry] = chip
            kinds.addView(chip)
        }
        paintChips()
        paintWhen()

        findViewById<View>(R.id.add_when_row).setOnClickListener { pickSchedule() }
        findViewById<View>(R.id.add_confirm).setOnClickListener { commit(input) }
        findViewById<View>(R.id.add_cancel).setOnClickListener { finish() }
        // Tapping the scrim dismisses, like the scope picker. The panel eats
        // its own taps so a miss inside it doesn't close a half-typed line.
        findViewById<View>(R.id.add_scrim).setOnClickListener { finish() }
        findViewById<View>(R.id.add_panel).setOnClickListener { }

        // The field is the whole point of the modal, so it opens focused with
        // the keyboard already up rather than costing an extra tap.
        input.requestFocus()
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE)
    }

    // ---- area -------------------------------------------------------------

    private fun chip(entry: WidgetItemKind): View {
        val chip = layoutInflater.inflate(R.layout.widget_quick_add_kind, null) as LinearLayout
        chip.findViewById<TextView>(R.id.kind_chip_label).text = entry.label
        chip.findViewById<ImageView>(R.id.kind_chip_icon).setImageResource(iconFor(entry))
        chip.layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply {
            marginEnd = resources.getDimensionPixelSize(R.dimen.widget_chip_gap)
        }
        chip.setOnClickListener {
            if (kind == entry) return@setOnClickListener
            kind = entry
            // The schedule means different things per area — a habit has no
            // date at all — so switching area drops what was picked rather
            // than carrying over a value the new area cannot express.
            startAt = null
            endAt = null
            allDay = true
            paintChips()
            paintWhen()
        }
        return chip
    }

    private fun iconFor(entry: WidgetItemKind): Int = when (entry) {
        WidgetItemKind.REMINDER -> R.drawable.widget_kind_reminder
        WidgetItemKind.TASK -> R.drawable.widget_kind_task
        WidgetItemKind.HABIT -> R.drawable.widget_kind_habit
    }

    /** Selection state for all three at once — a chip can only be drawn
     *  unselected by the same pass that selects another. */
    private fun paintChips() {
        for ((entry, chip) in chips) {
            val selected = entry == kind
            chip.setBackgroundResource(
                if (selected) R.drawable.widget_chip_selected else R.drawable.widget_outline_pill,
            )
            chip.findViewById<TextView>(R.id.kind_chip_label).setTextColor(
                if (selected) WidgetPalette.INK_ACCENT else WidgetPalette.TEXT,
            )
            chip.findViewById<ImageView>(R.id.kind_chip_icon).apply {
                setColorFilter(if (selected) WidgetPalette.INK_ACCENT else WidgetPalette.TEXT)
                // SRC_ATOP ignores a filter's alpha, so an unselected chip's
                // icon is muted with imageAlpha, not with a faded colour.
                imageAlpha = if (selected) WidgetPalette.ALPHA_FULL else WidgetPalette.ALPHA_TYPE
            }
        }
        findViewById<ImageView>(R.id.add_area_icon).apply {
            setImageResource(iconFor(kind))
            setColorFilter(WidgetPalette.TEXT)
            imageAlpha = WidgetPalette.ALPHA_TYPE
        }
    }

    // ---- schedule ---------------------------------------------------------

    /**
     * Runs the pickers the current area needs, in order, each one opening
     * only if the previous was answered. Cancelling anywhere leaves what was
     * already chosen rather than half-writing a schedule.
     */
    private fun pickSchedule() {
        when (kind) {
            WidgetItemKind.REMINDER -> pickDate(startAt) { date ->
                pickTime(date) { withTime ->
                    startAt = withTime
                    endAt = null
                    allDay = false
                    paintWhen()
                }
            }
            WidgetItemKind.TASK -> pickDate(startAt, R.string.widget_add_range_start) { start ->
                pickDate(endAt ?: start, R.string.widget_add_range_end) { end ->
                    // A backwards range is a mis-tap, not an intent. The later
                    // of the two is the deadline either way.
                    val ordered = if (end.before(start)) start to end else start to end
                    startAt = minOf(ordered.first.timeInMillis, ordered.second.timeInMillis)
                        .let { calendarOf(it) }
                    val last = maxOf(start.timeInMillis, end.timeInMillis).let { calendarOf(it) }
                    askForTime(last) { timed ->
                        endAt = timed ?: last
                        allDay = timed == null
                        paintWhen()
                    }
                }
            }
            WidgetItemKind.HABIT -> askForTime(startAt ?: nowAtHour()) { timed ->
                startAt = timed
                endAt = null
                allDay = timed == null
                paintWhen()
            }
        }
    }

    private fun pickDate(
        initial: Calendar?,
        titleRes: Int? = null,
        onPicked: (Calendar) -> Unit,
    ) {
        val base = initial ?: Calendar.getInstance()
        val dialog = DatePickerDialog(
            this,
            { _, year, month, day ->
                onPicked(
                    Calendar.getInstance().apply {
                        timeInMillis = base.timeInMillis
                        set(Calendar.YEAR, year)
                        set(Calendar.MONTH, month)
                        set(Calendar.DAY_OF_MONTH, day)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                    },
                )
            },
            base.get(Calendar.YEAR),
            base.get(Calendar.MONTH),
            base.get(Calendar.DAY_OF_MONTH),
        )
        if (titleRes != null) dialog.setTitle(titleRes)
        dialog.show()
    }

    /** AM/PM, always — `is24HourView = false` regardless of the device clock,
     *  which is how every reminder time in the app is now written. */
    private fun pickTime(day: Calendar, onPicked: (Calendar) -> Unit) {
        TimePickerDialog(
            this,
            { _, hour, minute ->
                onPicked(
                    Calendar.getInstance().apply {
                        timeInMillis = day.timeInMillis
                        set(Calendar.HOUR_OF_DAY, hour)
                        set(Calendar.MINUTE, minute)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                    },
                )
            },
            day.get(Calendar.HOUR_OF_DAY),
            day.get(Calendar.MINUTE),
            false,
        ).show()
    }

    /** The optional-time step: "All day" is an answer, not a cancel. */
    private fun askForTime(day: Calendar, onAnswered: (Calendar?) -> Unit) {
        AlertDialog.Builder(this)
            .setTitle(R.string.widget_add_time_prompt)
            .setNegativeButton(R.string.widget_add_all_day) { _, _ -> onAnswered(null) }
            .setPositiveButton(R.string.widget_add_time_pick) { _, _ ->
                pickTime(day) { onAnswered(it) }
            }
            .show()
    }

    private fun calendarOf(millis: Long): Calendar =
        Calendar.getInstance().apply { timeInMillis = millis }

    private fun nowAtHour(): Calendar = Calendar.getInstance().apply {
        add(Calendar.HOUR_OF_DAY, 1)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }

    /**
     * The when-row's line: "Wed 3 Sep · 6:00 PM", "3 Sep – 7 Sep · All day",
     * or the prompt while nothing is picked. Accent once a moment is set, so
     * the row reads as answered at a glance.
     */
    private fun paintWhen() {
        val label = findViewById<TextView>(R.id.add_when_label)
        val icon = findViewById<ImageView>(R.id.add_when_icon)
        val start = startAt

        val text = when {
            start == null && kind == WidgetItemKind.HABIT ->
                getString(R.string.widget_add_all_day)
            start == null -> getString(R.string.widget_add_when_empty)
            kind == WidgetItemKind.HABIT -> timeFormat.format(start.time)
            else -> {
                val end = endAt
                val dates = if (end == null || sameDay(start, end)) {
                    dayFormat.format(start.time)
                } else {
                    "${dayFormat.format(start.time)} – ${dayFormat.format(end.time)}"
                }
                val moment = if (allDay) {
                    getString(R.string.widget_add_all_day)
                } else {
                    timeFormat.format((end ?: start).time)
                }
                "$dates · $moment"
            }
        }

        label.text = text
        val answered = start != null || kind == WidgetItemKind.HABIT
        label.setTextColor(
            if (start != null) WidgetPalette.INK_ACCENT else WidgetPalette.TEXT_CAPTION,
        )
        icon.setColorFilter(if (start != null) WidgetPalette.INK_ACCENT else WidgetPalette.TEXT)
        icon.imageAlpha = if (answered) WidgetPalette.ALPHA_FULL else WidgetPalette.ALPHA_TYPE
    }

    private fun sameDay(a: Calendar, b: Calendar): Boolean =
        a.get(Calendar.YEAR) == b.get(Calendar.YEAR) &&
            a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)

    // ---- commit -----------------------------------------------------------

    private fun commit(input: EditText) {
        val label = input.text.toString().trim()
        // An empty line is not an item. Nothing is queued and nothing is
        // said — the field is still there and still focused.
        if (label.isEmpty()) return

        // A reminder and a task both need a date before they can be created;
        // the app would reject them for the same reason. Said here rather
        // than discovered on the next app launch.
        if (kind != WidgetItemKind.HABIT && startAt == null) {
            Toast.makeText(this, R.string.widget_add_when_needed, Toast.LENGTH_SHORT).show()
            pickSchedule()
            return
        }

        val id = WidgetPendingAdds.ID_PREFIX + System.currentTimeMillis()
        WidgetPendingAdds.enqueue(
            this,
            PendingAdd(
                id = id,
                kind = kind,
                label = label,
                startAt = startAt?.timeInMillis,
                endAt = endAt?.timeInMillis,
                allDay = allDay,
                at = System.currentTimeMillis(),
            ),
        )
        WidgetDataStore.addLocally(
            this,
            WidgetItem(
                id = id,
                kind = kind,
                label = label,
                // The row's time column, on the same rule the pushed snapshot
                // uses: a timed item shows its time, an all-day one shows
                // nothing rather than a fabricated midnight.
                time = if (allDay || startAt == null) {
                    ""
                } else {
                    timeFormat.format((endAt ?: startAt)!!.time)
                },
            ),
        )
        SteadyProgressWidgetProvider.refreshAll(this)

        Toast.makeText(this, R.string.widget_add_queued, Toast.LENGTH_SHORT).show()
        finish()
    }

    private companion object {
        /** AM/PM, and the day without a year — the modal never schedules far
         *  enough out for one to be useful. */
        val timeFormat = SimpleDateFormat("h:mm a", Locale.getDefault())
        val dayFormat = SimpleDateFormat("EEE d MMM", Locale.getDefault())
    }
}
