package expo.modules.steadywidget

import android.graphics.Paint

/**
 * UI LOCKED - Isolates all exact visual tokens and appearance rules
 * from the established Nocturne widget design system.
 */
object WidgetRendererVisualSpec {
    // Colors
    const val COLOR_ICON_CHECKED = 0xFF52BA69.toInt()
    const val COLOR_ICON_UNCHECKED = 0xFFFFFFFF.toInt() // Visible pure white
    const val COLOR_ICON_TYPE = 0xFFFAF7F1.toInt()

    // Category specific icon colors matching app theme
    const val COLOR_KIND_REMINDER = 0xFF9E86FF.toInt() // tabReminders #9E86FF
    const val COLOR_KIND_TASK = 0xFFFF86EC.toInt()     // tabTasks #FF86EC
    const val COLOR_KIND_HABIT = 0xFF86E6B0.toInt()    // tabHabits #86E6B0
    const val COLOR_KIND_DEFAULT = 0xFFFAF7F1.toInt()

    const val COLOR_TEXT = 0xFFF0EDE6.toInt()
    const val COLOR_TEXT_CAPTION = 0xFFB3ADA3.toInt()
    const val COLOR_TEXT_DONE = 0x73F0EDE6.toInt()

    const val COLOR_PANEL_DEFAULT = 0xFF161513.toInt()

    // Alpha steps (0-255)
    const val ALPHA_FULL = 255
    const val ALPHA_UNCHECKED = 255 // 100% visible white
    const val ALPHA_TYPE = 255 // Full vivid category icon
    const val ALPHA_DONE = 115 // 45%

    // Text paint flags
    const val FLAGS_STRIKE_THRU = Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG
    const val FLAGS_NORMAL = Paint.ANTI_ALIAS_FLAG

    // Dimensions & thresholds
    const val COMPACT_WIDTH_DP = 260
    const val DEFAULT_PANEL_ALPHA = 242 // ~95%
}
