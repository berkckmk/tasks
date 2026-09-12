package com.steadyprogress.steady_progress.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.steadyprogress.steady_progress.R

/**
 * The scope picker: **Today · Reminders · Tasks**.
 *
 * ## Why this is an Activity
 *
 * RemoteViews has no popup, no menu and no `Spinner`, so a widget cannot open
 * a chooser of its own. The header chip fires a `PendingIntent` into this —
 * a transparent, no-title Activity that draws the panel where the chip is,
 * writes the choice for its `appWidgetId`, and finishes.
 *
 * ## What it replaces
 *
 * The old top-left tap target, which cycled through single fields and had no
 * path back to the multi-field panel: once you left "everything", you could
 * only reach it again by walking the whole cycle, and it was invisible — the
 * affordance was painted into the bitmap. Three states, all mutually
 * reachable, and a chip you can see.
 *
 * The panel is anchored at `left: 13dp, top: 32dp` relative to the widget's
 * own panel — directly under the chip it came from — and sized to its labels.
 * It must not overflow the widget's bounds, which is why nothing pads it out
 * to a dialog width.
 */
class WidgetScopePickerActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        appWidgetId = intent?.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.widget_scope_picker)

        val current = WidgetConfigStore.read(this, appWidgetId).scope
        val panel = findViewById<LinearLayout>(R.id.picker_panel)

        // Anchored so the popup's own top-left lands on the chip that opened
        // it, rather than in the screen's corner.
        //
        // **The launcher never tells an app where its widget sits.**
        // `getAppWidgetOptions` reports the size and never the position, and
        // a `PendingIntent` carries no touch coordinates — so this cannot be
        // measured, only placed. The constants below are the chip's position
        // for a widget in the home screen's **top row**, which is where these
        // offsets used to be measured from too; the previous pair described
        // the chip's offset *inside the panel* (13, 32) and were then applied
        // as screen coordinates, which is why the popup opened above and to
        // the left of the chip instead of on it.
        //
        // Clamped so a widget placed lower down still gets a popup fully on
        // screen rather than one hanging off the bottom edge.
        panel.post {
            val params = panel.layoutParams as FrameLayout.LayoutParams
            val root = findViewById<View>(R.id.picker_scrim)
            params.gravity = Gravity.START or Gravity.TOP
            params.leftMargin = dp(ANCHOR_LEFT_DP)
                .coerceAtMost((root.width - panel.width - dp(8)).coerceAtLeast(0))
            params.topMargin = dp(ANCHOR_TOP_DP)
                .coerceAtMost((root.height - panel.height - dp(8)).coerceAtLeast(0))
            panel.layoutParams = params
        }

        for (scope in WidgetScope.entries) {
            panel.addView(row(scope, selected = scope == current))
        }

        // Tapping outside dismisses without changing anything.
        findViewById<View>(R.id.picker_scrim).setOnClickListener { finish() }
    }

    private fun row(scope: WidgetScope, selected: Boolean): View {
        val row = layoutInflater.inflate(R.layout.widget_scope_picker_row, null)
            as LinearLayout

        row.findViewById<TextView>(R.id.picker_row_label).apply {
            text = scope.label
            // The selected row is marked by its accent tint ground **only** —
            // no check mark, no counts. Lighting the label as well would be a
            // second signal for one state.
            setTextColor(if (selected) WidgetPalette.INK_ACCENT else WidgetPalette.TEXT)
        }

        row.findViewById<ImageView>(R.id.picker_row_icon).apply {
            setImageResource(
                when (scope) {
                    WidgetScope.TODAY -> R.drawable.widget_kind_habit
                    WidgetScope.REMINDERS -> R.drawable.widget_kind_reminder
                    WidgetScope.TASKS -> R.drawable.widget_kind_task
                    WidgetScope.HABITS -> R.drawable.widget_kind_habit
                },
            )
            setColorFilter(if (selected) WidgetPalette.INK_ACCENT else WidgetPalette.TEXT)
            // SRC_ATOP ignores a filter's alpha, so an unselected row's icon
            // is muted with imageAlpha rather than with a faded colour.
            imageAlpha = if (selected) WidgetPalette.ALPHA_FULL else WidgetPalette.ALPHA_TYPE
        }

        if (selected) {
            row.setBackgroundResource(R.drawable.widget_picker_row_selected)
        }

        row.layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        )

        row.setOnClickListener {
            WidgetConfigStore.writeScope(this, appWidgetId, scope)
            SteadyProgressWidgetProvider.refresh(this, appWidgetId)
            finish()
        }

        return row
    }

    private fun dp(value: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        value.toFloat(),
        resources.displayMetrics,
    ).toInt()

    private companion object {
        /** The scope chip's own top-left, for a widget in the home screen's
         *  top row: the panel's inset plus the chip's offset within it. */
        const val ANCHOR_LEFT_DP = 30
        const val ANCHOR_TOP_DP = 79
    }
}
