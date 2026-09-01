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
    const val TEXT = 0xFFE9E9ED.toInt()
    const val ACCENT = 0xFF9184D9.toInt()
    const val INK_ACCENT = 0xFFD2CEFD.toInt()

    /** `text` at 58% — the note step. */
    val TEXT_NOTE = fade(0.58)

    /** `text` at 42% — captions and the time column. */
    val TEXT_CAPTION = fade(0.42)

    /**
     * A completed row drops to 45%.
     *
     * Applied to the text colours rather than to the view, because RemoteViews
     * exposes no `setAlpha` for a TextView. Same result, one fewer view.
     */
    val TEXT_DONE = fade(0.45)

    // -- Icons: opaque colour + a separate alpha. --------------------------
    // See the class doc. Each pair is one muted step from the design.

    /** An unchecked circle: `text` at 32%. */
    const val ICON_UNCHECKED = TEXT
    val ALPHA_UNCHECKED = alpha(0.32)

    /** A checked circle: the accent, at full strength. */
    const val ICON_CHECKED = ACCENT
    const val ALPHA_FULL = 255

    /** The row's small type mark: `text` at 38%. */
    const val ICON_TYPE = TEXT
    val ALPHA_TYPE = alpha(0.38)

    /** The empty state's glyph: `text` at 35%. */
    const val ICON_EMPTY = TEXT
    val ALPHA_EMPTY = alpha(0.35)

    /** A completed row's icons fade with its text. */
    val ALPHA_DONE = alpha(0.45)

    private fun fade(value: Double): Int =
        Color.argb(alpha(value), 0xE9, 0xE9, 0xED)

    private fun alpha(value: Double): Int = (value * 255).toInt()
}
