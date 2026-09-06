package com.steadyprogress.steady_progress.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import com.steadyprogress.steady_progress.MainActivity
import com.steadyprogress.steady_progress.R

/**
 * The Steady Progress home-screen widget.
 *
 * ## What this is now
 *
 * Ordinary RemoteViews. A `LinearLayout` panel holding a scope chip, a
 * quick-add button, a determinate `ProgressBar` and a `ListView` fed by
 * [WidgetItemsService]. No `Bitmap`, no `BlurMaskFilter`, no bitmap budget,
 * no transaction-limit risk on resize, and no wallpaper copy on disk.
 *
 * That also means it cannot hit the `InflateException` that once rendered the
 * widget as a silent empty box — every class in the layout is one RemoteViews
 * permits. **After touching `widget_steady_progress.xml`, install and grep
 * logcat for `InflateException` anyway.** The empty box is the signature, and
 * it fails silently by design.
 *
 * ## What is deliberately kept
 *
 *  - The one-way SharedPreferences snapshot pushed from `HomeWidgetSync`.
 *    The widget still never touches Firestore.
 *  - Nullable-safe reads throughout: the widget can be placed before the app
 *    has ever run, and must render calmly rather than show zeros as if real.
 *  - `updatePeriodMillis = 0`. The platform floors periodic updates at 30
 *    minutes and wakes the device to deliver them; the clock ticks itself and
 *    the data is pushed when it changes.
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
     * Rebuilds at the new size when the user resizes.
     *
     * The row count and the footer depend on the height, so the layout
     * genuinely differs between 2x2, 4x2 and 4x4 — this is not just a redraw.
     */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        buildInto(context, appWidgetManager, appWidgetId)
    }

    /** Drops each removed widget's settings. Left behind, the keys accumulate
     *  forever and a recycled id would inherit the settings of a widget the
     *  user already deleted. */
    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            WidgetConfigStore.clear(context, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_ROW) return

        when (intent.getStringExtra(EXTRA_ACTION)) {
            ACTION_TOGGLE -> {
                val itemId = intent.getStringExtra(EXTRA_ITEM_ID) ?: return
                val kind = WidgetItemKind.fromKey(intent.getStringExtra(EXTRA_ITEM_KIND))
                // Never write from onReceive. A broadcast receiver gets a few
                // seconds, and this has to reach SharedPreferences, the
                // launcher and eventually Firestore — so it enqueues and
                // returns. See WidgetToggleWorker.
                WidgetToggleWorker.enqueue(context, itemId, kind)
            }
            ACTION_OPEN -> {
                val itemId = intent.getStringExtra(EXTRA_ITEM_ID)
                val kind = WidgetItemKind.fromKey(intent.getStringExtra(EXTRA_ITEM_KIND))
                context.startActivity(openItemIntent(context, kind, itemId))
            }
        }
    }

    companion object {
        /** The broadcast the collection's fill-in intents land on. */
        const val ACTION_ROW = "com.steadyprogress.ACTION_WIDGET_ROW"

        const val EXTRA_ACTION = "action"
        const val EXTRA_ITEM_ID = "itemId"
        const val EXTRA_ITEM_KIND = "itemKind"

        const val ACTION_TOGGLE = "toggle"
        const val ACTION_OPEN = "open"

        /** Rebuilds every placed widget. */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, SteadyProgressWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            for (id in ids) buildInto(context, manager, id)
            // The panel is rebuilt above; the *collection* has to be told
            // separately, or the rows keep whatever the factory last built.
            manager.notifyAppWidgetViewDataChanged(ids, R.id.items)
        }

        /** Rebuilds one instance — used by the setup screen and the scope
         *  picker, where the layout itself may have changed, not just data. */
        fun refresh(context: Context, appWidgetId: Int) {
            val manager = AppWidgetManager.getInstance(context)
            buildInto(context, manager, appWidgetId)
            manager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.items)
        }

        private fun buildInto(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_steady_progress)
            val data = WidgetDataStore.read(context)
            val config = WidgetConfigStore.read(context, widgetId)

            val options = manager.getAppWidgetOptions(widgetId)
            val heightDp = options
                .getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
                .takeIf { it > 0 } ?: DEFAULT_HEIGHT_DP
            val widthDp = options
                .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
                .takeIf { it > 0 } ?: DEFAULT_WIDTH_DP

            // 2x2 is 166x158, 4x2 is 348x158, 4x4 is 348x340.
            val isTall = heightDp >= TALL_HEIGHT_DP
            val isNarrow = widthDp < WIDE_WIDTH_DP

            applyPanel(views, config)
            applyHeader(context, views, data, config, isNarrow, widgetId)
            applyRows(context, views, widgetId, data)
            applyFooter(context, views, data, config, isTall)

            manager.updateAppWidget(widgetId, views)
        }

        /**
         * The configurable ground.
         *
         * `setColorFilter` + `setImageAlpha` on the fill ImageView rather than
         * `setBackgroundColor` on the panel: the latter would replace the
         * shape drawable and take the 22dp corners and the hairline with it.
         * See `widget_panel_fill.xml`.
         *
         * Only the fill is touched. The edge, the text, the accent bar and the
         * icons keep their own opaque colours, so contrast holds at every
         * slider position.
         */
        private fun applyPanel(views: RemoteViews, config: WidgetConfig) {
            views.setInt(R.id.panel_fill, "setColorFilter", config.panelColor)
            views.setInt(R.id.panel_fill, "setImageAlpha", config.panelAlpha)
            // "None" means no panel: the edge goes with the fill, or the
            // widget is a floating rectangle outline on the wallpaper.
            views.setViewVisibility(
                R.id.panel_edge,
                if (config.ground == WidgetGround.NONE) View.GONE else View.VISIBLE,
            )
        }

        private fun applyHeader(
            context: Context,
            views: RemoteViews,
            data: WidgetData,
            config: WidgetConfig,
            isNarrow: Boolean,
            widgetId: Int,
        ) {
            views.setTextViewText(R.id.scope_chip, config.scope.label.uppercase() + " ⌄")

            // 2x2 shows the count alone; 4x2 and 4x4 add the streak. Never a
            // streak of 0 dressed up as a fact.
            val summary = when {
                !data.hasData -> ""
                isNarrow -> "${data.doneCount} / ${data.totalCount}"
                data.bestStreak > 0 ->
                    "${data.doneCount} / ${data.totalCount} · ${data.bestStreak} day streak"
                else -> "${data.doneCount} / ${data.totalCount}"
            }
            views.setTextViewText(R.id.summary, summary)
            views.setProgressBar(
                R.id.progress,
                100,
                (data.progress * 100).toInt(),
                false,
            )

            // Quick-add: a translucent modal over the home screen, not the
            // app. It used to open `/reminders/new` in MainActivity, which is
            // a cold start and a full-screen form for one line of text — and
            // it takes away the surface the user was already looking at. The
            // modal composes the item, queues it, and drops an optimistic row
            // straight into the widget. See WidgetQuickAddActivity.
            val addIntent = Intent(context, WidgetQuickAddActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                // Per-widget data URI for the same reason the collection
                // intent carries one: PendingIntent equality ignores extras,
                // so without it two placed widgets would share one intent and
                // the second would compose into the first one's scope.
                setData(Uri.parse(toUri(Intent.URI_INTENT_SCHEME)))
            }
            views.setOnClickPendingIntent(
                R.id.quick_add,
                PendingIntent.getActivity(
                    context,
                    widgetId + 10_000, // Offset so it never collides with the scope-chip request code
                    addIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        }

        private fun applyRows(
            context: Context,
            views: RemoteViews,
            widgetId: Int,
            data: WidgetData,
        ) {
            val serviceIntent = Intent(context, WidgetItemsService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                // The launcher caches a RemoteViewsFactory per Intent, and it
                // compares Intents *ignoring* extras. Without a per-widget
                // data URI, two placed widgets with different scopes would
                // share one factory and show the same rows.
                //
                // setData(), not `data =`: inside this apply block the name
                // `data` resolves to the WidgetData parameter above, not to
                // the Intent's own property.
                setData(Uri.parse(toUri(Intent.URI_INTENT_SCHEME)))
            }
            views.setRemoteAdapter(R.id.items, serviceIntent)
            views.setEmptyView(R.id.items, R.id.empty)

            // One template for the whole collection plus a fill-in per row —
            // the only supported way to make collection rows tappable, and the
            // only one that doesn't blow the transaction size on a long list.
            val template = Intent(context, SteadyProgressWidgetProvider::class.java).apply {
                action = ACTION_ROW
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            }
            views.setPendingIntentTemplate(
                R.id.items,
                PendingIntent.getBroadcast(
                    context,
                    widgetId,
                    template,
                    // MUTABLE because the whole point of a template is that
                    // the fill-in intent supplies the row's extras.
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
                ),
            )

            // The scope chip opens the picker. RemoteViews has no popup and no
            // Spinner, so this is a transparent Activity.
            views.setOnClickPendingIntent(
                R.id.scope_chip,
                PendingIntent.getActivity(
                    context,
                    widgetId,
                    Intent(context, WidgetScopePickerActivity::class.java).apply {
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )

            // Tapping the header (but not the chip) opens the app.
            views.setOnClickPendingIntent(R.id.summary, launchApp(context))

            views.setInt(R.id.empty_icon, "setColorFilter", WidgetPalette.ICON_EMPTY)
            views.setInt(R.id.empty_icon, "setImageAlpha", WidgetPalette.ALPHA_EMPTY)
            views.setTextViewText(
                R.id.empty_message,
                context.getString(
                    if (data.hasData) {
                        R.string.widget_empty_message_synced
                    } else {
                        R.string.widget_empty_message
                    },
                ),
            )
        }

        private fun applyFooter(
            context: Context,
            views: RemoteViews,
            data: WidgetData,
            config: WidgetConfig,
            isTall: Boolean,
        ) {
            if (!isTall) {
                views.setViewVisibility(R.id.footer, View.GONE)
                return
            }

            views.setViewVisibility(R.id.footer, View.VISIBLE)

            // "+2 later this week" — what the visible rows don't cover.
            val total = data.itemsFor(config).size
            val overflow = (total - VISIBLE_ROWS_TALL).coerceAtLeast(0)
            views.setTextViewText(
                R.id.footer_note,
                if (overflow > 0) {
                    context.getString(R.string.widget_footer_more, overflow)
                } else {
                    ""
                },
            )
            views.setOnClickPendingIntent(R.id.footer_action, launchApp(context))
        }

        /** Opens the app at the item the row names. */
        private fun openItemIntent(
            context: Context,
            kind: WidgetItemKind,
            itemId: String?,
        ): Intent {
            val route = when {
                itemId.isNullOrEmpty() -> "/reminders"
                kind == WidgetItemKind.REMINDER -> "/reminders/$itemId/edit"
                kind == WidgetItemKind.TASK -> "/tasks/$itemId/edit"
                else -> "/habits/$itemId/edit"
            }
            return Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EXTRA_ROUTE, route)
            }
        }

        /** The route the app should open on, read by MainActivity. */
        const val EXTRA_ROUTE = "steady_progress_route"

        private fun launchApp(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private const val DEFAULT_WIDTH_DP = 348
        private const val DEFAULT_HEIGHT_DP = 158

        /** Above this the widget is 4x4: the footer appears and ~6 rows fit. */
        private const val TALL_HEIGHT_DP = 260

        /** Below this it is 2x2: the summary drops the streak. */
        private const val WIDE_WIDTH_DP = 260

        private const val VISIBLE_ROWS_TALL = 6
    }
}
