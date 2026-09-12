package com.steadyprogress.steady_progress.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
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

/**
 * Renders the widget at each of its three sizes and writes the result to the
 * device, so the panel can actually be looked at.
 *
 * A widget is the one surface in this app that cannot be inspected any other
 * way: it lives in the launcher's process, `flutter run` never draws it, and
 * the only feedback the platform gives when it goes wrong is an empty box.
 * This stands the same RemoteViews up in the test process, measures it at the
 * real dp sizes, and draws it into a Bitmap.
 *
 * Not an assertion test — [WidgetLayoutInflationTest] is where the assertions
 * live. This exists to produce something to look at:
 *
 *     adb shell am instrument -w -e class \
 *       com.steadyprogress.steady_progress.widget.WidgetRenderCaptureTest \
 *       com.steadyprogress.steady_progress.test/androidx.test.runner.AndroidJUnitRunner
 *     adb pull /sdcard/Android/data/com.steadyprogress.steady_progress/files/widget-4x2.png
 *
 * The rows are drawn by hand here rather than through the RemoteViewsService:
 * a collection is populated by the launcher's own adapter, which does not
 * exist in a test process, so a `ListView` fed by `setRemoteAdapter` renders
 * empty no matter what the data says.
 */
@RunWith(AndroidJUnit4::class)
class WidgetRenderCaptureTest {

    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun captureAllThreeSizes() {
        capture("widget-2x2", 166, 158, WidgetConfig.DEFAULT, rows = 3, narrow = true)
        capture("widget-4x2", 348, 158, WidgetConfig.DEFAULT, rows = 3, narrow = false)
        capture("widget-4x4", 348, 340, WidgetConfig.DEFAULT, rows = 6, narrow = false, tall = true)

        // The opacity slider at both ends, and the accent ground — the three
        // settings most likely to break contrast.
        capture(
            "widget-opacity-0", 348, 158,
            WidgetConfig.DEFAULT.copy(opacity = 0), rows = 3, narrow = false,
        )
        capture(
            "widget-opacity-100", 348, 158,
            WidgetConfig.DEFAULT.copy(opacity = 100), rows = 3, narrow = false,
        )
        capture(
            "widget-ground-accent", 348, 158,
            WidgetConfig.DEFAULT.copy(ground = WidgetGround.ACCENT), rows = 3, narrow = false,
        )
        capture("widget-empty", 348, 158, WidgetConfig.DEFAULT, rows = 0, narrow = false)

        // The ground that broke: light type on a bright wallpaper. The
        // mid-grey stand-in every capture above uses is dark enough to
        // flatter faint text, which is exactly why the washed-out ramp was
        // never visible here. WidgetTextContrastTest asserts on this case;
        // these two are for looking at it.
        capture(
            "widget-light-wallpaper", 348, 158, WidgetConfig.DEFAULT,
            rows = 3, narrow = false, wallpaper = LIGHT_WALLPAPER,
        )
        capture(
            "widget-light-wallpaper-no-panel", 348, 158,
            WidgetConfig.DEFAULT.copy(ground = WidgetGround.NONE),
            rows = 3, narrow = false, wallpaper = LIGHT_WALLPAPER,
        )
    }

    private fun capture(
        name: String,
        widthDp: Int,
        heightDp: Int,
        config: WidgetConfig,
        rows: Int,
        narrow: Boolean,
        tall: Boolean = false,
        wallpaper: Int = GREY_WALLPAPER,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_steady_progress)
        val root = views.apply(context, null)

        // The panel, exactly as the provider applies it.
        root.findViewById<ImageView>(R.id.panel_fill).apply {
            setColorFilter(config.panelColor, android.graphics.PorterDuff.Mode.SRC_ATOP)
            imageAlpha = config.panelAlpha
        }
        root.findViewById<View>(R.id.panel_edge).visibility =
            if (config.ground == WidgetGround.NONE) View.GONE else View.VISIBLE

        root.findViewById<TextView>(R.id.scope_chip).text =
            config.scope.label.uppercase() + " ⌄"
        root.findViewById<TextView>(R.id.summary).text =
            if (narrow) "5 / 12" else "5 / 12 · 42 day streak"
        root.findViewById<android.widget.ProgressBar>(R.id.progress).progress = 42

        val list = root.findViewById<View>(R.id.items)
        val empty = root.findViewById<View>(R.id.empty)
        if (rows == 0) {
            list.visibility = View.GONE
            empty.visibility = View.VISIBLE
            root.findViewById<ImageView>(R.id.empty_icon).apply {
                setColorFilter(WidgetPalette.ICON_EMPTY, android.graphics.PorterDuff.Mode.SRC_ATOP)
                imageAlpha = WidgetPalette.ALPHA_EMPTY
            }
        } else {
            // Swap the ListView for a plain column of the same row layout —
            // see the class doc for why the real collection can't render here.
            val parent = root.findViewById<LinearLayout>(R.id.panel)
            val index = parent.indexOfChild(list)
            parent.removeView(list)
            val column = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f,
                ).apply { topMargin = dp(6) }
            }
            for ((time, title, kind, done) in sampleRows().take(rows)) {
                column.addView(row(time, title, kind, done, compact = narrow))
            }
            parent.addView(column, index)
        }

        if (tall) {
            root.findViewById<View>(R.id.footer).visibility = View.VISIBLE
            root.findViewById<TextView>(R.id.footer_note).text = "+2 later this week"
        }

        val w = dp(widthDp)
        val h = dp(heightDp)
        root.measure(
            View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY),
        )
        root.layout(0, 0, w, h)

        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        // A stand-in for a wallpaper, so a translucent panel is judged
        // against something rather than against nothing.
        canvas.drawColor(wallpaper)
        root.draw(canvas)

        val dir = context.getExternalFilesDir(null) ?: context.filesDir
        File(dir, "$name.png").outputStream().use {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
        }
    }

    private fun sampleRows() = listOf(
        Row("9:15", "Call the dentist", WidgetItemKind.REMINDER, false),
        Row("11:00", "Draft the invoice", WidgetItemKind.TASK, false),
        Row("13:30", "Standup notes", WidgetItemKind.TASK, false),
        Row("18:00", "Evening walk", WidgetItemKind.HABIT, false),
        Row("21:00", "Read", WidgetItemKind.HABIT, false),
        Row("7:00", "Morning review", WidgetItemKind.REMINDER, true),
    )

    private data class Row(
        val time: String,
        val title: String,
        val kind: WidgetItemKind,
        val done: Boolean,
    )

    private fun row(
        time: String,
        title: String,
        kind: WidgetItemKind,
        done: Boolean,
        compact: Boolean = false,
    ): View {
        val views = RemoteViews(context.packageName, R.layout.widget_row)
        val view = views.apply(context, null)

        view.findViewById<TextView>(R.id.row_time).apply {
            text = time
            setTextSize(TypedValue.COMPLEX_UNIT_SP, if (compact) 10.5f else 11f)
        }
        view.findViewById<TextView>(R.id.row_title).apply {
            text = title
            setTextSize(TypedValue.COMPLEX_UNIT_SP, if (compact) 12f else 12.5f)
        }
        view.findViewById<TextView>(R.id.row_kind).text = kind.label

        // 2x2 drops the kind label and the type icon — see
        // WidgetItemsFactory.compact.
        val hidden = if (compact) View.GONE else View.VISIBLE
        view.findViewById<View>(R.id.row_kind).visibility = hidden
        view.findViewById<View>(R.id.row_icon).visibility = hidden

        view.findViewById<ImageView>(R.id.row_toggle).apply {
            setImageResource(
                if (done) R.drawable.widget_check_circle_fill else R.drawable.widget_circle,
            )
            setColorFilter(
                if (done) WidgetPalette.ICON_CHECKED else WidgetPalette.ICON_UNCHECKED,
                android.graphics.PorterDuff.Mode.SRC_ATOP,
            )
            imageAlpha =
                if (done) WidgetPalette.ALPHA_FULL else WidgetPalette.ALPHA_UNCHECKED
        }
        view.findViewById<ImageView>(R.id.row_icon).apply {
            setImageResource(
                when (kind) {
                    WidgetItemKind.REMINDER -> R.drawable.widget_kind_reminder
                    WidgetItemKind.TASK -> R.drawable.widget_kind_task
                    WidgetItemKind.HABIT -> R.drawable.widget_kind_habit
                },
            )
            setColorFilter(WidgetPalette.ICON_TYPE, android.graphics.PorterDuff.Mode.SRC_ATOP)
            imageAlpha =
                if (done) WidgetPalette.ALPHA_DONE else WidgetPalette.ALPHA_TYPE
        }

        if (done) {
            view.findViewById<TextView>(R.id.row_title).apply {
                setTextColor(WidgetPalette.TEXT_DONE)
                paintFlags = paintFlags or android.graphics.Paint.STRIKE_THRU_TEXT_FLAG
            }
            view.findViewById<TextView>(R.id.row_time).setTextColor(WidgetPalette.TEXT_DONE)
            view.findViewById<TextView>(R.id.row_kind).setTextColor(WidgetPalette.TEXT_DONE)
        }

        return view
    }

    private companion object {
        /** Mid-grey: the neutral default every size is captured over. */
        val GREY_WALLPAPER = Color.rgb(0x6E, 0x72, 0x82)

        /** A bright photo — the case the washed-out ramp failed on. */
        val LIGHT_WALLPAPER = Color.rgb(0xEC, 0xEA, 0xE6)
    }

    private fun dp(value: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        value.toFloat(),
        context.resources.displayMetrics,
    ).toInt()
}
