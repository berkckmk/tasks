package com.steadyprogress.steady_progress

import com.steadyprogress.steady_progress.widget.SteadyProgressWidgetProvider
import com.steadyprogress.steady_progress.widget.WidgetDataStore
import com.steadyprogress.steady_progress.widget.WidgetPendingToggles
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
                    "clearPendingToggles" -> {
                        @Suppress("UNCHECKED_CAST")
                        val ids = call.argument<List<String>>("ids").orEmpty()
                        WidgetPendingToggles.clear(applicationContext, ids)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        private const val DEVICE_INFO_CHANNEL = "com.steadyprogress/device_info"
        private const val WIDGET_CHANNEL = "com.steadyprogress/widget"
    }
}
