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

        // Anchored under the chip. The launcher never tells an app where its
        // widget sits — `getAppWidgetOptions` reports the size and never the
        // position — so this is placed relative to the *screen* using the
        // chip's own offset within the panel, which is the closest an app can
        // get. Clamped below so it can't run off the edge.
        (panel.layoutParams as FrameLayout.LayoutParams).apply {
            gravity = Gravity.START or Gravity.TOP
            leftMargin = dp(ANCHOR_LEFT_DP)
            topMargin = dp(ANCHOR_TOP_DP)
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
        const val ANCHOR_LEFT_DP = 13
        const val ANCHOR_TOP_DP = 32
    }
}
