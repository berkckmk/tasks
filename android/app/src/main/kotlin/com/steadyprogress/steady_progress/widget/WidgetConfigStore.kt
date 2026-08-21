package com.steadyprogress.steady_progress.widget

import android.content.Context
import android.content.SharedPreferences
import android.graphics.RectF
import java.io.File

/**
 * Which fields a single placed widget shows.
 *
 * Scoped per `appWidgetId`, not per app: the same user can put two copies on
 * their home screen — a wide one with everything, a small one with just the
 * ring — and each keeps its own selection.
 */
enum class WidgetField(val key: String, val label: String, val description: String) {
    RING("ring", "Progress ring", "Today's completion as a percentage"),
    SUMMARY("summary", "Summary line", "\"7 of 11 done\""),
    HABITS("habits", "Habits", "How many of today's habits are done"),
    TASKS("tasks", "Tasks", "How many of today's tasks are done"),
    REMINDERS("reminders", "Reminders", "Upcoming reminders and nudges"),
    STREAK("streak", "Streak", "Your longest current run of days"),
}

data class WidgetConfig(
    val fields: Set<WidgetField>,
    /**
     * How much the material fills in behind the content, 0-100.
     *
     * At 0 the panel is barely there — a rim and some content floating on the
     * wallpaper. At 100 it's a solid frosted slab. [DEFAULT_LEVEL] is the
     * tuned middle.
     */
    val background: Int = DEFAULT_LEVEL,
    /**
     * How much the material scatters light, 0-100.
     *
     * Note this is *not* a backdrop blur, and can't be: a widget has no way
     * to read the wallpaper (see [LiquidGlass]). What it controls is the
     * glass's own diffusion — the internal bloom, the caustic pooling, the
     * edge absorption and the surface grain. Turned up, the panel reads as
     * heavily frosted; turned down, as clear glass with a crisp edge.
     */
    val blur: Int = DEFAULT_LEVEL,
    /**
     * Overall widget opacity, 0-100. 100 = default/full. This scales the
     * panel's alpha so the user can make the whole widget more transparent.
     */
    val opacity: Int = 100,
    /**
     * File name, inside the app's private files dir, of the wallpaper image
     * this widget refracts. `null` means no backdrop — the material draws its
     * own optics over nothing, exactly as it did before this existed.
     *
     * A *copy*, not a content URI. The widget re-renders from a background
     * broadcast, potentially after a reboot, and neither `ACTION_PICK_IMAGES`
     * nor a plain `ACTION_OPEN_DOCUMENT` grant is guaranteed to still be valid
     * at that point. Copying once, at pick time, is what makes the backdrop
     * survive.
     */
    val backdropFile: String? = null,
    /**
     * Which part of [backdropFile] sits behind this widget, in normalized
     * 0..1 coordinates.
     *
     * The user places this by dragging in the configure screen, because there
     * is no way to derive it: `AppWidgetManager.getAppWidgetOptions()` reports
     * the widget's *size* but never its position on the home screen. A
     * launcher knows where its own widgets sit; an app does not.
     */
    val backdropRect: RectF? = null,
    /**
     * Blur radius applied to the backdrop crop, 0-100.
     *
     * Distinct from [blur] on purpose — see that field. This one is the real
     * out-of-focus falloff of what is *behind* the glass; [blur] is the
     * material's own internal diffusion. Collapsing the two into one control
     * would break the hand-tuned midpoint [blur] is calibrated against.
     */
    val backdropBlur: Int = DEFAULT_BACKDROP_BLUR,
) {

    fun has(field: WidgetField): Boolean = field in fields

    /** True when the ring is the only thing to draw, which gets its own
     *  centred layout rather than a ring with an empty column beside it. */
    val isRingOnly: Boolean get() = fields == setOf(WidgetField.RING)

    /** True when there is nothing to draw but the panel itself. */
    val isEmpty: Boolean get() = fields.isEmpty()

    /** 0f..1f, for the renderer. */
    val backgroundFraction: Float get() = background.coerceIn(0, 100) / 100f
    val blurFraction: Float get() = blur.coerceIn(0, 100) / 100f
    val opacityFraction: Float get() = opacity.coerceIn(0, 100) / 100f
    val backdropBlurFraction: Float get() = backdropBlur.coerceIn(0, 100) / 100f

    /** True when this widget has a wallpaper to refract. */
    val hasBackdrop: Boolean get() = backdropFile != null

    companion object {
        /** Mid-scale, and the value at which both sliders reproduce the
         *  hand-tuned look the material was designed at. */
        const val DEFAULT_LEVEL = 50

        /** Enough to read as "behind glass" without erasing the wallpaper. */
        const val DEFAULT_BACKDROP_BLUR = 40

        /** What a freshly placed widget shows before anyone configures it. */
        val DEFAULT = WidgetConfig(WidgetField.entries.toSet())
    }
}

object WidgetConfigStore {

    private const val PREFS = "steady_progress_widget_config"

    private const val KEY_BACKGROUND = "background"
    private const val KEY_BLUR = "blur"
    private const val KEY_OPACITY = "opacity"
    private const val KEY_BACKDROP_FILE = "backdrop_file"
    private const val KEY_BACKDROP_BLUR = "backdrop_blur"
    private const val KEY_BACKDROP_L = "backdrop_l"
    private const val KEY_BACKDROP_T = "backdrop_t"
    private const val KEY_BACKDROP_R = "backdrop_r"
    private const val KEY_BACKDROP_B = "backdrop_b"

    private fun key(appWidgetId: Int, field: WidgetField) = "w${appWidgetId}_${field.key}"
    private fun key(appWidgetId: Int, name: String) = "w${appWidgetId}_$name"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun read(context: Context, appWidgetId: Int): WidgetConfig {
        val p = prefs(context)
        // Absent keys fall back to the default *per field*, so a widget
        // placed before this feature existed keeps showing everything rather
        // than going blank after an app update.
        val fields = WidgetField.entries.filter { field ->
            p.getBoolean(key(appWidgetId, field), field in WidgetConfig.DEFAULT.fields)
        }
        return WidgetConfig(
            fields = fields.toSet(),
            background = p.getInt(key(appWidgetId, KEY_BACKGROUND), WidgetConfig.DEFAULT_LEVEL),
            blur = p.getInt(key(appWidgetId, KEY_BLUR), WidgetConfig.DEFAULT_LEVEL),
            opacity = p.getInt(key(appWidgetId, KEY_OPACITY), 100),
            backdropFile = p.getString(key(appWidgetId, KEY_BACKDROP_FILE), null),
            backdropRect = readBackdropRect(p, appWidgetId),
            backdropBlur = p.getInt(
                key(appWidgetId, KEY_BACKDROP_BLUR),
                WidgetConfig.DEFAULT_BACKDROP_BLUR,
            ),
        )
    }

    /**
     * The crop is four floats rather than a serialized RectF, so it stays
     * readable in the prefs file and doesn't depend on RectF's own format.
     *
     * A widget saved before this feature existed has none of these keys; the
     * `contains` check is what distinguishes that from a deliberate full-frame
     * crop of 0,0,1,1.
     */
    private fun readBackdropRect(p: SharedPreferences, appWidgetId: Int): RectF? {
        if (!p.contains(key(appWidgetId, KEY_BACKDROP_L))) return null
        return RectF(
            p.getFloat(key(appWidgetId, KEY_BACKDROP_L), 0f),
            p.getFloat(key(appWidgetId, KEY_BACKDROP_T), 0f),
            p.getFloat(key(appWidgetId, KEY_BACKDROP_R), 1f),
            p.getFloat(key(appWidgetId, KEY_BACKDROP_B), 1f),
        )
    }

    fun write(context: Context, appWidgetId: Int, config: WidgetConfig) {
        val editor = prefs(context).edit()
        for (field in WidgetField.entries) {
            editor.putBoolean(key(appWidgetId, field), config.has(field))
        }
        editor.putInt(key(appWidgetId, KEY_BACKGROUND), config.background)
        editor.putInt(key(appWidgetId, KEY_BLUR), config.blur)
        editor.putInt(key(appWidgetId, KEY_OPACITY), config.opacity)
        editor.putInt(key(appWidgetId, KEY_BACKDROP_BLUR), config.backdropBlur)
        if (config.backdropFile == null) {
            editor.remove(key(appWidgetId, KEY_BACKDROP_FILE))
        } else {
            editor.putString(key(appWidgetId, KEY_BACKDROP_FILE), config.backdropFile)
        }
        val rect = config.backdropRect
        if (rect == null) {
            editor.remove(key(appWidgetId, KEY_BACKDROP_L))
            editor.remove(key(appWidgetId, KEY_BACKDROP_T))
            editor.remove(key(appWidgetId, KEY_BACKDROP_R))
            editor.remove(key(appWidgetId, KEY_BACKDROP_B))
        } else {
            editor.putFloat(key(appWidgetId, KEY_BACKDROP_L), rect.left)
            editor.putFloat(key(appWidgetId, KEY_BACKDROP_T), rect.top)
            editor.putFloat(key(appWidgetId, KEY_BACKDROP_R), rect.right)
            editor.putFloat(key(appWidgetId, KEY_BACKDROP_B), rect.bottom)
        }
        editor.apply()
    }

    /** Where a widget's wallpaper copy lives. One per widget id, so two
     *  widgets can sit over different parts of the home screen. */
    fun backdropFileName(appWidgetId: Int): String = "widget_backdrop_$appWidgetId.webp"

    fun backdropFile(context: Context, name: String): File = File(context.filesDir, name)

    /** Called from the provider's onDeleted — otherwise a removed widget's
     *  keys accumulate in the prefs file forever, and a recycled id would
     *  inherit a stranger's layout. */
    fun clear(context: Context, appWidgetId: Int) {
        val editor = prefs(context).edit()
        for (field in WidgetField.entries) {
            editor.remove(key(appWidgetId, field))
        }
        editor.remove(key(appWidgetId, KEY_BACKGROUND))
        editor.remove(key(appWidgetId, KEY_BLUR))
        editor.remove(key(appWidgetId, KEY_OPACITY))
        editor.remove(key(appWidgetId, KEY_BACKDROP_BLUR))
        editor.remove(key(appWidgetId, KEY_BACKDROP_L))
        editor.remove(key(appWidgetId, KEY_BACKDROP_T))
        editor.remove(key(appWidgetId, KEY_BACKDROP_R))
        editor.remove(key(appWidgetId, KEY_BACKDROP_B))

        // The prefs keys aren't the only thing left behind: without this the
        // wallpaper copy stays in filesDir forever, and a recycled widget id
        // would inherit a stranger's backdrop.
        val name = prefs(context).getString(key(appWidgetId, KEY_BACKDROP_FILE), null)
        if (name != null) backdropFile(context, name).delete()
        editor.remove(key(appWidgetId, KEY_BACKDROP_FILE))

        editor.apply()
    }
}
