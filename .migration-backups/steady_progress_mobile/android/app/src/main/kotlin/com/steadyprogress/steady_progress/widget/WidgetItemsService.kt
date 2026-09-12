package com.steadyprogress.steady_progress.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.steadyprogress.steady_progress.R

/**
 * Supplies the widget's scrolling rows.
 *
 * A `RemoteViewsService` collection is the only way to get a list that
 * actually scrolls into a widget — and scrolling is the thing the old bitmap
 * panel could never do at any size.
 */
class WidgetItemsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        val appWidgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        return WidgetItemsFactory(applicationContext, appWidgetId)
    }
}

private class WidgetItemsFactory(
    private val context: Context,
    private val appWidgetId: Int,
) : RemoteViewsService.RemoteViewsFactory {

    private var items: List<WidgetItem> = emptyList()

    /**
     * True at 2x2.
     *
     * The handoff specifies the kind label and the type icon for 4x2 and 4x4
     * only, and the reason is visible the moment you try it at 2x2: at 166dp
     * wide, "Reminder" plus a 12dp glyph plus the time column leaves the
     * title about 30dp, so every row ellipsises to two or three characters.
     * A 2x2 shows the time and the title, and that is the whole row.
     *
     * The factory knows the widget's size because it knows its id — the size
     * is not passed to it, it is asked for.
     */
    private var compact = false

    override fun onCreate() = Unit

    /**
     * Called on the service's own thread, and allowed to be slow — unlike the
     * provider's broadcast. Reading two SharedPreferences files is all it
     * does; the widget never touches Firestore.
     */
    override fun onDataSetChanged() {
        val data = WidgetDataStore.read(context)
        val config = WidgetConfigStore.read(context, appWidgetId)
        items = if (!data.hasData) emptyList() else data.itemsFor(config)

        val widthDp = AppWidgetManager.getInstance(context)
            .getAppWidgetOptions(appWidgetId)
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        // 0 when the launcher hasn't reported a size yet — assume the wide
        // default rather than compacting a widget that isn't small.
        compact = widthDp in 1 until COMPACT_WIDTH_DP
    }

    override fun onDestroy() {
        items = emptyList()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_row)
        // getViewAt can be called against a stale count while the collection
        // is being refreshed. Returning the loading view is the documented
        // way to say "not that one"; indexing past the end would crash the
        // service and blank the list.
        val item = items.getOrNull(position) ?: return views

        views.setTextViewText(R.id.row_time, item.time)
        views.setTextViewText(R.id.row_title, item.label)
        views.setTextViewText(R.id.row_kind, item.kind.label)

        // 2x2: time and title only. See `compact`.
        val hidden = if (compact) View.GONE else View.VISIBLE
        views.setViewVisibility(R.id.row_kind_group, hidden)
        views.setViewVisibility(R.id.row_kind, hidden)
        views.setViewVisibility(R.id.row_icon, hidden)
        views.setTextViewTextSize(
            R.id.row_time,
            TypedValue.COMPLEX_UNIT_SP,
            if (compact) 14.5f else 15.5f,
        )
        views.setTextViewTextSize(
            R.id.row_title,
            TypedValue.COMPLEX_UNIT_SP,
            if (compact) 17f else 18f,
        )
        views.setTextViewTextSize(
            R.id.row_kind,
            TypedValue.COMPLEX_UNIT_SP,
            15f,
        )

        views.setImageViewResource(
            R.id.row_toggle,
            if (item.done) R.drawable.widget_check_circle_fill else R.drawable.widget_circle,
        )
        // Colour and alpha are set separately on every icon: setColorFilter
        // is SRC_ATOP, which takes its alpha from the destination and ignores
        // the filter's own. See WidgetPalette.
        views.setInt(
            R.id.row_toggle,
            "setColorFilter",
            if (item.done) WidgetPalette.ICON_CHECKED else WidgetPalette.ICON_UNCHECKED,
        )
        views.setInt(
            R.id.row_toggle,
            "setImageAlpha",
            if (item.done) WidgetPalette.ALPHA_FULL else WidgetPalette.ALPHA_UNCHECKED,
        )

        views.setImageViewResource(
            R.id.row_icon,
            when (item.kind) {
                WidgetItemKind.REMINDER -> R.drawable.widget_kind_reminder
                WidgetItemKind.TASK -> R.drawable.widget_kind_task
                WidgetItemKind.HABIT -> R.drawable.widget_kind_habit
            },
        )
        views.setInt(R.id.row_icon, "setColorFilter", WidgetPalette.ICON_TYPE)
        views.setInt(
            R.id.row_icon,
            "setImageAlpha",
            if (item.done) WidgetPalette.ALPHA_DONE else WidgetPalette.ALPHA_TYPE,
        )

        // A completed row drops to 45% and gets a line-through, the same rule
        // the app uses. RemoteViews has no `setAlpha` for a TextView, so the
        // fade is applied to the colours rather than the view.
        if (item.done) {
            views.setTextColor(R.id.row_title, WidgetPalette.TEXT_DONE)
            views.setTextColor(R.id.row_time, WidgetPalette.TEXT_DONE)
            views.setTextColor(R.id.row_kind, WidgetPalette.TEXT_DONE)
            // setPaintFlags is @RemotableViewMethod on TextView — the only
            // way to strike text through from a RemoteViews.
            views.setInt(R.id.row_title, "setPaintFlags", STRIKE_FLAGS)
        } else {
            views.setTextColor(R.id.row_title, WidgetPalette.TEXT)
            views.setTextColor(R.id.row_time, WidgetPalette.TEXT_CAPTION)
            views.setTextColor(R.id.row_kind, WidgetPalette.TEXT_CAPTION)
            views.setInt(R.id.row_title, "setPaintFlags", BASE_FLAGS)
        }

        // `setPendingIntentTemplate` on the list plus `setOnClickFillInIntent`
        // per row is the only supported way to make collection rows tappable —
        // a PendingIntent per row would blow the transaction size on a long
        // list. Two targets: the toggle ticks it, the rest of the row opens
        // the app at that item.
        views.setOnClickFillInIntent(
            R.id.row_toggle,
            Intent()
                .putExtra(SteadyProgressWidgetProvider.EXTRA_ACTION, SteadyProgressWidgetProvider.ACTION_TOGGLE)
                .putExtra(SteadyProgressWidgetProvider.EXTRA_ITEM_ID, item.id)
                .putExtra(SteadyProgressWidgetProvider.EXTRA_ITEM_KIND, item.kind.key),
        )
        views.setOnClickFillInIntent(
            R.id.row,
            Intent()
                .putExtra(SteadyProgressWidgetProvider.EXTRA_ACTION, SteadyProgressWidgetProvider.ACTION_OPEN)
                .putExtra(SteadyProgressWidgetProvider.EXTRA_ITEM_ID, item.id)
                .putExtra(SteadyProgressWidgetProvider.EXTRA_ITEM_KIND, item.kind.key),
        )

        views.setContentDescription(
            R.id.row_toggle,
            if (item.done) {
                context.getString(R.string.widget_row_toggle_done, item.label)
            } else {
                context.getString(R.string.widget_row_toggle_open, item.label)
            },
        )

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    /**
     * A stable id per row, so the list keeps its scroll position across a
     * refresh instead of jumping to the top every time a tick lands.
     */
    override fun getItemId(position: Int): Long =
        items.getOrNull(position)?.let { (it.kind.key + it.id).hashCode().toLong() }
            ?: position.toLong()

    override fun hasStableIds(): Boolean = true

    private companion object {
        // Paint.STRIKE_THRU_TEXT_FLAG | Paint.ANTI_ALIAS_FLAG
        const val STRIKE_FLAGS = 0x10 or 0x01
        const val BASE_FLAGS = 0x01

        /** Below this the widget is 2x2 (166dp) rather than 4x2 (348dp). */
        const val COMPACT_WIDTH_DP = 260
    }
}
