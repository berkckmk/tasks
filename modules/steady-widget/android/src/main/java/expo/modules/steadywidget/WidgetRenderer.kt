package expo.modules.steadywidget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import java.util.concurrent.ConcurrentHashMap

/**
 * UI LOCKED - Renders widget views without altering layout XML or drawables.
 * Uses modern Android 12+ RemoteCollectionItems for instant, zero-service list updates.
 */
object WidgetRenderer {

    private val idCache = ConcurrentHashMap<String, Int>()

    private fun resId(context: Context, name: String, type: String): Int {
        val key = "$type/$name"
        return idCache.computeIfAbsent(key) {
            context.resources.getIdentifier(name, type, context.packageName)
        }
    }

    fun renderAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val provider = ComponentName(context, SteadyWidgetProvider::class.java)
        val ids = manager.getAppWidgetIds(provider)
        if (ids != null && ids.isNotEmpty()) {
            for (id in ids) {
                render(context, manager, id)
            }
        }
    }

    fun render(context: Context, manager: AppWidgetManager, widgetId: Int) {
        val snapshot = WidgetStore.getSnapshot(context)
        val layoutId = resId(context, "widget_steady_progress", "layout")
        if (layoutId == 0) return

        val views = RemoteViews(context.packageName, layoutId)

        // 1. Panel Background & Configurable Opacity (Transparent by default)
        val panelFillId = resId(context, "panel_fill", "id")
        val panelEdgeId = resId(context, "panel_edge", "id")

        val configPrefs = context.getSharedPreferences("steady_progress_widget_config", Context.MODE_PRIVATE)
        val isConfigured = configPrefs.getBoolean("w${widgetId}_configured", false)
        val groundKey = if (isConfigured) {
            configPrefs.getString("w${widgetId}_ground", "none") ?: "none"
        } else {
            "none"
        }
        val opacity = if (isConfigured) {
            configPrefs.getInt("w${widgetId}_opacity", 0)
        } else {
            0
        }

        val isTransparent = !isConfigured || groundKey == "none" || opacity <= 0

        if (isTransparent) {
            // Default: 100% transparent! Content floats directly on wallpaper.
            if (panelFillId != 0) {
                views.setViewVisibility(panelFillId, View.GONE)
                views.setInt(panelFillId, "setImageAlpha", 0)
            }
            if (panelEdgeId != 0) {
                views.setViewVisibility(panelEdgeId, View.GONE)
                views.setInt(panelEdgeId, "setImageAlpha", 0)
            }
        } else {
            val rgb = when (groundKey.lowercase()) {
                "surface" -> 0x232532
                "ink" -> 0x292B31
                "accent" -> 0x2B2741
                else -> 0x232532
            }
            val alpha = ((opacity.coerceIn(0, 100) / 100f) * 255).toInt()
            val color = 0xFF000000.toInt() or rgb
            val edgeA = minOf(alpha, 120)

            if (panelFillId != 0) {
                views.setViewVisibility(panelFillId, View.VISIBLE)
                views.setInt(panelFillId, "setColorFilter", color)
                views.setInt(panelFillId, "setImageAlpha", alpha)
            }
            if (panelEdgeId != 0) {
                views.setViewVisibility(panelEdgeId, View.VISIBLE)
                views.setInt(panelEdgeId, "setImageAlpha", edgeA)
            }
        }

        // 2. Scope Chip (TODAY ▾ / REMINDERS ▾ / TASKS ▾ / HABITS ▾)
        val scopeChipId = resId(context, "scope_chip", "id")
        if (scopeChipId != 0) {
            val scopeLabel = when (snapshot.selectedView.lowercase().trim()) {
                "reminders", "reminder" -> "REMINDERS ▾"
                "tasks", "task" -> "TASKS ▾"
                "habits", "habit" -> "HABITS ▾"
                else -> "TODAY ▾"
            }
            views.setTextViewText(scopeChipId, scopeLabel)

            val cycleIntent = Intent(context, WidgetActionReceiver::class.java).apply {
                action = WidgetActionReceiver.ACTION_CYCLE_SCOPE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            }
            views.setOnClickPendingIntent(
                scopeChipId,
                PendingIntent.getBroadcast(
                    context,
                    widgetId + 20_000,
                    cycleIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
        }

        // 3. Summary & Progress for the currently active scope
        val scopeItems = snapshot.itemsForScope(snapshot.selectedView)
        val scopeCompleted = scopeItems.count { it.completed }
        val scopeTotal = scopeItems.size
        val scopeProgress = if (scopeTotal > 0) (scopeCompleted.toFloat() / scopeTotal).coerceIn(0f, 1f) else 0f

        val summaryId = resId(context, "summary", "id")
        if (summaryId != 0) {
            val normalizedScope = snapshot.selectedView.lowercase().trim()
            val isHabitOrToday = normalizedScope.startsWith("habit") || normalizedScope == "today"
            val text = when {
                !snapshot.hasData -> ""
                snapshot.bestStreak > 0 && isHabitOrToday -> "$scopeCompleted / $scopeTotal · ${snapshot.bestStreak}d streak"
                else -> "$scopeCompleted / $scopeTotal"
            }
            views.setTextViewText(summaryId, text)
        }

        val progressId = resId(context, "progress", "id")
        if (progressId != 0) {
            views.setProgressBar(progressId, 100, (scopeProgress * 100).toInt(), false)
        }

        // 4. Quick-Add (+) Button -> Native Quick Add Modal
        val quickAddId = resId(context, "quick_add", "id")
        if (quickAddId != 0) {
            val addIntent = Intent().apply {
                setClassName(context.packageName, "com.steadyprogress.steady_progress.widget.WidgetQuickAddActivity")
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_MULTIPLE_TASK
            }
            views.setOnClickPendingIntent(
                quickAddId,
                PendingIntent.getActivity(
                    context,
                    widgetId + 10_000,
                    addIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
        }

        // 5. Items Collection (Modern RemoteCollectionItems on Android 12+)
        val itemsViewId = resId(context, "items", "id")
        val emptyViewId = resId(context, "empty", "id")
        val rowLayoutId = resId(context, "widget_row", "layout")

        val displayItems = scopeItems

        if (itemsViewId != 0 && rowLayoutId != 0) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // PendingIntent Template for the collection view (FLAG_MUTABLE is required for fill-in merging)
                val templateIntent = Intent(context, WidgetActionReceiver::class.java)
                val templatePending = PendingIntent.getBroadcast(
                    context,
                    widgetId + 30_000,
                    templateIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                )
                views.setPendingIntentTemplate(itemsViewId, templatePending)

                val collectionBuilder = RemoteViews.RemoteCollectionItems.Builder()
                    .setHasStableIds(true)

                for (item in displayItems) {
                    val row = RemoteViews(context.packageName, rowLayoutId)

                    // Text & Time
                    val rowTimeId = resId(context, "row_time", "id")
                    if (rowTimeId != 0) {
                        row.setTextViewText(rowTimeId, item.time)
                    }

                    val rowTitleId = resId(context, "row_title", "id")
                    if (rowTitleId != 0) {
                        row.setTextViewText(rowTitleId, item.title)
                        if (item.completed) {
                            row.setTextColor(rowTitleId, WidgetRendererVisualSpec.COLOR_TEXT_DONE)
                            row.setInt(rowTitleId, "setPaintFlags", WidgetRendererVisualSpec.FLAGS_STRIKE_THRU)
                        } else {
                            row.setTextColor(rowTitleId, WidgetRendererVisualSpec.COLOR_TEXT)
                            row.setInt(rowTitleId, "setPaintFlags", WidgetRendererVisualSpec.FLAGS_NORMAL)
                        }
                    }

                    // Kind text is hidden per requirement (only icon is displayed)
                    val rowKindId = resId(context, "row_kind", "id")
                    if (rowKindId != 0) {
                        row.setViewVisibility(rowKindId, View.GONE)
                    }

                    // Toggle Checkbox
                    val rowToggleId = resId(context, "row_toggle", "id")
                    if (rowToggleId != 0) {
                        val checkedDrawableId = resId(context, "widget_check_circle_fill", "drawable")
                        val uncheckedDrawableId = resId(context, "widget_circle", "drawable")

                        row.setImageViewResource(
                            rowToggleId,
                            if (item.completed) checkedDrawableId else uncheckedDrawableId
                        )
                        row.setInt(
                            rowToggleId,
                            "setColorFilter",
                            if (item.completed) WidgetRendererVisualSpec.COLOR_ICON_CHECKED else WidgetRendererVisualSpec.COLOR_ICON_UNCHECKED
                        )
                        row.setInt(
                            rowToggleId,
                            "setImageAlpha",
                            if (item.completed) WidgetRendererVisualSpec.ALPHA_FULL else WidgetRendererVisualSpec.ALPHA_UNCHECKED
                        )

                        // Checkbox Click FillInIntent -> triggers ACTION_TOGGLE via template
                        val toggleFillIn = Intent().apply {
                            action = WidgetActionReceiver.ACTION_TOGGLE
                            putExtra(WidgetActionReceiver.EXTRA_CLICK_ACTION, WidgetActionReceiver.ACTION_TOGGLE)
                            putExtra(WidgetActionReceiver.EXTRA_ITEM_ID, item.id)
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                        }
                        row.setOnClickFillInIntent(rowToggleId, toggleFillIn)
                    }

                    // Row Type Icon colored with exact app section color
                    val rowIconId = resId(context, "row_icon", "id")
                    if (rowIconId != 0) {
                        val (iconRes, iconColor) = when {
                            item.type.lowercase().startsWith("reminder") ->
                                resId(context, "widget_kind_reminder", "drawable") to WidgetRendererVisualSpec.COLOR_KIND_REMINDER
                            item.type.lowercase().startsWith("habit") ->
                                resId(context, "widget_kind_habit", "drawable") to WidgetRendererVisualSpec.COLOR_KIND_HABIT
                            else ->
                                resId(context, "widget_kind_task", "drawable") to WidgetRendererVisualSpec.COLOR_KIND_TASK
                        }
                        if (iconRes != 0) {
                            row.setImageViewResource(rowIconId, iconRes)
                            row.setInt(rowIconId, "setColorFilter", iconColor)
                            row.setInt(
                                rowIconId,
                                "setImageAlpha",
                                if (item.completed) WidgetRendererVisualSpec.ALPHA_DONE else WidgetRendererVisualSpec.ALPHA_TYPE
                            )
                        }
                    }

                    // Row Body Click -> Open App Detail
                    val rowRootId = resId(context, "row", "id")
                    if (rowRootId != 0) {
                        val openFillIn = Intent().apply {
                            action = WidgetActionReceiver.ACTION_OPEN
                            putExtra(WidgetActionReceiver.EXTRA_CLICK_ACTION, WidgetActionReceiver.ACTION_OPEN)
                            putExtra(WidgetActionReceiver.EXTRA_ITEM_ID, item.id)
                            putExtra(WidgetActionReceiver.EXTRA_ITEM_TYPE, item.type)
                        }
                        row.setOnClickFillInIntent(rowRootId, openFillIn)
                    }

                    collectionBuilder.addItem(item.id.hashCode().toLong(), row)
                }

                views.setRemoteAdapter(itemsViewId, collectionBuilder.build())
                if (emptyViewId != 0) {
                    views.setEmptyView(itemsViewId, emptyViewId)
                }
            }
        }

        manager.updateAppWidget(widgetId, views)
    }
}
