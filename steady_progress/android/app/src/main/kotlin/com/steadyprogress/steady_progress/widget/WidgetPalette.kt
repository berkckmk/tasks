package com.steadyprogress.steady_progress.widget

import android.graphics.Color

/**
 * Nocturne, as ARGB ints.
 *
 * The same values as `res/values/colors.xml`, restated here because
 * `RemoteViews.setInt(id, "setColorFilter", …)` and `setTextColor` take a
 * colour, not a resource id, and resolving a resource inside a
 * `RemoteViewsFactory` means holding a themed Context the service doesn't
 * necessarily have. Two copies of eight numbers is the cheaper problem.
 *
 * Source of truth is `lib/app/theme/app_colors.dart`. These do **not** flip
 * with the device theme: a widget sits on the user's wallpaper with no app
 * ground behind it, and there is nothing for it to follow.
 *
 * ## Why the muted steps sit just under white
 *
 * That same missing ground is why the ramp here is not Nocturne's 58/42/32,
 * and no longer the 85/68/55 that replaced it. In the app a caption at 42%
 * sits on a known dark surface. In the widget there is no panel by default,
 * so it sits on a photograph nobody chose for it — and there the *spread*
 * between steps is what fails, not just the floor: a step far enough below
 * white to read as secondary on one wallpaper reads as dirty on the next.
 *
 * So every step below is within 15 points of full white, and the hierarchy is
 * carried by size and weight instead. Every TextView in the widget layouts
 * also carries a `nocturne_text_shadow` blur, which is what gives light type
 * a dark neighbour when the panel gives it none. Change one of these and
 * change `res/values/colors.xml` with it — the two copies are load-bearing.
 *
 * ## Text colours vs icon colours
 *
 * The two halves below are not interchangeable, and mixing them up produces a
 * bug that is easy to miss:
 *
 *  - **Text** takes an ARGB directly. `setTextColor` honours the alpha, so a
 *    muted step is just a colour.
 *  - **Icons** are tinted with `setColorFilter`, which applies `SRC_ATOP` —
 *    and `SRC_ATOP` takes its alpha from the *destination*, not the filter.
 *    Passing a 32%-alpha colour therefore produces a fully opaque icon in a
 *    slightly washed-out hue, not a 32% icon. The muting has to come from
 *    `setImageAlpha` instead, which is why every icon here is an opaque
 *    colour plus a separate alpha constant.
 *
 * That is the same reason the panel's ground is a filter *and* an alpha — see
 * `widget_panel_fill.xml`.
 */
object WidgetPalette {

    // -- Text: ARGB, alpha honoured. ---------------------------------------
    const val TEXT = 0xFFF2F2F6.toInt()
    const val ACCENT = 0xFFA79BE8.toInt()
    const val INK_ACCENT = 0xFFDEDBFF.toInt()

    /** `text` at 92% — the note step. */
    val TEXT_NOTE = fade(0.92)

    /** `text` at 85% — captions and the time column. */
    val TEXT_CAPTION = fade(0.85)

    /**
     * A completed row drops to 72% — the one step allowed to fall out of the
     * band above, because "done" is a state the eye should be able to skip.
     *
     * Applied to the text colours rather than to the view, because RemoteViews
     * exposes no `setAlpha` for a TextView. Same result, one fewer view.
     */
    val TEXT_DONE = fade(0.72)

    // -- Icons: opaque colour + a separate alpha. --------------------------
    // See the class doc. Each pair is one muted step from the design.

    /** An unchecked circle: `text` at 72%. */
    const val ICON_UNCHECKED = TEXT
    val ALPHA_UNCHECKED = alpha(0.72)

    /** A checked circle: the accent, at full strength. */
    const val ICON_CHECKED = ACCENT
    const val ALPHA_FULL = 255

    /** The row's small type mark: `text` at 78%. */
    const val ICON_TYPE = TEXT
    val ALPHA_TYPE = alpha(0.78)

    /** The empty state's glyph: `text` at 78%. */
    const val ICON_EMPTY = TEXT
    val ALPHA_EMPTY = alpha(0.78)

    /** A completed row's icons fade with its text. */
    val ALPHA_DONE = alpha(0.72)

    private fun fade(value: Double): Int =
        Color.argb(alpha(value), 0xF2, 0xF2, 0xF6)

    private fun alpha(value: Double): Int = (value * 255).toInt()
}
