package expo.modules.steadywidget

import android.graphics.Paint

/**
 * UI LOCKED - Isolates all exact visual tokens and appearance rules
 * from the established Nocturne widget design system.
 */
object WidgetRendererVisualSpec {
    // Monochrome white neon tokens.
    const val COLOR_ICON_CHECKED = 0xFFFFFFFF.toInt()
    const val COLOR_ICON_UNCHECKED = 0xFFFFFFFF.toInt()
    const val COLOR_ICON_TYPE = 0xFFFFFFFF.toInt()

    // Category marks stay monochrome in the home-screen widget.
    const val COLOR_KIND_REMINDER = 0xFFFFFFFF.toInt()
    const val COLOR_KIND_TASK = 0xFFFFFFFF.toInt()
    const val COLOR_KIND_HABIT = 0xFFFFFFFF.toInt()
    const val COLOR_KIND_DEFAULT = 0xFFFFFFFF.toInt()

    const val COLOR_TEXT = 0xFFFFFFFF.toInt()
    const val COLOR_TEXT_CAPTION = 0xFFC8C8C8.toInt()
    const val COLOR_TEXT_DONE = 0xFF909090.toInt()

    const val COLOR_PANEL_DEFAULT = 0xFF161513.toInt()

    // Alpha steps (0-255)
    const val ALPHA_FULL = 255
    const val ALPHA_UNCHECKED = 255
    const val ALPHA_TYPE = 235
    const val ALPHA_DONE = 145

    // Text paint flags
    const val FLAGS_STRIKE_THRU = Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG
    const val FLAGS_NORMAL = Paint.ANTI_ALIAS_FLAG

    // Dimensions & thresholds
    const val COMPACT_WIDTH_DP = 260
    const val DEFAULT_PANEL_ALPHA = 242 // ~95%
}
