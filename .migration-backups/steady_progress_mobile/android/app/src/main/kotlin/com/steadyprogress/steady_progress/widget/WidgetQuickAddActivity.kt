package com.steadyprogress.steady_progress.widget

import android.app.Activity
import android.app.AlertDialog
import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.appwidget.AppWidgetManager
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.view.WindowManager
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.Switch
import android.widget.TextView
import android.widget.Toast
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.steadyprogress.steady_progress.R
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/**
 * Full-featured creation modal opened from the widget's `+` button.
 * Adapts its controls and fields dynamically based on the selected item kind:
 * - Reminder: Title, Note/Message, Date & 24h Time, Recurrence, Sesli Alarm (Important).
 * - Task: Title, Description, Date range & 24h Time, Priority, Recurrence.
 * - Habit: Name, Category, Frequency, Reminder Time (24h), Color palette.
 *
 * Uses 24-hour time format with Europe/Istanbul timezone.
 */
class WidgetQuickAddActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var kind = WidgetItemKind.REMINDER
    private val kindChips = mutableMapOf<WidgetItemKind, View>()

    /** Moment or start of range. */
    private var startAt: Calendar? = null

    /** End of range (for tasks). */
    private var endAt: Calendar? = null

    /** All-day flag. True when no clock time is set. */
    private var allDay = true

    // Task state
    private var selectedPriority: String = "medium"
    private var selectedTaskRepeat: String = "Tek seferlik"

    // Reminder state
    private var selectedReminderRepeat: String = "Tek seferlik"

    // Habit state
    private var selectedHabitCategory: String = "morning"
    private var selectedHabitFrequency: String = "Daily"
    private var selectedHabitColor: Long = 0xFF9E86FFL

    private lateinit var scrim: View
    private lateinit var panel: View
    private lateinit var titleHeader: TextView
    private lateinit var inputTitle: EditText
    private lateinit var descContainer: View
    private lateinit var inputDesc: EditText
    private lateinit var sectionTask: LinearLayout
    private lateinit var sectionReminder: LinearLayout
    private lateinit var sectionHabit: LinearLayout
    private lateinit var switchImportant: Switch

    private var imeInsetBottom = 0
    private var systemInsetTop = 0
    private val visibleWindowFrame = Rect()
    private val rootLocation = IntArray(2)

    private val keyboardLayoutListener = ViewTreeObserver.OnGlobalLayoutListener {
        repositionPanelForKeyboard()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        appWidgetId = intent?.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        setContentView(R.layout.widget_quick_add)

        scrim = findViewById(R.id.add_scrim)
        panel = findViewById(R.id.add_panel)
        titleHeader = findViewById(R.id.add_title)
        inputTitle = findViewById(R.id.add_input)
        descContainer = findViewById(R.id.add_description_container)
        inputDesc = findViewById(R.id.add_description)
        sectionTask = findViewById(R.id.section_task_controls)
        sectionReminder = findViewById(R.id.section_reminder_controls)
        sectionHabit = findViewById(R.id.section_habit_controls)
        switchImportant = findViewById(R.id.add_important_switch)

        installKeyboardAvoidance()

        // Default area follows current widget scope
        kind = when (WidgetConfigStore.read(this, appWidgetId).scope) {
            WidgetScope.TASKS -> WidgetItemKind.TASK
            WidgetScope.REMINDERS -> WidgetItemKind.REMINDER
            WidgetScope.TODAY -> WidgetItemKind.REMINDER
        }

        // 1. Build Kind Selector Chips at top
        val kindsContainer = findViewById<LinearLayout>(R.id.add_kinds)
        for (entry in WidgetItemKind.entries) {
            val chip = buildKindChip(entry)
            kindChips[entry] = chip
            kindsContainer.addView(chip)
        }

        // 2. Build Sub-options (Priorities, Repeats, Categories, Colors)
        buildTaskControls()
        buildReminderControls()
        buildHabitControls()

        // 3. Setup Listeners
        findViewById<View>(R.id.add_when_row).setOnClickListener { pickSchedule() }
        findViewById<View>(R.id.add_confirm).setOnClickListener { commit() }
        findViewById<View>(R.id.add_cancel).setOnClickListener { finish() }
        scrim.setOnClickListener { finish() }
        panel.setOnClickListener { }

        // 4. Initial paint
        updateFormForKind()

        inputTitle.requestFocus()
        window.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE or
                WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE,
        )
    }

    override fun onDestroy() {
        if (::scrim.isInitialized) {
            scrim.viewTreeObserver.removeOnGlobalLayoutListener(keyboardLayoutListener)
        }
        super.onDestroy()
    }

    private fun installKeyboardAvoidance() {
        ViewCompat.setOnApplyWindowInsetsListener(scrim) { _, insets ->
            imeInsetBottom = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom
            systemInsetTop = insets.getInsets(
                WindowInsetsCompat.Type.statusBars() or
                    WindowInsetsCompat.Type.displayCutout(),
            ).top
            scrim.post(::repositionPanelForKeyboard)
            insets
        }
        scrim.viewTreeObserver.addOnGlobalLayoutListener(keyboardLayoutListener)
        ViewCompat.requestApplyInsets(scrim)
    }

    private fun repositionPanelForKeyboard() {
        if (!::scrim.isInitialized || !::panel.isInitialized || scrim.height == 0) return

        scrim.getWindowVisibleDisplayFrame(visibleWindowFrame)
        scrim.getLocationOnScreen(rootLocation)
        val visibleBottomInRoot =
            (visibleWindowFrame.bottom - rootLocation[1]).coerceIn(0, scrim.height)
        val frameInsetBottom = (scrim.height - visibleBottomInRoot).coerceAtLeast(0)
        val keyboardInset = maxOf(imeInsetBottom, frameInsetBottom)

        val gap = resources.getDimensionPixelSize(R.dimen.widget_modal_keyboard_gap)
        val visibleBottom = scrim.height - keyboardInset - gap
        val minimumTop = systemInsetTop + gap
        val requiredShift = (panel.bottom - visibleBottom).coerceAtLeast(0)
        val availableShift = (panel.top - minimumTop).coerceAtLeast(0)

        panel.translationY = -minOf(requiredShift, availableShift).toFloat()
    }

    // ---- Mode / Kind Selection ---------------------------------------------

    private fun buildKindChip(entry: WidgetItemKind): View {
        val chip = layoutInflater.inflate(R.layout.widget_quick_add_kind, null) as LinearLayout
        val label = when (entry) {
            WidgetItemKind.REMINDER -> "Hatırlatıcı"
            WidgetItemKind.TASK -> "Görev"
            WidgetItemKind.HABIT -> "Alışkanlık"
        }
        chip.findViewById<TextView>(R.id.kind_chip_label).text = label
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
            startAt = null
            endAt = null
            allDay = true
            updateFormForKind()
        }
        return chip
    }

    private fun updateFormForKind() {
        // 1. Paint top kind chips
        for ((entry, chip) in kindChips) {
            val selected = entry == kind
            val (activeTextColor, categoryColor) = when (entry) {
                WidgetItemKind.REMINDER -> 0xFF6242DE.toInt() to 0xFF9E86FF.toInt()
                WidgetItemKind.TASK -> 0xFFB32598.toInt() to 0xFFFF86EC.toInt()
                WidgetItemKind.HABIT -> 0xFF1B7A48.toInt() to 0xFF86E6B0.toInt()
            }
            chip.setBackgroundResource(
                if (selected) R.drawable.widget_chip_selected else R.drawable.widget_outline_pill,
            )
            chip.findViewById<TextView>(R.id.kind_chip_label).setTextColor(
                if (selected) activeTextColor else 0xFF6F6A63.toInt(),
            )
            chip.findViewById<ImageView>(R.id.kind_chip_icon).apply {
                setColorFilter(if (selected) categoryColor else 0xFF969087.toInt())
                imageAlpha = if (selected) 255 else 180
            }
        }

        // 2. Update Title & Hints
        when (kind) {
            WidgetItemKind.TASK -> {
                titleHeader.setText(R.string.widget_add_title_task)
                inputTitle.setHint(R.string.widget_add_hint_task)
                descContainer.visibility = View.VISIBLE
                sectionTask.visibility = View.VISIBLE
                sectionReminder.visibility = View.GONE
                sectionHabit.visibility = View.GONE
            }
            WidgetItemKind.REMINDER -> {
                titleHeader.setText(R.string.widget_add_title_reminder)
                inputTitle.setHint(R.string.widget_add_hint_reminder)
                descContainer.visibility = View.VISIBLE
                sectionTask.visibility = View.GONE
                sectionReminder.visibility = View.VISIBLE
                sectionHabit.visibility = View.GONE
            }
            WidgetItemKind.HABIT -> {
                titleHeader.setText(R.string.widget_add_title_habit)
                inputTitle.setHint(R.string.widget_add_hint_habit)
                descContainer.visibility = View.GONE
                sectionTask.visibility = View.GONE
                sectionReminder.visibility = View.GONE
                sectionHabit.visibility = View.VISIBLE
            }
        }

        paintWhen()
    }

    private fun iconFor(entry: WidgetItemKind): Int = when (entry) {
        WidgetItemKind.REMINDER -> R.drawable.widget_kind_reminder
        WidgetItemKind.TASK -> R.drawable.widget_kind_task
        WidgetItemKind.HABIT -> R.drawable.widget_kind_habit
    }

    // ---- Sub-options Builders ----------------------------------------------

    private fun buildTaskControls() {
        val priorityContainer = findViewById<LinearLayout>(R.id.task_priority_chips)
        priorityContainer.removeAllViews()
        val priorities = listOf(
            "low" to getString(R.string.widget_priority_low),
            "medium" to getString(R.string.widget_priority_medium),
            "high" to getString(R.string.widget_priority_high),
        )
        for ((value, label) in priorities) {
            val chip = createTextPill(label) {
                selectedPriority = value
                buildTaskControls()
            }
            stylePill(chip, selectedPriority == value, 0xFFFF86EC.toInt(), 0xFFB32598.toInt())
            priorityContainer.addView(chip)
        }

        val repeatContainer = findViewById<LinearLayout>(R.id.task_repeat_chips)
        repeatContainer.removeAllViews()
        val repeats = listOf(
            getString(R.string.widget_repeat_none),
            getString(R.string.widget_repeat_daily),
            getString(R.string.widget_repeat_weekdays),
            getString(R.string.widget_repeat_weekly),
            getString(R.string.widget_repeat_monthly),
        )
        for (item in repeats) {
            val chip = createTextPill(item) {
                selectedTaskRepeat = item
                buildTaskControls()
            }
            stylePill(chip, selectedTaskRepeat == item, 0xFFFF86EC.toInt(), 0xFFB32598.toInt())
            repeatContainer.addView(chip)
        }
    }

    private fun buildReminderControls() {
        val repeatContainer = findViewById<LinearLayout>(R.id.reminder_repeat_chips)
        repeatContainer.removeAllViews()
        val repeats = listOf(
            getString(R.string.widget_repeat_none),
            getString(R.string.widget_repeat_daily),
            getString(R.string.widget_repeat_weekdays),
            getString(R.string.widget_repeat_weekly),
            getString(R.string.widget_repeat_monthly),
        )
        for (item in repeats) {
            val chip = createTextPill(item) {
                selectedReminderRepeat = item
                buildReminderControls()
            }
            stylePill(chip, selectedReminderRepeat == item, 0xFF9E86FF.toInt(), 0xFF6242DE.toInt())
            repeatContainer.addView(chip)
        }
    }

    private fun buildHabitControls() {
        // Categories: morning, daily, evening, health
        val catContainer = findViewById<LinearLayout>(R.id.habit_category_chips)
        catContainer.removeAllViews()
        val categories = listOf(
            "morning" to getString(R.string.widget_habit_cat_morning),
            "daily" to getString(R.string.widget_habit_cat_daily),
            "evening" to getString(R.string.widget_habit_cat_evening),
            "health" to getString(R.string.widget_habit_cat_health),
        )
        for ((key, label) in categories) {
            val chip = createTextPill(label) {
                selectedHabitCategory = key
                buildHabitControls()
            }
            stylePill(chip, selectedHabitCategory == key, 0xFF86E6B0.toInt(), 0xFF1B7A48.toInt())
            catContainer.addView(chip)
        }

        // Frequencies: Daily, Weekdays, Weekends
        val freqContainer = findViewById<LinearLayout>(R.id.habit_frequency_chips)
        freqContainer.removeAllViews()
        val frequencies = listOf(
            "Daily" to getString(R.string.widget_habit_freq_daily),
            "Weekdays" to getString(R.string.widget_habit_freq_weekdays),
            "Weekends" to getString(R.string.widget_habit_freq_weekends),
        )
        for ((key, label) in frequencies) {
            val chip = createTextPill(label) {
                selectedHabitFrequency = key
                buildHabitControls()
            }
            stylePill(chip, selectedHabitFrequency == key, 0xFF86E6B0.toInt(), 0xFF1B7A48.toInt())
            freqContainer.addView(chip)
        }

        // Color dots
        val colorContainer = findViewById<LinearLayout>(R.id.habit_color_dots)
        colorContainer.removeAllViews()
        val colors = listOf(
            0xFF9E86FFL, // Purple
            0xFFFF86ECL, // Pink
            0xFF86E6B0L, // Green
            0xFF64B5F6L, // Blue
            0xFFFFB74DL, // Orange
        )
        for (col in colors) {
            val dot = View(this).apply {
                val size = (resources.displayMetrics.density * 26).toInt()
                layoutParams = LinearLayout.LayoutParams(size, size).apply {
                    marginEnd = (resources.displayMetrics.density * 10).toInt()
                }
                val isSelected = selectedHabitColor == col
                val drawable = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(col.toInt())
                    if (isSelected) {
                        setStroke((resources.displayMetrics.density * 2.5f).toInt(), 0xFF292724.toInt())
                    }
                }
                background = drawable
                setOnClickListener {
                    selectedHabitColor = col
                    buildHabitControls()
                }
            }
            colorContainer.addView(dot)
        }
    }

    private fun createTextPill(text: String, onClick: () -> Unit): TextView {
        return TextView(this).apply {
            this.text = text
            textSize = 13f
            typeface = android.graphics.Typeface.DEFAULT
            gravity = Gravity.CENTER
            setPadding(
                (resources.displayMetrics.density * 12).toInt(),
                (resources.displayMetrics.density * 6).toInt(),
                (resources.displayMetrics.density * 12).toInt(),
                (resources.displayMetrics.density * 6).toInt(),
            )
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                marginEnd = (resources.displayMetrics.density * 6).toInt()
            }
            setOnClickListener { onClick() }
        }
    }

    private fun stylePill(textView: TextView, isSelected: Boolean, activeBg: Int, activeText: Int) {
        if (isSelected) {
            val drawable = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 999f
                setColor(0xFFF0ECE5.toInt())
                setStroke((resources.displayMetrics.density * 1.5f).toInt(), activeText)
            }
            textView.background = drawable
            textView.setTextColor(activeText)
        } else {
            val drawable = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 999f
                setColor(Color.TRANSPARENT)
                setStroke((resources.displayMetrics.density * 1f).toInt(), 0xFFD6D0C6.toInt())
            }
            textView.background = drawable
            textView.setTextColor(0xFF6F6A63.toInt())
        }
    }

    // ---- Schedule / When ---------------------------------------------------

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
        val base = initial ?: Calendar.getInstance(istanbulZone, trLocale)
        val dialog = DatePickerDialog(
            this,
            { _, year, month, day ->
                onPicked(
                    Calendar.getInstance(istanbulZone, trLocale).apply {
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

    /** 24-hour time picker with Europe/Istanbul timezone. */
    private fun pickTime(day: Calendar, onPicked: (Calendar) -> Unit) {
        TimePickerDialog(
            this,
            { _, hour, minute ->
                onPicked(
                    Calendar.getInstance(istanbulZone, trLocale).apply {
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
            true, // 24-hour view!
        ).show()
    }

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
        Calendar.getInstance(istanbulZone, trLocale).apply { timeInMillis = millis }

    private fun nowAtHour(): Calendar = Calendar.getInstance(istanbulZone, trLocale).apply {
        add(Calendar.HOUR_OF_DAY, 1)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }

    private fun paintWhen() {
        val label = findViewById<TextView>(R.id.add_when_label)
        val icon = findViewById<ImageView>(R.id.add_when_icon)
        val start = startAt

        val text = when {
            start == null && kind == WidgetItemKind.HABIT ->
                getString(R.string.widget_habit_time_label)
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
            if (start != null) 0xFF292724.toInt() else 0xFF969087.toInt(),
        )
        icon.setColorFilter(if (start != null) 0xFF292724.toInt() else 0xFF969087.toInt())
        icon.imageAlpha = if (answered) 255 else 180
    }

    private fun sameDay(a: Calendar, b: Calendar): Boolean =
        a.get(Calendar.YEAR) == b.get(Calendar.YEAR) &&
            a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)

    // ---- Commit ------------------------------------------------------------

    private fun commit() {
        val label = inputTitle.text.toString().trim()
        if (label.isEmpty()) return

        if (kind != WidgetItemKind.HABIT && startAt == null) {
            Toast.makeText(this, R.string.widget_add_when_needed, Toast.LENGTH_SHORT).show()
            pickSchedule()
            return
        }

        val desc = inputDesc.text?.toString()?.trim().orEmpty()
        val id = WidgetPendingAdds.ID_PREFIX + System.currentTimeMillis()

        val repeat = when (kind) {
            WidgetItemKind.TASK -> selectedTaskRepeat
            WidgetItemKind.REMINDER -> selectedReminderRepeat
            WidgetItemKind.HABIT -> ""
        }

        val important = if (kind == WidgetItemKind.REMINDER) switchImportant.isChecked else false

        val pendingAdd = PendingAdd(
            id = id,
            kind = kind,
            label = label,
            startAt = startAt?.timeInMillis,
            endAt = endAt?.timeInMillis,
            allDay = allDay,
            at = System.currentTimeMillis(),
            description = desc,
            priority = selectedPriority,
            repeatRule = repeat,
            isImportant = important,
            category = selectedHabitCategory,
            frequency = selectedHabitFrequency,
            color = selectedHabitColor,
        )

        // 1. Enqueue to durable SharedPreferences queue for React Native drain
        WidgetPendingAdds.enqueue(this, pendingAdd)

        // 2. Add an optimistic row to the active widget store (single source of
        // truth for the currently rendered widget) so the new item shows up
        // instantly, then refresh the widget to display it.
        val displayTime = if (allDay || startAt == null) {
            ""
        } else {
            timeFormat.format((endAt ?: startAt)!!.time)
        }

        try {
            val modernType = when (kind) {
                WidgetItemKind.REMINDER -> "reminder"
                WidgetItemKind.TASK -> "task"
                WidgetItemKind.HABIT -> "habit"
            }
            expo.modules.steadywidget.WidgetStore.addItem(
                this,
                expo.modules.steadywidget.WidgetItem(
                    id = id,
                    type = modernType,
                    title = label,
                    time = displayTime,
                    completed = false,
                ),
            )
            expo.modules.steadywidget.WidgetRenderer.renderAll(this)
        } catch (_: Exception) {}

        Toast.makeText(this, R.string.widget_add_queued, Toast.LENGTH_SHORT).show()
        finish()
    }

    private companion object {
        val istanbulZone: TimeZone = TimeZone.getTimeZone("Europe/Istanbul")
        val trLocale: Locale = Locale.forLanguageTag("tr-TR")

        /** 24-hour time format in Europe/Istanbul timezone. */
        val timeFormat = SimpleDateFormat("HH:mm", trLocale).apply {
            timeZone = istanbulZone
        }

        val dayFormat = SimpleDateFormat("EEE d MMM", trLocale).apply {
            timeZone = istanbulZone
        }
    }
}
