# Steady Progress

A calm, premium productivity tracking app (Flutter, Android + Web) with a
Firebase backend — habits, tasks, goals, premium modules, and Google
integrations.

> **Before working on Google Sign-In, Calendar/Sheets/Drive/Docs
> integrations, Cloud Functions, or release prep, read
> [`docs/GOOGLE_INTEGRATIONS_AND_PRODUCTION.md`](docs/GOOGLE_INTEGRATIONS_AND_PRODUCTION.md)
> first.** It documents what's implemented, what's design-only (and why),
> the security model for OAuth tokens, and the exact deploy steps left.
>
> Also see [`docs/SECURITY_REVIEW.md`](docs/SECURITY_REVIEW.md) for a
> full-project security audit (server-side plan enforcement, billing
> correctness, habit/task count limits).

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

## Learning Flutter

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Flutter documentation](https://docs.flutter.dev/)
