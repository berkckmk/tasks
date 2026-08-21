package com.steadyprogress.steady_progress.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.RectF
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.util.TypedValue
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.widget.Button
import android.widget.CheckBox
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import android.widget.Toast
import com.steadyprogress.steady_progress.R
import java.io.FileOutputStream

/**
 * Lets the user choose which fields a widget shows.
 *
 * Opened by the launcher in two situations: once when the widget is first
 * dropped on the home screen, and again whenever the user long-presses it and
 * taps the launcher's own reconfigure affordance (see `widgetFeatures` in
 * res/xml/widget_steady_progress_info.xml).
 *
 * Deliberately a plain Android activity rather than a Flutter route: the
 * launcher starts this directly, often while the app isn't running, and
 * spinning up a Flutter engine to draw five checkboxes would put a visible
 * delay in front of a trivial screen.
 */
class SteadyProgressWidgetConfigureActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private val checkboxes = mutableMapOf<WidgetField, CheckBox>()
    private lateinit var preview: ImageView
    private var backgroundBar: SeekBar? = null
    private var blurBar: SeekBar? = null
    private var opacityBar: SeekBar? = null
    private var backdropBlurBar: SeekBar? = null

    private lateinit var wallpaperView: ImageView
    private lateinit var dragHint: TextView

    /** File name of the wallpaper copy, or null for no backdrop. */
    private var backdropFile: String? = null

    /** Where the panel sits on the wallpaper, normalized 0..1. Null until a
     *  wallpaper is picked; [DEFAULT_BACKDROP_RECT] is applied at that point. */
    private var backdropRect: RectF? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Set before anything can fail. The launcher treats a cancelled
        // result as "don't place the widget", which is the correct outcome
        // if the user backs out of this screen.
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.widget_configure)
        applySystemBarInsets()
        preview = findViewById(R.id.config_preview)
        wallpaperView = findViewById(R.id.config_wallpaper)
        dragHint = findViewById(R.id.config_drag_hint)

        val current = WidgetConfigStore.read(this, appWidgetId)
        backdropFile = current.backdropFile
        backdropRect = current.backdropRect

        buildFieldList()
        buildAppearanceSliders()
        buildWallpaperControls()
        refreshWallpaperViews()
        renderPreview()

        findViewById<Button>(R.id.config_save).setOnClickListener { save() }
        findViewById<Button>(R.id.config_cancel).setOnClickListener { finish() }
    }

    /**
     * Pads the content clear of the status and navigation bars.
     *
     * Android 15 draws every activity edge-to-edge whether it asks to or not,
     * so without this the heading sits under the clock and the Save button
     * under the gesture bar. Done in code rather than with
     * `fitsSystemWindows` because this is a plain framework activity with no
     * AppCompat behind it to interpret that attribute consistently across the
     * versions this app supports.
     */
    private fun applySystemBarInsets() {
        val root = findViewById<View>(R.id.config_root)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            root.setOnApplyWindowInsetsListener { view, insets ->
                val bars = insets.getInsets(
                    WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout(),
                )
                view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
                insets
            }
            root.requestApplyInsets()
        } else {
            @Suppress("DEPRECATION")
            root.setOnApplyWindowInsetsListener { view, insets ->
                view.setPadding(
                    insets.systemWindowInsetLeft,
                    insets.systemWindowInsetTop,
                    insets.systemWindowInsetRight,
                    insets.systemWindowInsetBottom,
                )
                insets
            }
            root.requestApplyInsets()
        }
    }

    private fun buildFieldList() {
        val container = findViewById<LinearLayout>(R.id.config_fields)
        val current = WidgetConfigStore.read(this, appWidgetId)

        for (field in WidgetField.entries) {
            val row = layoutInflater.inflate(R.layout.widget_configure_row, container, false)
            val checkbox = row.findViewById<CheckBox>(R.id.row_checkbox)

            checkbox.text = field.label
            checkbox.isChecked = current.has(field)
            row.findViewById<TextView>(R.id.row_description).text = field.description

            // The whole row is the touch target, not just the box — a 20dp
            // checkbox in a list this size is an unnecessarily small target.
            row.setOnClickListener { checkbox.toggle() }
            checkbox.setOnCheckedChangeListener { _, _ -> renderPreview() }

            checkboxes[field] = checkbox
            container.addView(row)
        }
    }

    /**
     * The two glass controls.
     *
     * Kept separate from the field checkboxes above because they answer a
     * different question: the checkboxes decide *what* the widget says, these
     * decide how the material behind it behaves.
     */
    private fun buildAppearanceSliders() {
        val container = findViewById<LinearLayout>(R.id.config_sliders)
        val current = WidgetConfigStore.read(this, appWidgetId)

        backgroundBar = addSlider(
            container,
            getString(R.string.config_background_label),
            getString(R.string.config_background_description),
            current.background,
        )
        blurBar = addSlider(
            container,
            getString(R.string.config_blur_label),
            getString(R.string.config_blur_description),
            current.blur,
        )

        opacityBar = addSlider(
            container,
            getString(R.string.config_opacity_label),
            getString(R.string.config_opacity_description),
            current.opacity,
        )

        // Lives in its own container under the wallpaper controls, not with
        // the three above: it does nothing at all without a backdrop, and
        // showing it next to controls that always work would suggest
        // otherwise.
        backdropBlurBar = addSlider(
            findViewById(R.id.config_backdrop_sliders),
            getString(R.string.config_backdrop_blur_label),
            getString(R.string.config_backdrop_blur_description),
            current.backdropBlur,
        )
    }

    private fun addSlider(
        container: LinearLayout,
        label: String,
        description: String,
        initial: Int,
    ): SeekBar {
        val row = layoutInflater.inflate(R.layout.widget_configure_slider, container, false)
        row.findViewById<TextView>(R.id.slider_label).text = label
        row.findViewById<TextView>(R.id.slider_description).text = description

        val value = row.findViewById<TextView>(R.id.slider_value)
        val bar = row.findViewById<SeekBar>(R.id.slider_bar)
        bar.progress = initial
        value.text = getString(R.string.config_percent, initial)

        bar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar, progress: Int, fromUser: Boolean) {
                value.text = getString(R.string.config_percent, progress)
                // The number updates on every pixel of the drag, but the
                // preview only redraws while the finger is down at whole
                // steps — a re-render invalidates the panel cache and pays
                // for the whole blur stack, which is too much to do on every
                // one of a hundred progress callbacks.
                if (fromUser && progress % PREVIEW_STEP == 0) renderPreview()
            }

            override fun onStartTrackingTouch(seekBar: SeekBar) = Unit

            /** Always redraw on release, so the preview ends on the exact
             *  value the user chose rather than the last multiple of the
             *  step. */
            override fun onStopTrackingTouch(seekBar: SeekBar) = renderPreview()
        })

        container.addView(row)
        return bar
    }

    private fun selectedConfig() = WidgetConfig(
        fields = checkboxes.filterValues { it.isChecked }.keys.toSet(),
        background = backgroundBar?.progress ?: WidgetConfig.DEFAULT_LEVEL,
        blur = blurBar?.progress ?: WidgetConfig.DEFAULT_LEVEL,
        opacity = opacityBar?.progress ?: 100,
        backdropFile = backdropFile,
        backdropRect = backdropRect,
        backdropBlur = backdropBlurBar?.progress ?: WidgetConfig.DEFAULT_BACKDROP_BLUR,
    )

    /**
     * Draws the real widget with the current selection.
     *
     * Worth the few milliseconds: the field names alone don't tell you how
     * much room each one takes or how the layout re-flows when you switch one
     * off, and this is the same [GlassRenderer] the home screen uses — so
     * what's on screen here is exactly what gets placed.
     */
    private fun renderPreview() {
        val widthPx = dp(PREVIEW_WIDTH_DP)
        val heightPx = dp(PREVIEW_HEIGHT_DP)
        preview.setImageBitmap(
            GlassRenderer.render(
                this,
                widthPx,
                heightPx,
                previewData(),
                selectedConfig(),
            ),
        )
    }

    /**
     * Real numbers when the app has synced any, otherwise a plausible sample.
     *
     * A preview full of zeroes would make every option look identical and
     * hide exactly what the user is here to judge — how the widget looks with
     * that field on.
     */
    private fun previewData(): WidgetData {
        val stored = WidgetDataStore.read(this)
        if (stored.hasData && stored.totalCount > 0) return stored
        return WidgetData(
            habitsDone = 5,
            habitsTotal = 7,
            tasksDone = 2,
            tasksTotal = 4,
            bestStreak = 12,
            hasData = true,
        )
    }


    // =====================================================================
    // Wallpaper backdrop
    // =====================================================================

    /**
     * Wires the pick / remove buttons and the drag-to-position gesture.
     *
     * Plain `startActivityForResult` rather than an AndroidX
     * `ActivityResultContracts.PickVisualMedia`: this is a bare framework
     * [Activity] with no AppCompat behind it (see the class doc), and the
     * contracts API needs a `ComponentActivity` to register against.
     */
    private fun buildWallpaperControls() {
        findViewById<Button>(R.id.config_wallpaper_pick).setOnClickListener { pickWallpaper() }
        findViewById<Button>(R.id.config_wallpaper_clear).setOnClickListener { removeWallpaper() }
        preview.setOnTouchListener(panelDragListener())
    }

    private fun pickWallpaper() {
        // Both of these are permission-free. ACTION_PICK_IMAGES is the system
        // photo picker (API 33+) and shows only what the user selects;
        // ACTION_OPEN_DOCUMENT is the equivalent on older releases. Asking for
        // READ_MEDIA_IMAGES to do this would be a real permission for no
        // reason — see docs/ANDROID_SECURITY_POSTURE.md.
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Intent(MediaStore.ACTION_PICK_IMAGES).apply { type = "image/*" }
        } else {
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "image/*"
            }
        }
        try {
            startActivityForResult(intent, REQUEST_PICK_WALLPAPER)
        } catch (e: android.content.ActivityNotFoundException) {
            Toast.makeText(this, R.string.config_wallpaper_unavailable, Toast.LENGTH_SHORT).show()
        }
    }

    @Deprecated("Framework Activity has no ActivityResultRegistry; see pickWallpaper().")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_PICK_WALLPAPER || resultCode != RESULT_OK) return
        val uri = data?.data ?: return

        val name = WidgetConfigStore.backdropFileName(appWidgetId)
        if (!copyWallpaper(uri, name)) {
            Toast.makeText(this, R.string.config_wallpaper_failed, Toast.LENGTH_SHORT).show()
            return
        }

        backdropFile = name
        // Start centred rather than at the last position: the new image has
        // nothing to do with where the previous one was cropped.
        backdropRect = RectF(DEFAULT_BACKDROP_RECT)

        // Give the material more body than it needs over nothing.
        //
        // DEFAULT_LEVEL is tuned for a panel with no backdrop, where the only
        // thing behind the text is the glass itself. Put a photograph back
        // there and a dark region under the chips drops them to unreadable —
        // which is exactly what the first build of this did. Raising the
        // slider rather than overriding the value in the renderer keeps it
        // visible and adjustable: the user can drag it straight back down if
        // they want more wallpaper and less panel.
        backgroundBar?.progress = BACKDROP_BACKGROUND_LEVEL

        refreshWallpaperViews()
        renderPreview()
    }

    /**
     * Copies the picked image into the app's private files dir, downscaled to
     * the display's own width.
     *
     * Copying rather than persisting the URI is what makes the backdrop
     * survive a reboot — see `WidgetConfig.backdropFile`. Downscaling matters
     * for a different reason: the panel crop is at most a few hundred pixels
     * wide, so a 12-megapixel original is decoded and thrown away on every
     * render, and `RemoteViews` has a hard bitmap budget besides.
     */
    private fun copyWallpaper(uri: Uri, name: String): Boolean {
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
            if (bounds.outWidth <= 0) return false

            val target = resources.displayMetrics.widthPixels.coerceAtLeast(1)
            val opts = BitmapFactory.Options().apply {
                inSampleSize = sampleSizeFor(bounds.outWidth, target)
            }
            val bitmap = contentResolver.openInputStream(uri)?.use {
                BitmapFactory.decodeStream(it, null, opts)
            } ?: return false

            WidgetConfigStore.backdropFile(this, name).let { file ->
                FileOutputStream(file).use { out ->
                    // WEBP_LOSSY at 90 is visually indistinguishable here —
                    // the image ends up blurred behind glass — at a fraction
                    // of PNG's size in the app's private storage.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        bitmap.compress(Bitmap.CompressFormat.WEBP_LOSSY, 90, out)
                    } else {
                        @Suppress("DEPRECATION")
                        bitmap.compress(Bitmap.CompressFormat.WEBP, 90, out)
                    }
                }
            }
            bitmap.recycle()
            true
        } catch (e: Exception) {
            false
        } catch (e: OutOfMemoryError) {
            false
        }
    }

    /** Largest power of two that keeps the decoded width at or above [target]. */
    private fun sampleSizeFor(sourceWidth: Int, target: Int): Int {
        var sample = 1
        while (sourceWidth / (sample * 2) >= target) sample *= 2
        return sample
    }

    private fun removeWallpaper() {
        backdropFile?.let { WidgetConfigStore.backdropFile(this, it).delete() }
        backdropFile = null
        backdropRect = null
        refreshWallpaperViews()
        renderPreview()
    }

    /** Shows or hides everything that only makes sense with a backdrop. */
    private fun refreshWallpaperViews() {
        val name = backdropFile
        val file = name?.let { WidgetConfigStore.backdropFile(this, it) }
        val bitmap = if (file != null && file.exists()) {
            BitmapFactory.decodeFile(file.absolutePath)
        } else {
            null
        }

        if (bitmap == null) {
            // Covers "cleared" and "the file went missing" with one path, so
            // a stale file name can never leave the UI claiming a backdrop
            // the renderer won't find either.
            backdropFile = null
            backdropRect = null
            wallpaperView.setImageDrawable(null)
            wallpaperView.visibility = View.GONE
            dragHint.visibility = View.GONE
            preview.translationX = 0f
            preview.translationY = 0f
        } else {
            wallpaperView.setImageBitmap(bitmap)
            wallpaperView.visibility = View.VISIBLE
            dragHint.visibility = View.VISIBLE
        }
        findViewById<View>(R.id.config_backdrop_sliders).visibility =
            if (bitmap == null) View.GONE else View.VISIBLE
    }

    /**
     * Lets the user drag the panel to where the widget actually sits.
     *
     * This step can't be skipped or inferred:
     * `AppWidgetManager.getAppWidgetOptions()` gives the widget's size but
     * never its position, and there is no API that does. A launcher knows
     * where its own widgets are; an app is only told how big to draw.
     */
    private fun panelDragListener(): View.OnTouchListener {
        var downX = 0f
        var downY = 0f
        var startTx = 0f
        var startTy = 0f

        return View.OnTouchListener { view, event ->
            if (backdropFile == null) return@OnTouchListener false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX
                    downY = event.rawY
                    startTx = view.translationX
                    startTy = view.translationY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    // Clamped to half the panel so it can be dragged to any
                    // edge without being pushed entirely off the wallpaper,
                    // which would store an empty crop.
                    val limitX = view.width / 2f
                    val limitY = view.height / 2f
                    view.translationX = (startTx + event.rawX - downX).coerceIn(-limitX, limitX)
                    view.translationY = (startTy + event.rawY - downY).coerceIn(-limitY, limitY)
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    commitDraggedRect()
                    view.performClick()
                    true
                }
                else -> false
            }
        }
    }

    /**
     * Turns the panel's on-screen position into the normalized crop.
     *
     * Measured against the wallpaper's *drawn* rectangle, not the ImageView's
     * bounds: the view is `fitCenter`, so with any aspect mismatch the image
     * is letterboxed and the two differ. Using the view bounds would shift
     * the crop by the size of the letterbox on every non-matching wallpaper.
     */
    private fun commitDraggedRect() {
        val drawable = wallpaperView.drawable ?: return
        val bounds = RectF(
            0f,
            0f,
            drawable.intrinsicWidth.toFloat(),
            drawable.intrinsicHeight.toFloat(),
        )
        wallpaperView.imageMatrix.mapRect(bounds)
        if (bounds.width() <= 0f || bounds.height() <= 0f) return

        // Both views share the FrameLayout's coordinate space, so the panel's
        // position is just its layout position plus the drag translation.
        val panelLeft = preview.left + preview.translationX - (wallpaperView.left + bounds.left)
        val panelTop = preview.top + preview.translationY - (wallpaperView.top + bounds.top)

        backdropRect = RectF(
            (panelLeft / bounds.width()).coerceIn(0f, 1f),
            (panelTop / bounds.height()).coerceIn(0f, 1f),
            ((panelLeft + preview.width) / bounds.width()).coerceIn(0f, 1f),
            ((panelTop + preview.height) / bounds.height()).coerceIn(0f, 1f),
        )
        renderPreview()
    }

    private fun save() {
        WidgetConfigStore.write(this, appWidgetId, selectedConfig())
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

    private companion object {
        /** Redraw the preview every N steps of a slider drag. */
        const val PREVIEW_STEP = 4
        const val PREVIEW_WIDTH_DP = 300
        const val PREVIEW_HEIGHT_DP = 132

        const val REQUEST_PICK_WALLPAPER = 1001

        /** Where the background slider lands when a wallpaper is picked. */
        const val BACKDROP_BACKGROUND_LEVEL = 72

        /**
         * Where a freshly picked wallpaper is cropped before the user drags.
         *
         * The middle of the image rather than the top: a home screen's widgets
         * are almost never at the very top, and a centred start is the
         * shortest drag to most real positions.
         */
        val DEFAULT_BACKDROP_RECT = RectF(0.1f, 0.35f, 0.9f, 0.65f)
    }
}
