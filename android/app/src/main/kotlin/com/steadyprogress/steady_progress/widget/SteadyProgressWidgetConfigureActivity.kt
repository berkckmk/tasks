package com.steadyprogress.steady_progress.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Color
import android.graphics.PorterDuff
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import com.steadyprogress.steady_progress.R

/**
 * The widget setup screen.
 *
 * Opened by the launcher in two situations: once when the widget is first
 * dropped, and again whenever the user long-presses it and taps the
 * launcher's own reconfigure affordance (see `widgetFeatures` in
 * `res/xml/widget_steady_progress_info.xml`).
 *
 * Deliberately a plain Android Activity rather than a Flutter route: the
 * launcher starts this directly, often while the app isn't running, and
 * spinning up a Flutter engine to draw four swatches and a slider would put a
 * visible delay in front of a trivial screen.
 *
 * ## What went away
 *
 * The previous version had Glass (two sliders tuning a material's optics) and
 * Wallpaper (pick an image, drag a crop rectangle over it, set a backdrop
 * blur) sections, plus six field checkboxes. All of it is gone with the
 * material it configured. What remains configures things the panel actually
 * has.
 */
class SteadyProgressWidgetConfigureActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var config = WidgetConfig.DEFAULT

    private lateinit var previewFill: ImageView
    private lateinit var previewRows: LinearLayout
    private lateinit var groundRow: LinearLayout
    private lateinit var rowsRow: LinearLayout
    private lateinit var includeRow: LinearLayout
    private lateinit var opacityValue: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        // Set the cancelled result up front. If the user backs out — or the
        // process is killed — the launcher must not keep a half-configured
        // widget on the home screen.
        setResult(
            RESULT_CANCELED,
            Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
        )

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        config = WidgetConfigStore.read(this, appWidgetId)
        setContentView(R.layout.widget_configure)

        previewFill = findViewById(R.id.preview_fill)
        previewRows = findViewById(R.id.preview_rows)
        groundRow = findViewById(R.id.ground_row)
        rowsRow = findViewById(R.id.rows_row)
        includeRow = findViewById(R.id.include_row)
        opacityValue = findViewById(R.id.opacity_value)

        findViewById<TextView>(R.id.preview_chip).text =
            config.scope.label.uppercase() + " ⌄"

        buildGroundSwatches()
        buildRowsSegmented()
        buildIncludeTags()
        bindOpacity()

        findViewById<View>(R.id.config_back).setOnClickListener { finish() }
        findViewById<View>(R.id.config_cancel).setOnClickListener { finish() }
        findViewById<View>(R.id.config_save).setOnClickListener { save() }

        refreshPreview()
    }

    // -- Background ---------------------------------------------------------

    /** Four 46dp swatches; the selected one takes a 2dp accent border. */
    private fun buildGroundSwatches() {
        groundRow.removeAllViews()
        for (ground in WidgetGround.entries) {
            val column = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
            }

            val swatch = ImageView(this).apply {
                layoutParams = LinearLayout.LayoutParams(dp(46), dp(46))
                setImageResource(
                    if (ground == config.ground) {
                        R.drawable.config_swatch_selected
                    } else {
                        R.drawable.config_swatch
                    },
                )
                // "None" has no colour to show, so it shows the absence: the
                // shape with no fill, which reads as an empty slot.
                setColorFilter(
                    if (ground == WidgetGround.NONE) {
                        Color.TRANSPARENT
                    } else {
                        Color.rgb(
                            (ground.rgb shr 16) and 0xFF,
                            (ground.rgb shr 8) and 0xFF,
                            ground.rgb and 0xFF,
                        )
                    },
                    PorterDuff.Mode.SRC_ATOP,
                )
                contentDescription = groundLabel(ground)
            }

            val label = TextView(this).apply {
                text = groundLabel(ground)
                textSize = 11f
                setPadding(0, dp(5), 0, 0)
                setTextColor(
                    resources.getColor(
                        if (ground == config.ground) R.color.config_accent
                        else R.color.config_text_muted,
                        theme,
                    ),
                )
            }

            column.setOnClickListener {
                config = config.copy(ground = ground)
                buildGroundSwatches()
                refreshPreview()
            }

            column.addView(swatch)
            column.addView(label)
            groundRow.addView(column)
        }
    }

    private fun groundLabel(ground: WidgetGround): String = getString(
        when (ground) {
            WidgetGround.SURFACE -> R.string.config_ground_surface
            WidgetGround.INK -> R.string.config_ground_ink
            WidgetGround.ACCENT -> R.string.config_ground_accent
            WidgetGround.NONE -> R.string.config_ground_none
        },
    )

    // -- Opacity ------------------------------------------------------------

    private fun bindOpacity() {
        val bar = findViewById<SeekBar>(R.id.opacity_bar)
        bar.progress = config.opacity
        showOpacity()

        bar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar, value: Int, fromUser: Boolean) {
                config = config.copy(opacity = value)
                showOpacity()
                refreshPreview()
            }

            override fun onStartTrackingTouch(seekBar: SeekBar) = Unit
            override fun onStopTrackingTouch(seekBar: SeekBar) = Unit
        })
    }

    private fun showOpacity() {
        opacityValue.text = getString(R.string.config_percent, config.opacity)
    }

    // -- Rows shown ---------------------------------------------------------

    /**
     * A segmented control of 1 / 2 / 3 / 5.
     *
     * The selected option draws an inset accent ring carrying the container's
     * own corner radius — see `config_segment_selected.xml` for why the radius
     * matters at the two ends.
     */
    private fun buildRowsSegmented() {
        rowsRow.removeAllViews()
        for (count in WidgetConfig.ROW_OPTIONS) {
            val selected = count == config.rows
            val cell = TextView(this).apply {
                text = count.toString()
                textSize = 12.5f
                gravity = Gravity.CENTER
                setPadding(0, dp(10), 0, dp(10))
                layoutParams =
                    LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
                setTextColor(
                    resources.getColor(
                        if (selected) R.color.config_accent else R.color.config_text_muted,
                        theme,
                    ),
                )
                if (selected) setBackgroundResource(R.drawable.config_segment_selected)
                setOnClickListener {
                    config = config.copy(rows = count)
                    buildRowsSegmented()
                    refreshPreview()
                }
            }
            rowsRow.addView(cell)
        }
    }

    // -- Include ------------------------------------------------------------

    private fun buildIncludeTags() {
        includeRow.removeAllViews()
        for (value in WidgetInclude.entries) {
            val selected = config.includes(value)
            val tag = TextView(this).apply {
                text = value.label
                textSize = 12f
                gravity = Gravity.CENTER
                setPadding(dp(9), dp(6), dp(9), dp(6))
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                ).apply { marginEnd = dp(6) }
                setBackgroundResource(
                    if (selected) R.drawable.config_tag_selected else R.drawable.config_tag,
                )
                setTextColor(
                    if (selected) WidgetPalette.ACCENT
                    else resources.getColor(R.color.config_text_muted, theme),
                )
                setOnClickListener {
                    val next = config.include.toMutableSet()
                    if (!next.remove(value)) next.add(value)
                    config = config.copy(include = next)
                    buildIncludeTags()
                    refreshPreview()
                }
            }
            includeRow.addView(tag)
        }
    }

    // -- Preview ------------------------------------------------------------

    /**
     * The live preview.
     *
     * Applies exactly what the provider applies — the same colour filter and
     * the same alpha on the same drawable — so what the user tunes here is
     * what lands on the home screen, rather than an approximation of it.
     */
    private fun refreshPreview() {
        previewFill.setColorFilter(config.panelColor, PorterDuff.Mode.SRC_ATOP)
        previewFill.imageAlpha = config.panelAlpha
        findViewById<View>(R.id.preview_edge).visibility =
            if (config.ground == WidgetGround.NONE) View.INVISIBLE else View.VISIBLE

        previewRows.removeAllViews()
        val sample = sampleRows().take(config.rows)
        for ((time, title, done) in sample) {
            previewRows.addView(previewRow(time, title, done))
        }
    }

    /**
     * Stand-in rows for the preview.
     *
     * Deliberately generic rather than the user's real data: the setup screen
     * can open before the app has ever synced, and a preview that is
     * sometimes empty is a preview that can't be judged against.
     */
    private fun sampleRows(): List<Triple<String, String, Boolean>> = buildList {
        if (config.includes(WidgetInclude.REMINDERS)) {
            add(Triple("9:15", "Call the dentist", false))
        }
        if (config.includes(WidgetInclude.TASKS)) {
            add(Triple("11:00", "Draft the invoice", false))
        }
        if (config.includes(WidgetInclude.HABITS)) {
            add(Triple("18:00", "Evening walk", false))
        }
        if (config.showsCompleted) {
            add(Triple("7:00", "Morning review", true))
        }
        if (isEmpty()) add(Triple("", "Nothing selected", false))
    }

    private fun previewRow(time: String, title: String, done: Boolean): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(3), 0, dp(3))
        }

        row.addView(
            ImageView(this).apply {
                layoutParams = LinearLayout.LayoutParams(dp(13), dp(13))
                setImageResource(
                    if (done) R.drawable.widget_check_circle_fill else R.drawable.widget_circle,
                )
                setColorFilter(
                    if (done) WidgetPalette.ICON_CHECKED else WidgetPalette.ICON_UNCHECKED,
                    PorterDuff.Mode.SRC_ATOP,
                )
                // SRC_ATOP ignores the filter's alpha, so the muting is a
                // separate imageAlpha. See WidgetPalette.
                imageAlpha =
                    if (done) WidgetPalette.ALPHA_FULL else WidgetPalette.ALPHA_UNCHECKED
            },
        )
        row.addView(
            TextView(this).apply {
                text = time
                textSize = 10f
                gravity = Gravity.END
                setTextColor(WidgetPalette.TEXT_CAPTION)
                layoutParams =
                    LinearLayout.LayoutParams(dp(30), ViewGroup.LayoutParams.WRAP_CONTENT)
                        .apply { marginStart = dp(7) }
            },
        )
        row.addView(
            TextView(this).apply {
                text = title
                textSize = 11.5f
                maxLines = 1
                setTextColor(if (done) WidgetPalette.TEXT_DONE else WidgetPalette.TEXT)
                layoutParams = LinearLayout.LayoutParams(
                    0,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    1f,
                ).apply { marginStart = dp(7) }
            },
        )
        return row
    }

    // -- Save ---------------------------------------------------------------

    private fun save() {
        WidgetConfigStore.write(this, appWidgetId, config)
        SteadyProgressWidgetProvider.refresh(this, appWidgetId)
        setResult(
            RESULT_OK,
            Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
        )
        finish()
    }

    private fun dp(value: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        value.toFloat(),
        resources.displayMetrics,
    ).toInt()
}
