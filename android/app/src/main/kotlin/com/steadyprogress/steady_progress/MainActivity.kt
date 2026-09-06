package com.steadyprogress.steady_progress

import com.steadyprogress.steady_progress.widget.SteadyProgressWidgetProvider
import com.steadyprogress.steady_progress.widget.WidgetDataStore
import com.steadyprogress.steady_progress.widget.WidgetPendingAdds
import com.steadyprogress.steady_progress.widget.WidgetPendingToggles
import com.steadyprogress.steady_progress.reminders.AlarmScheduler
import com.steadyprogress.steady_progress.reminders.NotificationChannels
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_INFO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Always a real IANA zone id ("Europe/Istanbul"), which is
                    // exactly what Dart's DateTime.timeZoneName is not — see
                    // lib/core/time/device_timezone.dart.
                    "getTimeZoneId" -> result.success(TimeZone.getDefault().id)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidget" -> {
                        @Suppress("UNCHECKED_CAST")
                        val data = call.arguments as? Map<String, Any?> ?: emptyMap()
                        WidgetDataStore.write(applicationContext, data)
                        SteadyProgressWidgetProvider.refreshAll(applicationContext)
                        result.success(true)
                    }
                    // Sign-out: drop the cached numbers so the widget stops
                    // showing the previous account's progress on a shared
                    // device.
                    "clearWidget" -> {
                        WidgetDataStore.clear(applicationContext)
                        WidgetPendingToggles.clear(
                            applicationContext,
                            WidgetPendingToggles.read(applicationContext).map { it.id },
                        )
                        WidgetPendingAdds.clear(
                            applicationContext,
                            WidgetPendingAdds.read(applicationContext).map { it.id },
                        )
                        SteadyProgressWidgetProvider.refreshAll(applicationContext)
                        result.success(true)
                    }
                    // Ticks the widget made while the app wasn't running. The
                    // widget never writes to Firestore itself — see
                    // WidgetPendingToggles — so the app drains this queue
                    // through the real repositories on start and on resume.
                    "readPendingToggles" -> {
                        result.success(WidgetPendingToggles.readAsJson(applicationContext))
                    }
                    // Only the ids Flutter actually applied, never a wholesale
                    // clear: a tick made while the drain was in flight has to
                    // survive it.
                    // Items composed in the widget's quick-add modal. The
                    // widget cannot create one itself — a task's create is
                    // denied by firestore.rules and goes through a Cloud
                    // Function — so it queues them and the app creates them
                    // through the ordinary repositories. See WidgetPendingAdds.
                    "readPendingAdds" -> {
                        result.success(WidgetPendingAdds.readAsJson(applicationContext))
                    }
                    "clearPendingAdds" -> {
                        @Suppress("UNCHECKED_CAST")
                        val ids = call.argument<List<String>>("ids").orEmpty()
                        WidgetPendingAdds.clear(applicationContext, ids)
                        // The optimistic rows go with the queue: the real
                        // documents are in the app's next push, and leaving
                        // both in shows every added item twice.
                        WidgetDataStore.dropLocalAdds(applicationContext, ids)
                        SteadyProgressWidgetProvider.refreshAll(applicationContext)
                        result.success(true)
                    }
                    "clearPendingToggles" -> {
                        @Suppress("UNCHECKED_CAST")
                        val ids = call.argument<List<String>>("ids").orEmpty()
                        WidgetPendingToggles.clear(applicationContext, ids)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        NotificationChannels.ensureCreated(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAlarm" -> {
                        val id = call.argument<String>("id") ?: ""
                        val timestampMs = call.argument<Number>("timestampMs")?.toLong() ?: 0L
                        val title = call.argument<String>("title") ?: ""
                        val message = call.argument<String>("message") ?: ""
                        val priority = call.argument<String>("priority") ?: "normal"
                        AlarmScheduler.schedule(
                            applicationContext,
                            id,
                            timestampMs,
                            title,
                            message,
                            priority,
                        )
                        result.success(true)
                    }
                    "cancelAlarm" -> {
                        val id = call.argument<String>("id") ?: ""
                        AlarmScheduler.cancel(applicationContext, id)
                        result.success(true)
                    }
                    "testNotification" -> {
                        val id = call.argument<String>("id") ?: "test"
                        val title = call.argument<String>("title") ?: "Önemli İlaç"
                        val message = call.argument<String>("message") ?: "İlaç vakti geldi!"
                        val priority = call.argument<String>("priority") ?: "important"
                        val intent = android.content.Intent(applicationContext, com.steadyprogress.steady_progress.reminders.AlarmReceiver::class.java).apply {
                            action = com.steadyprogress.steady_progress.reminders.AlarmReceiver.ACTION_ALARM
                            putExtra(com.steadyprogress.steady_progress.reminders.AlarmReceiver.EXTRA_ID, id)
                            putExtra(com.steadyprogress.steady_progress.reminders.AlarmReceiver.EXTRA_TITLE, title)
                            putExtra(com.steadyprogress.steady_progress.reminders.AlarmReceiver.EXTRA_MESSAGE, message)
                            putExtra(com.steadyprogress.steady_progress.reminders.AlarmReceiver.EXTRA_PRIORITY, priority)
                        }
                        applicationContext.sendBroadcast(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        private const val DEVICE_INFO_CHANNEL = "com.steadyprogress/device_info"
        private const val WIDGET_CHANNEL = "com.steadyprogress/widget"
        private const val ALARM_CHANNEL = "com.steadyprogress/reminders_alarm"
    }
}
