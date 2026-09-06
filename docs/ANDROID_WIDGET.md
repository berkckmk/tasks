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

## Writes back: two queues, both drained by the app

The one-way rule above still holds — the widget process never touches
Firestore — but the widget is not read-only. It composes intents and the app
executes them.

| Queue | Written by | Drained by |
|---|---|---|
| `WidgetPendingToggles` | the row toggle, via `WidgetToggleWorker` | `HomeWidgetSync._drainPending` |
| `WidgetPendingAdds` | the header's `+`, via `WidgetQuickAddActivity` | `HomeWidgetSync._drainPendingAdds` |

Both drain on mount and on every resume, and both keep an entry queued when the
write fails rather than dropping it.

`WidgetPendingAdds` exists for a reason worth restating: **the widget cannot
create a task at all.** `firestore.rules` denies `create` on `tasks` and
`habits` outright and creation goes through the `createTask` / `createHabit`
callables, which is where the Starter plan's limits are enforced — see
invariant 2 in `CLAUDE.md`. Creating from Kotlin would mean a second copy of
the plan rules inside a process with no auth session.

So the modal writes the intent to the queue *and* an optimistic row into
`WidgetDataStore` (`addLocally`), so the launcher shows the item at once. Three
things keep the two halves consistent:

- `WidgetDataStore.write` folds still-queued adds back into every pushed
  snapshot, so a push landing before the drain does not delete a row the user
  can see.
- `clearPendingAdds` calls `WidgetDataStore.dropLocalAdds` for the ids it
  cleared, or the composed row and the real one would both show.
- Sign-out clears the add queue along with the toggle queue.

The honest limitation is the toggle queue's: until the app runs again, a
composed item lives only on this device.

## The quick-add modal

The `+` used to fire a `PendingIntent` at `MainActivity` with `/reminders/new`.
That is a cold start, a route push and a full-screen form for one line of text,
and it takes away the surface the user was looking at. It now opens
`WidgetQuickAddActivity`: translucent, `backgroundDimAmount 0.5`, and shaped
like Google's own reminder sheet — a title, then one **row per decision** (a
leading icon, a label, the current value) separated by hairlines. Two rows:
when, and area (Reminder / Task / Habit, defaulting to the widget's own scope).

**The schedule rules are the app's, enforced here rather than approximated.**
A modal that queued an item the app would then reject is worse than one that
asks:

| Area | Date | Time |
|---|---|---|
| Reminder | required | **required** |
| Task | required, and a **range** (start then end) | optional — skipping it means All day |
| Habit | none (it recurs) | optional |

Times use `is24HourView = false`, matching the app's AM/PM pickers. The queue
carries `startAt`, `endAt` and `allDay` alongside the label, and
`HomeWidgetSync._create` maps them onto the ordinary action classes — it does
not re-derive them, because a second looser copy of these rules is the one that
would let a bad item through.

**The panel is held near the top of the screen, not centred.** A translucent,
non-floating window does not get resized for the IME, so a centred panel is
measured against the full screen height and its buttons land behind the
keyboard. `adjustResize` and `fitsSystemWindows` were both tried first and
neither helps for this window type; a top anchor clears a full-height keyboard
with no inset plumbing.

## Why a reminder you just added may not be on the widget

`homeWidgetSnapshotProvider` decides which reminders travel, and the rule used
to be `isSameDay(dueAt, now)` alone. That is why a reminder added in the app
could never reach the widget: added for tomorrow it was not today's, and the
moment it came due it became yesterday's. The rule is now **today's, plus
anything overdue and not completed**. There is still no forward horizon.

Two other filters routinely look like a sync bug and are not:

- **Completed rows are hidden** unless the widget's Include set has
  `completed`. A widget whose every task is ticked shows no tasks.
- **A reminder with no `dueAt` never appears anywhere**, widget or app:
  `watchReminders` orders by `dueAt`, and Firestore omits documents that lack
  the field a query orders on.

Before suspecting the channel, dump what actually reached the device:

```bash
adb shell run-as com.steadyprogress.steady_progress \
  cat /data/data/com.steadyprogress.steady_progress/shared_prefs/steady_progress_widget.xml
```

If the item is in that file, the push works and the filter is what is hiding it.

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

## Hit areas are not glyph sizes

A collection row's clickable regions are exactly the views
`setOnClickFillInIntent` was called on — there is no touch-slop expansion, no
`TouchDelegate` (that needs a real `View` subclass), and no minimum size
enforced for you. So a hit area is whatever you sized the view, and it is very
easy to size the view to the *picture* instead.

The toggle shipped as a 15dp `ImageView`, because the circle looks like 15dp.
That made the tap target 15 x 15dp — about 2.4mm, against the platform's 48dp
guidance. And the miss is not a no-op: the toggle and the row share the row,
with `R.id.row` carrying "open the app at this item", so every near-miss on a
checkbox is a full-screen context switch. The reported symptom was exactly
that — trying to tick something off and landing in the app.

The fix is to separate the two: the view is `28 x 26dp`, the drawable is
`20dp`, and `paddingEnd` holds the difference so the circle still sits flush
with the panel's start padding rather than being centred in a wider box that
shoves the whole row right.

**The row height is the real ceiling.** The row is `wrap_content`, so the
toggle's height *is* the row height, and the row height decides whether the
4x2's three configured rows fit before the list starts scrolling. 26dp is what
fits; the remaining growth has to come out of the width, and the width comes
out of the title. At 4x2 that is free, at 2x2 it is not — the 8dp `paddingEnd`
is the row's own gap unit and `row_time` gives up its matching start margin to
pay for it, which is what keeps a 2x2 title from ellipsising a word earlier
than it used to.

If a bigger target is ever wanted, the honest lever is the *row*, not the
toggle: fewer, taller rows. That is a product decision, not a layout one.

## Contrast: why the widget's ramp is not the app's

The widget's type is fixed light and does not flip with the device theme,
because a widget has no app ground to follow — only the user's wallpaper.
**And by default it has no panel of its own either** (`WidgetConfig.ground`
is `NONE`): the rows sit directly on the photograph, the way the launcher's
own clock and weather widgets do. Everything below exists so that is a
supportable default rather than a bug.

It shipped, twice, with a ramp that could not support it.

**First**, with Nocturne's *app* ramp (note 58%, caption 42%, unchecked 32%),
which is tuned against a known dark surface. On a bright wallpaper with the
panel turned down, every step below full washed out; at ground `None` the
measured contrast was **1.0:1** — the text was the same luminance as the
wallpaper, literally invisible. The reported symptom was a widget that looked
switched off.

**Second**, with that ramp raised but not reshaped (note 85%, caption 68%,
unchecked 55%). This cleared the contrast floor, and still looked wrong: the
*spread* between steps is the part that does not survive an unknown ground.
A caption sits at 68% because 68% reads as "secondary" against the surface it
was chosen for. Put it on a photograph and it does not read as secondary, it
reads as dirty — the eye has no reference for what full strength was supposed
to be, so a dimmed step is just a worse-looking step.

What actually works is the trick every transparent platform widget uses:
**put the whole ramp within a hair of white and carry the hierarchy on size
and weight instead.** A 10sp label and a 12.5sp title, both essentially white,
are never confusable, and neither ever looks faded.

Three things do it, and all three are needed:

1. **A flattened ramp.** `res/values/colors.xml` and `WidgetPalette` carry the
   widget's own steps — note 92%, caption 85%, and a 72% floor reserved for
   *completed* rows, the one state the eye should be able to skip. The two
   copies are load-bearing; change one and change the other.
2. **A shadow on every TextView** (`nocturne_text_shadow`). Light type is only
   as readable as its darkest neighbour, and on a bright photo the wallpaper
   gives it none.
3. **The right shadow.** Dense (90% alpha) and *slightly* diffuse — 3dp at
   dy 1. The density carries a bright ground; the radius is what stops the
   result reading as an embossed outline instead of as white text.

That third point was arrived at by rendering it. The widget was drawn over
light, mid and dark grounds at six shadow settings, and the luminance range
inside the row text measured on the light one — the case that decides it:

| Shadow | Ramp | Light-wallpaper range | Reads as |
|---|---|---|---|
| 2dp, dy 0.5, α 90% | 85/68 | 125 | hard rim; times visibly grey |
| 2dp, dy 0.5, α 90% | 92/85 | 125 | hard rim |
| 3dp, dy 1, α 70% | 92/85 | 94 | soft, but giving up margin |
| 3dp, dy 1, α 90% | 92/85 | **118** | **soft grounding, full margin** |
| 6dp, dy 1, α 60% | 92/85 | 81 | grey haze, worse than no shadow |

So widening the blur costs almost nothing as long as the alpha stays up; it
was the *low-alpha* wide blurs that turned into a halo, not width itself. The
2dp original was tighter than it needed to be.

**The limit is real and worth stating.** On a genuinely bright wallpaper,
white text with no ground behind it is legible, not comfortable — no ramp or
shadow fixes that, and the reference designs this imitates are all sitting on
mid-toned photographs. What the numbers above buy is that the default is as
good as that case can be, and the setup screen still offers three panels for
a user whose wallpaper needs one. The live preview mirrors the widget's type,
so it must be kept in sync.

Raising `nocturne_divider` for the same reason would move the panel's hairline,
which is calibrated against One UI — see above. That token is unchanged here.
Measure the edge again if you touch it.

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

`WidgetTextContrastTest` guards the contrast above. It draws the real
RemoteViews over a bright and a dark ground and samples the luminance range
inside each text view's own rectangle, so it measures what the eye gets *after*
the panel fill, the alpha and the shadow have composited — asserting on the
colour constants would not have caught the bug, since those behaved exactly as
written. It is verified to fail on the values that shipped.

Two of its three cases run on `WidgetConfig.DEFAULT`, which is now the
no-panel configuration, and the third turns a panel on — because a ground the
default never renders is a ground that rots.

`connectedAndroidTest` uninstalls the app afterwards, which deletes the PNGs
`WidgetRenderCaptureTest` writes. To keep them, install and instrument by hand:

```bash
(cd android && ./gradlew :app:assembleDebug :app:assembleDebugAndroidTest)
adb install -r -t build/app/outputs/apk/debug/app-debug.apk
adb install -r -t build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb shell am instrument -w -e class \
  com.steadyprogress.steady_progress.widget.WidgetRenderCaptureTest \
  com.steadyprogress.steady_progress.test/androidx.test.runner.AndroidJUnitRunner
adb pull /sdcard/Android/data/com.steadyprogress.steady_progress/files/widget-4x2.png
```

The capture set includes `widget-light-wallpaper*.png` — the bright ground the
ramp failed on. The other captures use a mid-grey stand-in, which is dark
enough to flatter faint text, and is why this was never visible in them.
