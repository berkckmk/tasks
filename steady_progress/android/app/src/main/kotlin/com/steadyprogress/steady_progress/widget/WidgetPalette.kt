package com.steadyprogress.steady_progress.widget

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
 * The current home-screen treatment is intentionally monochrome: task text is
 * pure white, supporting labels are grey, and glow is kept to icons and
 * outlines. Change one of these and change `res/values/colors.xml` with it —
 * the two copies are load-bearing.
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
    const val TEXT = 0xFFFFFFFF.toInt()
    const val ACCENT = 0xFFFFFFFF.toInt()
    const val INK_ACCENT = 0xFFFFFFFF.toInt()

    /** Secondary copy. */
    const val TEXT_NOTE = 0xFFC8C8C8.toInt()

    /** Captions and the time column. */
    const val TEXT_CAPTION = 0xFFC8C8C8.toInt()

    /**
     * A completed row drops to 72% — the one step allowed to fall out of the
     * band above, because "done" is a state the eye should be able to skip.
     *
     * Applied to the text colours rather than to the view, because RemoteViews
     * exposes no `setAlpha` for a TextView. Same result, one fewer view.
     */
    const val TEXT_DONE = 0xFF909090.toInt()

    // -- Icons: opaque colour + a separate alpha. --------------------------
    // See the class doc. Each pair is one muted step from the design.

    /** An unchecked circle: pure white. */
    const val ICON_UNCHECKED = TEXT
    const val ALPHA_UNCHECKED = 255

    /** A checked circle: the accent, at full strength. */
    const val ICON_CHECKED = ACCENT
    const val ALPHA_FULL = 255

    /** The row's small type mark: white with controlled alpha. */
    const val ICON_TYPE = TEXT
    val ALPHA_TYPE = alpha(0.92)

    /** The empty state's glyph: `text` at 78%. */
    const val ICON_EMPTY = TEXT
    val ALPHA_EMPTY = alpha(0.92)

    /** A completed row's icons fade with its text. */
    val ALPHA_DONE = alpha(0.72)

    private fun alpha(value: Double): Int = (value * 255).toInt()
}
