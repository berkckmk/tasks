# Steady Progress

A calm, premium life-management app (Flutter, Android + Web) with a
Firebase backend — focused on three pillars: Tasks, Reminders, and Habits.
The product is intentionally scoped to those areas so people can track the
core routines they need without extra modules or unrelated planning surfaces.

> **The deployed backend can be older than this repo.** Rules and functions are
> deployed by hand and have drifted before, which presents as a whole feature
> area failing while the source looks correct. Check
> [`docs/DEPLOYMENT_STATE.md`](docs/DEPLOYMENT_STATE.md) before debugging any
> "works locally, fails on device" gap.

## Documentation

[`CLAUDE.md`](CLAUDE.md) is the orientation page — architecture, commands, and
the invariants not to regress. Then, by task:

| Document | Read before |
|---|---|
| [`docs/DEPLOYMENT_STATE.md`](docs/DEPLOYMENT_STATE.md) | Deploying, or diagnosing repo-vs-production gaps |
| [`docs/FIRESTORE_DATA_MODEL.md`](docs/FIRESTORE_DATA_MODEL.md) | Adding a collection, field, or write path |
| [`docs/GOOGLE_INTEGRATIONS_AND_PRODUCTION.md`](docs/GOOGLE_INTEGRATIONS_AND_PRODUCTION.md) | Google Sign-In, Calendar/Sheets/Drive/Docs, Cloud Functions, release prep |
| [`docs/SECURITY_REVIEW.md`](docs/SECURITY_REVIEW.md) | Plan enforcement, billing, rules — the backend axis |
| [`docs/ANDROID_SECURITY_POSTURE.md`](docs/ANDROID_SECURITY_POSTURE.md) | Permissions and the app's footprint on a user's device |
| [`docs/ANDROID_WIDGET.md`](docs/ANDROID_WIDGET.md) | Anything under `android/.../widget/` or `res/layout/widget_*` |
| [`docs/DEVICE_DEBUGGING.md`](docs/DEVICE_DEBUGGING.md) | Running on a physical Android device |
| [`docs/SEEDING_TEST_DATA.md`](docs/SEEDING_TEST_DATA.md) | Populating an account with realistic data |

## Getting Started

```bash
flutter pub get
flutter run                 # Android/iOS
flutter run -d chrome       # Web
```

Verification used throughout development:

```bash
flutter analyze
flutter test
(cd functions && npx tsc --noEmit)
firebase deploy --only firestore:rules --dry-run   # rules compile check
```

## Plans and access

The app is in a **closed beta**: every signed-in account is granted the
Complete plan for free by the `kBetaAllAccess` flag in
[`lib/features/subscription/domain/beta_access.dart`](lib/features/subscription/domain/beta_access.dart),
which is mirrored in `functions/src/lib/plan.ts` and `firestore.rules`.

Entitlement itself (`users/{uid}/subscription/status`) is Admin-SDK-only —
only the verified Stripe webhook and Play purchase check may grant a paid
plan. See `docs/GOOGLE_INTEGRATIONS_AND_PRODUCTION.md` §7 for the exact steps
to end the beta and switch on real billing.

## Home-screen widget (Android)

A resizable home-screen widget showing today's completion ring, habit/task
counts and best streak, rendered in an Apple "Liquid Glass" material.

Because `RemoteViews` can't host a custom `View` (so no `RenderEffect`, no
shaders) and a widget can't read the wallpaper by itself, the panel is drawn
into a bitmap and shown in a single `ImageView`. The setup screen can take a
wallpaper image from you and let you drag the panel to where the widget sits,
which is what gives the glass something real to refract. See the header
comment in
[`LiquidGlass.kt`](android/app/src/main/kotlin/com/steadyprogress/steady_progress/widget/LiquidGlass.kt)
for what that reproduces and why.

Data flows one way: Flutter pushes a snapshot over a method channel whenever
the counts change ([`HomeWidgetSync`](lib/features/home_widget/presentation/home_widget_sync.dart)),
the widget renders from that. It never touches Firestore.

The rendering is covered by instrumentation tests, which have to run on a
device or emulator — `Bitmap`/`BlurMaskFilter`/`Path` are native:

```bash
(cd android && ./gradlew :app:connectedDebugAndroidTest)
```

## Learning Flutter

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Flutter documentation](https://docs.flutter.dev/)
