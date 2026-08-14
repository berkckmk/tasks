# Security Review

A full-project security/architecture scan of the Flutter app, Firestore/
Storage rules, and Cloud Functions. All findings below were fixed in the
same pass — see "Status" per item. Read this alongside
[`GOOGLE_INTEGRATIONS_AND_PRODUCTION.md`](GOOGLE_INTEGRATIONS_AND_PRODUCTION.md)
for the broader architecture.

## Findings & fixes

### 1. Plan/subscription enforcement existed only in the Flutter client — FIXED

**The problem:** `PlanEnforcement` (Dart) gated the UI for Complete-only
modules (Finance, Workout, Learning, Content), Growth+ (Goal planner), and
Google integrations — but nothing on the server checked any of this.
Anyone with their own valid Firebase ID token could bypass the app
entirely and:
- Write directly to `finance_transactions`, `savings_goals`, `workouts`,
  `exercise_logs`, `learning_items`, `content_items`, or `goals` via the
  Firestore client SDK (e.g. from a browser console), regardless of their
  actual plan.
- Call `connectGoogleIntegration`, `syncGoogleCalendar`,
  `exportToGoogleSheets`, `backupToGoogleDrive`, or
  `generateGoogleDocsReport` directly, getting full Complete-plan Google
  integration functionality on a Starter or Growth plan.

**The fix:**
- `firestore.rules` gained a `userPlan(uid)` / `hasPlanAtLeast(uid, plans)`
  helper that reads `subscription/status.planId` via `get()` and gates
  `create`/`update` on the six Complete-only collections (Complete) and
  `goals` (Growth or Complete). Reads/deletes stay owner-only, so a
  downgraded user can still see and clean up their old data.
- `functions/src/lib/plan.ts` adds the equivalent server-side check
  (`assertPlan`), wired into `connectGoogleIntegration`,
  `syncGoogleCalendar` (via `syncForUser`, so the daily
  `scheduledCalendarSync` job also stops syncing a downgraded user, not
  just the callable), `exportToGoogleSheets`, `backupToGoogleDrive`, and
  `generateGoogleDocsReport`.
- Both fail closed: if `subscription/status` doesn't exist yet (e.g. the
  brief window right after sign-up), the check denies rather than allows.

**Habit/task count limits — now also fixed (see finding #5 below).** They
were deliberately left client-only in the first pass of this review,
documented here as a residual gap, and closed in a follow-up pass.

### 2. Stripe webhook hardcoded the purchased plan — FIXED

**The problem:** `handleBillingWebhook`'s `checkout.session.completed`
handler wrote `planId: "growth"` unconditionally, regardless of which
price the user actually checked out with. A Complete purchase would have
been silently downgraded to Growth (only self-correcting later if/when a
`customer.subscription.updated` event happened to arrive).

**The fix:** `createStripeCheckoutSession` now derives `planId` from the
priceId **server-side** (`billing/priceMapping.ts` — never trusts a
client-supplied planId, which would let someone request the cheap price
while claiming the expensive plan) and stamps it into the session's
metadata at creation time. The webhook reads `session.metadata.planId`
instead of guessing.

### 3. Play Billing purchase tokens weren't bound to the Firebase account — FIXED

**The problem:** `verifyPlayPurchase` confirmed a purchase token was
*real* (via the Android Publisher API) but not that it belonged to the
*calling* Firebase user. A purchase token obtained for one Google account
could in principle be replayed against a different Firebase uid to grant
that account a plan for free. Not exploitable today (`billingServiceProvider`
did not point at `PlayBillingService`), but a real gap for whenever Play
Billing goes live.

**The fix:** `PlayBillingService.purchasePlan` now sets
`PurchaseParam.applicationUserName` to the current Firebase uid (this maps
to Google Play's "obfuscated account ID"). `verifyPlayPurchase` checks
`response.data.obfuscatedExternalAccountId === uid` before granting
anything, rejecting any mismatch.

### 4. `functions/.gitignore` was silently excluding source files from version control — FIXED

**The problem:** `functions/.gitignore` had an unanchored `lib/` pattern,
meant to ignore the *compiled* `functions/lib/` output. Unanchored, it
matched **any** directory named `lib` at any depth — including
`functions/src/lib/`, which holds `admin.ts` (Firebase Admin
initialization) and `tokens.ts` (the secure OAuth refresh-token storage
helpers described in `GOOGLE_INTEGRATIONS_AND_PRODUCTION.md` §3). Those
two files — plus the new `plan.ts` from finding #1 — were never actually
tracked by git, in the initial commit or since. A fresh clone would be
missing them and fail to build.

**The fix:** anchored the pattern to `/lib/`, so it only matches
`functions/lib/` (the compiled output) and no longer shadows
`functions/src/lib/`.

### 5. Habit/task count limits were client-only — FIXED

**The problem:** `PlanEnforcement.canCreateHabit`/`canCreateTask` (Dart)
gated the "add habit"/"add task" buttons at the Starter plan's limits (3
active habits, 20 active tasks — `plan_catalog.dart`), but
`firestore.rules` allowed `create` on both collections for any owner, with
no limit check. A signed-in user could bypass the UI entirely and write a
4th habit or 21st task directly via the Firestore client SDK.

Unlike finding #1's plan-tier gates, this couldn't be fixed with a rule
alone: Firestore security rules have no function to count how many
documents already exist in a collection, so there's no expression a rule
could evaluate to reject "your 4th habit."

**The fix:** habit/task creation now goes through two new Cloud Functions,
`createHabit` and `createTask`
(`functions/src/habits/createHabit.ts`, `functions/src/tasks/createTask.ts`),
and `firestore.rules` changed `allow create` to `if false` on both
`habits/{habitId}` and `tasks/{taskId}` — so the client can no longer
create either directly, only through these functions. Each function:
- Reads the caller's plan via the existing `getUserPlanId` helper.
- On the Starter plan, counts the real collection with a Firestore
  aggregation query (`.count().get()` — no denormalized counter to keep in
  sync, so no drift is possible) and rejects with `resource-exhausted` if
  the caller is already at the limit (3 habits; 20 tasks with
  `status in ['todo', 'inProgress']`, mirroring
  `PlanEnforcement.activeTaskCount`).
- Growth/Complete skip the count check entirely (unlimited).

`FirestoreHabitRepository.saveHabit`/`FirestoreTaskRepository.saveTask`
call the Cloud Function only when creating (`id == null`); editing an
existing habit/task is unaffected and still writes directly to Firestore,
since edits can't increase the count. The client-side `PlanEnforcement`
check is left in place as the fast, pre-emptive UX (it still blocks
navigation to the add screen before the server round-trip); the Cloud
Function is the backstop that makes the limit actually enforced, catching
both direct-Firestore bypass attempts and legitimate races (e.g. the same
account creating from two devices at once).

### 6. Email/password sign-up had no anti-abuse gate — FIXED

**The problem:** anyone could create an account with any email address —
one they don't own, a disposable one, a script iterating through
addresses — and get full app access immediately. Firebase's own
`signUpWithEmail` never required proof the caller actually controls the
inbox.

**The fix:** `AuthRepository.signUpWithEmail` now sends a verification
email on signup, and `firestore.rules`' `isOwner(uid)` — the base check
almost every collection's rules build on — now also requires
`request.auth.token.email_verified == true`. Google accounts arrive with
that already true (Google verifies it), so this never affects them; it
only ever gates the email/password path. The Flutter router mirrors this
with a `/verify-email` redirect (`app/router/app_router.dart`), but that
alone is only UX — the rules change is what actually stops an
unverified account from writing to Firestore directly with its own valid
ID token, the same class of gap as findings #1 and #5.

This forced one real ordering change: the profile/subscription bootstrap
that used to happen immediately in `AuthActions.signUp()` had to move to
`AuthActions.checkEmailVerified()` (fired from the verify-email screen,
either on a manual "I've verified" tap or a silent check on screen load),
since the ID token doesn't carry `email_verified: true` until *after*
verification completes — writing the profile doc at the old point would
now be rejected. `reloadAndCheckEmailVerified()` force-refreshes the ID
token (`getIdToken(true)`) right after confirming verification, since
`User.reload()` alone updates the cached `User` object but not the active
token's claims that rules actually check.

### 7. The entitlement document that finding #1 depends on was client-writable — FIXED

**The problem:** finding #1 above closed the "plan enforcement is client-only"
gap by having `firestore.rules` and `functions/src/lib/plan.ts` read the
user's plan from `users/{uid}/subscription/status`. But that document was
itself client-writable — the rule allowed `create`/`update` with any
`planId` — because `DevBillingService` wrote it directly to simulate a
purchase. That made the whole check **circular**: the account being gated
could write the very document that gates it. One console write
(`{planId: 'complete', billingProvider: 'x'}`) unlocked every Growth/Complete
collection and every `assertPlan`-guarded Cloud Function, with no Stripe or
Play interaction. The rule's own comment noted this was only safe "because no
real payment provider is connected yet" — but `webhook.ts`, `stripe.ts` and
`playBilling.ts` were already written and exported, so that premise had
lapsed.

Related: nothing anywhere read `status`, `expiresAt` or `trialEndsAt`. A
cancelled, refunded or lapsed subscription kept its `planId` forever, so a
failed `customer.subscription.deleted` delivery meant permanent free access.

**The fix:**
- `subscription/status` is now Admin-SDK-only: `allow update, delete: if
  false`. `create` remains, pinned to `planId == 'starter'`, purely so the
  sign-up bootstrap works without a Cloud Function round-trip — it grants
  nothing, and the document can't be deleted and re-created to reset it.
- `DevBillingService` is deleted. `BetaBillingService` replaces it and cannot
  write entitlement at all.
- Free access during the closed beta comes from an explicit `kBetaAllAccess`
  flag mirrored in the client, the functions and the rules — one auditable
  switch instead of a writable field on every tester's document.
- Both `getUserPlanId()` and `firestore.rules`' `userPlan()` now resolve
  expired/cancelled/lapsed subscriptions to `starter`.

## What this review did NOT cover

- **No Firebase Emulator / rules-unit-testing was run.** `fake_cloud_firestore`
  (used in `flutter test`) doesn't enforce security rules at all — it's an
  in-memory fake with no rules engine — so the existing test suite would
  not have caught any of the Firestore rules issues above, and won't catch
  regressions in them going forward. Before shipping, set up
  `firebase emulators:exec` with `@firebase/rules-unit-testing` to actually
  test `firestore.rules` and `storage.rules` against both allowed and
  denied cases. In particular, nothing automated asserts that direct
  client writes to `habits`/`tasks` `create` are actually denied — that's
  currently only verified by reading the rules file.
- Dependency/supply-chain scanning (`npm audit` on `functions/`, `flutter
  pub outdated` for known CVEs) wasn't part of this pass.
- This was a static review of source code, not a penetration test against
  a deployed environment (there isn't one yet — see the deploy steps in
  `GOOGLE_INTEGRATIONS_AND_PRODUCTION.md`).

## Verification

- `flutter analyze` → clean
- `flutter test` → 3/3 passing
- `flutter build web` / `flutter build apk --debug` → succeed
- `functions/`: `npx tsc --noEmit` and `npm run build` → clean
