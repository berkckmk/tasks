# Google Integrations & Production Readiness

> **Read this file before touching Google Sign-In, Calendar/Sheets/Drive/Docs
> integrations, Cloud Functions, Storage, Messaging, Analytics/Crashlytics,
> billing, or release prep.** It documents what's already implemented,
> what's design-only (and why), and the exact steps left to actually deploy
> and test any of it. Last updated after the "fill every gap up to real
> payment" pass.

## Verification status

- `flutter analyze` → clean
- `flutter test` → 3/3 passing (one test drives the full authenticated
  shell, including the Google Integrations and Reports screens)
- `flutter build web` and `flutter build apk --debug` → succeed, with every
  package in this doc included (Storage, Messaging, Analytics, Crashlytics,
  in_app_purchase, image_picker)
- **The Cloud Functions TypeScript actually compiles**: `npm install` +
  `tsc --noEmit` + `npm run build` inside `functions/` were run for real
  against the actual `googleapis` / `firebase-admin` / `firebase-functions`
  / `stripe` type definitions — this isn't just written-and-hoped-for code.

None of this has been deployed or run against a real Google Cloud project,
Play Console, or Stripe account — that requires interactive account setup
that couldn't be done in the environment this was built in. Everything
below is either real, verified code, or clearly marked as a placeholder
needing external configuration.

---

## 1) What's implemented (real code)

**Auth & Google integrations** (see the top of this file's previous
version in git history for the full write-up — summarized here):
- Real Google Sign-In, account linking, conflict handling.
- Google Integrations screen (`/google-integrations`) with incremental,
  per-integration OAuth scopes — never all four at once.
- Calendar/Sheets/Drive/Docs Cloud Functions, all verified to compile.
- Everything gated behind `PlanEnforcement.canAccessGoogleIntegrations`.

**Firebase Storage:**
- Avatar upload — tap the avatar on the Profile screen, picks an image
  (`image_picker`, gallery source), uploads to
  `users/{uid}/avatar.jpg`, saves the download URL to
  `UserProfile.photoUrl`. See
  `lib/features/profile/data/avatar_repository.dart`,
  `application/avatar_actions.dart`.
- `storage.rules` — publicly readable (so `Image.network` works without an
  auth header), owner-only write, capped at 5MB, must be an image.

**Cloud Messaging (FCM):**
- Toggling "Reminders & nudges" on the Profile screen requests
  notification permission and registers this device's FCM token to
  `users/{uid}/fcmTokens/{token}`; toggling off unregisters it. See
  `lib/features/notifications/`.
- Background handler registered in `main.dart`
  (`_firebaseMessagingBackgroundHandler`) so pushes are delivered even when
  the app isn't running.
- **Cloud Functions that actually send them:**
  `sendHabitReminders` (every 15 minutes, matches each habit's
  `reminderTimeLabel` against the current time *in that user's own
  timezone*) and `sendDailyTaskDigest` (once daily, "N tasks due today").
  Both clean up tokens Firebase reports as no-longer-valid. See
  `functions/src/notifications/reminders.ts`.

**Analytics & Crashlytics:**
- `AnalyticsService` (`lib/core/analytics/analytics_service.dart`) — a
  typed wrapper so event names live in one place instead of scattered
  string literals. Wired into: sign-up/login (with method),
  habit-completed, task-completed, goal-created, plan-upgrade-attempted/
  -succeeded, google-integration-connected.
- Crashlytics wired in `main.dart` via `FlutterError.onError` and
  `PlatformDispatcher.instance.onError` — **guarded with `if (!kIsWeb)`**
  since Crashlytics has no web implementation; web errors still surface in
  the browser console as normal.

**Payments — real provider integrations, not yet the active default:**
- `PlayBillingService` (`lib/features/subscription/data/`) — real
  `in_app_purchase` wiring: queries the product, starts the purchase,
  listens to the purchase stream, and **never grants entitlement from the
  client purchase state alone** — every successful purchase is sent to the
  `verifyPlayPurchase` Cloud Function (Android Publisher API) before
  `subscription/status` is touched.
- `StripeCheckoutService` — calls `createStripeCheckoutSession`, redirects
  to Stripe's hosted Checkout page (no card fields in this app at all).
  Completion is handled entirely by `handleBillingWebhook`, which **now
  has real Stripe signature verification** (previously a 501 placeholder)
  and updates `subscription/status` on `checkout.session.completed` /
  `customer.subscription.updated` / `customer.subscription.deleted`.
- `createStripePortalSession` — opens Stripe's hosted "manage my
  subscription" page.
- `verifyPlayPurchase` — calls the Android Publisher API
  (`androidpublisher.purchases.subscriptions.get`) to confirm a purchase
  token is real and active before granting the plan.
- **`billingServiceProvider` returns `BetaBillingService`** during the
  closed beta (see §7). Unlike the `DevBillingService` it replaced, it cannot
  write entitlement — `subscription/status` is Admin-SDK-only now.

---

## 2) Architecture (text diagram)

```
┌──────────────────────────────┐
│   Flutter App (Android/Web)  │
│                               │
│  UI ──▶ Riverpod Actions      │
│           │                   │
│           ├─▶ FirebaseAuth ───────────────┐
│           ├─▶ Firestore (users/{uid}/…) ──┤
│           ├─▶ FirebaseStorage (avatar) ────┤
│           ├─▶ FirebaseMessaging (token) ───┤
│           ├─▶ FirebaseAnalytics ───────────┤
│           ├─▶ Crashlytics (Android/iOS) ───┤
│           ├─▶ in_app_purchase (Android) ───┤ (not active default)
│           └─▶ FirebaseFunctions.call ────┐ │
└─────────────────────────────────────────┼─┼───────────────┐
                                           │ │               │
                    ┌──────────────────────▼─▼──┐            │
                    │   Cloud Functions (Node)   │            │
                    │                            │            │
                    │  connectGoogleIntegration  │──▶ Google APIs
                    │  syncGoogleCalendar        │    (Calendar/Sheets/
                    │  exportToGoogleSheets      │     Drive/Docs)
                    │  backupToGoogleDrive       │            │
                    │  generateGoogleDocsReport  │            │
                    │  scheduledCalendarSync     │            │
                    │  sendHabitReminders ───────┼──▶ FCM ───▶ device
                    │  sendDailyTaskDigest       │            │
                    │  createStripeCheckoutSession──▶ Stripe ─┤
                    │  handleBillingWebhook  ◀───┼── Stripe   │
                    │  verifyPlayPurchase ───────┼──▶ Android Publisher API
                    │                            │            │
                    │  refresh tokens + secrets  │            │
                    │  live here — never sent    │            │
                    │  to the client              │            │
                    └──────────────┬─────────────┘            │
                                   │ Admin SDK (rules bypass)  │
                    ┌──────────────▼─────────────┐             │
                    │  Firestore                 │             │
                    │  users/{uid}/                │             │
                    │    integrations/{id}   (client: read-only)│
                    │    secureTokens/{id}   (client: NO access)│
                    │    reports/{id}        (client: read-only)│
                    │    fcmTokens/{token}   (client: read/write,│
                    │                         own device only)  │
                    │    subscription/status (client: WRITABLE  │
                    │                         for now — dev only,│
                    │                         see §7)            │
                    │    tasks, habits, ...   (client: read/write,│
                    │                          rules-validated)  │
                    └─────────────────────────────┘
```

**The core invariant:** the client never calls a Google/Stripe/Play API
directly for anything that grants entitlement, and never sees a refresh
token or a client secret. Everything privileged goes through a callable
function.

---

## 3) Token & security architecture

*(Unchanged from the Google-integrations phase — see git history for the
full write-up on OAuth code exchange and refresh token storage. Same
model now applies to Stripe/Play secrets: `STRIPE_SECRET_KEY`,
`STRIPE_WEBHOOK_SECRET`, and the Play verification service account all
live only in `functions/.env` / Cloud Functions config, never in the
Flutter app.)*

---

## 4) Firestore & Storage security rules — what's new this pass

| Collection/path | Client read | Client write |
|---|---|---|
| `fcmTokens/{token}` | ✅ (own) | ✅ (own) — a device token isn't a credential for the user's account, so client-write is an acceptable trade-off to avoid a Cloud Function round-trip just to register a device |
| `storage: users/{uid}/avatar.jpg` | ✅ (public) | ✅ (own uid, ≤5MB, must be `image/*`) |
| `subscription/status` | ✅ (own) | `create` only, pinned to `planId: 'starter'` (the sign-up bootstrap). `update`/`delete` denied — entitlement is Admin-SDK-only, written by `handleBillingWebhook` / `verifyPlayPurchase` |

Everything from the previous phase (`integrations/*`, `secureTokens/*`,
`reports/*` all function-only) is unchanged.

---

## 5) Deploy order (next steps)

1. `flutterfire configure` to connect a real Firebase project (still
   placeholder values in `lib/firebase_options.dart`).
2. Firebase Console → Authentication → Sign-in method → enable **Google**.
3. Google Cloud Console → APIs & Services → Library → enable **Calendar
   API, Sheets API, Drive API, Docs API, Android Publisher API**.
4. Create a **Web application OAuth client** → put its ID into
   `lib/core/google/google_auth_config.dart`.
5. Firebase Console → Project Settings → Cloud Messaging → Web
   configuration → generate a Web Push certificate → put the key into
   `lib/core/google/fcm_config.dart` (`webVapidKey`).
6. Copy `functions/.env.example` to `functions/.env`, fill in the Google
   OAuth secret, Stripe keys, and `ANDROID_PACKAGE_NAME`.
7. `firebase deploy --only firestore:rules,firestore:indexes,storage,functions`
8. `flutter build web && firebase deploy --only hosting`
9. For Stripe: after the first deploy, copy the deployed
   `handleBillingWebhook` URL into Stripe Dashboard → Developers →
   Webhooks, then copy the signing secret it gives you back into
   `functions/.env`'s `STRIPE_WEBHOOK_SECRET` and redeploy functions.
10. For Play Billing: create the subscription products in Play Console
    matching `lib/features/subscription/domain/billing_product_ids.dart`,
    then grant the Cloud Functions service account access under Play
    Console → Users and permissions.

---

## 6) Production readiness

| Area | Status |
|---|---|
| Firestore rules | ✅ written, all collections covered |
| Firestore indexes | ✅ `firestore.indexes.json` |
| Storage rules | ✅ `storage.rules` |
| Error logging | ✅ Crashlytics wired (Android/iOS); web errors surface in browser console |
| Analytics events | ✅ `AnalyticsService`, wired into key actions (see §1) |
| Push notifications | ✅ FCM token lifecycle + two scheduled sender functions |
| App versioning | `pubspec.yaml` has `version: 1.0.0+1`; override with `--build-name`/`--build-number` in CI |
| Environment config | Recommended, not done: `--dart-define=ENVIRONMENT=prod` plus separate `firebase_options_dev.dart` / `firebase_options_prod.dart` |
| Privacy Policy | **Required** — must now also disclose push notification tokens and any avatar image storage, in addition to Calendar/Sheets/Drive/Docs data |
| Terms of Service | Recommended for a subscription SaaS (cancellation/refund policy) |

---

## 7) Payments — how to actually go live

**What exists:** `PlayBillingService` and `StripeCheckoutService` are
real, compile-checked implementations of `BillingService`. `verifyPlayPurchase`,
`createStripeCheckoutSession`, `createStripePortalSession`, and a
signature-verifying `handleBillingWebhook` are real, compile-checked Cloud
Functions.

**What's NOT done, and can't be from this environment:** creating the
actual subscription products in Play Console and prices in the Stripe
Dashboard, and testing a real purchase — both need accounts/consoles this
environment has no access to.

**`billingServiceProvider` currently returns `BetaBillingService`**, because
the app is in a closed beta where every account is granted the Complete plan
for free — see `lib/features/subscription/domain/beta_access.dart`.

That free access comes from the `kBetaAllAccess` flag, **not** from a
client-writable entitlement document. `subscription/status` is now
Admin-SDK-only (`allow update, delete: if false`), which is what makes every
plan check trustworthy: previously both `firestore.rules`' `userPlan()` and
`functions/src/lib/plan.ts`' `getUserPlanId()` read a document the account
being gated could write, so any user could grant themselves Complete with a
single console write, and `BetaBillingService` cannot grant anything at all.

To go live, once Play Console/Stripe are set up:

1. Fill in real IDs in
   `lib/features/subscription/domain/billing_product_ids.dart`, and set
   `STRIPE_PRICE_GROWTH` / `STRIPE_PRICE_COMPLETE` / `APP_ALLOWED_ORIGINS` in
   `functions/.env` (unknown price IDs are rejected — the mapping fails
   closed).
2. Set the three secrets with `firebase functions:secrets:set`
   (`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`,
   `GOOGLE_OAUTH_CLIENT_SECRET`). They're declared via `defineSecret` in
   `functions/src/lib/secrets.ts` and bound per function; a secret that isn't
   bound is never injected.
3. Turn off the closed beta by flipping **all three** mirrors in one commit:
   `kBetaAllAccess` (`beta_access.dart`), `BETA_ALL_ACCESS`
   (`functions/src/lib/plan.ts`), and `betaAllAccess()` (`firestore.rules`).
   Then delete the `kBetaAllAccess` branch in `billingServiceProvider` so it
   returns the real Stripe/Play services.
4. Update `test/app_flow_test.dart`'s "closed beta unlocks premium modules"
   case — it asserts `kBetaAllAccess` is true precisely so that turning the
   beta off surfaces here rather than silently changing behaviour.

Entitlement expiry is already enforced on both sides: `getUserPlanId` and
`firestore.rules` both resolve a cancelled/expired subscription (or one whose
`expiresAt` has passed) to `starter`, so a webhook that never arrives can't
leave a paid plan granted forever.

| Platform | Provider | Status |
|---|---|---|
| Android | Google Play Billing | Code ready; needs Play Console products + service account grant |
| Web | Stripe | Code ready; needs Dashboard prices + webhook registration |

---

## 8) Android & Web release prep

Unchanged from the previous phase — package name still needs changing
from the default, signing still needs a real upload keystore, app icons
are still placeholders, and Firebase Hosting is configured but not
deployed. See git history for the full checklist; nothing here changed
this pass except that the Play Billing permission
(`com.android.vending.BILLING`) is merged automatically by the
`in_app_purchase` plugin — no manual manifest edit needed.
