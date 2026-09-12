package com.steadyprogress.steady_progress.widget

import android.content.Context
import android.graphics.Color

/**
 * What one placed widget shows, and how its panel looks.
 *
 * Scoped per `appWidgetId`, not per app: the same user can put two copies on
 * their home screen — a wide one showing everything today, a small one showing
 * only reminders — and each keeps its own settings.
 *
 * ## What changed
 *
 * The previous version of this file carried nine settings across three
 * features that are all gone with the Liquid Glass panel: `background` and
 * `blur` (the material's own optics), `backdropFile` / `backdropRect` /
 * `backdropBlur` (a copied wallpaper crop the glass refracted), and a
 * six-value `WidgetField` set the user ticked on and off.
 *
 * None of that survives. The panel is flat, so there is no material to tune;
 * the wallpaper copy is gone with everything it needed (a picker grant, a
 * cleanup on delete, a downscale-blur); and the field set is replaced by a
 * single [WidgetScope], because "which of these six numbers do you want" was
 * always a worse question than "what should this widget be about".
 */
enum class WidgetScope(val key: String, val label: String) {
    /** Everything due today, across all three pillars. */
    TODAY("today", "Today"),
    TASKS("tasks", "Tasks"),
    REMINDERS("reminders", "Reminders");

    fun next(): WidgetScope = when (this) {
        TODAY -> TASKS
        TASKS -> REMINDERS
        REMINDERS -> TODAY
    }

    companion object {
        fun fromKey(key: String?): WidgetScope = when (key?.lowercase()?.trim()) {
            "tasks", "task" -> TASKS
            "reminders", "reminder" -> REMINDERS
            else -> TODAY
        }
    }
}

/**
 * The panel's ground.
 *
 * Four choices, composed with [WidgetConfig.opacity] into one ARGB. Every
 * value is a Nocturne ramp step — never pure black, never pure white.
 */
enum class WidgetGround(val key: String, val label: String, val rgb: Int) {
    SURFACE("surface", "Surface", 0x232532),
    INK("ink", "Ink", 0x292B31),
    ACCENT("accent", "Accent", 0x2B2741),

    /** No panel at all: content floating on the wallpaper. */
    NONE("none", "None", 0x000000);

    companion object {
        /**
         * The fallback is [NONE], and it has to be: this is the value a widget
         * with no stored `ground` key gets, which is every widget placed
         * before the setting existed as well as any bound without running the
         * setup screen. A `WidgetConfig()` default of [NONE] and a fallback of
         * something else would mean the documented default never actually
         * reached a real widget.
         */
        fun fromKey(key: String?): WidgetGround =
            entries.firstOrNull { it.key == key } ?: WidgetConfig.DEFAULT.ground
    }
}

/** Which pillars a Today-scoped widget draws from. */
enum class WidgetInclude(val key: String, val label: String) {
    REMINDERS("reminders", "Reminders"),
    TASKS("tasks", "Tasks"),
    HABITS("habits", "Habits"),

    /** Off by default: a widget of ticked rows is a widget of nothing to do. */
    COMPLETED("completed", "Completed");

    companion object {
        val DEFAULT = setOf(REMINDERS, TASKS, HABITS)
    }
}

data class WidgetConfig(
    val scope: WidgetScope = WidgetScope.TODAY,

    /**
     * No panel, by default.
     *
     * A panel is a box the widget draws around itself so its own text has
     * something to sit on. It is also the thing that stops the home screen
     * looking like one surface: every launcher-native widget alongside this
     * one — clock, weather — puts its type straight on the wallpaper and
     * spends nothing on a ground. Matching them is the point.
     *
     * This only works because the type does not depend on the panel: the
     * ramp is a near-white band and every glyph carries its own shadow, so
     * removing the ground costs contrast the text was never spending. See
     * `WidgetPalette` and `WidgetTextContrastTest`, which measures the
     * default — that is to say this case — against both wallpaper extremes.
     *
     * The other three grounds are still there, one tap away in the setup
     * screen, and [opacity] below is left where it was so choosing one gives
     * the previous panel back at full strength rather than a faded one.
     */
    val ground: WidgetGround = WidgetGround.NONE,

    /**
     * Panel opacity, 0-100. Default 58.
     *
     * Unused at the default [ground] of [WidgetGround.NONE], which is alpha 0
     * whatever the slider says. It is the strength a panel takes *when the
     * user asks for one*, so it stays at the tuned value rather than dropping
     * to 0 to agree with the new default.
     *
     * **Only the panel fades.** Text, the accent bar and the icons keep their
     * own opaque colours, which is what makes contrast hold at every slider
     * position — including 0, where the rows sit directly on the wallpaper.
     */
    val opacity: Int = DEFAULT_OPACITY,

    /** Rows shown at 4x2. The 4x4 size ignores this and fits what it can. */
    val rows: Int = DEFAULT_ROWS,
    val include: Set<WidgetInclude> = WidgetInclude.DEFAULT,
) {

    fun includes(value: WidgetInclude): Boolean = value in include

    val showsCompleted: Boolean get() = includes(WidgetInclude.COMPLETED)

    /**
     * The ground and the opacity composed into one ARGB, for
     * `setImageAlpha` + `setColorFilter` on the panel fill.
     *
     * [WidgetGround.NONE] is alpha 0 regardless of the slider — "no panel"
     * is a choice about the panel, not about how visible it is.
     */
    val panelAlpha: Int
        get() = if (ground == WidgetGround.NONE) {
            0
        } else {
            (opacity.coerceIn(0, 100) * 255 / 100)
        }

    val panelColor: Int get() = Color.rgb(
        (ground.rgb shr 16) and 0xFF,
        (ground.rgb shr 8) and 0xFF,
        ground.rgb and 0xFF,
    )

    companion object {
        /** Default is completely transparent: content floats directly on wallpaper. */
        const val DEFAULT_OPACITY = 0

        /** The segmented control offers 1 / 2 / 3 / 5. */
        const val DEFAULT_ROWS = 3
        val ROW_OPTIONS = listOf(1, 2, 3, 5)

        val DEFAULT = WidgetConfig()
    }
}

object WidgetConfigStore {

    private const val PREFS = "steady_progress_widget_config"

    private const val KEY_CONFIGURED = "configured"
    private const val KEY_SCOPE = "scope"
    private const val KEY_GROUND = "ground"
    private const val KEY_OPACITY = "opacity"
    private const val KEY_ROWS = "rows"
    private const val KEY_INCLUDE = "include"

    private fun key(appWidgetId: Int, name: String) = "w${appWidgetId}_$name"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun read(context: Context, appWidgetId: Int): WidgetConfig {
        val p = prefs(context)
        val includeKeys = p.getStringSet(key(appWidgetId, KEY_INCLUDE), null)
        val isConfigured = p.getBoolean(key(appWidgetId, KEY_CONFIGURED), false)

        return WidgetConfig(
            scope = WidgetScope.fromKey(p.getString(key(appWidgetId, KEY_SCOPE), null)),
            ground = if (isConfigured) {
                WidgetGround.fromKey(p.getString(key(appWidgetId, KEY_GROUND), "none"))
            } else {
                WidgetGround.NONE
            },
            opacity = if (isConfigured) {
                p.getInt(key(appWidgetId, KEY_OPACITY), 0)
            } else {
                0
            },
            rows = p.getInt(key(appWidgetId, KEY_ROWS), WidgetConfig.DEFAULT_ROWS),
            include = includeKeys
                ?.mapNotNull { k -> WidgetInclude.entries.firstOrNull { it.key == k } }
                ?.toSet()
                ?: WidgetInclude.DEFAULT,
        )
    }

    fun write(context: Context, appWidgetId: Int, config: WidgetConfig) {
        prefs(context).edit()
            .putBoolean(key(appWidgetId, KEY_CONFIGURED), true)
            .putString(key(appWidgetId, KEY_SCOPE), config.scope.key)
            .putString(key(appWidgetId, KEY_GROUND), config.ground.key)
            .putInt(key(appWidgetId, KEY_OPACITY), config.opacity)
            .putInt(key(appWidgetId, KEY_ROWS), config.rows)
            .putStringSet(
                key(appWidgetId, KEY_INCLUDE),
                config.include.map { it.key }.toSet(),
            )
            .apply()
    }

    /** Writes only the scope — what the picker Activity does. */
    fun writeScope(context: Context, appWidgetId: Int, scope: WidgetScope) {
        write(context, appWidgetId, read(context, appWidgetId).copy(scope = scope))
    }

    /**
     * Called from the provider's `onDeleted`. Left behind, the keys
     * accumulate in the prefs file forever and a recycled id would inherit
     * the settings of a widget the user already removed.
     */
    fun clear(context: Context, appWidgetId: Int) {
        prefs(context).edit()
            .remove(key(appWidgetId, KEY_SCOPE))
            .remove(key(appWidgetId, KEY_GROUND))
            .remove(key(appWidgetId, KEY_OPACITY))
            .remove(key(appWidgetId, KEY_ROWS))
            .remove(key(appWidgetId, KEY_INCLUDE))
            .apply()
    }
}
