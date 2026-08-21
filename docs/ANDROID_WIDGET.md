# The Android home-screen widget

A resizable home-screen widget showing today's completion ring, habit/task
counts and best streak, drawn in an Apple "Liquid Glass" material.

Source: `android/app/src/main/kotlin/com/steadyprogress/steady_progress/widget/`

| File | Role |
|---|---|
| `SteadyProgressWidgetProvider.kt` | `AppWidgetProvider`; builds the `RemoteViews` |
| `GlassRenderer.kt` | Composes the panel bitmap: content, chips, ring, hairline |
| `LiquidGlass.kt` | The material itself — squircle, rim, refraction, caustics, grain |
| `WidgetDataStore.kt` | The snapshot Flutter pushes, in SharedPreferences |
| `WidgetConfigStore.kt` | Per-`appWidgetId` field selection and glass sliders |
| `WidgetPage.kt`, `SteadyProgressWidgetConfigureActivity.kt` | Pages, setup screen |

## Why it is one bitmap

`RemoteViews` accepts only a fixed list of view classes. No custom `View`, so no
`RenderEffect`, no `setRenderEffect(blur)`, no shaders. And a widget cannot read
the wallpaper on its own — `WallpaperManager.getDrawable()` has needed storage
permission since Android 7 and is off-limits to ordinary apps from Android 13.

So `LiquidGlass` draws the whole panel into a `Bitmap` and the layout is a
single `ImageView`. What is reproduced is the *optics*: the cues the eye reads
as glass, layered back to front in `drawPanel()`, each documented at its own
function.

## The wallpaper backdrop

The platform won't hand the widget the wallpaper, but the **user** can, and
that is the one way to get a real backdrop behind the glass rather than a
simulated one. In the setup screen, *Choose wallpaper* opens the system photo
picker (`ACTION_PICK_IMAGES` on API 33+, `ACTION_OPEN_DOCUMENT` below it —
**neither needs a permission**), and the user drags the panel onto the spot
where the widget actually sits.

That drag is not a nicety. `AppWidgetManager.getAppWidgetOptions()` reports the
widget's *size* and never its *position*: a launcher knows where its own
widgets are, an app is only told how big to draw. There is no API to infer the
crop from, so the user places it.

Three things about how it is stored and drawn:

- **The image is copied**, into `filesDir/widget_backdrop_<appWidgetId>.webp`,
  downscaled to the display width. A content URI would do here — the widget
  re-renders from a background broadcast, possibly after a reboot, and the
  picker's grant is not guaranteed to still be valid then.
  `WidgetConfigStore.clear()` deletes the copy when the widget is removed.
- **The blur is downscale-then-upscale**, in `GlassRenderer.blur()`.
  `RenderScript` is gone as of API 31 and `RenderEffect` needs a `View` to
  attach to, which is exactly what a widget doesn't have. Note the two passes
  are at *different* sizes on purpose: `createScaledBitmap` returns the source
  untouched when the dimensions already match, so scaling twice to the same
  size blurs once.
- **`backdropBlur` is not `blur`.** `blur` is the material's own internal
  diffusion and its midpoint reproduces the hand-tuned constants exactly;
  `backdropBlur` is the wallpaper's out-of-focus falloff. They are separate
  fields and merging them would break that calibration.

Picking a wallpaper also raises the `background` slider to
`BACKDROP_BACKGROUND_LEVEL`. `DEFAULT_LEVEL` is tuned for a panel with nothing
behind it; over a dark photograph the chips drop to unreadable at that value.
The slider is moved rather than the renderer overridden, so it stays visible
and the user can drag it back.

With no backdrop configured — the default — `drawPanel` takes `backdrop = null`
and the output is unchanged.

Bitmap size is clamped by `clampToWidgetBitmapBudget` to the screen's pixel
area, so resizing to the 400×320dp maximum cannot blow the RemoteViews
transaction limit.

## The RemoteViews class trap

**Only RemoteViews-permitted classes may appear in `widget_steady_progress.xml`.**
Permitted: `FrameLayout`, `LinearLayout`, `RelativeLayout`, `GridLayout`,
`ImageView`, `TextView`, `Button`, `ImageButton`, `ProgressBar`, `Chronometer`,
`AnalogClock`, `TextClock`, the collection views. **Not** permitted: a bare
`View`, or `Space`.

This shipped broken. The layout used a plain `<View>` as an invisible 44dp tap
target, which produced:

```
InflateException: Binary XML file line #33 in layout/widget_steady_progress:
Class not allowed to be inflated android.view.View
```

The failure mode is the important part: inflating a disallowed class fails **the
entire layout**, not just that element. The widget rendered as an empty box on
the home screen with no other symptom — the provider ran fine, the bitmap was
built fine, and nothing crashed. The tap target is now an `ImageView` with no
drawable.

A second bug sat underneath it: a `widget_empty` `TextView` at
`match_parent`×`match_parent` was the **last** child of the `FrameLayout`, so it
painted over the whole panel and swallowed touches, and the provider never set
its visibility. The empty state is already drawn into the bitmap by
`GlassRenderer` (`"Open the app to sync"` when `!data.hasData`), so the
duplicate view was removed rather than hidden — one source of truth.

## Calibrating the edge against the launcher

The widget sits inches from One UI's own widget panels, so its containing line
has to be measured against them, not eyeballed. Method: screenshot the actual
home screen with `adb exec-out screencap -p`, then sample a luminance profile
across the panel edge with PIL and compare the **step** (edge peak minus the
fill just inside it), which is comparable across different fills.

Measured on a Galaxy S25:

| | Edge peak | Fill | Step |
|---|---|---|---|
| One UI panels | 74, **one physical pixel** | 25 | +49 |
| This widget, before | 216, 4px hard band | 45 | +171 |
| This widget, after | 109, 1px soft | 52 | +56 |

Two things had been wrong. `GlassRenderer.panelLayer` drew an extra hard stroke
*over* the finished material at `alpha 200` — near-white — and scaled its width
with the panel (1% of the min dimension, ~3px), so the line got heavier as the
widget grew, where the platform's stays one pixel at every size. Both are fixed;
the alpha now lives in `HAIRLINE_ALPHA`.

Note that One UI's own edge is not constant — sampled along one top edge it runs
+102 at the left, +49 in the middle, +5 at the right, because it carries its own
sheen. Matching a single number exactly would be overfitting; landing inside
that envelope is the goal.

The `LiquidGlass` rim layers themselves were investigated and found *not* to be
the problem — do not dial them down chasing this.

## Data flow

One way. Flutter pushes a snapshot over a method channel whenever the counts
change (`lib/features/home_widget/presentation/home_widget_sync.dart`) into
SharedPreferences, and the widget renders purely from that. The widget process
never touches Firestore: it has no auth session, and an `AppWidgetProvider` gets
only a few seconds of broadcast time — nowhere near a network round trip.

`WidgetDataStore.read` is nullable-safe with defaults throughout, because the
widget can be placed before the app has ever run and must render something calm
rather than crash or show zeros as if they were real.

`updatePeriodMillis` is `0` deliberately: the platform floors periodic widget
updates at 30 minutes and wakes the device to deliver them, which would burn
battery redrawing numbers that have not changed.

## A UX trap that is now reachable

Tapping the top-left target cycles which field is shown. `onReceive` writes
`WidgetConfig(setOf(nextField), …)` — always a **single** field — and the cycle
only ever moves between single fields. There is no path back to the default
multi-field panel through that control; the user has to long-press and use the
configure activity.

Nobody hit this before, because the layout never inflated and the tap target was
dead. It is live now. Adding an "all fields" step to the cycle would close it.

To restore a widget's default field set by hand (debug builds only), delete its
boolean keys and let `WidgetConfigStore.read` fall back to the per-field
default:

```bash
adb shell am force-stop com.steadyprogress.steady_progress
adb shell "run-as com.steadyprogress.steady_progress sed -i \
  '/w<ID>_ring/d;/w<ID>_summary/d;/w<ID>_habits/d;/w<ID>_tasks/d;/w<ID>_reminders/d;/w<ID>_streak/d' \
  /data/data/com.steadyprogress.steady_progress/shared_prefs/steady_progress_widget_config.xml"
```

Find `<ID>` in logcat (`Bound widget <id> to provider …`). Deleting the whole
prefs file also works but wipes every *other* placed widget's settings too.

## Testing

Rendering is covered by instrumentation tests, which must run on a device or
emulator because `Bitmap`, `BlurMaskFilter` and `Path` are native:

```bash
(cd android && ./gradlew :app:connectedDebugAndroidTest)
```

They do not cover the layout XML, which is where both shipped bugs lived. After
any change to `widget_steady_progress.xml`, install and check logcat for
`InflateException` — the widget failing silently to an empty box is the
signature.
