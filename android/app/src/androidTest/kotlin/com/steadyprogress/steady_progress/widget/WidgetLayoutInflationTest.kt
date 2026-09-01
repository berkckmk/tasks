package com.steadyprogress.steady_progress.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.steadyprogress.steady_progress.R
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Guards the one failure mode this widget has always had.
 *
 * RemoteViews permits a short list of view classes, and a bare `<View>` or
 * `<Space>` is not on it. Inflating one throws
 *
 *     android.view.InflateException: Class not allowed to be inflated
 *     android.view.View
 *
 * which fails the **whole layout**, not just that element — so the launcher
 * shows an empty box where the widget should be, silently, with nothing in the
 * UI to say why. That has shipped before. `docs/ANDROID_WIDGET.md` calls it
 * out and the provider's own doc comment says to grep logcat for it after
 * touching the layout; this test is the version that doesn't rely on
 * remembering.
 *
 * It runs on a device or emulator because `RemoteViews.apply()` is the real
 * inflate path — a host-side test would only prove the XML parses.
 *
 * Replaces `GlassRendererTest`, which exercised the bitmap renderer that no
 * longer exists.
 *
 *     (cd android && ./gradlew :app:connectedDebugAndroidTest)
 */
@RunWith(AndroidJUnit4::class)
class WidgetLayoutInflationTest {

    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    /**
     * The whole point: if any element in the panel is a class RemoteViews
     * rejects, `apply()` throws here instead of blanking on a home screen.
     */
    @Test
    fun panelLayoutInflatesThroughRemoteViews() {
        val views = RemoteViews(context.packageName, R.layout.widget_steady_progress)
        val root = views.apply(context, null)

        assertNotNull("panel layout produced no view", root)
        for (id in listOf(
            R.id.panel_fill,
            R.id.panel_edge,
            R.id.panel,
            R.id.scope_chip,
            R.id.summary,
            R.id.clock,
            R.id.progress,
            R.id.items,
            R.id.empty,
            R.id.footer,
        )) {
            assertNotNull(
                "expected view missing after inflate: ${context.resources.getResourceEntryName(id)}",
                root.findViewById<View>(id),
            )
        }
    }

    /** The collection row travels through the same inflate path. */
    @Test
    fun rowLayoutInflatesThroughRemoteViews() {
        val views = RemoteViews(context.packageName, R.layout.widget_row)
        val root = views.apply(context, null)

        assertNotNull(root.findViewById<View>(R.id.row_toggle))
        assertNotNull(root.findViewById<View>(R.id.row_time))
        assertNotNull(root.findViewById<View>(R.id.row_title))
        assertNotNull(root.findViewById<View>(R.id.row_kind))
        assertNotNull(root.findViewById<View>(R.id.row_icon))
    }

    /**
     * The provider's own build path, end to end, against an empty snapshot —
     * which is the state a freshly placed widget is in before the app has
     * ever run.
     */
    @Test
    fun providerBuildsAgainstAnEmptySnapshot() {
        WidgetDataStore.clear(context)

        val views = RemoteViews(context.packageName, R.layout.widget_steady_progress)
        val root = views.apply(context, null)
        assertNotNull(root)

        val data = WidgetDataStore.read(context)
        assertEquals(0, data.totalCount)
        assertTrue("a cleared store must not claim to have data", !data.hasData)
        assertTrue(
            "an empty snapshot must yield no rows, not a row of zeros",
            data.itemsFor(WidgetConfig.DEFAULT).isEmpty(),
        )
    }

    /** The setup screen and the scope picker are ordinary Activities, but
     *  their layouts still have to inflate. */
    @Test
    fun scopePickerLayoutsInflate() {
        val inflater = android.view.LayoutInflater.from(context)
        assertNotNull(inflater.inflate(R.layout.widget_scope_picker, null))
        assertNotNull(inflater.inflate(R.layout.widget_scope_picker_row, null))
        assertNotNull(inflater.inflate(R.layout.widget_configure, null))
    }

    /**
     * A placed widget's settings must survive being written and read back —
     * the picker writes only the scope, and it must not silently drop the
     * ground, the opacity or the Include set on the way through.
     *
     * That exact bug shipped in the previous config store: the field-cycle
     * handler rebuilt a fresh `WidgetConfig` by hand and lost `opacity` every
     * time the user tapped.
     */
    @Test
    fun writingOnlyTheScopeKeepsEverythingElse() {
        val id = 987654
        try {
            WidgetConfigStore.write(
                context,
                id,
                WidgetConfig(
                    scope = WidgetScope.TODAY,
                    ground = WidgetGround.ACCENT,
                    opacity = 31,
                    rows = 5,
                    include = setOf(WidgetInclude.TASKS),
                ),
            )

            WidgetConfigStore.writeScope(context, id, WidgetScope.TASKS)

            val back = WidgetConfigStore.read(context, id)
            assertEquals(WidgetScope.TASKS, back.scope)
            assertEquals(WidgetGround.ACCENT, back.ground)
            assertEquals(31, back.opacity)
            assertEquals(5, back.rows)
            assertEquals(setOf(WidgetInclude.TASKS), back.include)
        } finally {
            WidgetConfigStore.clear(context, id)
        }
    }

    /**
     * A widget id with nothing stored — one placed before these settings
     * existed — must come back with the defaults rather than blank.
     */
    @Test
    fun anUnconfiguredWidgetGetsTheDefaults() {
        val config = WidgetConfigStore.read(context, AppWidgetManager.INVALID_APPWIDGET_ID - 1)
        assertEquals(WidgetScope.TODAY, config.scope)
        assertEquals(WidgetGround.SURFACE, config.ground)
        assertEquals(WidgetConfig.DEFAULT_OPACITY, config.opacity)
        assertEquals(WidgetInclude.DEFAULT, config.include)
    }
}
