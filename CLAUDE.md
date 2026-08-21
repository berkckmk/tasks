# CLAUDE.md

Orientation for an AI agent working in this repo. Read this first, then the
document in `docs/` that matches what you're about to touch.

## What this is

**Steady Progress** — a Flutter (Android + Web) life-management app on a
Firebase backend. Three core pillars: **Tasks, Reminders, Habits**, plus
Complete-plan modules (finance, workout, learning, content, goals, analytics,
reports) and Google integrations.

Firebase project: **`tasks-1903`** (single project — there is no separate dev
project; `.firebaserc` defines two *hosting* targets, `production` and `test`,
against the same project). **Any write you make from a device or a script hits
production data.**

The app is in a closed beta: `kBetaAllAccess` grants every signed-in account
the Complete plan for free. That switch is mirrored in three places and all
three must agree — see `docs/DEPLOYMENT_STATE.md`, which also records that the
mirrors are currently *not* all live.

## Commands

```bash
flutter pub get
flutter analyze                     # expect 0 errors (warnings/infos exist)
flutter test                        # 33 tests, all passing as of 2026-08-15
flutter run -d chrome               # web
flutter run -d <device-id>          # Android

(cd functions && npx tsc --noEmit)  # Cloud Functions type check
firebase deploy --only firestore:rules --dry-run --project tasks-1903
```

Android widget rendering is covered by instrumentation tests, which need a real
device or emulator because `Bitmap`/`BlurMaskFilter`/`Path` are native:

```bash
(cd android && ./gradlew :app:connectedDebugAndroidTest)
```

## Architecture

Feature-first. Each feature under `lib/features/<name>/` is layered:

| Layer | Holds |
|---|---|
| `domain/` | Models, enums, repository *interfaces*. No Firebase imports. |
| `data/` | Firestore/Functions implementations of those interfaces. |
| `application/` | Riverpod providers and action classes. |
| `presentation/` | Screens and widgets. |

Shared code lives in `lib/core/` (firebase seam, widgets, time, analytics,
google config) and `lib/app/` (`router/`, `theme/`).

- **State**: `flutter_riverpod`. **Routing**: `go_router` (`lib/app/router/app_router.dart`).
- **Callables** go through `lib/core/firebase/callable_service.dart`, a thin
  seam over `FirebaseFunctions.httpsCallable` — use it rather than calling
  `httpsCallable` directly, so tests can substitute it.
- **Tests** use `firebase_auth_mocks` / `fake_cloud_firestore` swapped in via
  provider overrides (`test/support/fakes.dart`).

## Invariants — do not regress these

1. **Entitlement is Admin-SDK-only.** `users/{uid}/subscription/status` may be
   created by the client pinned to `starter`, but `update`/`delete` are denied
   outright. Only the verified Stripe webhook and the Play purchase check may
   grant a paid plan. If the client could write this, every plan check in
   `firestore.rules` and `functions/` becomes circular. `docs/SECURITY_REVIEW.md`
   calls this the single most important thing on that file not to regress.
2. **`habits` and `tasks` cannot be created by the client.** `firestore.rules`
   denies `create` on both. Creation goes through the `createHabit` /
   `createTask` callables, which count the collection inside a transaction to
   enforce the Starter plan's limits — security rules cannot count a
   collection, which is the whole reason those functions exist.
3. **Every collection needs an explicit `match` block.** Firestore default-denies
   and there is no catch-all in `firestore.rules`. A feature whose collection is
   missing from that file will look finished in the UI and fail silently at
   runtime — this exact bug shipped for `reminders`. See
   `docs/FIRESTORE_DATA_MODEL.md`.
4. **Widget layouts may only use RemoteViews-permitted view classes.** A bare
   `<View>` or `<Space>` fails the *entire* layout inflate, not just that
   element. See `docs/ANDROID_WIDGET.md`.

## Gotchas that have already cost time

- **The deployed backend can be older than this repo.** Rules and functions are
  deployed manually and have silently drifted before. Verify before assuming
  behaviour — `docs/DEPLOYMENT_STATE.md`.
- **`flutter test` proves nothing about security rules.** `fake_cloud_firestore`
  has no rules engine at all. Rules are only verified by reading them or by
  writing against the real project.
- **Wireless debugging drops constantly under Samsung power saving**, which
  looks like a Flutter/VM-service bug and is not — `docs/DEVICE_DEBUGGING.md`.
- Comments in the widget package described a `ListView` carousel and a
  `WidgetCollectionService` that no longer exist. They have been corrected, but
  treat old prose in this repo as a claim to verify, not a fact.

## Document index

| Document | Read it before |
|---|---|
| `docs/DEPLOYMENT_STATE.md` | Deploying anything, or debugging a "works locally, fails on device" gap |
| `docs/FIRESTORE_DATA_MODEL.md` | Adding a collection, a field, or a write path |
| `docs/GOOGLE_INTEGRATIONS_AND_PRODUCTION.md` | Google Sign-In, Calendar/Sheets/Drive/Docs, Cloud Functions, release prep |
| `docs/SECURITY_REVIEW.md` | Touching plan enforcement, billing, or rules (backend axis) |
| `docs/ANDROID_SECURITY_POSTURE.md` | Questions about permissions or the app's footprint on a user's device |
| `docs/ANDROID_WIDGET.md` | Any change under `android/.../widget/` or `res/layout/widget_*` |
| `docs/DEVICE_DEBUGGING.md` | Running on a physical Android device |
| `docs/SEEDING_TEST_DATA.md` | Needing realistic data in an account |
