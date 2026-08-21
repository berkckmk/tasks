# Seeding test data

**There is no dev Firebase project.** `tasks-1903` is the only one, so every
seeder here writes production data for a real account. Seed a throwaway account
unless you mean to populate your own.

## Three ways in

| Path | Covers | Use when |
|---|---|---|
| `/dev-seed` route | habits, tasks, reminders | You are already in the app; debug builds only (`kDebugMode`) |
| `lib/debug/seed_dev.dart` | habits, tasks, reminders | Calling from your own code |
| `lib/debug/seed_all.dart` | **every collection** | You need the whole product populated, or you are testing rules |

## The full seeder

```bash
flutter run -t lib/debug/seed_main.dart -d <device-id>
```

`seed_main.dart` is a separate entrypoint rather than a button in the app, so
seeding never ships in the real UI and `main.dart` stays untouched. It reuses
the app's Firebase config and whatever session is already persisted on the
device, so **the account signed in in the app is the account that gets seeded**.
Results print to the screen and to logcat as `SEED >> …` lines.

On a flaky wireless link, prefer building and launching by hand and reading the
result from logcat (see `DEVICE_DEBUGGING.md`) — `flutter run`'s VM-service
attach is the fragile part, not the seeding.

Two properties make it safe to re-run:

- **It tops up rather than duplicates.** Each module counts what is already
  there with an aggregation query and writes only the shortfall, taking the tail
  of its seed list so a second run adds items the first did not. A collection
  already at `kSeedCount` is reported as skipped.
- **Modules are independent.** A failure is recorded and the run continues, so
  one broken collection cannot mask the state of the rest.

Modules whose data depends on another (habit logs on habits, exercise logs on
workouts) report explicitly when the dependency produced nothing, rather than
reporting a vacuous success.

## It doubles as a rules and functions test

The seeder writes through the *real* paths — the `createHabit` / `createTask`
callables where rules deny client `create`, direct client writes everywhere else
— so its output is a live map of what the deployed backend actually permits.
That is more than `flutter test` can offer: `fake_cloud_firestore` has no rules
engine at all.

This is how the two largest backend problems in the project were found. A run on
2026-08-15 produced:

```
habits: FAILED (resource-exhausted: Starter plan allows up to 3 active habits)
tasks: 5
reminders: FAILED (permission-denied)
goals: FAILED (permission-denied)
finance_transactions: FAILED (permission-denied)
… every plan-gated module the same
```

Reading those two failure shapes:

- **A whole band of unrelated modules failing with `permission-denied`** meant
  the deployed rules predated `betaAllAccess()`. Deploying the rules fixed all
  seven at once.
- **`reminders` failing when the others recovered** meant something specific to
  that collection — it had no `match` block in `firestore.rules` at all, so
  default-deny applied. That needed a code change, not a deploy.
- **A Starter limit firing during the beta** meant the deployed *functions*
  predated `BETA_ALL_ACCESS`. Still outstanding — `DEPLOYMENT_STATE.md`.

If a fresh run shows a similar band of failures, suspect deployment drift before
suspecting the code.

## Cleaning up

There is no unseeder. Seeded documents carry `"Seed verisi — gerçek DB testi."`
in their description/notes fields where the model has one, which makes them
findable in the Firestore console. Habits, tasks and habit logs have no such
marker.
