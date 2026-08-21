package com.steadyprogress.steady_progress.widget

import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.SweepGradient
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.sin
import kotlin.random.Random

/**
 * Draws Apple's "Liquid Glass" material.
 *
 * A home-screen widget can't do what iOS does natively, and it's worth being
 * precise about why, because it shapes every decision below:
 *
 *  - A widget renders through `RemoteViews`, which only accepts a fixed list
 *    of view classes — no custom `View`, so no `RenderEffect`, no
 *    `setRenderEffect(blur)`, no shaders. The way around it is to render the
 *    whole panel into a [android.graphics.Bitmap] here and hand the widget a
 *    single `ImageView`. That's what [GlassRenderer] does.
 *  - Glass is defined by what's *behind* it, and a widget cannot **read** the
 *    wallpaper on its own: `WallpaperManager.getDrawable()` has needed
 *    storage permission since Android 7 and is off-limits to ordinary apps
 *    from Android 13.
 *
 * What's reproduced instead is the *optics* — the cues the eye actually reads
 * as glass. Layers are drawn back to front in [drawPanel]; each one models a
 * specific physical behaviour and is documented at its own function. Those
 * layers stand on their own and are what a widget with no backdrop still
 * shows.
 *
 * The second constraint has since been worked around rather than removed: the
 * platform still won't hand us the wallpaper, but the *user* can. The
 * configure screen lets them pick the image and drag the panel to where the
 * widget actually sits, and [drawPanel] composites that crop underneath the
 * material as `backdrop`. That is a real backdrop, blurred by
 * `GlassRenderer`, not a simulation of one — and it is opt-in, so the
 * optics-only path above remains the default.
 */
object LiquidGlass {

    /**
     * Corner shape exponent. A plain rounded rect is n = 2 (a circular arc);
     * Apple's squircle is a superellipse nearer n = 5, where curvature ramps
     * up smoothly instead of jumping from straight edge to arc. That
     * discontinuity is exactly what makes ordinary rounded corners read as
     * "Android card" rather than "iOS".
     */
    private const val SQUIRCLE_EXPONENT = 5.0

    /** Samples per corner. At widget corner radii (~40-70px) this is well
     *  past the point where the segments are individually visible. */
    private const val CORNER_SAMPLES = 24

    /**
     * A rounded rectangle whose corners are superellipse arcs rather than
     * circular ones — the continuous-curvature "squircle".
     *
     * Built by sampling |x/r|^n + |y/r|^n = 1 through each corner quadrant
     * and joining the quadrants with the straight edges. Sampling rather than
     * fitting Béziers keeps this exact for any exponent, with no magic
     * control-point constants to get subtly wrong.
     */
    fun squirclePath(rect: RectF, radius: Float, exponent: Double = SQUIRCLE_EXPONENT): Path {
        val path = Path()
        // A corner can never eat more than half the shorter side.
        val r = radius.coerceAtMost(minOf(rect.width(), rect.height()) / 2f)
        if (r <= 0f) {
            path.addRect(rect, Path.Direction.CW)
            return path
        }

        val inverse = 2.0 / exponent

        // Corner centres, clockwise from top-right, paired with the sign of
        // the quadrant they sweep into.
        val corners = arrayOf(
            floatArrayOf(rect.right - r, rect.top + r, 1f, -1f),    // top-right
            floatArrayOf(rect.right - r, rect.bottom - r, 1f, 1f),  // bottom-right
            floatArrayOf(rect.left + r, rect.bottom - r, -1f, 1f),  // bottom-left
            floatArrayOf(rect.left + r, rect.top + r, -1f, -1f),    // top-left
        )

        // Start mid-way along the top edge, clear of both corners.
        path.moveTo(rect.left + rect.width() / 2f, rect.top)

        for ((index, corner) in corners.withIndex()) {
            val (cx, cy, sx, sy) = corner
            for (i in 0..CORNER_SAMPLES) {
                val t = Math.PI / 2.0 * i / CORNER_SAMPLES
                // Superellipse quadrant, parameterised so i=0 meets one edge
                // tangentially and i=N meets the next. Clamped at zero
                // because cos(PI/2) lands a hair either side of it in double
                // precision, and a negative base would make pow() return NaN.
                val ux = cos(t).coerceAtLeast(0.0).pow(inverse).toFloat()
                val uy = sin(t).coerceAtLeast(0.0).pow(inverse).toFloat()

                // Sweep direction alternates so each quadrant is traversed
                // clockwise from the edge it starts on.
                val fromHorizontal = index % 2 == 0
                val px = if (fromHorizontal) cx + sx * uy * r else cx + sx * ux * r
                val py = if (fromHorizontal) cy + sy * ux * r else cy + sy * uy * r
                path.lineTo(px, py)
            }
        }

        path.close()
        return path
    }

    /**
     * Paints the full glass stack into [rect], back to front.
     *
     * [tint] is the accent the material is lit with — the panel picks up a
     * trace of it the way real glass carries the colour of what's behind it.
     */
    fun drawPanel(
        canvas: Canvas,
        rect: RectF,
        radius: Float,
        isDark: Boolean,
        tint: Int,
        background: Float = 0.5f,
        blur: Float = 0.5f,
        opacity: Float = 1f,
        backdrop: Bitmap? = null,
    ) {
        val shape = squirclePath(rect, radius)
        val bg = background.coerceIn(0f, 1f)
        val fr = blur.coerceIn(0f, 1f)
        val op = opacity.coerceIn(0f, 1f)

        // The rim, fringe, glints and shadow are the *shape* of the glass and
        // stay fixed: they're what keeps the panel legible as an object even
        // when the user dials the material down to almost nothing.
        drawAmbientShadow(canvas, shape, isDark, op)
        // The one thing the note at the top of this file said was impossible.
        // It still is, from inside the widget — this bitmap comes from a
        // wallpaper the *user* handed us in the configure screen, already
        // cropped to where the widget sits and blurred. Everything below it
        // stays exactly as it was: the nine optical layers after drawBody are
        // all drawn translucent, so they compose correctly over a real
        // backdrop without being retuned. With `backdrop` null the output is
        // unchanged, byte for byte.
        if (backdrop != null) drawBackdrop(canvas, shape, rect, backdrop, op)
        drawBody(canvas, shape, rect, isDark, tint, bg, op)
        drawInnerBloom(canvas, shape, rect, isDark, fr, op)
        drawEdgeAbsorption(canvas, shape, rect, radius, isDark, fr, op)
        drawRefractionBands(canvas, rect, radius, isDark, op)
        drawCaustic(canvas, shape, rect, isDark, fr, op)
        drawInnerShadow(canvas, rect, radius, isDark, op)
        drawChromaticFringe(canvas, rect, radius, op)
        drawSpecularRim(canvas, rect, radius, isDark, op)
        drawCornerGlints(canvas, rect, radius, isDark, op)
        drawGrain(canvas, shape, rect, isDark, fr, op)
    }

    /**
     * Interpolates an alpha across a slider's range, through a fixed middle.
     *
     * Each tunable is given three values — at 0, at the midpoint, and at 1 —
     * and the two halves are interpolated separately. That's the only way to
     * satisfy both constraints at once: the midpoint has to reproduce the
     * hand-tuned constants exactly, so an unconfigured widget looks precisely
     * as it did before these controls existed, *and* the ends have to be far
     * enough apart that moving the slider is visibly worth doing. A straight
     * two-point lerp through the tuned value gives one or the other, never
     * both — the first version of this was linear and the extremes were so
     * close together that the sliders looked broken.
     */
    private fun level(t: Float, atZero: Int, atMid: Int, atOne: Int): Int {
        val value = if (t <= 0.5f) {
            atZero + (atMid - atZero) * (t * 2f)
        } else {
            atMid + (atOne - atMid) * ((t - 0.5f) * 2f)
        }
        return value.toInt().coerceIn(0, 255)
    }

    /**
     * Paints the wallpaper crop inside the panel's own squircle.
     *
     * Clipped to [shape] rather than drawn as a rounded rect so the backdrop
     * ends exactly where the material does — a circular-arc clip against a
     * superellipse body leaves a sliver of wallpaper outside the glass at
     * each corner, which is very visible against a busy wallpaper.
     */
    private fun drawBackdrop(
        canvas: Canvas,
        shape: Path,
        rect: RectF,
        backdrop: Bitmap,
        opacity: Float,
    ) {
        val saved = canvas.save()
        canvas.clipPath(shape)
        canvas.drawBitmap(
            backdrop,
            null,
            rect,
            Paint(Paint.FILTER_BITMAP_FLAG).apply {
                alpha = (255 * opacity).toInt().coerceIn(0, 255)
            },
        )
        canvas.restoreToCount(saved)
    }

    /**
     * The wide, soft shadow that separates the panel from the wallpaper.
     * Deliberately large and faint rather than tight and dark — a tight
     * shadow reads as a paper card sitting on a surface, a diffuse one reads
     * as an object floating above it.
     */
    private fun drawAmbientShadow(canvas: Canvas, shape: Path, isDark: Boolean, opacity: Float) {
        val a = if (isDark) (120 * opacity).toInt() else (56 * opacity).toInt()
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (isDark) Color.argb(a, 0, 0, 0) else Color.argb(a, 24, 22, 18)
            maskFilter = BlurMaskFilter(22f, BlurMaskFilter.Blur.NORMAL)
        }
        canvas.save()
        canvas.translate(0f, 7f)
        canvas.drawPath(shape, paint)
        canvas.restore()
    }

    /**
     * The material itself: a translucent vertical gradient with a breath of
     * [tint].
     *
     * Alpha stays low on purpose. It's the one property that makes the panel
     * genuinely glass rather than a painted card — the wallpaper really does
     * show through, so the widget looks different on every home screen and
     * shifts as the user changes their background.
     */
    private fun drawBody(
        canvas: Canvas,
        shape: Path,
        rect: RectF,
        isDark: Boolean,
        tint: Int,
        background: Float,
        opacity: Float,
    ) {
        val op = opacity.coerceIn(0f, 1f)
        val top: Int
        val bottom: Int
        if (isDark) {
            top = Color.argb((level(background, 10, 58, 150) * op).toInt(), 255, 255, 255)
            bottom = Color.argb((level(background, 6, 30, 100) * op).toInt(), 255, 255, 255)
        } else {
            top = Color.argb((level(background, 24, 96, 215) * op).toInt(), 255, 255, 255)
            bottom = Color.argb((level(background, 12, 62, 165) * op).toInt(), 255, 255, 255)
        }

        canvas.drawPath(
            shape,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(
                    rect.left, rect.top, rect.left, rect.bottom,
                    top, bottom, Shader.TileMode.CLAMP,
                )
            },
        )

        // The accent the glass is "lit" through, strongest at the bottom-left
        // where the body gradient is thinnest, so the two don't fight.
        canvas.drawPath(
            shape,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = RadialGradient(
                    rect.left + rect.width() * 0.15f,
                    rect.bottom,
                    rect.width() * 0.85f,
                    intArrayOf(
                        Color.argb(
                            (level(background, if (isDark) 10 else 6, if (isDark) 46 else 34, if (isDark) 95 else 70) * op).toInt(),
                            Color.red(tint), Color.green(tint), Color.blue(tint),
                        ),
                        Color.TRANSPARENT,
                    ),
                    null,
                    Shader.TileMode.CLAMP,
                )
            },
        )
    }

    /**
     * Light scattering inside the material — a broad, very soft glow off the
     * top-left. This is the layer standing in for the backdrop blur the
     * platform won't give us: diffusion is most of what the eye reads as
     * "frosted" rather than "clear".
     */
    private fun drawInnerBloom(canvas: Canvas, shape: Path, rect: RectF, isDark: Boolean, frost: Float, opacity: Float) {
        val op = opacity.coerceIn(0f, 1f)
        canvas.save()
        canvas.clipPath(shape)
        canvas.drawRect(
            rect,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = RadialGradient(
                    rect.left + rect.width() * 0.22f,
                    rect.top + rect.height() * 0.08f,
                    rect.width() * 0.72f,
                    intArrayOf(
                        Color.argb((level(frost, if (isDark) 12 else 20, if (isDark) 44 else 78, if (isDark) 90 else 150) * op).toInt(), 255, 255, 255),
                        Color.argb((level(frost, if (isDark) 3 else 5, if (isDark) 12 else 20, if (isDark) 26 else 40) * op).toInt(), 255, 255, 255),
                        Color.TRANSPARENT,
                    ),
                    floatArrayOf(0f, 0.45f, 1f),
                    Shader.TileMode.CLAMP,
                )
            },
        )
        canvas.restore()
    }

    /**
     * Absorption: a real slab is thicker where you look through it obliquely,
     * so the rim swallows more light than the middle.
     *
     * Drawn as a wide, very soft inward band rather than a hard vignette. It
     * does most of the work of making the panel feel like it has *volume*
     * instead of being a flat sheet — without it the body gradient reads as a
     * printed gradient, because nothing varies with the geometry of the edge.
     */
    private fun drawEdgeAbsorption(
        canvas: Canvas,
        shape: Path,
        rect: RectF,
        radius: Float,
        isDark: Boolean,
        frost: Float,
        opacity: Float,
    ) {
        val op = opacity.coerceIn(0f, 1f)
        val inset = minOf(rect.width(), rect.height()) * 0.055f
        canvas.save()
        canvas.clipPath(shape)
        canvas.drawPath(
            squirclePath(
                RectF(
                    rect.left + inset, rect.top + inset,
                    rect.right - inset, rect.bottom - inset,
                ),
                (radius - inset).coerceAtLeast(1f),
            ),
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = inset * 2f
                maskFilter = BlurMaskFilter(inset * 0.9f, BlurMaskFilter.Blur.NORMAL)
                color = Color.argb((level(frost, if (isDark) 5 else 3, if (isDark) 20 else 11, if (isDark) 42 else 24) * op).toInt(), 0, 0, 0)
            },
        )
        canvas.restore()
    }

    /**
     * Edge refraction, in two depths.
     *
     * Where a curved edge bends light, it concentrates it into a bright band
     * just inside the rim. Drawing that at two different depths — a wide soft
     * one and a tight bright one closer in — is what gives the edge apparent
     * *thickness*. A single band reads as a drawn outline; two read as light
     * travelling through a solid that has a near face and a far face.
     */
    private fun drawRefractionBands(canvas: Canvas, rect: RectF, radius: Float, isDark: Boolean, opacity: Float) {
        // Outer, wide and soft: the diffuse spread.
        val startAlphaOuter = (if (isDark) 150 else 205) * opacity
        val middleAlphaOuter = (if (isDark) 38 else 62) * opacity
        val endAlphaOuter = (if (isDark) 95 else 135) * opacity
        drawBand(
            canvas, rect, radius,
            inset = 2.5f, width = 6f, blur = 5f,
            start = Color.argb(startAlphaOuter.toInt(), 255, 255, 255),
            middle = Color.argb(middleAlphaOuter.toInt(), 255, 255, 255),
            end = Color.argb(endAlphaOuter.toInt(), 255, 255, 255),
        )
        // Inner, tight and bright: the focused caustic line. Sits deeper in,
        // so the two never merge into one fat stroke.
        val startAlphaInner = (if (isDark) 96 else 128) * opacity
        val middleAlphaInner = (if (isDark) 16 else 26) * opacity
        val endAlphaInner = (if (isDark) 52 else 74) * opacity
        drawBand(
            canvas, rect, radius,
            inset = 7.5f, width = 2.5f, blur = 2.5f,
            start = Color.argb(startAlphaInner.toInt(), 255, 255, 255),
            middle = Color.argb(middleAlphaInner.toInt(), 255, 255, 255),
            end = Color.argb(endAlphaInner.toInt(), 255, 255, 255),
        )
    }

    private fun drawBand(
        canvas: Canvas,
        rect: RectF,
        radius: Float,
        inset: Float,
        width: Float,
        blur: Float,
        start: Int,
        middle: Int,
        end: Int,
    ) {
        val banded = RectF(
            rect.left + inset, rect.top + inset,
            rect.right - inset, rect.bottom - inset,
        )
        canvas.drawPath(
            squirclePath(banded, (radius - inset).coerceAtLeast(1f)),
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = width
                maskFilter = BlurMaskFilter(blur, BlurMaskFilter.Blur.NORMAL)
                shader = LinearGradient(
                    rect.left, rect.top, rect.right, rect.bottom,
                    intArrayOf(start, middle, end),
                    floatArrayOf(0f, 0.55f, 1f),
                    Shader.TileMode.CLAMP,
                )
            },
        )
    }

    /**
     * The pool of light that collects low in the panel — light entering the
     * top face of a lens converges toward the far side. Subtle, wide, and
     * offset from the bloom above it, so the panel is brightest at two
     * separated depths rather than uniformly lit from one corner.
     */
    private fun drawCaustic(canvas: Canvas, shape: Path, rect: RectF, isDark: Boolean, frost: Float, opacity: Float) {
        canvas.save()
        canvas.clipPath(shape)
        canvas.drawRect(
            rect,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = RadialGradient(
                    rect.right - rect.width() * 0.28f,
                    rect.bottom - rect.height() * 0.06f,
                    rect.width() * 0.42f,
                    intArrayOf(
                        Color.argb((level(frost, if (isDark) 7 else 12, if (isDark) 26 else 44, if (isDark) 52 else 85) * opacity).toInt(), 255, 255, 255),
                        Color.TRANSPARENT,
                    ),
                    null,
                    Shader.TileMode.CLAMP,
                )
            },
        )
        canvas.restore()
    }

    /**
     * Inner shadow along the bottom-right, opposite the light. Without it the
     * panel has no thickness and the specular rim below just looks like a
     * stroke.
     */
    private fun drawInnerShadow(canvas: Canvas, rect: RectF, radius: Float, isDark: Boolean, opacity: Float) {
        val inset = 1f
        val inner = RectF(
            rect.left + inset, rect.top + inset,
            rect.right - inset, rect.bottom - inset,
        )
        canvas.drawPath(
            squirclePath(inner, radius - inset),
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = 6f
                maskFilter = BlurMaskFilter(7f, BlurMaskFilter.Blur.NORMAL)
                shader = LinearGradient(
                    rect.left, rect.top, rect.right, rect.bottom,
                    intArrayOf(
                        Color.TRANSPARENT,
                        Color.TRANSPARENT,
                        Color.argb(((if (isDark) 92 else 40) * opacity).toInt(), 0, 0, 0),
                    ),
                    floatArrayOf(0f, 0.5f, 1f),
                    Shader.TileMode.CLAMP,
                )
            },
        )
    }

    /**
     * Chromatic aberration at the rim.
     *
     * Glass disperses — its refractive index varies with wavelength — so a
     * thick curved edge splits light into faint colour fringes, warm on one
     * side of the boundary and cool on the other. Reproduced by tracing the
     * edge twice at sub-pixel offsets in opposite directions, one warm and
     * one cool, both barely visible on their own.
     *
     * This is the cheapest large gain in realism available here: the eye
     * reads colour separation at an edge as *physical glass* long before it
     * consciously notices why, and its absence is a big part of why flat
     * "glassmorphism" looks synthetic.
     */
    private fun drawChromaticFringe(canvas: Canvas, rect: RectF, radius: Float, opacity: Float) {
        val edge = RectF(rect.left + 0.75f, rect.top + 0.75f, rect.right - 0.75f, rect.bottom - 0.75f)
        val path = squirclePath(edge, radius - 0.75f)

        // Warm fringe, pushed a hair down-right.
        canvas.save()
        canvas.translate(0.9f, 0.9f)
        canvas.drawPath(
            path,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = 1.6f
                maskFilter = BlurMaskFilter(0.8f, BlurMaskFilter.Blur.NORMAL)
                color = Color.argb((88 * opacity).toInt(), 255, 158, 74)
            },
        )
        canvas.restore()

        // Cool fringe, the same distance the other way.
        canvas.save()
        canvas.translate(-0.9f, -0.9f)
        canvas.drawPath(
            path,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = 1.6f
                maskFilter = BlurMaskFilter(0.8f, BlurMaskFilter.Blur.NORMAL)
                color = Color.argb((88 * opacity).toInt(), 74, 158, 255)
            },
        )
        canvas.restore()
    }

    /**
     * The specular rim — a hairline highlight tracing the very edge.
     *
     * Brightest along the top (where a curved edge faces the light), dimmest
     * at the waist, then brightening again along the bottom: that second
     * pickup is light wrapping around the underside of the slab, and leaving
     * it out is what makes most "glassmorphism" look like a flat card with a
     * white border.
     */
    private fun drawSpecularRim(canvas: Canvas, rect: RectF, radius: Float, isDark: Boolean, opacity: Float) {
        val inset = 0.75f
        val edge = RectF(
            rect.left + inset, rect.top + inset,
            rect.right - inset, rect.bottom - inset,
        )

        val bright = Color.argb(((if (isDark) 52 else 60) * opacity).toInt(), 255, 255, 255)
        val dim = Color.argb(((if (isDark) 7 else 14) * opacity).toInt(), 255, 255, 255)
        val mid = Color.argb(((if (isDark) 26 else 34) * opacity).toInt(), 255, 255, 255)

        canvas.drawPath(
            squirclePath(edge, radius - inset),
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = 1f
                // A sweep, not a linear gradient.
                //
                // The light has to run bright at the top-left, fading to the
                // top-right, then bright again at the bottom-right, fading to
                // the bottom-left. A linear gradient can't express that on a
                // wide rectangle: whichever axis you pick, the four corners
                // don't land where you need them. On a 722x302 panel a
                // top-left-to-bottom-right gradient puts the top-right corner
                // at 0.85 along the axis — practically on top of the
                // bottom-right — so the two corners that should differ most
                // come out nearly identical.
                //
                // A sweep is parameterised by *angle around the centre*, which
                // is exactly how a highlight travels along a perimeter, so
                // each corner gets its own stop no matter the aspect ratio.
                // Android sweeps clockwise from 3 o'clock, putting the corners
                // at: bottom-right 0.125, bottom-left 0.375, top-left 0.625,
                // top-right 0.875.
                shader = SweepGradient(
                    rect.centerX(), rect.centerY(),
                    intArrayOf(mid, bright, dim, bright, dim, mid),
                    floatArrayOf(0f, 0.125f, 0.375f, 0.625f, 0.875f, 1f),
                )
            },
        )
    }

    /**
     * Corner glints.
     *
     * Specular intensity tracks surface curvature, and on a squircle
     * curvature peaks in the corners — that's where a real edge throws its
     * brightest highlight. The rim above is a single vertical gradient, which
     * can't know where the corners are, so the two lit corners get an extra
     * blurred pass clipped to a radial falloff around them.
     *
     * Only the corners facing the light source (top-left) and its exit
     * (bottom-right) glint; lighting every corner equally would flatten the
     * panel back out.
     */
    private fun drawCornerGlints(canvas: Canvas, rect: RectF, radius: Float, isDark: Boolean, opacity: Float) {
        val edge = RectF(rect.left + 1f, rect.top + 1f, rect.right - 1f, rect.bottom - 1f)
        val path = squirclePath(edge, radius - 1f)
        val reach = radius * 0.95f

        for ((cx, cy, strength) in listOf(
            Triple(rect.left + radius * 0.5f, rect.top + radius * 0.5f, if (isDark) 30 else 38),
            Triple(rect.right - radius * 0.5f, rect.bottom - radius * 0.5f, if (isDark) 16 else 21),
        )) {
            val s = (strength * opacity).toInt()
            canvas.drawPath(
                path,
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = 1.4f
                    maskFilter = BlurMaskFilter(2.2f, BlurMaskFilter.Blur.NORMAL)
                    shader = RadialGradient(
                        cx, cy, reach,
                        intArrayOf(Color.argb(s, 255, 255, 255), Color.TRANSPARENT),
                        null,
                        Shader.TileMode.CLAMP,
                    )
                },
            )
        }
    }

    /**
     * Micro-texture.
     *
     * Frosted glass is not smooth — it scatters at a grain far too fine to
     * resolve, which the eye still reads as surface. Every layer above is a
     * mathematically perfect gradient, and perfect gradients are the tell
     * that something was drawn rather than photographed. A few levels of
     * noise at very low alpha break up the banding and cost one tiled
     * bitmap.
     *
     * The tile is generated once and reused: it is deterministic (fixed
     * seed), so a widget never visibly changes texture between redraws.
     */
    private fun drawGrain(canvas: Canvas, shape: Path, rect: RectF, isDark: Boolean, frost: Float, opacity: Float) {
        canvas.save()
        canvas.clipPath(shape)
        canvas.drawRect(
            rect,
            Paint().apply {
                alpha = (level(frost, if (isDark) 2 else 1, if (isDark) 11 else 8, if (isDark) 24 else 18) * opacity).toInt()
                shader = BitmapShader(grainTile, Shader.TileMode.REPEAT, Shader.TileMode.REPEAT)
            },
        )
        canvas.restore()
    }

    private const val GRAIN_TILE_SIZE = 96

    private val grainTile: Bitmap by lazy {
        val bitmap = Bitmap.createBitmap(GRAIN_TILE_SIZE, GRAIN_TILE_SIZE, Bitmap.Config.ARGB_8888)
        val random = Random(20260815)
        val pixels = IntArray(GRAIN_TILE_SIZE * GRAIN_TILE_SIZE)
        for (i in pixels.indices) {
            // Symmetric around mid-grey so the grain neither lightens nor
            // darkens the panel overall, only breaks up its smoothness.
            val v = 128 + random.nextInt(-40, 41)
            pixels[i] = Color.argb(255, v, v, v)
        }
        bitmap.setPixels(pixels, 0, GRAIN_TILE_SIZE, 0, 0, GRAIN_TILE_SIZE, GRAIN_TILE_SIZE)
        bitmap
    }

    /** Destructuring helper so corner arrays read as (cx, cy, sx, sy). */
    private operator fun FloatArray.component1() = this[0]
    private operator fun FloatArray.component2() = this[1]
    private operator fun FloatArray.component3() = this[2]
    private operator fun FloatArray.component4() = this[3]
}
