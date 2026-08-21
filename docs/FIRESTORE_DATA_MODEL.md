# Firestore data model

Every collection the app stores, where it lives, who is allowed to write it,
and the shape it expects. Compiled by reading `firestore.rules`, the
`data/` repositories and the `domain/` models, then verified against the real
`tasks-1903` project on 2026-08-15 by writing to each one.

Everything is scoped under `users/{uid}/`. There are no top-level collections
other than `users`.

## Write paths at a glance

| Collection | Create path | Rules gate |
|---|---|---|
| `habits` | **`createHabit` callable only** | `allow create: if false` |
| `habit_logs` | client | owner + field validation |
| `tasks` | **`createTask` callable only** | `allow create: if false` |
| `reminders` | client | owner + field validation |
| `goals` | client | `hasPlanAtLeast(['growth','complete'])` |
| `finance_transactions` | client | `hasPlanAtLeast(['complete'])` |
| `savings_goals` | client | `hasPlanAtLeast(['complete'])` |
| `workouts` | client | `hasPlanAtLeast(['complete'])` |
| `exercise_logs` | client | `hasPlanAtLeast(['complete'])` |
| `learning_items` | client | `hasPlanAtLeast(['complete'])` |
| `content_items` | client | `hasPlanAtLeast(['complete'])` |
| `settings/{doc}` | client | owner |
| `weekly_plans` | client | owner (no field validation yet; UI not built) |
| `subscription/status` | client `create` pinned to `starter`; **no update/delete** | see below |
| `progress_snapshots` | **Admin SDK only** | `allow write: if false` |
| `integrations/{id}` | **Admin SDK only** | `allow write: if false` |
| `reports/{id}` | **Admin SDK only** | `allow write: if false` |
| `secureTokens/{id}` | **Admin SDK only** | — |
| `fcmTokens/{token}` | client | owner + `token == {token}` |

`hasPlanAtLeast` is `isOwner(uid) && (betaAllAccess() || userPlan(uid) in plans)`.
While the closed beta is on, `betaAllAccess()` returns `true`, so the
plan-gated collections are open to everyone **provided the current rules are
actually deployed** — see `DEPLOYMENT_STATE.md`.

## Two rules that are easy to get wrong

**There is no catch-all `match`.** Firestore default-denies. A collection with
no `match` block in `firestore.rules` rejects every client read *and* write with
`permission-denied`. This shipped: `reminders` — one of the three pillars named
in the README — had no block at all, so the whole feature was dead in
production while looking complete in the UI. Adding a collection means adding
its rule in the same change.

**`habits` and `tasks` deny `create` on purpose.** Starter caps active habits at
3 and active tasks at 20. Security rules cannot count a collection, so the caps
are enforced in `createHabit` / `createTask`, which count inside a transaction
(a read-then-write would let N concurrent calls all observe the same
under-limit count and all succeed). `update` and `delete` stay client-direct.

Known gap, documented in `functions/src/tasks/createTask.ts`: the task cap is
enforced at creation only. A Starter user can park 20 tasks as `done`, create 20
more, then flip the first 20 back to `todo`. Closing it needs an
`onDocumentUpdated` trigger firing on every task edit — not worth an invocation
per keystroke-save for a limit that only binds on the free tier.

## Document shapes

Field names below are what the rules validate and the repositories read. Where
a rule constrains a value, the constraint is given.

### `habits/{habitId}`
`name` (non-empty), `category` ∈ `morning|evening|health|work`, `frequencyLabel`,
`colorValue` (number), `reminderTimeLabel` (nullable; must parse as `09:00` or
`9:00 AM` — an unparseable `99:99` once rolled a calendar reminder four days
into the future, so `createHabit` rejects it), `createdAt`, `updatedAt`.

### `habit_logs/{habitId}_{yyyy-MM-dd}`
`habitId` (non-empty), `date` (must match `^\d{4}-\d{2}-\d{2}$`), `completed`
(bool), `completedAt` (nullable timestamp). The doc id encodes habit + day, so a
day can only be logged once per habit.

### `tasks/{taskId}`
`title` (non-empty), `description`, `dueDate` (nullable), `priority` ∈
`low|medium|high`, `status` ∈ `todo|inProgress|done`, `relatedGoalId`
(nullable), `createdAt`, `updatedAt`. `createTask` always sets `status: "todo"`
— status is an update-time concern.

### `reminders/{reminderId}`
`title` (non-empty), `message`, `dueAt` (nullable timestamp), `status` ∈
`scheduled|completed|snoozed|missed`, `createdAt`, `updatedAt`, `notifiedAt`
(nullable timestamp, **written by the backend**).

`notifiedAt` is the idempotency marker for `sendDueReminders` — set once the
push has gone out, so a retried run doesn't send it twice. The client clears it
with `FieldValue.delete()` on every edit (`FirestoreReminderRepository`), which
is what re-arms a rescheduled reminder. That delete only works because the
update path uses `set(..., merge: true)`; `add()` and a non-merging `set()`
both reject the sentinel.

### `users/{uid}.appPreferences` — notification settings
A map on the user document, not a subcollection: the scheduled functions
already read this document for `timezone`, so the switches cost no extra read
per user per run, and there is no new collection needing its own `match` block.

| Field | Type | Meaning |
|---|---|---|
| `notificationsEnabled` | bool | Master switch. False suppresses every channel. |
| `notifyHabitReminders` | bool | Gates `sendHabitReminders`. |
| `notifyTaskDigest` | bool | Gates `sendDailyTaskDigest`. |
| `notifyReminderAlerts` | bool | Gates `sendDueReminders`. |
| `taskDigestHour` | int, **0..23 enforced by the rule** | Local hour the digest is sent. |

**Every field is optional, and absent means enabled.** None of them exist on a
profile written before the notification settings screen shipped; defaulting to
off would have silently stopped notifications for every existing account on
deploy. The client
(`lib/features/notifications/domain/notification_settings.dart`) and the
backend (`functions/src/notifications/preferences.ts`) both default this way,
and the key strings are shared between them by hand — rename one without the
other and the switch quietly stops doing anything.

`taskDigestHour` is validated in rules *and* clamped in the function. The
duplication is deliberate: an out-of-range hour never matches the hourly pass,
so the failure mode is a digest that just stops arriving, with nothing logged.

### `goals/{goalId}`
`title` (non-empty), `description`, `category` ∈
`career|finance|health|learning|personal`, `targetDate` (nullable),
`progressType` ∈ `percentage|milestones`, `manualProgress` (number, **0..1
inclusive — the rule enforces the range**), `milestones` (array of
`{id, title, isDone}`), `updatedAt`.

### `finance_transactions/{id}`
`type` ∈ `income|expense`, `amount` (number, **> 0**), `category`, `note`,
`date`, `createdAt`.

### `savings_goals/{id}`
`title` (non-empty), `targetAmount` (number, **> 0**), `currentAmount`,
`targetDate` (nullable), `createdAt`.

### `workouts/{id}` and `exercise_logs/{id}`
Workout: `name` (non-empty), `date`. Exercise log: `workoutId` (non-empty),
`name` (non-empty), `sets`, `reps`, `weight`, `isPersonalRecord`. Logs
reference workouts by id; nothing enforces referential integrity.

### `learning_items/{id}`
`title` (non-empty), `type` ∈ `book|course|podcast`, `status` ∈
`planned|inProgress|completed`, `rating` (0-5), `notes`, `keyTakeaways`
(string array), `updatedAt`.

### `content_items/{id}`
`title` (non-empty), `platform`, `publishDate` (nullable), `status` ∈
`idea|drafted|scheduled|published`, `updatedAt`.

### `users/{uid}` (the profile document)
`create` requires `uid` matching the path, a non-empty `email`, `createdAt` and
`updatedAt` timestamps, `selectedPlan` ∈ `starter|growth|complete`, and
`onboardingCompleted` (bool). Identity fields are immutable on update.

### `subscription/status`
`create` is allowed but pinned to `planId == 'starter'` with a
`billingProvider` string, so the sign-up bootstrap works without a Cloud
Function round-trip. `update` and `delete` are denied, so the document cannot be
escalated afterwards, nor deleted and re-created to reset it. Beta access is
deliberately **not** granted by writing `complete` here — it comes from
`betaAllAccess()`, keeping the grant in one auditable place instead of scattered
across every tester's user document.

## Verifying rules

`flutter test` cannot help: `fake_cloud_firestore` is an in-memory fake with no
rules engine, so it will happily accept writes production rejects. Nothing
automated currently asserts that the `habits`/`tasks` `create` denial holds.

The gap is real but it *has* been checked empirically — a full write pass
against `tasks-1903` on 2026-08-15 confirmed both creates route through the
callables and that an unruled collection is denied. To make it repeatable, set
up `firebase emulators:exec` with `@firebase/rules-unit-testing`, as
`SECURITY_REVIEW.md` recommends.
