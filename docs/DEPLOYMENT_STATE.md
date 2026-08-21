# Deployment state

**The deployed backend can be older than this repo.** Rules and functions are
deployed by hand, and they have silently drifted before. When device behaviour
contradicts the source, suspect this file's contents before suspecting the code.

Project: **`tasks-1903`**. Region: `us-central1`. Last verified: **2026-08-15**.

## Current state

| Artefact | State |
|---|---|
| `firestore.rules` | **Deployed 2026-08-15** — current with the repo, including the `reminders` block |
| Cloud Functions | **STALE — blocked, see below** |
| Firestore indexes | not re-deployed in that pass |
| Hosting | not re-deployed in that pass |

## Functions deploy is blocked on the Secret Manager API

```
Error: Request to https://secretmanager.googleapis.com/v1/projects/tasks-1903/secrets/STRIPE_SECRET_KEY
had HTTP Error: 403, Secret Manager API has not been used in project tasks-1903
before or it is disabled.
```

The functions declare `STRIPE_SECRET_KEY`, and the API has never been enabled on
the project. Enable it, then retry:

```
https://console.developers.google.com/apis/api/secretmanager.googleapis.com/overview?project=tasks-1903
```

```bash
firebase deploy --only functions --project tasks-1903
```

### What being stale actually costs

`functions/src/lib/plan.ts` in this repo has `BETA_ALL_ACCESS = true`, so
`getUserPlanId()` should return `"complete"` for everyone during the beta. The
*deployed* copy does not have it. Observed consequence on a live account:

```
createHabit → resource-exhausted:
"The Starter plan allows up to 3 active habits. Upgrade to Growth for unlimited habits."
```

So habit creation is capped at 3 in production even though the repo says the
beta grants Complete. Anything else gated by `getUserPlanId` or `assertPlan` is
equally suspect until the functions are redeployed.

The same drift previously affected the rules: every `hasPlanAtLeast` collection
(goals, finance, savings, workouts, exercise logs, learning, content) returned
`permission-denied` on a live account because the deployed rules predated
`betaAllAccess()`. Deploying the rules fixed all seven at once. Treat that as
the shape of this class of bug: a whole feature area failing at once, with the
source looking correct.

## The three beta mirrors

`kBetaAllAccess` is duplicated in three places and **all three must agree**:

1. `lib/features/subscription/domain/beta_access.dart` — `kBetaAllAccess` (client UI gating)
2. `functions/src/lib/plan.ts` — `BETA_ALL_ACCESS` (Cloud Functions enforcement)
3. `firestore.rules` — `betaAllAccess()` (direct Firestore access)

All three are `true` in the repo today. Only #1 and #3 are live. Ending the beta
means flipping all three *and* deploying #2 and #3 — see
`GOOGLE_INTEGRATIONS_AND_PRODUCTION.md` §7.

## Deployed functions

17 functions, matching this repo's `functions/src/index.ts` exports exactly (no
orphans to prune, so a deploy will not prompt for deletions):

```
backupToGoogleDrive              connectGoogleIntegration
createHabit                      createStripeCheckoutSession
createStripePortalSession        createTask
disconnectGoogleIntegration      exportToGoogleSheets
generateGoogleDocsReport         handleBillingWebhook
onHabitWriteCleanupCalendarEvent onTaskWriteCleanupCalendarEvent
scheduledCalendarSync            sendDailyTaskDigest
sendHabitReminders               syncGoogleCalendar
verifyPlayPurchase
```

`firebase functions:list --project tasks-1903` prints them as a table — pipe it
through `head` and you will truncate the list, which is how an earlier pass
miscounted it at 14.

## Deploy warnings worth acting on

- **Node.js 20 is decommissioned on 2026-10-30.** After that date functions
  cannot be deployed without upgrading the runtime. This is a hard deadline, not
  a nag.
- `firebase-functions` is behind; the CLI flags breaking changes on upgrade.
- The Android build warns that `cloud_functions` and `firebase_analytics` still
  apply the Kotlin Gradle Plugin, which future Flutter versions will refuse to
  build.

## Checks before deploying

```bash
flutter analyze                                                  # 0 errors
flutter test                                                     # 33 passing
(cd functions && npx tsc --noEmit)                               # clean
firebase deploy --only firestore:rules --dry-run --project tasks-1903
```

The dry run only compiles the rules — it does not tell you what is currently
live. There is no CLI command that prints the deployed ruleset, so the only
reliable way to detect drift is to exercise the behaviour against a real
account, as `SEEDING_TEST_DATA.md` describes.
