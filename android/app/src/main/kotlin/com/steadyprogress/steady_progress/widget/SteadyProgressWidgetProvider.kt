package com.steadyprogress.steady_progress.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.TypedValue
import android.widget.RemoteViews
import com.steadyprogress.steady_progress.MainActivity
import com.steadyprogress.steady_progress.R

/**
 * The Steady Progress home-screen widget.
 *
 * The whole panel is a single bitmap from [GlassRenderer], shown in the one
 * `ImageView` of `widget_steady_progress.xml`. See [LiquidGlass] for why the
 * material can't be built out of ordinary `RemoteViews` views at all.
 *
 * Anything added to that layout has to be a class RemoteViews permits — a
 * bare `View` is not one, and inflating it fails the entire layout rather
 * than just that element, leaving an empty box on the home screen.
 */
class SteadyProgressWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            buildInto(context, appWidgetManager, id)
        }
    }

    /**
     * Rebuilds at the new size when the user resizes the widget.
     *
     * The rows are size-specific bitmaps, so this has to rebuild rather than
     * let the list stretch what it already has.
     */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        buildInto(context, appWidgetManager, appWidgetId)
    }

    /** Drops each removed widget's saved field selection. Left behind, the
     *  keys accumulate forever and a recycled id would inherit the layout of
     *  a widget the user already deleted. */
    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            WidgetConfigStore.clear(context, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_SELECT_FIELD) {
            val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                val current = WidgetConfigStore.read(context, appWidgetId)
                val fields = WidgetField.entries
                val nextField = if (current.fields.size == 1) {
                    val currentField = current.fields.first()
                    val idx = fields.indexOf(currentField)
                    fields[(idx + 1) % fields.size]
                } else {
                    fields.first()
                }
                // copy(), not a fresh WidgetConfig: the previous version listed
                // the fields by hand and silently dropped `opacity` every time
                // the user cycled the shown field. Copying means new settings
                // can't be forgotten here again.
                WidgetConfigStore.write(
                    context,
                    appWidgetId,
                    current.copy(fields = setOf(nextField)),
                )
                refresh(context, appWidgetId)
            }
        }
    }

    companion object {
        private const val ACTION_SELECT_FIELD = "com.steadyprogress.ACTION_SELECT_WIDGET_FIELD"

        /**
         * Rebuilds every placed widget by calling buildInto. This replaces the
         * previous carousel-specific notify call.
         */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, SteadyProgressWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            for (id in ids) buildInto(context, manager, id)
        }

        /** Rebuilds one instance — used by the configure activity, where the
         *  card layout itself may have changed, not just the data. */
        fun refresh(context: Context, appWidgetId: Int) {
            buildInto(context, AppWidgetManager.getInstance(context), appWidgetId)
        }

        private fun buildInto(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_steady_progress)

            // Read current size & options as the carousel did previously.
            val options = manager.getAppWidgetOptions(widgetId)
            val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
                .takeIf { it > 0 } ?: DEFAULT_WIDTH_DP
            val heightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
                .takeIf { it > 0 } ?: DEFAULT_HEIGHT_DP

            val cardWidthPx = dpToPx(widthDp, context)
            val cardHeightPx = dpToPx(heightDp, context)

            val data = WidgetDataStore.read(context)
            val config = WidgetConfigStore.read(context, widgetId)

            val bitmap = GlassRenderer.render(context, cardWidthPx, cardHeightPx, data, config).also {
                it.density = context.resources.displayMetrics.densityDpi
            }
            views.setImageViewBitmap(R.id.widget_canvas, bitmap)

            // Whole canvas launches the app.
            views.setOnClickPendingIntent(R.id.widget_canvas, launchAppTemplate(context))

            // The top-left select area cycles which field is shown.
            val selectIntent = Intent(context, SteadyProgressWidgetProvider::class.java).apply {
                action = ACTION_SELECT_FIELD
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            }
            val selectPending = PendingIntent.getBroadcast(
                context,
                widgetId,
                selectIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_select_area, selectPending)

            manager.updateAppWidget(widgetId, views)
        }

        private fun dpToPx(dp: Int, context: Context): Int = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            context.resources.displayMetrics,
        ).toInt()

        private const val DEFAULT_WIDTH_DP = 250
        private const val DEFAULT_HEIGHT_DP = 110

        private fun launchAppTemplate(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
            )
        }
    }
}
