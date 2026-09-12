package expo.modules.steadywidget

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log

/**
 * FAST PATH - Handles widget user interactions entirely in native code without waking React Native.
 * Logs precise timing for each phase: action received, local state updated, render, total duration.
 */
class WidgetActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return
        val t0 = System.currentTimeMillis()

        val action = intent.getStringExtra(EXTRA_CLICK_ACTION) ?: intent.action

        when (action) {
            ACTION_TOGGLE -> {
                val itemId = intent.getStringExtra(EXTRA_ITEM_ID) ?: return
                val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)

                // 1. Update local state
                val newState = WidgetStore.toggleItem(context, itemId)
                val t1 = System.currentTimeMillis()

                // 2. Render RemoteViews & update widget
                val manager = AppWidgetManager.getInstance(context)
                if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    WidgetRenderer.render(context, manager, widgetId)
                } else {
                    WidgetRenderer.renderAll(context)
                }
                val t2 = System.currentTimeMillis()

                Log.i(
                    TAG,
                    "FAST PATH: Toggle [id=$itemId, newState=$newState] -> stateUpdate: ${t1 - t0}ms, render: ${t2 - t1}ms, total: ${t2 - t0}ms"
                )
            }

            ACTION_OPEN -> {
                val itemId = intent.getStringExtra(EXTRA_ITEM_ID) ?: return
                val type = intent.getStringExtra(EXTRA_ITEM_TYPE) ?: "task"
                val normalizedType = when (type.lowercase().trim()) {
                    "task", "tasks" -> "tasks"
                    "reminder", "reminders" -> "reminders"
                    "habit", "habits" -> "habits"
                    else -> "tasks"
                }
                val scheme = if (context.packageName.endsWith(".preview")) "steadyprogresspreview" else "steadyprogress"
                val openIntent = Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("$scheme:///$normalizedType/$itemId/edit")
                ).apply {
                    setPackage(context.packageName)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                try {
                    val bundle = if (android.os.Build.VERSION.SDK_INT >= 34) {
                        try {
                            val options = android.app.ActivityOptions.makeBasic()
                            val method = options.javaClass.getMethod("setPendingIntentBackgroundActivityStartMode", Int::class.javaPrimitiveType)
                            method.invoke(options, 1) // MODE_BACKGROUND_ACTIVITY_START_ALLOWED
                            options.toBundle()
                        } catch (_: Throwable) {
                            null
                        }
                    } else null

                    if (bundle != null) {
                        context.startActivity(openIntent, bundle)
                    } else {
                        context.startActivity(openIntent)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start activity for open action: ${e.message}")
                }
            }

            ACTION_CYCLE_SCOPE -> {
                val nextScope = WidgetStore.cycleScope(context)
                val t1 = System.currentTimeMillis()

                WidgetRenderer.renderAll(context)
                val t2 = System.currentTimeMillis()

                Log.i(
                    TAG,
                    "FAST PATH: CycleScope -> newScope: $nextScope -> stateUpdate: ${t1 - t0}ms, render: ${t2 - t1}ms, total: ${t2 - t0}ms"
                )
            }
        }
    }

    companion object {
        const val TAG = "SteadyWidgetAction"
        const val ACTION_TOGGLE = "expo.modules.steadywidget.ACTION_TOGGLE"
        const val ACTION_CYCLE_SCOPE = "expo.modules.steadywidget.ACTION_CYCLE_SCOPE"
        const val ACTION_ITEM_CLICK = "expo.modules.steadywidget.ACTION_ITEM_CLICK"
        const val ACTION_OPEN = "expo.modules.steadywidget.ACTION_OPEN"

        const val EXTRA_CLICK_ACTION = "extra_click_action"
        const val EXTRA_ITEM_ID = "extra_item_id"
        const val EXTRA_ITEM_TYPE = "extra_item_type"
    }
}
