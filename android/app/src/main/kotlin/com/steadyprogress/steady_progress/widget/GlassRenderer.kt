package com.steadyprogress.steady_progress.widget

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Renders the whole widget — glass panel plus content — into one bitmap.
 *
 * See [LiquidGlass] for why this is a bitmap rather than a view hierarchy:
 * `RemoteViews` won't host a custom `View`, so a single `ImageView` holding a
 * bitmap we drew ourselves is the only way to get this material onto a home
 * screen at all.
 *
 * The layout is driven by [WidgetConfig]: the user picks which fields to show
 * (see the configure activity), and the content re-flows around whatever is
 * left rather than leaving holes where a hidden field used to be.
 */
object GlassRenderer {

    // The app's palette (lib/app/theme/app_colors.dart), so the widget and
    // the dashboard read as one product.
    private val DEEP_GREEN = Color.rgb(0x2F, 0x52, 0x33)
    private val MUTED_BLUE = Color.rgb(0x5C, 0x7A, 0x99)
    private val AMBER = Color.rgb(0xC9, 0x8A, 0x3E)
    private val CHARCOAL = Color.rgb(0x2A, 0x2A, 0x28)

    /** Inset so the ambient shadow has room to fall outside the panel
     *  without being clipped by the bitmap edge. */
    private const val PANEL_PADDING = 14f

    /** Alpha of the containing hairline. See where it's drawn in [panelLayer]
     *  for the measurement this is tuned against. */
    private const val HAIRLINE_ALPHA = 60

    fun render(
        context: Context,
        widthPx: Int,
        heightPx: Int,
        data: WidgetData,
        config: WidgetConfig = WidgetConfig.DEFAULT,
    ): Bitmap = renderPage(context, widthPx, heightPx, data, config, WidgetPage.Today)

    /** Renders one carousel card. */
    fun renderPage(
        context: Context,
        widthPx: Int,
        heightPx: Int,
        data: WidgetData,
        config: WidgetConfig,
        page: WidgetPage,
    ): Bitmap {
        val (w, h) = clampToWidgetBitmapBudget(context, widthPx, heightPx)
        val isDark = isNightMode(context)
        val panel = RectF(PANEL_PADDING, PANEL_PADDING, w - PANEL_PADDING, h - PANEL_PADDING)

        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        canvas.drawBitmap(panelLayer(context, w, h, isDark, panel, config), 0f, 0f, null)
        when (page) {
            is WidgetPage.Today -> drawContent(canvas, panel, data, config, isDark)
            is WidgetPage.Section ->
                drawSection(canvas, panel, page, isDark, context.resources.displayMetrics.density)
        }

        return bitmap
    }

    /**
     * A section card: heading, counter, then as many rows as the card can
     * hold without crowding.
     *
     * How many rows fit is computed from the panel's own height rather than
     * fixed, because the user can resize the widget to anything between 110dp
     * and 220dp tall. A fixed row count would either waste half a tall widget
     * or overflow a short one.
     */
    private fun drawSection(
        canvas: Canvas,
        panel: RectF,
        page: WidgetPage.Section,
        isDark: Boolean,
        density: Float,
    ) {
        val primary = if (isDark) Color.WHITE else CHARCOAL
        val secondary = if (isDark) Color.argb(178, 255, 255, 255) else Color.argb(168, 42, 42, 40)

        val unit = panel.height()
        val padH = min(11f * density, unit * 0.14f)
        val padV = min(10f * density, unit * 0.12f)
        val left = panel.left + padH
        val right = panel.right - padH
        val available = right - left

        // Type is sized in dp, NOT as a fraction of the card.
        //
        // This is the whole point of a resizable list card: making a widget
        // taller should show *more rows*, not the same rows in bigger type.
        // Scaling off the panel height did the latter — a double-height card
        // rendered giant text and still cut off after three habits. The
        // fractions below are only a floor-guard so a very short card shrinks
        // its type rather than overflowing.
        val titleSize = min(13f * density, unit * 0.16f)
        val rowSize = min(10.5f * density, unit * 0.13f)

        val title = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = primary
            textSize = titleSize
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
        }
        var y = panel.top + padV + titleSize * 0.85f
        canvas.drawText(ellipsize(page.title, title, available * 0.6f), left, y, title)

        page.counter?.let { counter ->
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                textSize = rowSize * 0.92f
                typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
                textAlign = Paint.Align.RIGHT
                color = if (isDark) lighten(page.accent, 0.55f) else darken(page.accent, 0.15f)
            }
            canvas.drawText(counter, right, y, paint)
        }

        // Rows are laid out in the space left under the heading. One row is
        // held back for a "+N more" line whenever the list doesn't fit, so
        // the card never silently truncates.
        // A progress row carries a label and a bar; a checklist row is a
        // single line, so it doesn't need the same breathing room.
        val rowHeight = when (page.style) {
            WidgetPage.Section.Style.CHECKLIST -> rowSize * 1.42f
            WidgetPage.Section.Style.PROGRESS -> rowSize * 1.95f
        }
        val bodyTop = y + rowSize * 0.55f
        val bodyHeight = panel.bottom - padV - bodyTop
        val capacity = (bodyHeight / rowHeight).toInt().coerceAtLeast(1)

        val overflow = page.items.size > capacity
        val shown = if (overflow) capacity - 1 else page.items.size
        var rowY = bodyTop + rowHeight * 0.68f

        for (item in page.items.take(shown.coerceAtLeast(0))) {
            drawSectionRow(canvas, left, rowY, available, rowSize, item, page, isDark, primary)
            rowY += rowHeight
        }

        if (overflow) {
            val remaining = page.items.size - shown
            val more = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = secondary
                textSize = rowSize * 0.92f
                typeface = Typeface.create("sans-serif", Typeface.NORMAL)
            }
            canvas.drawText("+$remaining more", left, rowY, more)
        }
    }

    private fun drawSectionRow(
        canvas: Canvas,
        left: Float,
        baseline: Float,
        available: Float,
        textSize: Float,
        item: WidgetItem,
        page: WidgetPage.Section,
        isDark: Boolean,
        primary: Int,
    ) {
        val label = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.textSize = textSize
            typeface = Typeface.create("sans-serif", Typeface.NORMAL)
        }

        when (page.style) {
            WidgetPage.Section.Style.CHECKLIST -> {
                val markSize = textSize * 0.82f
                val cx = left + markSize / 2f
                val cy = baseline - textSize * 0.32f
                drawCheckMark(canvas, cx, cy, markSize / 2f, item.done, page.accent, isDark)

                val textLeft = left + markSize + textSize * 0.52f
                // A completed item is stated, not shouted: same size, lower
                // contrast, so the eye lands on what's still outstanding.
                label.color = if (item.done) {
                    if (isDark) Color.argb(120, 255, 255, 255) else Color.argb(110, 42, 42, 40)
                } else {
                    primary
                }
                canvas.drawText(
                    ellipsize(item.label, label, available - (textLeft - left)),
                    textLeft, baseline, label,
                )
            }

            WidgetPage.Section.Style.PROGRESS -> {
                val percent = (item.progress.coerceIn(0f, 1f) * 100).roundToInt()
                val percentPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    this.textSize = textSize * 0.92f
                    typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
                    textAlign = Paint.Align.RIGHT
                    color = if (isDark) lighten(page.accent, 0.55f) else darken(page.accent, 0.15f)
                }
                val percentText = "$percent%"
                val percentWidth = percentPaint.measureText(percentText)

                label.color = primary
                canvas.drawText(
                    ellipsize(item.label, label, available - percentWidth - textSize * 0.6f),
                    left, baseline - textSize * 0.42f, label,
                )
                canvas.drawText(percentText, left + available, baseline - textSize * 0.42f, percentPaint)

                // A hairline track under the label, so several reminders can be
                // compared at a glance without reading the numbers.
                val barY = baseline + textSize * 0.22f
                val barHeight = textSize * 0.20f
                val track = RectF(left, barY - barHeight / 2f, left + available, barY + barHeight / 2f)
                canvas.drawPath(
                    LiquidGlass.squirclePath(track, barHeight / 2f),
                    Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = if (isDark) Color.argb(46, 255, 255, 255) else Color.argb(52, 42, 42, 40)
                    },
                )
                val filled = available * item.progress.coerceIn(0f, 1f)
                if (filled > barHeight) {
                    val fill = RectF(left, track.top, left + filled, track.bottom)
                    canvas.drawPath(
                        LiquidGlass.squirclePath(fill, barHeight / 2f),
                        Paint(Paint.ANTI_ALIAS_FLAG).apply {
                            shader = LinearGradient(
                                fill.left, fill.top, fill.right, fill.bottom,
                                intArrayOf(lighten(page.accent, 0.3f), page.accent),
                                null, Shader.TileMode.CLAMP,
                            )
                        },
                    )
                }
            }
        }
    }

    /** A filled circle with a tick when done, an open ring when not. */
    private fun drawCheckMark(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        radius: Float,
        done: Boolean,
        accent: Int,
        isDark: Boolean,
    ) {
        if (done) {
            canvas.drawCircle(
                cx, cy, radius,
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (isDark) lighten(accent, 0.35f) else accent
                },
            )
            val tick = Path().apply {
                moveTo(cx - radius * 0.42f, cy + radius * 0.04f)
                lineTo(cx - radius * 0.10f, cy + radius * 0.38f)
                lineTo(cx + radius * 0.46f, cy - radius * 0.34f)
            }
            canvas.drawPath(
                tick,
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = radius * 0.32f
                    strokeCap = Paint.Cap.ROUND
                    strokeJoin = Paint.Join.ROUND
                    color = if (isDark) Color.argb(235, 12, 20, 14) else Color.WHITE
                },
            )
        } else {
            canvas.drawCircle(
                cx, cy, radius - radius * 0.14f,
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = radius * 0.28f
                    color = if (isDark) Color.argb(96, 255, 255, 255) else Color.argb(92, 42, 42, 40)
                },
            )
        }
    }

    /**
     * The glass panel, cached.
     *
     * The panel is the expensive half of a render — seven `BlurMaskFilter`
     * passes, all of which run in software because this draws into a
     * [Bitmap] rather than a hardware canvas. It also depends on nothing but
     * the widget's size and the night-mode flag: not the data, not the field
     * selection.
     *
     * That matters because both callers redraw far more often than the panel
     * actually changes — the configure screen re-renders on every checkbox
     * tap, and the provider on every data push. Without this cache a toggle
     * costs a full blur stack and the screen visibly stalls.
     *
     * Only one panel is held: a device has one widget size in play at a time
     * in the common case, and a stale entry is a megabyte that would never be
     * reused. Callers only ever composite this, never draw into it.
     */
    @Synchronized
    private fun panelLayer(
        context: Context,
        w: Int,
        h: Int,
        isDark: Boolean,
        panel: RectF,
        config: WidgetConfig,
    ): Bitmap {
        // The style levels belong in the key: dragging a slider has to
        // invalidate the panel, or the preview would never change. So does
        // every backdrop input — the file, the crop and the blur — or picking
        // a new wallpaper would repaint nothing and look like a broken save.
        val key = "$w×$h×$isDark×${config.background}×${config.blur}×${config.opacity}" +
            "×${config.backdropFile}×${config.backdropRect}×${config.backdropBlur}"
        cachedPanel?.let { if (cachedPanelKey == key && !it.isRecycled) return it }

        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        // Tuned against rendered previews rather than matched to Android's
        // 28dp widget radius: a superellipse corner hugs the edge for longer
        // than a circular arc of the same radius, so the identical number
        // reads noticeably rounder. This lands close to iOS's proportions.
        val radius = min(panel.width(), panel.height()) * 0.20f
        val backdrop = loadBackdrop(context, config, panel.width().toInt(), panel.height().toInt())
        LiquidGlass.drawPanel(
            Canvas(bitmap), panel, radius, isDark, resolveTint(backdrop),
            background = config.backgroundFraction,
            blur = config.blurFraction,
            opacity = config.opacityFraction,
            backdrop = backdrop,
        )

        // The containing hairline, drawn over the material.
        //
        // This has to be measured against the launcher rather than eyeballed:
        // it sits inches from One UI's own widget panels, and any mismatch in
        // weight is read as this widget not belonging on the home screen.
        // Sampled from a screenshot of that home screen, One UI draws its
        // panel edge as *one physical pixel* at luminance 74 over a fill of
        // 25 — a +49 step, neutral in hue.
        //
        // Two things were wrong with the previous version. It scaled the
        // stroke with the panel (1% of the min dimension, ~3px here), so the
        // line got heavier as the widget got bigger, where the platform's
        // stays one pixel at every size. And at alpha 200 it landed near
        // white — measured at 216 over a 45 fill, a +171 step, three and a
        // half times the platform's. Together those read as an outline drawn
        // on top of the panel rather than as its edge, which is exactly what
        // made the widget look pasted onto the wallpaper.
        //
        // HAIRLINE_ALPHA is what lands on the measured +49 once composited
        // over the material's own rim underneath. Re-measure from a
        // screenshot if it changes; it is not a free parameter.
        Canvas(bitmap).drawPath(
            LiquidGlass.squirclePath(panel, radius),
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = 1f
                color = Color.argb(HAIRLINE_ALPHA, 255, 255, 255)
            },
        )

        cachedPanel?.recycle()
        cachedPanel = bitmap
        cachedPanelKey = key
        return bitmap
    }


    // =====================================================================
    // Backdrop
    // =====================================================================

    /**
     * Loads the user's wallpaper, crops it to where the widget sits, and
     * blurs it — the image [LiquidGlass.drawPanel] composites under the glass.
     *
     * Returns null whenever there is nothing to show, including when the file
     * has gone missing (the user cleared app storage, a restore dropped it).
     * A missing backdrop must degrade to the optics-only panel, never to a
     * blank widget on someone's home screen.
     */
    private fun loadBackdrop(
        context: Context,
        config: WidgetConfig,
        targetW: Int,
        targetH: Int,
    ): Bitmap? {
        val name = config.backdropFile ?: return null
        if (targetW <= 0 || targetH <= 0) return null

        val file = WidgetConfigStore.backdropFile(context, name)
        if (!file.exists()) return null

        val full = try {
            BitmapFactory.decodeFile(file.absolutePath)
        } catch (e: OutOfMemoryError) {
            null
        } ?: return null

        // Default to the whole image when the crop was never set, so a
        // backdrop still appears if the drag step was skipped.
        val r = config.backdropRect ?: RectF(0f, 0f, 1f, 1f)
        val src = Rect(
            (r.left * full.width).toInt().coerceIn(0, full.width - 1),
            (r.top * full.height).toInt().coerceIn(0, full.height - 1),
            (r.right * full.width).toInt().coerceIn(1, full.width),
            (r.bottom * full.height).toInt().coerceIn(1, full.height),
        )
        if (src.width() < 1 || src.height() < 1) {
            full.recycle()
            return null
        }

        val crop = Bitmap.createBitmap(targetW, targetH, Bitmap.Config.ARGB_8888)
        Canvas(crop).drawBitmap(
            full,
            src,
            Rect(0, 0, targetW, targetH),
            Paint(Paint.FILTER_BITMAP_FLAG),
        )
        full.recycle()

        return blur(crop, config.backdropBlurFraction)
    }

    /**
     * Blurs by downscaling and scaling back up with bilinear filtering,
     * repeatedly.
     *
     * Not the obvious choice, but the obvious ones aren't available here:
     * `RenderScript` was deprecated in API 31 and removed from the toolchain,
     * and `RenderEffect.createBlurEffect` only applies through
     * `View.setRenderEffect` — and a widget has no custom `View` to set it on
     * (see [LiquidGlass]). Repeated bilinear downsampling converges on a
     * Gaussian, costs a few small allocations, needs no dependency, and works
     * on every API level this app supports.
     */
    private fun blur(source: Bitmap, strength: Float): Bitmap {
        val s = strength.coerceIn(0f, 1f)
        if (s <= 0.01f) return source

        // 1/2 at the low end down to 1/24 at the top. Past that the crop has
        // too few pixels left to carry any of the wallpaper's structure and
        // the backdrop turns into a flat colour wash.
        val factor = 2f + s * 22f
        val w = (source.width / factor).toInt().coerceAtLeast(2)
        val h = (source.height / factor).toInt().coerceAtLeast(2)

        // Two *different* sizes, halfway then the rest. Scaling twice to the
        // same size does nothing at all: createScaledBitmap returns the
        // source unchanged when the dimensions already match, so the obvious
        // "run it twice to soften it" is silently a single pass.
        val midW = ((source.width + w) / 2).coerceAtLeast(w)
        val midH = ((source.height + h) / 2).coerceAtLeast(h)

        val mid = Bitmap.createScaledBitmap(source, midW, midH, true)
        val small = Bitmap.createScaledBitmap(mid, w, h, true)
        if (mid != source) mid.recycle()

        val out = Bitmap.createScaledBitmap(small, source.width, source.height, true)
        if (small != out) small.recycle()
        source.recycle()
        return out
    }

    /**
     * The accent the material is lit with.
     *
     * With a backdrop, sampled from the backdrop itself, so the glass carries
     * the colour of what it is actually in front of. Without one, the system
     * wallpaper's own primary colour — `getWallpaperColors` needs no
     * permission (unlike reading the wallpaper image) and is available from
     * API 27, so even an unconfigured widget picks up something of the home
     * screen it sits on. [DEEP_GREEN] is the last resort, and what every
     * widget used before this existed.
     */
    private fun resolveTint(backdrop: Bitmap?): Int {
        if (backdrop != null) return dominantColor(backdrop)

        // Deliberately still the brand colour, and not the system wallpaper's.
        //
        // `WallpaperManager.getWallpaperColors(FLAG_SYSTEM)` would work here —
        // it needs no permission and has been available since API 27, unlike
        // reading the wallpaper *image* — and tinting from it is tempting.
        // But it would change how every already-placed widget looks, on an
        // upgrade, with no way for the user to ask for it or undo it, and a
        // dark wallpaper would push the material's body dark underneath text
        // that stays charcoal. Widgets that opted into a backdrop get their
        // tint from what's actually behind them, above; the rest keep the
        // tuned appearance they had.
        return DEEP_GREEN
    }

    /** Mean colour of a coarse sample. The backdrop is already blurred, so a
     *  handful of points is as good as every pixel and far cheaper. */
    private fun dominantColor(bitmap: Bitmap): Int {
        var r = 0L
        var g = 0L
        var b = 0L
        var n = 0
        val stepX = (bitmap.width / 8).coerceAtLeast(1)
        val stepY = (bitmap.height / 8).coerceAtLeast(1)
        var y = 0
        while (y < bitmap.height) {
            var x = 0
            while (x < bitmap.width) {
                val c = bitmap.getPixel(x, y)
                r += Color.red(c); g += Color.green(c); b += Color.blue(c)
                n++
                x += stepX
            }
            y += stepY
        }
        if (n == 0) return DEEP_GREEN
        return Color.rgb((r / n).toInt(), (g / n).toInt(), (b / n).toInt())
    }

    private var cachedPanel: Bitmap? = null
    private var cachedPanelKey: String? = null

    /**
     * Keeps the bitmap inside the size the platform will actually accept.
     *
     * `AppWidgetService` rejects a `RemoteViews` whose bitmaps exceed
     * `screenWidth * screenHeight * 4 * 1.5` bytes, and throws rather than
     * degrading — so a widget stretched to its maximum on a high-density
     * screen is exactly the case that would blow up in the field and never
     * on a test device. Budgeting against the real display (with headroom,
     * since other bitmaps in the same RemoteViews would count too) is the
     * only version of this check that scales with the device.
     *
     * Over budget, both sides are scaled by the same factor and the
     * `ImageView`'s `fitXY` stretches the result back up. Slightly softer on
     * a very large widget, which is strictly better than not rendering.
     */
    private fun clampToWidgetBitmapBudget(context: Context, widthPx: Int, heightPx: Int): Pair<Int, Int> {
        val w = widthPx.coerceAtLeast(1)
        val h = heightPx.coerceAtLeast(1)

        val metrics = context.resources.displayMetrics
        val budgetPx = metrics.widthPixels.toLong() * metrics.heightPixels.toLong()
        val requestedPx = w.toLong() * h.toLong()
        if (requestedPx <= budgetPx) return Pair(w, h)

        val scale = sqrt(budgetPx.toDouble() / requestedPx.toDouble())
        return Pair(
            (w * scale).toInt().coerceAtLeast(1),
            (h * scale).toInt().coerceAtLeast(1),
        )
    }

    private fun drawContent(
        canvas: Canvas,
        panel: RectF,
        data: WidgetData,
        config: WidgetConfig,
        isDark: Boolean,
    ) {
        val primary = if (isDark) Color.WHITE else CHARCOAL
        val secondary = if (isDark) Color.argb(178, 255, 255, 255) else Color.argb(168, 42, 42, 40)
        val unit = panel.height()
        val padding = unit * 0.16f

        if (config.isEmpty) {
            drawCentredMessage(canvas, panel, "Tap to configure", secondary, unit * 0.13f)
            return
        }

        if (config.isRingOnly) {
            // A ring with an empty column beside it looks like a rendering
            // bug, so this gets its own layout: one large centred dial.
            val radius = min(unit * 0.78f, panel.width() * 0.78f) / 2f
            drawProgressRing(
                canvas, panel.centerX(), panel.centerY(), radius,
                data.progress, isDark, primary, showLabel = data.hasData,
            )
            return
        }

        var textLeft = panel.left + padding
        var available = panel.width() - padding * 2f

        if (config.has(WidgetField.RING)) {
            val ringDiameter = min(unit * 0.62f, panel.width() * 0.32f)
            val ringCx = panel.left + padding + ringDiameter / 2f
            drawProgressRing(
                canvas, ringCx, panel.centerY(), ringDiameter / 2f,
                data.progress, isDark, primary, showLabel = data.hasData,
            )
            textLeft = ringCx + ringDiameter / 2f + padding * 0.85f
            available = panel.right - padding - textLeft
        }
        if (available <= 0f) return

        val titleSize = unit * 0.155f
        val bodySize = unit * 0.125f

        // Rows are measured before any are drawn so the whole block can be
        // centred. Without this, turning a field off leaves the remaining
        // text sitting where the full three-row stack used to start.
        val showSummary = config.has(WidgetField.SUMMARY)
        val showChips = data.hasData && data.totalCount > 0 &&
            (config.has(WidgetField.HABITS) || config.has(WidgetField.TASKS))

        val titleAdvance = titleSize * 1.02f
        val summaryAdvance = bodySize * 1.5f
        val chipsAdvance = bodySize * 1.62f

        var stackHeight = titleAdvance
        if (showSummary) stackHeight += summaryAdvance
        if (showChips) stackHeight += chipsAdvance

        var y = panel.centerY() - stackHeight / 2f + titleSize * 0.80f

        val title = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = primary
            textSize = titleSize
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
        }
        val body = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = secondary
            textSize = bodySize
            typeface = Typeface.create("sans-serif", Typeface.NORMAL)
        }

        // The streak sits right-aligned on the title's line rather than in
        // the chip row below. Three chips need roughly 1.5x the width this
        // layout has, so the streak was always the one silently dropped —
        // and it's the most motivating number on the widget. Up here it uses
        // space that was otherwise empty.
        var titleWidth = available
        if (config.has(WidgetField.STREAK) && data.hasData && data.bestStreak > 0) {
            titleWidth -= drawStreakBadge(canvas, panel, y, bodySize, data.bestStreak, isDark, available)
        }
        canvas.drawText(ellipsize("Today", title, titleWidth), textLeft, y, title)

        if (showSummary) {
            y += summaryAdvance
            val summary = when {
                !data.hasData -> "Open the app to sync"
                data.totalCount == 0 -> "Nothing scheduled"
                else -> "${data.doneCount} of ${data.totalCount} done"
            }
            canvas.drawText(ellipsize(summary, body, available), textLeft, y, body)
        }

        if (showChips) {
            y += chipsAdvance
            drawChips(canvas, textLeft, y, available, bodySize, data, config, isDark)
        }
    }

    private fun drawCentredMessage(
        canvas: Canvas,
        panel: RectF,
        text: String,
        color: Int,
        size: Float,
    ) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            textSize = size
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create("sans-serif", Typeface.NORMAL)
        }
        val metrics = paint.fontMetrics
        canvas.drawText(text, panel.centerX(), panel.centerY() - (metrics.ascent + metrics.descent) / 2f, paint)
    }

    /**
     * The completion ring. The track is a faint inset of the material itself
     * rather than a grey stroke, so it reads as part of the glass; the
     * progress arc is a gradient so it catches light like the rim does.
     */
    private fun drawProgressRing(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        radius: Float,
        progress: Float,
        isDark: Boolean,
        labelColor: Int,
        showLabel: Boolean,
    ) {
        val stroke = radius * 0.20f
        val box = RectF(cx - radius, cy - radius, cx + radius, cy + radius)

        canvas.drawCircle(
            cx, cy, radius,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = stroke
                color = if (isDark) Color.argb(52, 255, 255, 255) else Color.argb(64, 42, 42, 40)
            },
        )

        if (progress > 0f) {
            canvas.drawArc(
                box, -90f, 360f * progress, false,
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = stroke
                    strokeCap = Paint.Cap.ROUND
                    shader = LinearGradient(
                        box.left, box.top, box.right, box.bottom,
                        intArrayOf(lighten(DEEP_GREEN, 0.35f), DEEP_GREEN),
                        null,
                        Shader.TileMode.CLAMP,
                    )
                },
            )
        }

        if (!showLabel) return

        val percent = "${(progress * 100).roundToInt()}%"
        val label = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = labelColor
            textSize = radius * 0.62f
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }
        // Centre on the glyph box, not the baseline, or the number sits low.
        val metrics = label.fontMetrics
        canvas.drawText(percent, cx, cy - (metrics.ascent + metrics.descent) / 2f, label)
    }

    /**
     * Draws the streak right-aligned on the title line, and returns the width
     * it consumed (0 if it didn't fit) so the title can be ellipsized clear
     * of it.
     */
    private fun drawStreakBadge(
        canvas: Canvas,
        panel: RectF,
        baseline: Float,
        textSize: Float,
        streak: Int,
        isDark: Boolean,
        available: Float,
    ): Float {
        val label = "${streak}d streak"
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.textSize = textSize * 0.86f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        }

        val padH = textSize * 0.44f
        val padV = textSize * 0.30f
        val width = paint.measureText(label) + padH * 2f
        val height = paint.textSize + padV * 2f

        // Never let the badge crowd the title on a narrow widget — below half
        // the text column, drop it rather than ellipsize both.
        if (width > available * 0.5f) return 0f

        val right = panel.right - textSize * 1.28f
        val box = RectF(right - width, baseline - height * 0.74f, right, baseline + height * 0.26f)
        drawChipBackground(canvas, box, height, AMBER, isDark)

        paint.color = if (isDark) lighten(AMBER, 0.55f) else darken(AMBER, 0.15f)
        canvas.drawText(label, box.left + padH, baseline, paint)

        return width + padH
    }

    private fun drawChips(
        canvas: Canvas,
        left: Float,
        baseline: Float,
        available: Float,
        textSize: Float,
        data: WidgetData,
        config: WidgetConfig,
        isDark: Boolean,
    ) {
        // The streak deliberately isn't here — see drawStreakBadge.
        val chips = buildList {
            if (config.has(WidgetField.HABITS) && data.habitsTotal > 0) {
                add("${data.habitsDone}/${data.habitsTotal} habits" to DEEP_GREEN)
            }
            if (config.has(WidgetField.TASKS) && data.tasksTotal > 0) {
                add("${data.tasksDone}/${data.tasksTotal} tasks" to MUTED_BLUE)
            }
        }

        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.textSize = textSize * 0.86f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        }

        var x = left
        val padH = textSize * 0.44f
        val padV = textSize * 0.30f
        val height = paint.textSize + padV * 2f

        for ((label, accent) in chips) {
            val width = paint.measureText(label) + padH * 2f
            if (x + width > left + available) break

            val box = RectF(x, baseline - height * 0.72f, x + width, baseline + height * 0.28f)
            drawChipBackground(canvas, box, height, accent, isDark)

            paint.color = if (isDark) lighten(accent, 0.55f) else darken(accent, 0.15f)
            canvas.drawText(label, x + padH, baseline, paint)
            x += width + padH * 0.7f
        }
    }

    /**
     * A chip's tinted fill and hairline border — the same squircle as the
     * panel, so the shape language stays consistent at every scale.
     */
    private fun drawChipBackground(
        canvas: Canvas,
        box: RectF,
        height: Float,
        accent: Int,
        isDark: Boolean,
    ) {
        val shape = LiquidGlass.squirclePath(box, height * 0.42f)
        canvas.drawPath(
            shape,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb(
                    if (isDark) 54 else 40,
                    Color.red(accent), Color.green(accent), Color.blue(accent),
                )
            },
        )
        canvas.drawPath(
            shape,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = 1f
                color = Color.argb(
                    if (isDark) 90 else 70,
                    Color.red(accent), Color.green(accent), Color.blue(accent),
                )
            },
        )
    }

    /** Trims [text] to fit [available] px, appending an ellipsis. */
    private fun ellipsize(text: String, paint: Paint, available: Float): String {
        if (paint.measureText(text) <= available) return text
        var end = text.length
        while (end > 1 && paint.measureText(text.substring(0, end) + "…") > available) end--
        return text.substring(0, end) + "…"
    }

    private fun isNightMode(context: Context): Boolean =
        (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES

    private fun lighten(color: Int, amount: Float): Int = Color.rgb(
        mix(Color.red(color), 255, amount),
        mix(Color.green(color), 255, amount),
        mix(Color.blue(color), 255, amount),
    )

    private fun darken(color: Int, amount: Float): Int = Color.rgb(
        mix(Color.red(color), 0, amount),
        mix(Color.green(color), 0, amount),
        mix(Color.blue(color), 0, amount),
    )

    private fun mix(from: Int, to: Int, amount: Float): Int =
        max(0, min(255, (from + (to - from) * amount).roundToInt()))
}
