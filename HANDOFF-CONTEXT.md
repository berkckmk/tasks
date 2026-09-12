# Handoff context — steady_progress

You are being asked to commit and push the working tree of a Flutter + Firebase
app. This document tells you what changed, what was already there before, and
what must not be committed. **Read the "Do not attribute" section before writing
any commit message** — a large part of the working tree is not from the session
that produced these changes.

- **Repo:** `/Users/pix/pix-code/task/steady_progress`
- **Base commit:** `c4801fd` — *Close plan-enforcement hole, fix broken sync/edit flows, harden backend*
- **Branch:** whatever `c4801fd` is on; nothing has been branched or committed since.
- **Working tree:** 59 modified, 35 untracked (after the `.gitignore` fix below).

---

## 1. Do not attribute — pre-existing uncommitted work

The tree was **already dirty** before this session started. The following were
modified or untracked at `c4801fd` and are *not* part of the work described in
section 2. Do not describe them in the commit message as if they were:

**Already modified:**
`README.md`, `android/app/build.gradle.kts`,
`android/app/src/main/AndroidManifest.xml`, `MainActivity.kt`,
`android/app/src/main/res/values{,-night}/styles.xml`, `firestore.rules`,
`functions/tsconfig.json`, `lib/app/router/app_router.dart`,
`lib/core/widgets/empty_state.dart`,
`lib/features/auth/application/auth_actions.dart`,
`lib/features/habits/data/firestore_habit_repository.dart`,
`lib/features/more/presentation/more_screen.dart`,
`lib/features/profile/application/profile_providers.dart`,
`lib/features/profile/data/user_profile_repository.dart`,
`lib/features/splash/presentation/splash_screen.dart`,
`lib/features/subscription/presentation/guarded_create.dart`,
`lib/features/workout/presentation/workout_screen.dart`,
`test/app_flow_test.dart`, `test/support/fakes.dart`

**Already untracked (entire features/docs, authored earlier):**
`CLAUDE.md`, `docs/` (all 8 files), `lib/core/time/`, `lib/debug/`,
`lib/features/home_widget/`, `lib/features/reminders/`,
`android/app/src/androidTest/`,
`android/app/src/main/kotlin/.../widget/`, `android/app/src/main/res/layout/`,
`android/app/src/main/res/xml/`, `android/app/src/main/res/values*/colors.xml`,
`android/app/src/main/res/values/strings.xml`,
`android/app/src/main/res/drawable/config_*.xml`,
`android/app/src/main/res/drawable/widget_preview_panel.xml`,
`test/iana_timezone_test.dart`, `test/reminder_repository_test.dart`

Several of those files were **also edited** by this session (see section 2), so
they carry both. Where that is true it is called out inline below.

> Note: some pre-existing files also picked up whitespace-only reflow from a
> `dart format` run: `app_router.dart`, `empty_state.dart`, `auth_actions.dart`,
> `firestore_habit_repository.dart`, `profile_providers.dart`,
> `user_profile_repository.dart`, `splash_screen.dart`, `guarded_create.dart`.
> Content is unchanged (the formatter is semantics-preserving); only line
> wrapping moved.

---

## 2. What this session changed

Three workstreams, in order.

### A. Liquid Glass UI (`liquid_glass_widgets: ^0.30.2`)

Added the package and moved the app's structural chrome onto it.

**New files**
| File | Purpose |
|---|---|
| `lib/app/theme/app_glass_theme.dart` | App-wide `GlassThemeData` (tint, thickness, blur) |
| `lib/app/theme/app_backdrop.dart` | The static gradient the glass refracts |
| `lib/core/widgets/app_glass_app_bar.dart` | `AppGlassAppBar` — restores the back button Material gave for free |
| `lib/core/widgets/app_glass_page.dart` | `AppGlassPage` — backdrop wrapper installed once from `MaterialApp.builder` |
| `lib/core/widgets/app_fab.dart` | `AppFab` — replaces 8 identical `FloatingActionButton`s |
| `lib/core/widgets/app_dialogs.dart` | `confirmDestructive()` — replaces 4 identical delete dialogs |
| `lib/core/layout/scroll_insets.dart` | `scrollInsets()` — reserves the glass tab bar's height in scrollables |

**Changed**
- `pubspec.yaml` / `pubspec.lock` — the dependency.
- `lib/main.dart` — `LiquidGlassWidgets.initialize()` + `wrap()`.
- `lib/app/app.dart` — backdrop installed once via `MaterialApp.builder`.
- `lib/app/theme/app_colors.dart` — added `glassSurface` / `glassDivider` / `onGlass*` tokens.
- `lib/app/theme/app_theme.dart` — transparent scaffold + app bar, dead nav themes removed, `snackBarTheme` added.
- `lib/core/widgets/responsive_scaffold.dart` — `GlassTabBar.bottom` + a hand-built glass rail (the package has no rail).
- `lib/core/widgets/app_card.dart`, `app_button.dart`, `app_badge.dart` — glass internals, **outer APIs unchanged** so their 79 call sites did not move.
- 23 screens — `AppBar` → `AppGlassAppBar`.
- 8 screens — FAB → `AppFab`.
- 5 sheets — `showModalBottomSheet` → `GlassModalSheet.show`.
- 5 dialogs — `showDialog`/`AlertDialog` → `GlassDialog`.
- `reminder_card.dart` — the app's last raw Material `Card` → `AppCard`.
- `dev_seed_screen.dart` — the app's last `ElevatedButton` → `AppButton`.
- **Deleted** `lib/widgets/liquid_glass_card.dart` (200 lines, referenced nowhere, never tracked by git).

### B. Android home-screen widget — real wallpaper backdrop

The widget's Kotlin renderer already imitated Liquid Glass optics but had no
real backdrop, because a widget cannot read the wallpaper (blocked since
Android 13). Worked around by letting the **user** supply the image.

- `functions`-side: none.
- `WidgetConfigStore.kt` — `backdropFile`, `backdropRect`, `backdropBlur` + persistence + cleanup on delete.
- `LiquidGlass.kt` — `drawPanel(..., backdrop: Bitmap?)`, composited between the ambient shadow and the body, clipped to the panel's squircle. **With `backdrop == null` the output is unchanged.**
- `GlassRenderer.kt` — loads/crops/blurs the wallpaper; backdrop identity added to the panel cache key.
- `SteadyProgressWidgetConfigureActivity.kt` + `widget_configure.xml` + `strings.xml` — permission-free photo picker, drag-to-position, backdrop blur slider.
- `SteadyProgressWidgetProvider.kt` — `copy()` instead of a hand-listed rebuild (this also fixed an existing bug that dropped `opacity` whenever the shown field was cycled).
- `docs/ANDROID_WIDGET.md`, `README.md` — the "a true backdrop blur is impossible" claim was no longer true.

### C. Notification settings module

Per-channel switches that gate real scheduled functions.

**New**
| File | Purpose |
|---|---|
| `lib/features/notifications/domain/notification_settings.dart` | Model + `NotificationChannel` enum |
| `lib/features/notifications/application/notification_settings_providers.dart` | Providers + actions (FCM permission/token handling moved here) |
| `lib/features/notifications/presentation/notification_settings_screen.dart` | The settings screen |
| `functions/src/notifications/preferences.ts` | Backend reader for the same keys |
| `test/notification_settings_test.dart` | 9 tests, mostly around the backwards-compat defaults |

**Changed**
- `functions/src/notifications/reminders.ts` — both existing senders gated per channel; digest hour is now a user setting instead of a hardcoded 08:00; **new `sendDueReminders`** (the `reminders` collection had a `dueAt` and no sender at all).
- `functions/src/lib/datetime.ts` — added `wallClockLabelInTimeZone()`.
- `functions/src/index.ts` — exports `sendDueReminders`.
- `firestore.rules` — `hasValidNotificationPreferences()`; `taskDigestHour` constrained to 0..23.
- `lib/app/router/app_router.dart` — `/settings/notifications`.
- `lib/features/profile/presentation/profile_screen.dart` — single switch → row opening the new screen, with a summary line.
- `lib/features/reminders/data/firestore_reminder_repository.dart` — clears `notifiedAt` on edit so a rescheduled reminder re-arms.
- `docs/FIRESTORE_DATA_MODEL.md` — documents `appPreferences` notification fields and `reminders.notifiedAt`.

### D. Cleanups
- Analyzer: **13 warnings → 0** (10 redundant record-field casts in `seed_dev.dart`, 3 dead imports in the reminders feature).
- `.gitignore` — `/build/` is root-anchored and did not match `android/build/`; added `android/build/`, `android/.gradle/`, `android/gradle_dryrun_output.txt`.

---

## 3. Do not commit

`.gitignore` now excludes these, but verify they are absent from the staged set:

- `android/build/` (132K of Gradle output)
- `android/gradle_dryrun_output.txt` (93K log)

Also consider whether these *should* be committed at all — they are the user's
own untracked work and may be deliberate work-in-progress:

- `android/app/src/androidTest/` — **does not compile** (see section 5).

---

## 4. Verification — all green as of handoff

Run from `/Users/pix/pix-code/task/steady_progress`:

```bash
flutter analyze                 # 0 errors, 0 warnings
flutter test                    # 42 tests, all passing
(cd functions && npx tsc --noEmit)
firebase deploy --only firestore:rules --dry-run --project tasks-1903
```

Also verified by hand on a physical Galaxy S25 (release build) and on
`flutter run -d chrome`.

---

## 5. Known issues to carry into the commit message or an issue tracker

1. **Backend is not deployed.** `firebase functions:list` confirms production
   still runs the *old* `sendHabitReminders` / `sendDailyTaskDigest` and has no
   `sendDueReminders`. Until `firebase deploy --only functions,firestore:rules`
   runs, the three notification switches and the digest-hour picker write to
   Firestore and nothing reads them. This is deliberate — deploying touches
   production (`tasks-1903`) and was left to the owner.
2. **`android/app/src/androidTest/` does not compile.** It expects
   `WidgetData.goals` and a carousel API that do not exist. Pre-existing,
   untracked, never built. It blocks
   `./gradlew :app:connectedDebugAndroidTest`, which is the only test coverage
   the widget renderer has.
3. **App is light-mode only.** `AppGlassTheme` carries a full dark variant and
   `AppBackdrop` has a dark path, but no `darkTheme`/`themeMode` is set. Turning
   it on needs an audit of ~264 static `AppColors.charcoal`-style references
   first, or dark mode ships unreadable.
4. **Form controls are still Material**: `TextField` ×22, `TextFormField` ×2,
   `Chip` ×17, `CircularProgressIndicator` ×18, `ListTile` ×8,
   `SwitchListTile` ×4, `LinearProgressIndicator` ×4, `Slider` ×1.
5. **SnackBars are themed, not `GlassToast`.** ~15 of ~35 call sites capture the
   messenger before an `await`; `GlassToast.show` needs a live `BuildContext`,
   so migrating them would trade a working error message for a possible crash.
6. **Six module screens still hand-roll their locked `Scaffold`** instead of
   delegating to `RequiresModule` (finance, workout, learning, content,
   analytics, reports). `goals_screen.dart` shows the correct pattern.
7. **No backend tests.** `functions/package.json` has no test script, so
   `preferences.ts` and `sendDueReminders` are covered only by `tsc`.

---

## 6. Suggested commit split

The tree mixes three independent features plus someone else's in-flight work.
A single commit is defensible only if the owner confirms the pre-existing
changes are theirs to include. Otherwise split:

1. `chore: ignore android build output` — `.gitignore` alone.
2. `fix: drop redundant casts and dead imports` — `seed_dev.dart` + 3 reminders files.
3. `feat: liquid glass UI` — workstream A.
4. `feat(widget): refract a user-supplied wallpaper` — workstream B.
5. `feat: per-channel notification settings` — workstream C.

Commits 3–5 each touch `README.md`/`docs/` — keep each doc change with its
feature.

**Ask the owner before including** the section-1 files in any of these; they
predate this work and their intent is not documented anywhere in the tree.
