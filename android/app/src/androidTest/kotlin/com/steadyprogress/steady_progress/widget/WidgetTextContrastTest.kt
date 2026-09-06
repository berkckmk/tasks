package com.steadyprogress.steady_progress.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.util.TypedValue
import android.view.View
import android.widget.TextView
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.steadyprogress.steady_progress.R
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import kotlin.math.max
import kotlin.math.min

/**
 * Measures whether the widget's text is actually readable on the wallpaper.
 *
 * ## The bug this exists for
 *
 * The widget's type is fixed light — it does not flip with the device theme,
 * because a widget has no app ground to follow, only the user's wallpaper.
 * The muted ramp it inherited from the app (note 58%, caption 42%, unchecked
 * 32%) was tuned against a known dark surface. Put the same ramp on a *bright*
 * wallpaper with the panel opacity turned down and every step below full
 * washes out: the reported symptom was a header and a row of items that looked
 * switched off rather than merely secondary.
 *
 * The widget has since stopped drawing a panel at all by default, which makes
 * that the ordinary case rather than the corner one — see
 * `WidgetConfig.ground`. Two of the three tests below therefore run on
 * `WidgetConfig.DEFAULT`, and the panelled configuration gets its own.
 *
 * Nothing caught it. `WidgetLayoutInflationTest` proves the layout inflates,
 * and `WidgetRenderCaptureTest` draws it over one mid-grey stand-in — a ground
 * dark enough that light text passes on it no matter how faint. The failing
 * case was never rendered.
 *
 * ## What is measured
 *
 * The panel is drawn over the two grounds that bracket the real range — near
 * white and near black — and each text view's own rectangle is sampled from
 * the finished bitmap. Within that rectangle the glyphs are the extreme
 * pixels and the gaps between them are the ground, so comparing the darkest
 * and lightest luminance in the box gives the contrast the eye actually gets,
 * *after* the panel fill, the alpha and the text shadow have all composited.
 * That is the number that was wrong; asserting on the colour constants alone
 * would not have caught it, since those were behaving exactly as written.
 *
 * The floor is deliberately a floor, not a target. It is set below what the
 * current values produce so ordinary design tuning does not trip it, and far
 * enough above the old values that the shipped bug fails it — the old ramp
 * scored in the twenties on white, against a threshold of 60.
 *
 *     (cd android && ./gradlew :app:connectedDebugAndroidTest)
 */
@RunWith(AndroidJUnit4::class)
class WidgetTextContrastTest {

    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    /**
     * The bright wallpaper the bug was reported on, at the default settings —
     * which now means with no panel, so the text has nothing behind it but
     * its own shadow. The hardest case the app ships, and the ordinary one.
     */
    @Test
    fun textReadsOnALightWallpaper() {
        assertContrast(Color.rgb(0xEC, 0xEA, 0xE6), "a light wallpaper")
    }

    /** The other end: the widget must not have become a smear of shadow. */
    @Test
    fun textReadsOnADarkWallpaper() {
        assertContrast(Color.rgb(0x0E, 0x0F, 0x16), "a dark wallpaper")
    }

    /**
     * The panel is opt-in now, which is exactly why it needs its own test:
     * nothing else here would render it, and a ground the default never
     * touches is a ground that rots. A panel can only add contrast, so this
     * asserting the same floor is not a weaker check of the panel — it is a
     * check that turning one on has not broken the layout underneath it.
     */
    @Test
    fun textReadsWithThePanelTurnedOn() {
        assertContrast(
            Color.rgb(0xEC, 0xEA, 0xE6),
            "a light wallpaper with the panel turned on",
            WidgetConfig.DEFAULT.copy(ground = WidgetGround.SURFACE),
        )
    }

    private fun assertContrast(
        wallpaper: Int,
        label: String,
        config: WidgetConfig = WidgetConfig.DEFAULT,
    ) {
        val views = RemoteViewsPanel(context, config)
        val bitmap = views.render(wallpaper)

        val failures = mutableListOf<String>()
        for ((name, view) in views.textViews()) {
            val contrast = bitmap.contrastIn(views.boundsOf(view))
            if (contrast < MIN_CONTRAST) {
                failures += "  $name: $contrast (needs $MIN_CONTRAST)"
            }
        }

        assertTrue(
            "Widget text washes out on $label — the luminance range inside " +
                "each glyph box, after the panel fill, the alpha and the " +
                "shadow composite:\n" + failures.joinToString("\n"),
            failures.isEmpty(),
        )
    }

    /**
     * Luminance range inside one text view's rectangle.
     *
     * The glyphs and the ground between them are both in the box, so the
     * spread between the darkest and lightest pixel is the contrast the text
     * is actually rendered at. An empty TextView has no glyphs and so no
     * spread, which is why [RemoteViewsPanel] gives every one of them text.
     */
    private fun Bitmap.contrastIn(bounds: IntArray): Int {
        val (left, top, right, bottom) = bounds
        var darkest = 255
        var lightest = 0
        for (y in top until bottom) {
            for (x in left until right) {
                val p = getPixel(x, y)
                // Rec. 601 luma, integer — the same weighting the eye applies.
                val luma = (299 * Color.red(p) + 587 * Color.green(p) +
                    114 * Color.blue(p)) / 1000
                darkest = min(darkest, luma)
                lightest = max(lightest, luma)
            }
        }
        return lightest - darkest
    }

    private operator fun IntArray.component4(): Int = this[3]

    /** Stands the real RemoteViews up and draws it, exactly as the provider would. */
    private class RemoteViewsPanel(
        private val context: Context,
        private val config: WidgetConfig,
    ) {
        /** Declared before `init`, which fills it. */
        private val rows = mutableListOf<View>()

        private val root: View = android.widget.RemoteViews(
            context.packageName,
            R.layout.widget_steady_progress,
        ).apply(context, null)

        init {
            root.findViewById<android.widget.ImageView>(R.id.panel_fill).apply {
                setColorFilter(config.panelColor, android.graphics.PorterDuff.Mode.SRC_ATOP)
                imageAlpha = config.panelAlpha
            }
            root.findViewById<View>(R.id.panel_edge).visibility =
                if (config.ground == WidgetGround.NONE) View.GONE else View.VISIBLE

            // Every measured view needs glyphs in it, or its box is uniform
            // ground and scores zero for reasons that have nothing to do with
            // contrast. The strings are the real ones the provider writes.
            root.findViewById<TextView>(R.id.scope_chip).text = "TODAY ⌄"
            root.findViewById<TextView>(R.id.summary).text = "9 / 9 · 1 day streak"
            root.findViewById<View>(R.id.footer).visibility = View.VISIBLE
            root.findViewById<TextView>(R.id.footer_note).text = "+2 later this week"

            // The collection cannot render in a test process — the launcher's
            // adapter does not exist here — so the rows are the row layout
            // stood up directly, which is the same inflate with the same
            // colours. See WidgetRenderCaptureTest.
            val panel = root.findViewById<android.widget.LinearLayout>(R.id.panel)
            val list = root.findViewById<View>(R.id.items)
            val index = panel.indexOfChild(list)
            panel.removeView(list)
            panel.addView(rowColumn(), index)
        }

        private fun rowColumn(): View =
            android.widget.LinearLayout(context).apply {
                orientation = android.widget.LinearLayout.VERTICAL
                layoutParams = android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f,
                )
                addView(row("9:50", "deneme 123", WidgetItemKind.REMINDER))
            }

        private fun row(time: String, title: String, kind: WidgetItemKind): View {
            val view = android.widget.RemoteViews(
                context.packageName,
                R.layout.widget_row,
            ).apply(context, null)
            view.findViewById<TextView>(R.id.row_time).text = time
            view.findViewById<TextView>(R.id.row_title).text = title
            view.findViewById<TextView>(R.id.row_kind).text = kind.label
            rows += view
            return view
        }

        fun textViews(): List<Pair<String, TextView>> = buildList {
            add("scope_chip" to root.findViewById(R.id.scope_chip))
            add("summary" to root.findViewById(R.id.summary))
            add("footer_note" to root.findViewById(R.id.footer_note))
            add("footer_action" to root.findViewById(R.id.footer_action))
            for (row in rows) {
                add("row_time" to row.findViewById(R.id.row_time))
                add("row_title" to row.findViewById(R.id.row_title))
                add("row_kind" to row.findViewById(R.id.row_kind))
            }
        }

        fun render(wallpaper: Int): Bitmap {
            val w = dp(348)
            val h = dp(340)
            root.measure(
                View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY),
            )
            root.layout(0, 0, w, h)

            val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            Canvas(bitmap).apply {
                drawColor(wallpaper)
                root.draw(this)
            }
            return bitmap
        }

        /** A view's rectangle in the finished bitmap's coordinates. */
        fun boundsOf(view: View): IntArray {
            var left = 0
            var top = 0
            var node: View? = view
            while (node != null && node !== root) {
                left += node.left
                top += node.top
                node = node.parent as? View
            }
            return intArrayOf(left, top, left + view.width, top + view.height)
        }

        private fun dp(value: Int): Int = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            context.resources.displayMetrics,
        ).toInt()
    }

    private companion object {
        /**
         * Luminance spread a piece of widget text must reach, 0-255.
         *
         * A floor, not a target: the near-white ramp clears it comfortably at
         * both ends — measured around 118 on the light wallpaper with no panel
         * — while the ramp that shipped scores roughly half this. Chosen so
         * tuning a step by a few percent stays green and losing the shadow or
         * dropping back toward 32% goes red.
         */
        const val MIN_CONTRAST = 60
    }
}
