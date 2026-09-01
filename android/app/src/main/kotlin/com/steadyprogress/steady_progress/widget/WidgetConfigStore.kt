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
    REMINDERS("reminders", "Reminders"),
    TASKS("tasks", "Tasks");

    companion object {
        fun fromKey(key: String?): WidgetScope =
            entries.firstOrNull { it.key == key } ?: TODAY
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
        fun fromKey(key: String?): WidgetGround =
            entries.firstOrNull { it.key == key } ?: SURFACE
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
    val ground: WidgetGround = WidgetGround.SURFACE,

    /**
     * Panel opacity, 0-100. Default 58.
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
        /** Tuned: reads as a panel without erasing the wallpaper behind it. */
        const val DEFAULT_OPACITY = 58

        /** The segmented control offers 1 / 2 / 3 / 5. */
        const val DEFAULT_ROWS = 3
        val ROW_OPTIONS = listOf(1, 2, 3, 5)

        val DEFAULT = WidgetConfig()
    }
}

object WidgetConfigStore {

    private const val PREFS = "steady_progress_widget_config"

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
        return WidgetConfig(
            scope = WidgetScope.fromKey(p.getString(key(appWidgetId, KEY_SCOPE), null)),
            ground = WidgetGround.fromKey(p.getString(key(appWidgetId, KEY_GROUND), null)),
            opacity = p.getInt(key(appWidgetId, KEY_OPACITY), WidgetConfig.DEFAULT_OPACITY),
            rows = p.getInt(key(appWidgetId, KEY_ROWS), WidgetConfig.DEFAULT_ROWS),
            // A widget placed before this feature existed has no key at all,
            // and must keep showing everything rather than going blank after
            // an app update.
            include = includeKeys
                ?.mapNotNull { k -> WidgetInclude.entries.firstOrNull { it.key == k } }
                ?.toSet()
                ?: WidgetInclude.DEFAULT,
        )
    }

    fun write(context: Context, appWidgetId: Int, config: WidgetConfig) {
        prefs(context).edit()
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
