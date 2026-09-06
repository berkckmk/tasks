package com.steadyprogress.steady_progress.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.PorterDuff
import android.util.TypedValue
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.RemoteViews
import android.widget.TextView
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.steadyprogress.steady_progress.R
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** SCRATCH — renders candidate type scales. Delete after choosing one. */
@RunWith(AndroidJUnit4::class)
class ZzTypeScaleSweepTest {

    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    /** Every size the widget uses, at one scale factor. */
    private data class Scale(val name: String, val k: Float) {
        val chip get() = 9.5f * k
        val summary get() = 11.5f * k
        val time get() = 11f * k
        val title get() = 12.5f * k
        val kind get() = 10f * k
        /** The time column is fixed and must grow with the digits in it. */
        val timeColumnDp get() = (34f * k).toInt()
    }

    @Test
    fun sweep() {
        val scales = listOf(
            Scale("A-current-1.00x", 1.00f),
            Scale("B-1.12x", 1.12f),
            Scale("C-1.24x", 1.24f),
            Scale("D-1.36x", 1.36f),
            Scale("E-1.50x", 1.50f),
        )
        for (s in scales) {
            render(s, "mid", Color.rgb(0x6E, 0x72, 0x82), 348, 158)
            render(s, "narrow", Color.rgb(0x6E, 0x72, 0x82), 166, 158)
            render(s, "narrow-notime", Color.rgb(0x6E, 0x72, 0x82), 166, 158, hideTime = true)
        }
    }

    private fun render(
        s: Scale,
        tag: String,
        wallpaper: Int,
        wDp: Int,
        hDp: Int,
        hideTime: Boolean = false,
    ) {
        val root = RemoteViews(context.packageName, R.layout.widget_steady_progress)
            .apply(context, null)
        // The shipped default: no panel, rows straight on the wallpaper.
        root.findViewById<ImageView>(R.id.panel_fill).imageAlpha = 0
        root.findViewById<View>(R.id.panel_edge).visibility = View.GONE

        root.findViewById<TextView>(R.id.scope_chip).apply {
            text = "TODAY ⌄"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, s.chip)
        }
        root.findViewById<TextView>(R.id.summary).apply {
            text = if (wDp < 200) "5 / 12" else "5 / 12 · 42 day streak"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, s.summary)
        }
        root.findViewById<android.widget.ProgressBar>(R.id.progress).progress = 42

        val panel = root.findViewById<LinearLayout>(R.id.panel)
        val list = root.findViewById<View>(R.id.items)
        val index = panel.indexOfChild(list)
        panel.removeView(list)
        val column = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f,
            ).apply { topMargin = dp(6) }
        }
        val rows = listOf(
            Triple("9:15", "Call the dentist", "Reminder"),
            Triple("11:00", "Draft the invoice", "Task"),
            Triple("13:30", "Standup notes", "Task"),
        )
        for ((t, ti, k) in rows) column.addView(row(t, ti, k, s, wDp < 200, hideTime))
        panel.addView(column, index)

        val w = dp(wDp); val h = dp(hDp)
        root.measure(
            View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY),
        )
        root.layout(0, 0, w, h)
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        Canvas(bitmap).apply { drawColor(wallpaper); root.draw(this) }
        val dir = context.getExternalFilesDir(null) ?: context.filesDir
        File(dir, "type-${s.name}-$tag.png").outputStream().use {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
        }
    }

    private fun row(
        time: String,
        title: String,
        kind: String,
        s: Scale,
        compact: Boolean,
        hideTime: Boolean = false,
    ): View {
        val view = RemoteViews(context.packageName, R.layout.widget_row).apply(context, null)
        view.findViewById<TextView>(R.id.row_time).apply {
            text = time
            setTextSize(TypedValue.COMPLEX_UNIT_SP, s.time)
            layoutParams = (layoutParams as LinearLayout.LayoutParams)
                .apply { width = dp(s.timeColumnDp) }
            visibility = if (hideTime) View.GONE else View.VISIBLE
        }
        view.findViewById<TextView>(R.id.row_title).apply {
            text = title
            setTextSize(TypedValue.COMPLEX_UNIT_SP, s.title)
        }
        view.findViewById<TextView>(R.id.row_kind).apply {
            text = kind
            setTextSize(TypedValue.COMPLEX_UNIT_SP, s.kind)
            visibility = if (compact) View.GONE else View.VISIBLE
        }
        view.findViewById<ImageView>(R.id.row_toggle).apply {
            setColorFilter(WidgetPalette.ICON_UNCHECKED, PorterDuff.Mode.SRC_ATOP)
            imageAlpha = WidgetPalette.ALPHA_UNCHECKED
        }
        view.findViewById<ImageView>(R.id.row_icon).apply {
            setImageResource(R.drawable.widget_kind_task)
            setColorFilter(WidgetPalette.ICON_TYPE, PorterDuff.Mode.SRC_ATOP)
            imageAlpha = WidgetPalette.ALPHA_TYPE
            visibility = if (compact) View.GONE else View.VISIBLE
        }
        return view
    }

    private fun dp(value: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), context.resources.displayMetrics,
    ).toInt()
}
