package com.steadyprogress.steady_progress.widget

import android.graphics.Color

/**
 * One card in the widget's carousel.
 *
 * The carousel always opens on [Today]; the three section pages appear only
 * when they have something to show, so a user with no reminders never scrolls
 * into an empty "Reminders" card.
 */
sealed interface WidgetPage {

    data object Today : WidgetPage

    data class Section(
        val title: String,
        val items: List<WidgetItem>,
        val accent: Int,
        /** Shown top-right, e.g. "5/7". Null hides the counter. */
        val counter: String?,
        val style: Style,
    ) : WidgetPage {
        enum class Style { CHECKLIST, PROGRESS }
    }

    companion object {
        /**
         * How many times the page set repeats in the carousel.
         *
         * ListView has no looping mode, so "infinite" is a large repeated
         * range: enough that a user never reaches an end, small enough that
         * the adapter stays cheap. Rows are built on demand, so only the
         * handful on screen ever exist.
         */
        const val CAROUSEL_LOOPS = 500

        private val DEEP_GREEN = Color.rgb(0x2F, 0x52, 0x33)
        private val MUTED_BLUE = Color.rgb(0x5C, 0x7A, 0x99)
        private val AMBER = Color.rgb(0xC9, 0x8A, 0x3E)

        /**
         * The pages this snapshot can fill, in carousel order.
         *
         * Never empty: [Today] always renders, even with no data at all, so
         * the list always has something to show and the widget never appears
         * broken on a fresh install.
         */
        fun pagesFor(data: WidgetData): List<WidgetPage> = buildList {
            add(Today)
            if (data.habits.isNotEmpty()) {
                add(
                    Section(
                        title = "Habits",
                        items = data.habits,
                        accent = DEEP_GREEN,
                        counter = "${data.habitsDone}/${data.habitsTotal}",
                        style = Section.Style.CHECKLIST,
                    ),
                )
            }
            if (data.tasks.isNotEmpty()) {
                add(
                    Section(
                        title = "Tasks",
                        items = data.tasks,
                        accent = MUTED_BLUE,
                        counter = "${data.tasksDone}/${data.tasksTotal}",
                        style = Section.Style.CHECKLIST,
                    ),
                )
            }
            if (data.reminders.isNotEmpty()) {
                add(
                    Section(
                        title = "Reminders",
                        items = data.reminders,
                        accent = AMBER,
                        counter = null,
                        style = Section.Style.PROGRESS,
                    ),
                )
            }
        }
    }
}
